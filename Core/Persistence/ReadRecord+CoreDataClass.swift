//
//  ReadRecord+CoreDataClass.swift
//  Legado-iOS
//
//  阅读记录实体 — 对标 Android ReadRecord
//

import Foundation
import CoreData

@objc(ReadRecord)
public class ReadRecord: NSManagedObject {
    @NSManaged public var deviceId: String
    @NSManaged public var bookName: String
    @NSManaged public var readTime: Int64      // 累计阅读时长（毫秒）
    @NSManaged public var lastRead: Int64      // 最后阅读时间戳
}

// MARK: - Fetch Request
extension ReadRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ReadRecord> {
        return NSFetchRequest<ReadRecord>(entityName: "ReadRecord")
    }
}

// MARK: - 计算属性
extension ReadRecord {
    var readTimeMinutes: Double {
        Double(readTime) / 60000.0
    }

    var lastReadDate: Date {
        Date(timeIntervalSince1970: TimeInterval(lastRead) / 1000.0)
    }
}

// MARK: - 初始化
extension ReadRecord {
    static func create(in context: NSManagedObjectContext, bookName: String) -> ReadRecord {
        let entity = NSEntityDescription.entity(forEntityName: "ReadRecord", in: context)!
        let r = ReadRecord(entity: entity, insertInto: context)
        r.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        r.bookName = bookName
        r.readTime = 0
        r.lastRead = Int64(Date().timeIntervalSince1970 * 1000)
        return r
    }
}
