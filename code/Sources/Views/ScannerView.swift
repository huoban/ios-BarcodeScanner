import AVFoundation
import CoreMedia
import SwiftUI

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
    @State private var showWeb = false
    @State private var webURL: URL?
    @State private var showPermissionAlert = false
    @State private var toast: String?
    @State private var isFlashOn = false
    @State private var scanStartTime = Date()
    @State private var lastHandledTimestamp: Int64 = 0

    private var isSubpageActive: Bool {
        showSettings || showHistory || showWeb
    }

    private var scannerSignature: String {
        let values: [Any] = [
            preferences.qrEnabled, preferences.dataMatrixEnabled, preferences.code39Enabled,
            preferences.upceanEnabled, preferences.code128Enabled, preferences.pdfEnabled,
            preferences.aztecEnabled, preferences.code93Enabled, preferences.code2of5Enabled,
            preferences.codabarEnabled, preferences.useFrontCamera, preferences.scanOrientation,
            preferences.scanningResolution, preferences.stringEncoding
        ]
        return values.map { String(describing: $0) }.joined(separator: "|")
    }

    var body: some View {
        NavigationView {
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
            .navigationBarHidden(true)
            .background(navigationLinks)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            self.showWelcomeIfNeeded()
            self.prepareCamera()
        }
        .onDisappear { self.scanner.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                self.prepareCamera()
            } else {
                self.scanner.stop()
            }
        }
        .onChange(of: showSettings) { _ in self.syncCameraState() }
        .onChange(of: showHistory) { _ in self.syncCameraState() }
        .onChange(of: showWeb) { _ in self.syncCameraState() }
        .onChange(of: showResult) { _ in self.syncCameraState() }
        .onChange(of: scannerSignature) { _ in
            // 设置在子页面中修改时先不重启相机，返回首页后由 syncCameraState 应用
            guard !self.isSubpageActive else { return }
            self.scanner.restart()
            self.scanner.setPaused(self.showResult)
        }
        .onReceive(scanner.$detected) { value in
            guard let (result, buffer) = value else { return }
            self.scanner.detected = nil
            self.handleDetected(result: result, buffer: buffer)
        }
        .onChange(of: toast) { _ in
            guard self.toast != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.toast = nil }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(title: Text("需要相机权限"), message: Text("请在系统设置中允许使用相机"), dismissButton: .default(Text("知道了")))
        }
    }

    @ViewBuilder
    private var navigationLinks: some View {
        ZStack {
            NavigationLink(
                destination: SettingsView().environmentObject(self.preferences),
                isActive: $showSettings
            ) { EmptyView() }
            NavigationLink(
                destination: HistoryView()
                    .environmentObject(self.preferences)
                    .environmentObject(self.store),
                isActive: $showHistory
            ) { EmptyView() }
            NavigationLink(
                destination: WebViewScreen(url: webURL ?? URL(string: "about:blank")!),
                isActive: $showWeb
            ) { EmptyView() }
        }
        .hidden()
    }

    private var controlButtons: some View {
        VStack(spacing: 12) {
            button(systemName: "gearshape") { self.showSettings = true }
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

    private func showWelcomeIfNeeded() {
        guard preferences.isFirstLaunch else { return }
        preferences.isFirstLaunch = false
        toast = "欢迎使用条码扫描记录！将摄像头对准条码即可自动识别。"
    }

    private func prepareCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            syncCameraState()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.syncCameraState()
                    } else {
                        self.showPermissionAlert = true
                    }
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    /// 与 Android onResume/onPause 一致：
    /// 子页面打开时停止相机；结果层显示时仅暂停解码；只有回到首页且无结果层时才恢复解码。
    private func syncCameraState() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        if isSubpageActive {
            scanner.setPaused(true)
            scanner.stop()
        } else if showResult {
            scanner.setPaused(true)
            scanner.start()
        } else {
            scanner.start()
            scanner.setPaused(false)
            scanner.resetConfirmation()
            scanStartTime = Date()
        }
    }

    private func handleDetected(result: ScanResult, buffer: CMSampleBuffer?) {
        // 双保险：同一时间戳的结果只处理一次
        guard result.timestamp != lastHandledTimestamp else { return }
        lastHandledTimestamp = result.timestamp

        // 解码确认时 BarcodeScanner 已同步置为暂停，这里先落盘再决定展示方式
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
            webURL = url
            showWeb = true
        } else {
            detectedResult = result
            durationText = String(format: "%.1f", Date().timeIntervalSince(scanStartTime))
            showResult = true
        }
    }

    private func dismissResult() {
        guard showResult else { return }
        showResult = false
        detectedResult = nil
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
                        self.webURL = url
                        self.showWeb = true
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
