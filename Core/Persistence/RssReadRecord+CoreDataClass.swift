//
//  RssReadRecord+CoreDataClass.swift
//  Legado-iOS
//
//  RSS 已读记录 — 对标 Android RssReadRecord
//

import Foundation
import CoreData

@objc(RssReadRecord)
public class RssReadRecord: NSManagedObject {
    @NSManaged public var record: String  // "origin##link" 复合主键
    @NSManaged public var read: Bool
}

// MARK: - Fetch Request
extension RssReadRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<RssReadRecord> {
        return NSFetchRequest<RssReadRecord>(entityName: "RssReadRecord")
    }
}

// MARK: - 初始化
extension RssReadRecord {
    static func create(in context: NSManagedObjectContext, origin: String, link: String) -> RssReadRecord {
        let entity = NSEntityDescription.entity(forEntityName: "RssReadRecord", in: context)!
        let rr = RssReadRecord(entity: entity, insertInto: context)
        rr.record = "\(origin)##\(link)"
        rr.read = true
        return rr
    }
}
