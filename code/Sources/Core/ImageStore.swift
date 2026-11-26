import CoreImage
import CoreMedia
import Foundation
import UIKit

/// 扫码截图保存，使用系统 ImageIO/JPEG 编码替代 Android WebP
enum ImageStore {
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save(sampleBuffer: CMSampleBuffer, timestamp: Int64) -> String? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
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

    static func delete(at path: String?) {
        guard let path = path, !path.isEmpty else { return }
        let canonical = (path as NSString).standardizingPath
        guard canonical.hasPrefix(directory.path + "/") else { return }
        try? FileManager.default.removeItem(atPath: canonical)
    }
}
