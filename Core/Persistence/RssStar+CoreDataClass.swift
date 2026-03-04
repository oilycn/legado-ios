//
//  RssStar+CoreDataClass.swift
//  Legado-iOS
//
//  RSS 收藏实体 — 对标 Android RssStar
//

import Foundation
import CoreData

@objc(RssStar)
public class RssStar: NSManagedObject {
    @NSManaged public var origin: String
    @NSManaged public var sort: String
    @NSManaged public var title: String
    @NSManaged public var starDate: Int64
    @NSManaged public var link: String
    @NSManaged public var pubDate: String?
    @NSManaged public var articleDescription: String?  // 避免与 NSObject.description 冲突
    @NSManaged public var content: String?
    @NSManaged public var image: String?
    @NSManaged public var variable: String?
}

// MARK: - Fetch Request
extension RssStar {
    @nonobjc class func fetchRequest() -> NSFetchRequest<RssStar> {
        return NSFetchRequest<RssStar>(entityName: "RssStar")
    }
}

// MARK: - 初始化
extension RssStar {
    static func create(in context: NSManagedObjectContext) -> RssStar {
        let entity = NSEntityDescription.entity(forEntityName: "RssStar", in: context)!
        let star = RssStar(entity: entity, insertInto: context)
        star.origin = ""
        star.sort = ""
        star.title = ""
        star.link = ""
        star.starDate = Int64(Date().timeIntervalSince1970 * 1000)
        return star
    }
}

// MARK: - JSON Codable
extension RssStar {
    struct CodableForm: Codable {
        var origin: String
        var sort: String
        var title: String
        var starDate: Int64
        var link: String
        var pubDate: String?
        var description: String?
        var content: String?
        var image: String?
        var variable: String?
    }

    var codableForm: CodableForm {
        CodableForm(origin: origin, sort: sort, title: title, starDate: starDate,
                     link: link, pubDate: pubDate, description: articleDescription,
                     content: content, image: image, variable: variable)
    }
}
