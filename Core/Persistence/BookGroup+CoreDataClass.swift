//
//  BookGroup+CoreDataClass.swift
//  Legado-iOS
//
//  书籍分组实体 — 对标 Android BookGroup
//

import Foundation
import CoreData

@objc(BookGroup)
public class BookGroup: NSManagedObject {
    @NSManaged public var groupId: Int64
    @NSManaged public var groupName: String
    @NSManaged public var cover: String?
    @NSManaged public var order: Int32
    @NSManaged public var enableRefresh: Bool
    @NSManaged public var show: Bool
}

// MARK: - Fetch Request
extension BookGroup {
    @nonobjc class func fetchRequest() -> NSFetchRequest<BookGroup> {
        return NSFetchRequest<BookGroup>(entityName: "BookGroup")
    }
}

// MARK: - 计算属性
extension BookGroup {
    /// Android 使用 flag 位掩码标识分组
    static let allGroupId: Int64 = -1
    static let noneGroupId: Int64 = -2
    static let errorGroupId: Int64 = -11
    static let localGroupId: Int64 = -12
    static let audioGroupId: Int64 = -13
    static let netNoneGroupId: Int64 = -14

    var isSystem: Bool { groupId < 0 }
}

// MARK: - 初始化
extension BookGroup {
    static func create(in context: NSManagedObjectContext, groupId: Int64 = 0, groupName: String = "") -> BookGroup {
        let entity = NSEntityDescription.entity(forEntityName: "BookGroup", in: context)!
        let group = BookGroup(entity: entity, insertInto: context)
        group.groupId = groupId == 0 ? Int64(Date().timeIntervalSince1970 * 1000) : groupId
        group.groupName = groupName
        group.order = 0
        group.enableRefresh = true
        group.show = true
        return group
    }
}

// MARK: - JSON Codable
extension BookGroup {
    struct CodableForm: Codable {
        var groupId: Int64
        var groupName: String
        var cover: String?
        var order: Int32
        var enableRefresh: Bool
        var show: Bool
    }

    var codableForm: CodableForm {
        CodableForm(groupId: groupId, groupName: groupName, cover: cover,
                     order: order, enableRefresh: enableRefresh, show: show)
    }

    func update(from form: CodableForm) {
        self.groupId = form.groupId
        self.groupName = form.groupName
        self.cover = form.cover
        self.order = form.order
        self.enableRefresh = form.enableRefresh
        self.show = form.show
    }
}
