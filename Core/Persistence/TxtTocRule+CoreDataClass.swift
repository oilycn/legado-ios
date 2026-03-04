//
//  TxtTocRule+CoreDataClass.swift
//  Legado-iOS
//
//  TXT 目录识别规则 — 对标 Android TxtTocRule
//

import Foundation
import CoreData

@objc(TxtTocRule)
public class TxtTocRule: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var rule: String
    @NSManaged public var serialNumber: Int32
    @NSManaged public var example: String?
    @NSManaged public var enabled: Bool
}

// MARK: - Fetch Request
extension TxtTocRule {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TxtTocRule> {
        return NSFetchRequest<TxtTocRule>(entityName: "TxtTocRule")
    }
}

// MARK: - 初始化
extension TxtTocRule {
    static func create(in context: NSManagedObjectContext) -> TxtTocRule {
        let entity = NSEntityDescription.entity(forEntityName: "TxtTocRule", in: context)!
        let tocRule = TxtTocRule(entity: entity, insertInto: context)
        tocRule.name = ""
        tocRule.rule = ""
        tocRule.serialNumber = 0
        tocRule.enabled = true
        return tocRule
    }
}

// MARK: - JSON Codable
extension TxtTocRule {
    struct CodableForm: Codable {
        var name: String
        var rule: String
        var serialNumber: Int32
        var example: String?
        var enabled: Bool
    }

    var codableForm: CodableForm {
        CodableForm(name: name, rule: rule, serialNumber: serialNumber,
                     example: example, enabled: enabled)
    }
}
