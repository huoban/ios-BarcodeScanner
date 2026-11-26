import AVFoundation
import CoreMedia
import Foundation
import UIKit

/// AVFoundation 原生扫码：预览、元数据识别、截图帧、闪光灯、变焦
final class BarcodeScanner: NSObject, ObservableObject {
    @Published var detected: (ScanResult, CMSampleBuffer?)?

    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.huoban.barcode.session")
    private let outputQueue = DispatchQueue(label: "com.huoban.barcode.output")
    private let stateLock = NSLock()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var device: AVCaptureDevice?
    private var isRunning = false
    private var isPaused = false
    private var latestBuffer: CMSampleBuffer?
    private var pendingText: String?
    private var confirmCount = 0

    private var horizontalOnly = false
    private var encoding = "UTF-8"
    private let preferences: Preferences

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        super.init()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            self.configure()
            self.session.startRunning()
            self.isRunning = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.session.stopRunning()
            self.isRunning = false
        }
    }

    func restart() {
        stop()
        start()
    }

    func setPaused(_ paused: Bool) {
        stateLock.lock()
        isPaused = paused
        if paused {
            pendingText = nil
            confirmCount = 0
        }
        stateLock.unlock()
    }

    func resetConfirmation() {
        stateLock.lock()
        pendingText = nil
        confirmCount = 0
        stateLock.unlock()
    }

    func toggleFlash() -> Bool {
        var enabled = false
        sessionQueue.sync { [weak self] in
            guard let self = self, let device = self.device, device.hasTorch, device.isTorchModeSupported(.on) else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = device.torchMode == .on ? .off : .on
                device.unlockForConfiguration()
                enabled = device.torchMode == .on
            } catch {
                NSLog("toggle torch failed: \(error)")
            }
        }
        return enabled
    }

    func toggleZoom() {
        sessionQueue.sync { [weak self] in
            guard let self = self, let device = self.device else { return }
            let minimum = device.minAvailableVideoZoomFactor
            let maximum = min(device.maxAvailableVideoZoomFactor, 6)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = device.videoZoomFactor <= minimum + 0.01 ? maximum : minimum
                device.unlockForConfiguration()
            } catch {
                NSLog("toggle zoom failed: \(error)")
            }
        }
    }

    private func configure() {
        horizontalOnly = preferences.scanOrientation == "Horizontal"
        encoding = preferences.stringEncoding

        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        let position: AVCaptureDevice.Position = preferences.useFrontCamera ? .front : .back
        let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)
        device = captureDevice

        if let captureDevice = captureDevice,
           let input = try? AVCaptureDeviceInput(device: captureDevice),
           session.canAddInput(input) {
            session.addInput(input)
        }

        let preset: AVCaptureSession.Preset = preferences.scanningResolution == "HD" ? .hd1280x720 : .hd1920x1080
        if session.canSetSessionPreset(preset) { session.sessionPreset = preset }

        metadataOutput.setMetadataObjectsDelegate(self, queue: outputQueue)
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = BarcodeFormat.enabledTypes(in: preferences)
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let initialZoom = Float(preferences.initialZoom), initialZoom > 0,
           let device = device, device.isZoomSupported() {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = min(max(initialZoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                device.unlockForConfiguration()
            } catch {
                NSLog("apply initial zoom failed: \(error)")
            }
        }

        session.commitConfiguration()
        resetConfirmation()
    }
}

extension AVCaptureDevice {
    func isZoomSupported() -> Bool { maxAvailableVideoZoomFactor > minAvailableVideoZoomFactor }
}

extension BarcodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        outputQueue.async { [weak self] in
            self?.latestBuffer = sampleBuffer
        }
    }
}

extension BarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let rawText = object.stringValue else { return }

        stateLock.lock()
        guard !isPaused else {
            stateLock.unlock()
            return
        }
        if horizontalOnly && !Self.isHorizontal(object.corners) {
            pendingText = nil
            confirmCount = 0
            stateLock.unlock()
            return
        }
        guard Self.isValidText(rawText) else {
            pendingText = nil
            confirmCount = 0
            stateLock.unlock()
            return
        }

        let text = Self.decode(rawText, encoding: encoding)
        let buffer = latestBuffer
        var emitted: (ScanResult, CMSampleBuffer?)?

        if text == pendingText {
            confirmCount += 1
            if confirmCount >= 2 {
                let displayName = BarcodeFormat.displayName(for: object.type)
                let result = ScanResult(
                    text: text,
                    barcodeType: displayName,
                    format: displayName,
                    isGS1: rawText.hasPrefix("]e0"),
                    orientation: 0,
                    timestamp: Int64(Date().timeIntervalSince1970 * 1000)
                )
                emitted = (result, buffer)
                pendingText = nil
                confirmCount = 0
            }
        } else {
            pendingText = text
            confirmCount = 1
        }
        stateLock.unlock()

        if let emitted = emitted {
            DispatchQueue.main.async { [weak self] in
                self?.detected = emitted
            }
        }
    }

    private static func isValidText(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 }
    }

    /// iOS 原生只提供解码字符串，按所选字符集对 UTF-8 字节做最佳-effort 重解码
    private static func decode(_ text: String, encoding: String) -> String {
        guard encoding != "UTF-8" else { return text }
        let cfEncoding: CFStringEncoding = encoding == "GBK"
            ? kCFStringEncodingGB_18030_2000
            : kCFStringEncodingISOLatin1
        let nsEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        return String(bytes: Array(text.utf8), encoding: nsEncoding) ?? text
    }

    private static func isHorizontal(_ corners: [Any]?) -> Bool {
        guard let corners = corners as? [[String: Any]], corners.count >= 2 else { return true }
        func value(_ dict: [String: Any], _ key: String) -> Double? {
            (dict[key] as? NSNumber)?.doubleValue ?? (dict[key] as? Double)
        }
        guard let x0 = value(corners[0], "X"), let y0 = value(corners[0], "Y"),
              let x1 = value(corners[1], "X"), let y1 = value(corners[1], "Y") else { return true }
        let dx = x1 - x0
        let dy = y1 - y0
        if dx == 0 && dy == 0 { return true }
        var angle = atan2(dy, dx) * 180 / Double.pi
        if angle < 0 { angle += 180 }
        return angle <= 20 || angle >= 160
    }
}
