import Foundation

struct ScanResult: Equatable {
    let text: String
    let barcodeType: String
    let format: String
    let isGS1: Bool
    let orientation: Int
    let timestamp: Int64
}
