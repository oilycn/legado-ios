//
//  CacheEntry+CoreDataClass.swift
//  Legado-iOS
//
//  缓存实体 — 对标 Android Cache（重命名避免与系统 NSCache 冲突）
//

import Foundation
import CoreData

@objc(CacheEntry)
public class CacheEntry: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String?
    @NSManaged public var deadLine: Int64  // 0 表示永不过期
}

// MARK: - Fetch Request
extension CacheEntry {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CacheEntry> {
        return NSFetchRequest<CacheEntry>(entityName: "CacheEntry")
    }
}

// MARK: - 计算属性
extension CacheEntry {
    var isExpired: Bool {
        guard deadLine > 0 else { return false }
        return Int64(Date().timeIntervalSince1970 * 1000) > deadLine
    }
}

// MARK: - 初始化
extension CacheEntry {
    static func create(in context: NSManagedObjectContext, key: String, value: String?, deadLine: Int64 = 0) -> CacheEntry {
        let entity = NSEntityDescription.entity(forEntityName: "CacheEntry", in: context)!
        let c = CacheEntry(entity: entity, insertInto: context)
        c.key = key
        c.value = value
        c.deadLine = deadLine
        return c
    }
}
