import AVFoundation
import CoreMedia
import SwiftUI

private struct WebItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ImageItem: Identifiable {
    let id = UUID()
    let path: String
}

struct ScannerView: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var store: HistoryStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var scanner = BarcodeScanner()
    @State private var detectedResult: ScanResult?
    @State private var durationText = "0.0"
    @State private var showResult = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showPermissionAlert = false
    @State private var webItem: WebItem?
    @State private var imageItem: ImageItem?
    @State private var toast: String?
    @State private var isFlashOn = false
    @State private var isZoomed = false
    @State private var scanStartTime = Date()

    private var scannerSignature: String {
        let values: [Any] = [
            preferences.qrEnabled, preferences.dataMatrixEnabled, preferences.code39Enabled,
            preferences.upceanEnabled, preferences.code128Enabled, preferences.pdfEnabled,
            preferences.aztecEnabled, preferences.code93Enabled, preferences.code2of5Enabled,
            preferences.codabarEnabled, preferences.useFrontCamera, preferences.scanOrientation,
            preferences.scanningResolution, preferences.stringEncoding, preferences.initialZoom
        ]
        return values.map { String(describing: $0) }.joined(separator: "|")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(scanner: scanner)
                    .ignoresSafeArea()

                ViewfinderOverlay(holeFrame: viewfinderFrame(in: geometry.size))
                    .ignoresSafeArea()

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { self.dismissResult() }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        controlButtons
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 32)
                }

                if showResult, let result = detectedResult {
                    resultCard(result: result)
                }

                if let toast = toast {
                    Text(toast)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .transition(.opacity)
                }
            }
        }
        .onAppear(perform: authorizeAndStart)
        .onDisappear { self.scanner.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                self.authorizeAndStart()
            } else {
                self.scanner.stop()
            }
        }
        .onChange(of: scannerSignature) { _ in
            self.scanner.restart()
            self.scanner.setPaused(false)
        }
        .onReceive(scanner.$detected) { value in
            guard let (result, buffer) = value else { return }
            self.scanner.detected = nil
            self.handleDetected(result: result, buffer: buffer)
        }
        .onChange(of: toast) { _ in
            guard self.toast != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.toast = nil }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(self.preferences)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(onOpenImage: { self.imageItem = ImageItem(path: $0) })
                .environmentObject(self.preferences)
                .environmentObject(self.store)
        }
        .sheet(item: $webItem) { item in
            WebViewScreen(url: item.url, onDismiss: self.resumeAfterSubsheet)
        }
        .sheet(item: $imageItem) { item in
            NavigationView {
                ZoomableImageView(path: item.path)
                    .navigationTitle("图片预览")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { self.imageItem = nil }
                        }
                    }
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(title: Text("需要相机权限"), message: Text("请在系统设置中允许使用相机"), dismissButton: .default(Text("知道了")))
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 12) {
            button(systemName: "gearshape") { self.showSettings = true }
            button(systemName: isZoomed ? "zoom.in" : "zoom.out") {
                self.scanner.toggleZoom()
                self.isZoomed.toggle()
            }
            button(systemName: isFlashOn ? "bolt.fill" : "bolt") {
                self.isFlashOn = self.scanner.toggleFlash()
            }
            button(systemName: "clock.arrow.circlepath") { self.showHistory = true }
        }
    }

    private func button(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .accessibilityLabel(systemName)
    }

    private func viewfinderFrame(in size: CGSize) -> CGRect {
        let mmToPoint = 160.0 / 25.4
        var width = floor(76 * mmToPoint)
        var height = floor(130 * mmToPoint)
        let maxWidth = size.width * 0.8
        let maxHeight = size.height * 0.8
        if width > maxWidth || height > maxHeight {
            let scale = min(maxWidth / width, maxHeight / height)
            width *= scale
            height *= scale
        }
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func authorizeAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            scanner.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.scanner.start() } else { self.showPermissionAlert = true }
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    private func handleDetected(result: ScanResult, buffer: CMSampleBuffer?) {
        let path = buffer.flatMap { ImageStore.save(sampleBuffer: $0, timestamp: result.timestamp) }
        store.insert(result: result, imagePath: path)

        if preferences.soundEnabled { SoundPlayer.play(preferences: preferences) }
        if preferences.vibrateEnabled { SoundPlayer.vibrate() }
        if preferences.autoCopyToClipboard {
            SoundPlayer.copyToClipboard(result.text)
            toast = "已复制到剪贴板"
        }

        scanner.setPaused(true)
        if preferences.openURLAutomatically,
           let url = Webhook.finalURL(base: preferences.webhookURL, result: result.text) {
            webItem = WebItem(url: url)
        } else {
            detectedResult = result
            durationText = String(format: "%.1f", Date().timeIntervalSince(scanStartTime))
            showResult = true
        }
    }

    private func dismissResult() {
        guard showResult else { return }
        showResult = false
        resumeAfterSubsheet()
    }

    private func resumeAfterSubsheet() {
        scanner.setPaused(false)
        scanner.resetConfirmation()
        scanStartTime = Date()
    }

    private func resultCard(result: ScanResult) -> some View {
        VStack(spacing: 12) {
            Text("点击空白处继续 \(durationText) 秒")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Text(result.barcodeType)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
            Text(result.format)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Text(result.text)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(5)
                .multilineTextAlignment(.center)
            HStack(spacing: 24) {
                Button("提交") {
                    if let url = Webhook.finalURL(base: self.preferences.webhookURL, result: result.text) {
                        self.webItem = WebItem(url: url)
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("复制") {
                    SoundPlayer.copyToClipboard(result.text)
                    self.toast = "已复制到剪贴板"
                }
                .buttonStyle(.bordered)
            }
            .foregroundColor(.white)
        }
        .padding(24)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
}
