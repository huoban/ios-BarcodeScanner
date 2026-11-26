import AVFoundation

/// 条码格式开关与 AVFoundation 原生类型的映射
enum BarcodeFormat: String, CaseIterable, Identifiable {
    case qr
    case dataMatrix
    case code39
    case upcean
    case code128
    case pdf
    case aztec
    case code93
    case code2of5
    case codabar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qr: return "QR"
        case .dataMatrix: return "DataMatrix"
        case .code39: return "Code39"
        case .upcean: return "UPCEAN"
        case .code128: return "Code128"
        case .pdf: return "PDF"
        case .aztec: return "Aztec"
        case .code93: return "Code93"
        case .code2of5: return "Code2of5"
        case .codabar: return "Codabar"
        }
    }

    var subtitle: String {
        switch self {
        case .qr: return "QR Code"
        case .dataMatrix: return "Data Matrix"
        case .code39: return "Code 39"
        case .upcean: return "EAN-13 / EAN-8 / UPC-A / UPC-E"
        case .code128: return "Code 128"
        case .pdf: return "PDF417"
        case .aztec: return "Aztec"
        case .code93: return "Code 93"
        case .code2of5: return "ITF"
        case .codabar: return "Codabar"
        }
    }

    var avTypes: [AVMetadataObject.ObjectType] {
        switch self {
        case .qr: return [.qr]
        case .dataMatrix: return [.dataMatrix]
        case .code39: return [.code39]
        case .upcean: return [.ean13, .ean8, .upce]
        case .code128: return [.code128]
        case .pdf: return [.pdf417]
        case .aztec: return [.aztec]
        case .code93: return [.code93]
        case .code2of5: return [.itf14]
        case .codabar:
            if #available(iOS 15.4, *) { return [.codabar] }
            return []
        }
    }

    func isEnabled(in preferences: Preferences) -> Bool {
        switch self {
        case .qr: return preferences.qrEnabled
        case .dataMatrix: return preferences.dataMatrixEnabled
        case .code39: return preferences.code39Enabled
        case .upcean: return preferences.upceanEnabled
        case .code128: return preferences.code128Enabled
        case .pdf: return preferences.pdfEnabled
        case .aztec: return preferences.aztecEnabled
        case .code93: return preferences.code93Enabled
        case .code2of5: return preferences.code2of5Enabled
        case .codabar: return preferences.codabarEnabled
        }
    }

    func setEnabled(_ value: Bool, in preferences: Preferences) {
        switch self {
        case .qr: preferences.qrEnabled = value
        case .dataMatrix: preferences.dataMatrixEnabled = value
        case .code39: preferences.code39Enabled = value
        case .upcean: preferences.upceanEnabled = value
        case .code128: preferences.code128Enabled = value
        case .pdf: preferences.pdfEnabled = value
        case .aztec: preferences.aztecEnabled = value
        case .code93: preferences.code93Enabled = value
        case .code2of5: preferences.code2of5Enabled = value
        case .codabar: preferences.codabarEnabled = value
        }
    }

    static func displayName(for type: AVMetadataObject.ObjectType) -> String {
        if #available(iOS 15.4, *), type == .codabar { return "Codabar" }
        switch type {
        case .qr: return "QR Code"
        case .dataMatrix: return "Data Matrix"
        case .code39: return "Code 39"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upce: return "UPC-E"
        case .code128: return "Code 128"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .code93: return "Code 93"
        case .itf14: return "ITF"
        default: return "Unknown (\(type.rawValue))"
        }
    }

    static func enabledTypes(in preferences: Preferences) -> [AVMetadataObject.ObjectType] {
        var result: [AVMetadataObject.ObjectType] = []
        for format in BarcodeFormat.allCases where format.isEnabled(in: preferences) {
            result.append(contentsOf: format.avTypes)
        }
        return result.isEmpty ? [.code128] : result
    }
}
