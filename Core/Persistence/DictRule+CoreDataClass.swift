//
//  DictRule+CoreDataClass.swift
//  Legado-iOS
//
//  词典规则实体 — 对标 Android DictRule
//

import Foundation
import CoreData

@objc(DictRule)
public class DictRule: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var urlRule: String
    @NSManaged public var showRule: String
    @NSManaged public var enabled: Bool
    @NSManaged public var sortNumber: Int32
}

// MARK: - Fetch Request
extension DictRule {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DictRule> {
        return NSFetchRequest<DictRule>(entityName: "DictRule")
    }
}

// MARK: - 初始化
extension DictRule {
    static func create(in context: NSManagedObjectContext) -> DictRule {
        let entity = NSEntityDescription.entity(forEntityName: "DictRule", in: context)!
        let rule = DictRule(entity: entity, insertInto: context)
        rule.name = ""
        rule.urlRule = ""
        rule.showRule = ""
        rule.enabled = true
        rule.sortNumber = 0
        return rule
    }
}

// MARK: - JSON Codable
extension DictRule {
    struct CodableForm: Codable {
        var name: String
        var urlRule: String
        var showRule: String
        var enabled: Bool
        var sortNumber: Int32
    }

    var codableForm: CodableForm {
        CodableForm(name: name, urlRule: urlRule, showRule: showRule,
                     enabled: enabled, sortNumber: sortNumber)
    }
}
