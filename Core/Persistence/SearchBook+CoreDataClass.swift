//
//  SearchBook+CoreDataClass.swift
//  Legado-iOS
//
//  搜索结果实体 — 对标 Android SearchBook
//

import Foundation
import CoreData

@objc(SearchBook)
public class SearchBook: NSManagedObject {
    @NSManaged public var bookUrl: String
    @NSManaged public var origin: String
    @NSManaged public var originName: String
    @NSManaged public var type: Int32
    @NSManaged public var name: String
    @NSManaged public var author: String
    @NSManaged public var kind: String?
    @NSManaged public var coverUrl: String?
    @NSManaged public var intro: String?
    @NSManaged public var wordCount: String?
    @NSManaged public var latestChapterTitle: String?
    @NSManaged public var tocUrl: String?
    @NSManaged public var time: Int64
    @NSManaged public var variable: String?
    @NSManaged public var originOrder: Int32
}

// MARK: - Fetch Request
extension SearchBook {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SearchBook> {
        return NSFetchRequest<SearchBook>(entityName: "SearchBook")
    }
}

// MARK: - 计算属性
extension SearchBook {
    var displayName: String { name }
    var displayAuthor: String { author }
    var displayCoverUrl: String? { coverUrl }
    var displayIntro: String? { intro }
}

// MARK: - 初始化
extension SearchBook {
    static func create(in context: NSManagedObjectContext) -> SearchBook {
        let entity = NSEntityDescription.entity(forEntityName: "SearchBook", in: context)!
        let sb = SearchBook(entity: entity, insertInto: context)
        sb.name = ""
        sb.author = ""
        sb.bookUrl = ""
        sb.origin = ""
        sb.originName = ""
        sb.type = 0
        sb.time = Int64(Date().timeIntervalSince1970 * 1000)
        sb.originOrder = 0
        return sb
    }
}

// MARK: - JSON Codable
extension SearchBook {
    struct CodableForm: Codable {
        var bookUrl: String
        var origin: String
        var originName: String
        var type: Int32
        var name: String
        var author: String
        var kind: String?
        var coverUrl: String?
        var intro: String?
        var wordCount: String?
        var latestChapterTitle: String?
        var tocUrl: String?
        var time: Int64
        var variable: String?
        var originOrder: Int32
    }

    var codableForm: CodableForm {
        CodableForm(bookUrl: bookUrl, origin: origin, originName: originName,
                     type: type, name: name, author: author, kind: kind,
                     coverUrl: coverUrl, intro: intro, wordCount: wordCount,
                     latestChapterTitle: latestChapterTitle, tocUrl: tocUrl,
                     time: time, variable: variable, originOrder: originOrder)
    }
}
