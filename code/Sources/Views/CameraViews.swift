import AVFoundation
import SwiftUI
import UIKit

final class PreviewContainerView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        backgroundColor = .black
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreview: UIViewRepresentable {
    let scanner: BarcodeScanner

    func makeUIView(context: Context) -> PreviewContainerView {
        PreviewContainerView(previewLayer: scanner.previewLayer)
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}
}

final class ViewfinderDrawView: UIView {
    var holeFrame: CGRect = .zero {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let hole = UIBezierPath(roundedRect: holeFrame, cornerRadius: 8)
        UIColor.black.withAlphaComponent(0.5).setFill()
        UIRectFill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(0, holeFrame.minY - rect.minY)))
        UIRectFill(CGRect(x: rect.minX, y: holeFrame.maxY, width: rect.width, height: max(0, rect.maxY - holeFrame.maxY)))
        UIRectFill(CGRect(x: rect.minX, y: holeFrame.minY, width: max(0, holeFrame.minX - rect.minX), height: holeFrame.height))
        UIRectFill(CGRect(x: holeFrame.maxX, y: holeFrame.minY, width: max(0, rect.maxX - holeFrame.maxX), height: holeFrame.height))
        UIColor.green.setStroke()
        hole.lineWidth = 2
        hole.stroke()
    }
}

struct ViewfinderOverlay: UIViewRepresentable {
    let holeFrame: CGRect

    func makeUIView(context: Context) -> ViewfinderDrawView {
        let view = ViewfinderDrawView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ViewfinderDrawView, context: Context) {
        uiView.holeFrame = holeFrame
    }
}
