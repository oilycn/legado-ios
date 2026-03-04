//
//  RssSource+CoreDataClass.swift
//  Legado-iOS
//
//  RSS 订阅源实体 — 对标 Android RssSource
//

import Foundation
import CoreData

@objc(RssSource)
public class RssSource: NSManagedObject {
    // MARK: - 基本信息
    @NSManaged public var sourceUrl: String
    @NSManaged public var sourceName: String
    @NSManaged public var sourceIcon: String?
    @NSManaged public var sourceGroup: String?
    @NSManaged public var sourceComment: String?
    @NSManaged public var enabled: Bool
    @NSManaged public var sortUrl: String?
    @NSManaged public var singleUrl: Bool
    @NSManaged public var articleStyle: Int32  // 0=默认, 1=全文, 2=图片

    // MARK: - 请求配置
    @NSManaged public var header: String?
    @NSManaged public var loginUrl: String?
    @NSManaged public var loginUi: String?
    @NSManaged public var loginCheckJs: String?
    @NSManaged public var concurrentRate: String?
    @NSManaged public var jsLib: String?
    @NSManaged public var enabledCookieJar: Bool

    // MARK: - 列表规则
    @NSManaged public var ruleArticles: String?
    @NSManaged public var ruleNextPage: String?
    @NSManaged public var ruleTitle: String?
    @NSManaged public var rulePubDate: String?
    @NSManaged public var ruleDescription: String?
    @NSManaged public var ruleImage: String?
    @NSManaged public var ruleLink: String?

    // MARK: - 正文规则
    @NSManaged public var ruleContent: String?
    @NSManaged public var style: String?
    @NSManaged public var injectJs: String?
    @NSManaged public var enableJs: Bool

    // MARK: - 排序与时间
    @NSManaged public var customOrder: Int32
    @NSManaged public var lastUpdateTime: Int64
    @NSManaged public var variable: String?
    @NSManaged public var variableComment: String?
    @NSManaged public var customTag: String?
    @NSManaged public var coverDecodeJs: String?
}

// MARK: - Fetch Request
extension RssSource {
    @nonobjc class func fetchRequest() -> NSFetchRequest<RssSource> {
        return NSFetchRequest<RssSource>(entityName: "RssSource")
    }
}

// MARK: - 计算属性
extension RssSource {
    var displayName: String { sourceName }
    var displayIcon: String? { sourceIcon }
}

// MARK: - 初始化
extension RssSource {
    static func create(in context: NSManagedObjectContext) -> RssSource {
        let entity = NSEntityDescription.entity(forEntityName: "RssSource", in: context)!
        let source = RssSource(entity: entity, insertInto: context)
        source.sourceUrl = ""
        source.sourceName = ""
        source.enabled = true
        source.singleUrl = false
        source.articleStyle = 0
        source.enabledCookieJar = false
        source.enableJs = false
        source.customOrder = 0
        source.lastUpdateTime = Int64(Date().timeIntervalSince1970 * 1000)
        return source
    }
}

// MARK: - JSON Codable
extension RssSource {
    struct CodableForm: Codable {
        var sourceUrl: String
        var sourceName: String
        var sourceIcon: String?
        var sourceGroup: String?
        var sourceComment: String?
        var enabled: Bool
        var sortUrl: String?
        var singleUrl: Bool
        var articleStyle: Int32
        var header: String?
        var loginUrl: String?
        var loginUi: String?
        var loginCheckJs: String?
        var concurrentRate: String?
        var jsLib: String?
        var enabledCookieJar: Bool
        var ruleArticles: String?
        var ruleNextPage: String?
        var ruleTitle: String?
        var rulePubDate: String?
        var ruleDescription: String?
        var ruleImage: String?
        var ruleLink: String?
        var ruleContent: String?
        var style: String?
        var injectJs: String?
        var enableJs: Bool
        var customOrder: Int32
        var lastUpdateTime: Int64
        var variable: String?
        var variableComment: String?
        var customTag: String?
        var coverDecodeJs: String?
    }

    var codableForm: CodableForm {
        CodableForm(
            sourceUrl: sourceUrl, sourceName: sourceName, sourceIcon: sourceIcon,
            sourceGroup: sourceGroup, sourceComment: sourceComment, enabled: enabled,
            sortUrl: sortUrl, singleUrl: singleUrl, articleStyle: articleStyle,
            header: header, loginUrl: loginUrl, loginUi: loginUi,
            loginCheckJs: loginCheckJs, concurrentRate: concurrentRate,
            jsLib: jsLib, enabledCookieJar: enabledCookieJar,
            ruleArticles: ruleArticles, ruleNextPage: ruleNextPage,
            ruleTitle: ruleTitle, rulePubDate: rulePubDate,
            ruleDescription: ruleDescription, ruleImage: ruleImage,
            ruleLink: ruleLink, ruleContent: ruleContent, style: style,
            injectJs: injectJs, enableJs: enableJs, customOrder: customOrder,
            lastUpdateTime: lastUpdateTime, variable: variable,
            variableComment: variableComment, customTag: customTag,
            coverDecodeJs: coverDecodeJs
        )
    }

    func update(from form: CodableForm) {
        self.sourceUrl = form.sourceUrl
        self.sourceName = form.sourceName
        self.sourceIcon = form.sourceIcon
        self.sourceGroup = form.sourceGroup
        self.sourceComment = form.sourceComment
        self.enabled = form.enabled
        self.sortUrl = form.sortUrl
        self.singleUrl = form.singleUrl
        self.articleStyle = form.articleStyle
        self.header = form.header
        self.loginUrl = form.loginUrl
        self.loginUi = form.loginUi
        self.loginCheckJs = form.loginCheckJs
        self.concurrentRate = form.concurrentRate
        self.jsLib = form.jsLib
        self.enabledCookieJar = form.enabledCookieJar
        self.ruleArticles = form.ruleArticles
        self.ruleNextPage = form.ruleNextPage
        self.ruleTitle = form.ruleTitle
        self.rulePubDate = form.rulePubDate
        self.ruleDescription = form.ruleDescription
        self.ruleImage = form.ruleImage
        self.ruleLink = form.ruleLink
        self.ruleContent = form.ruleContent
        self.style = form.style
        self.injectJs = form.injectJs
        self.enableJs = form.enableJs
        self.customOrder = form.customOrder
        self.lastUpdateTime = form.lastUpdateTime
        self.variable = form.variable
        self.variableComment = form.variableComment
        self.customTag = form.customTag
        self.coverDecodeJs = form.coverDecodeJs
    }
}
