//
//  Cookie+CoreDataClass.swift
//  Legado-iOS
//
//  Cookie 存储实体 — 对标 Android Cookie
//

import Foundation
import CoreData

@objc(Cookie)
public class Cookie: NSManagedObject {
    @NSManaged public var url: String
    @NSManaged public var cookie: String
}

// MARK: - Fetch Request
extension Cookie {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Cookie> {
        return NSFetchRequest<Cookie>(entityName: "Cookie")
    }
}

// MARK: - 初始化
extension Cookie {
    static func create(in context: NSManagedObjectContext, url: String, cookie: String) -> Cookie {
        let entity = NSEntityDescription.entity(forEntityName: "Cookie", in: context)!
        let c = Cookie(entity: entity, insertInto: context)
        c.url = url
        c.cookie = cookie
        return c
    }
}
