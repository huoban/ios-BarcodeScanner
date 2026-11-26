import Foundation

enum Webhook {
    /// Android Uri.encode 的字符集：保留未保留字符，其余百分号编码
    private static let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")

    static func finalURL(base: String, result: String) -> URL? {
        let encoded = result.addingPercentEncoding(withAllowedCharacters: allowed) ?? result
        let value = base.contains("{result}")
            ? base.replacingOccurrences(of: "{result}", with: encoded)
            : base + encoded
        return URL(string: value)
    }
}

struct RemoteItem: Identifiable {
    let id = UUID()
    let title: String
    let time: String?
}

enum RemoteQuery {
    static func fetch(baseURL: String, query: String, completion: @escaping (Result<[RemoteItem], Error>) -> Void) {
        guard let url = Webhook.finalURL(base: baseURL, result: query) else {
            completion(.failure(NSError(domain: "RemoteQuery", code: -1)))
            return
        }
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, !data.isEmpty else {
                completion(.failure(NSError(domain: "RemoteQuery", code: -2)))
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let message = (json["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                var items: [RemoteItem] = []
                if let array = json["data"] as? [[String: Any]] {
                    for entry in array {
                        let identifier = ((entry["id"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let timestamp = ((entry["timestamp"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if identifier.isEmpty && timestamp.isEmpty { continue }
                        let title = message.isEmpty ? identifier : message + identifier
                        items.append(RemoteItem(title: title, time: timestamp.isEmpty ? nil : timestamp))
                    }
                }
                if items.isEmpty {
                    items.append(RemoteItem(title: message.isEmpty ? "无匹配：" : message, time: nil))
                }
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum CsvExporter {
    static func export(records: [HistoryRecord]) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("barcode_history_\(formatter.string(from: Date())).csv")
        var lines = ["序号,条码类型,条码格式,扫描结果,是否GS1,扫描时间,方向"]
        for (index, record) in records.enumerated() {
            let result = record.resultText
                .replacingOccurrences(of: ",", with: "，")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\"", with: "\"\"")
            let date = Date(timeIntervalSince1970: Double(record.timestamp) / 1000)
            let display = Self.displayFormatter.string(from: date)
            lines.append("\(index + 1),\(record.barcodeType),\(record.barcodeFormat),\"\(result)\",\(record.isGS1 ? "是" : "否"),\(display),\(record.orientation)")
        }
        let content = lines.joined(separator: "\n") + "\n"
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            NSLog("CSV export failed: \(error)")
            return nil
        }
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
