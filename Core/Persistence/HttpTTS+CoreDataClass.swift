//
//  HttpTTS+CoreDataClass.swift
//  Legado-iOS
//
//  在线 TTS 引擎配置 — 对标 Android HttpTTS
//

import Foundation
import CoreData

@objc(HttpTTS)
public class HttpTTS: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var name: String
    @NSManaged public var url: String
    @NSManaged public var header: String?
    @NSManaged public var loginUrl: String?
    @NSManaged public var loginUi: String?
    @NSManaged public var loginCheckJs: String?
    @NSManaged public var contentType: String?
    @NSManaged public var concurrentRate: String?
    @NSManaged public var enabled: Bool
    @NSManaged public var order: Int32
}

// MARK: - Fetch Request
extension HttpTTS {
    @nonobjc class func fetchRequest() -> NSFetchRequest<HttpTTS> {
        return NSFetchRequest<HttpTTS>(entityName: "HttpTTS")
    }
}

// MARK: - 初始化
extension HttpTTS {
    static func create(in context: NSManagedObjectContext) -> HttpTTS {
        let entity = NSEntityDescription.entity(forEntityName: "HttpTTS", in: context)!
        let tts = HttpTTS(entity: entity, insertInto: context)
        tts.id = Int64(Date().timeIntervalSince1970 * 1000)
        tts.name = ""
        tts.url = ""
        tts.enabled = true
        tts.order = 0
        return tts
    }
}

// MARK: - JSON Codable
extension HttpTTS {
    struct CodableForm: Codable {
        var id: Int64
        var name: String
        var url: String
        var header: String?
        var loginUrl: String?
        var loginUi: String?
        var loginCheckJs: String?
        var contentType: String?
        var concurrentRate: String?
        var enabled: Bool
        var order: Int32
    }

    var codableForm: CodableForm {
        CodableForm(id: id, name: name, url: url, header: header,
                     loginUrl: loginUrl, loginUi: loginUi,
                     loginCheckJs: loginCheckJs, contentType: contentType,
                     concurrentRate: concurrentRate, enabled: enabled, order: order)
    }

    func update(from form: CodableForm) {
        self.id = form.id
        self.name = form.name
        self.url = form.url
        self.header = form.header
        self.loginUrl = form.loginUrl
        self.loginUi = form.loginUi
        self.loginCheckJs = form.loginCheckJs
        self.contentType = form.contentType
        self.concurrentRate = form.concurrentRate
        self.enabled = form.enabled
        self.order = form.order
    }
}
