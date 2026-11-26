import CoreImage
import CoreMedia
import Foundation
import ImageIO
import UIKit

/// 扫码截图保存，使用系统 ImageIO/JPEG 编码替代 Android WebP
enum ImageStore {
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 相机分析帧是横向像素，按竖屏方向烘焙旋转，保证保存的截图与预览始终为竖屏
    static func save(sampleBuffer: CMSampleBuffer, timestamp: Int64, isFrontCamera: Bool) -> String? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let orientation: CGImagePropertyOrientation = isFrontCamera ? .leftMirrored : .right
        let oriented = ciImage.oriented(orientation)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(oriented, from: oriented.extent) else { return nil }
        return save(uiImage: UIImage(cgImage: cgImage, scale: 1, orientation: .up), timestamp: timestamp)
    }

    static func save(uiImage: UIImage, timestamp: Int64) -> String? {
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return nil }
        let url = directory.appendingPathComponent("\(timestamp).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            NSLog("save screenshot failed: \(error)")
            return nil
        }
    }

    static func image(at path: String?) -> UIImage? {
        guard let path = path, !path.isEmpty else { return nil }
        let canonical = (path as NSString).standardizingPath
        guard canonical.hasPrefix(directory.path + "/") else { return nil }
        return UIImage(contentsOfFile: canonical)
    }

    /// 预览专用：历史遗留的横屏截图也统一转成竖屏显示
    static func portraitImage(at path: String?) -> UIImage? {
        guard let image = image(at: path) else { return nil }
        guard image.size.width > image.size.height else { return image }
        let size = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            cgContext.rotate(by: .pi / 2)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    static func delete(at path: String?) {
        guard let path = path, !path.isEmpty else { return }
        let canonical = (path as NSString).standardizingPath
        guard canonical.hasPrefix(directory.path + "/") else { return }
        try? FileManager.default.removeItem(atPath: canonical)
    }
}
