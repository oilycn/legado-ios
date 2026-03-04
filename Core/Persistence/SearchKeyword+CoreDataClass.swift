//
//  SearchKeyword+CoreDataClass.swift
//  Legado-iOS
//
//  搜索关键词历史 — 对标 Android SearchKeyword
//

import Foundation
import CoreData

@objc(SearchKeyword)
public class SearchKeyword: NSManagedObject {
    @NSManaged public var word: String
    @NSManaged public var usage: Int32
    @NSManaged public var lastUseTime: Int64
}

// MARK: - Fetch Request
extension SearchKeyword {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SearchKeyword> {
        return NSFetchRequest<SearchKeyword>(entityName: "SearchKeyword")
    }
}

// MARK: - 初始化
extension SearchKeyword {
    static func create(in context: NSManagedObjectContext, word: String) -> SearchKeyword {
        let entity = NSEntityDescription.entity(forEntityName: "SearchKeyword", in: context)!
        let kw = SearchKeyword(entity: entity, insertInto: context)
        kw.word = word
        kw.usage = 1
        kw.lastUseTime = Int64(Date().timeIntervalSince1970 * 1000)
        return kw
    }
}
