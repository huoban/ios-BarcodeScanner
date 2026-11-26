import CoreData
import Foundation

@objc(HistoryRecord)
final class HistoryRecord: NSManagedObject {
    @NSManaged var id: Int64
    @NSManaged var barcodeType: String
    @NSManaged var barcodeFormat: String
    @NSManaged var resultText: String
    @NSManaged var isGS1: Bool
    @NSManaged var rawBytes: Data?
    @NSManaged var orientation: Int32
    @NSManaged var timestamp: Int64
    @NSManaged var imagePath: String?
}

/// 使用 Foundation 原生 Core Data 替代 Android Room
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    init() {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "HistoryRecord"
        entity.managedObjectClassName = NSStringFromClass(HistoryRecord.self)
        entity.properties = [
            Self.attribute("id", .integer64AttributeType, optional: false),
            Self.attribute("barcodeType", .stringAttributeType, optional: false),
            Self.attribute("barcodeFormat", .stringAttributeType, optional: false),
            Self.attribute("resultText", .stringAttributeType, optional: false),
            Self.attribute("isGS1", .booleanAttributeType, optional: false),
            Self.attribute("rawBytes", .binaryDataAttributeType, optional: true),
            Self.attribute("orientation", .integer32AttributeType, optional: false),
            Self.attribute("timestamp", .integer64AttributeType, optional: false),
            Self.attribute("imagePath", .stringAttributeType, optional: true)
        ]
        model.entities = [entity]

        container = NSPersistentContainer(name: "BarcodeScanner", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error {
                NSLog("Core Data load failed: \(error)")
            }
        }
        context = container.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
        let description = NSAttributeDescription()
        description.name = name
        description.attributeType = type
        description.isOptional = optional
        return description
    }

    func allRecords() -> [HistoryRecord] {
        let request = NSFetchRequest<HistoryRecord>(entityName: "HistoryRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func search(_ query: String) -> [HistoryRecord] {
        guard !query.isEmpty else { return allRecords() }
        let request = NSFetchRequest<HistoryRecord>(entityName: "HistoryRecord")
        request.predicate = NSPredicate(format: "resultText CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func insert(result: ScanResult, imagePath: String?) {
        let record = NSEntityDescription.insertNewObject(forEntityName: "HistoryRecord", into: context) as! HistoryRecord
        record.id = (allRecords().map(\.id).max() ?? 0) + 1
        record.barcodeType = result.barcodeType
        record.barcodeFormat = result.format
        record.resultText = result.text
        record.isGS1 = result.isGS1
        record.rawBytes = Data(result.text.utf8)
        record.orientation = Int32(result.orientation)
        record.timestamp = result.timestamp
        record.imagePath = imagePath
        save()
    }

    /// 保留今天及往前 days-1 个自然日
    func deleteOlderThan(days: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoffDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return }
        let cutoff = Int64(cutoffDate.timeIntervalSince1970 * 1000)
        let request = NSFetchRequest<HistoryRecord>(entityName: "HistoryRecord")
        request.predicate = NSPredicate(format: "timestamp < %lld", cutoff)
        let records = (try? context.fetch(request)) ?? []
        for record in records {
            ImageStore.delete(at: record.imagePath)
            context.delete(record)
        }
        save()
    }

    func deleteAll() {
        let records = allRecords()
        for record in records {
            ImageStore.delete(at: record.imagePath)
            context.delete(record)
        }
        save()
    }

    private func save() {
        try? context.save()
        objectWillChange.send()
    }
}
