//
//  RssArticle+CoreDataClass.swift
//  Legado-iOS
//
//  RSS 文章实体 — 对标 Android RssArticle
//

import Foundation
import CoreData

@objc(RssArticle)
public class RssArticle: NSManagedObject {
    @NSManaged public var origin: String
    @NSManaged public var sort: String
    @NSManaged public var title: String
    @NSManaged public var order: Int32
    @NSManaged public var link: String
    @NSManaged public var pubDate: String?
    @NSManaged public var articleDescription: String?  // 避免与 NSObject.description 冲突
    @NSManaged public var content: String?
    @NSManaged public var image: String?
    @NSManaged public var read: Bool
    @NSManaged public var variable: String?
}

// MARK: - Fetch Request
extension RssArticle {
    @nonobjc class func fetchRequest() -> NSFetchRequest<RssArticle> {
        return NSFetchRequest<RssArticle>(entityName: "RssArticle")
    }
}

// MARK: - 初始化
extension RssArticle {
    static func create(in context: NSManagedObjectContext) -> RssArticle {
        let entity = NSEntityDescription.entity(forEntityName: "RssArticle", in: context)!
        let article = RssArticle(entity: entity, insertInto: context)
        article.origin = ""
        article.sort = ""
        article.title = ""
        article.link = ""
        article.order = 0
        article.read = false
        return article
    }
}

// MARK: - JSON Codable
extension RssArticle {
    struct CodableForm: Codable {
        var origin: String
        var sort: String
        var title: String
        var order: Int32
        var link: String
        var pubDate: String?
        var description: String?
        var content: String?
        var image: String?
        var read: Bool
        var variable: String?
    }

    var codableForm: CodableForm {
        CodableForm(origin: origin, sort: sort, title: title, order: order,
                     link: link, pubDate: pubDate, description: articleDescription,
                     content: content, image: image, read: read, variable: variable)
    }
}
