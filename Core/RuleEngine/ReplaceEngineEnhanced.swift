//
//  ReplaceEngineEnhanced.swift
//  Legado-iOS
//
//  替换规则引擎增强功能
//  P1-T9 实现
//

import Foundation
import CoreData

// MARK: - 替换规则组

struct ReplaceRuleGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var rules: [ReplaceRuleItem]
    var enabled: Bool
    var sortOrder: Int
    
    init(name: String, rules: [ReplaceRuleItem] = [], enabled: Bool = true, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.rules = rules
        self.enabled = enabled
        self.sortOrder = sortOrder
    }
}

// MARK: - 替换规则项（用于导入导出）

struct ReplaceRuleItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var pattern: String
    var replacement: String
    var scope: String // global, book, chapter
    var scopeId: String? // 书籍 ID 或章节 ID
    var isRegex: Bool
    var enabled: Bool
    var priority: Int
    var order: Int
    
    init(
        name: String,
        pattern: String,
        replacement: String,
        scope: String = "global",
        scopeId: String? = nil,
        isRegex: Bool = false,
        enabled: Bool = true,
        priority: Int = 0,
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
        self.scope = scope
        self.scopeId = scopeId
        self.isRegex = isRegex
        self.enabled = enabled
        self.priority = priority
        self.order = order
    }
    
    /// 从 CoreData 实体创建
    init(from rule: ReplaceRule) {
        self.id = rule.ruleId
        self.name = rule.name
        self.pattern = rule.pattern
        self.replacement = rule.replacement
        self.scope = rule.scope
        self.scopeId = rule.scopeId
        self.isRegex = rule.isRegex
        self.enabled = rule.enabled
        self.priority = Int(rule.priority)
        self.order = Int(rule.order)
    }
}

// MARK: - 替换引擎增强版

class ReplaceEngineEnhanced {
    
    // MARK: - 单例
    
    static let shared = ReplaceEngineEnhanced()
    
    private let baseEngine = ReplaceEngine.shared
    
    // MARK: - 缓存
    
    private var ruleCache: [String: [ReplaceRuleItem]] = [:]
    private var groupCache: [String: ReplaceRuleGroup] = [:]
    
    // MARK: - 应用替换规则（增强版）
    
    /// 应用所有匹配的替换规则
    func applyEnhanced(
        text: String,
        scope: String = "global",
        scopeId: String? = nil,
        context: NSManagedObjectContext? = nil
    ) -> String {
        var result = text
        
        // 获取适用规则
        let applicableRules = getApplicableRules(scope: scope, scopeId: scopeId, context: context)
        
        // 应用规则
        result = baseEngine.apply(text: result, items: applicableRules)
        
        return result
    }
    
    /// 应用书籍级规则
    func applyBookRules(text: String, bookId: UUID, context: NSManagedObjectContext? = nil) -> String {
        return applyEnhanced(text: text, scope: "book", scopeId: bookId.uuidString, context: context)
    }
    
    /// 应用章节级规则
    func applyChapterRules(text: String, chapterId: UUID, context: NSManagedObjectContext? = nil) -> String {
        return applyEnhanced(text: text, scope: "chapter", scopeId: chapterId.uuidString, context: context)
    }
    
    // MARK: - 规则管理
    
    /// 获取适用的规则
    private func getApplicableRules(
        scope: String,
        scopeId: String?,
        context: NSManagedObjectContext?
    ) -> [ReplaceRuleItem] {
        var rules: [ReplaceRuleItem] = []
        
        // 全局规则
        rules.append(contentsOf: getRules(scope: "global", scopeId: nil, context: context))
        
        // 书籍级规则
        if scope != "global", let id = scopeId {
            rules.append(contentsOf: getRules(scope: "book", scopeId: id, context: context))
        }
        
        // 章节级规则
        if scope == "chapter", let id = scopeId {
            rules.append(contentsOf: getRules(scope: "chapter", scopeId: id, context: context))
        }
        
        return rules
    }
    
    private func getRules(scope: String, scopeId: String?, context: NSManagedObjectContext?) -> [ReplaceRuleItem] {
        let cacheKey = "\(scope)_\(scopeId ?? "nil")"
        
        if let cached = ruleCache[cacheKey] {
            return cached
        }
        
        guard let context = context ?? CoreDataStack.shared.viewContext as NSManagedObjectContext? else {
            return []
        }
        
        let request = ReplaceRule.fetchRequest()
        request.predicate = NSPredicate(format: "scope == %@ AND enabled == YES", scope)
        
        if let id = scopeId {
            request.predicate = NSPredicate(format: "scope == %@ AND scopeId == %@ AND enabled == YES", scope, id)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "order", ascending: true)
        ]
        
        guard let results = try? context.fetch(request) else {
            return []
        }
        
        let items = results.map { ReplaceRuleItem(from: $0) }
        ruleCache[cacheKey] = items
        
        return items
    }
    
    /// 清除缓存
    func clearCache() {
        ruleCache = [:]
        groupCache = [:]
    }
    
    // MARK: - 批量操作
    
    /// 批量添加规则
    func addRules(_ items: [ReplaceRuleItem], context: NSManagedObjectContext? = nil) {
        let ctx = context ?? CoreDataStack.shared.viewContext
        
        for item in items {
            let rule = ReplaceRule.create(in: ctx)
            rule.ruleId = item.id
            rule.name = item.name
            rule.pattern = item.pattern
            rule.replacement = item.replacement
            rule.scope = item.scope
            rule.scopeId = item.scopeId
            rule.isRegex = item.isRegex
            rule.enabled = item.enabled
            rule.priority = Int32(item.priority)
            rule.order = Int32(item.order)
        }
        
        try? CoreDataStack.shared.save()
        clearCache()
    }
    
    /// 批量更新规则
    func updateRules(_ items: [ReplaceRuleItem], context: NSManagedObjectContext? = nil) {
        let ctx = context ?? CoreDataStack.shared.viewContext
        
        for item in items {
            let request = ReplaceRule.fetchRequest()
            request.predicate = NSPredicate(format: "ruleId == %@", item.id as CVarArg)
            
            guard let rule = try? ctx.fetch(request).first else { continue }
            
            rule.name = item.name
            rule.pattern = item.pattern
            rule.replacement = item.replacement
            rule.scope = item.scope
            rule.scopeId = item.scopeId
            rule.isRegex = item.isRegex
            rule.enabled = item.enabled
            rule.priority = Int32(item.priority)
            rule.order = Int32(item.order)
        }
        
        try? CoreDataStack.shared.save()
        clearCache()
    }
    
    /// 批量删除规则
    func deleteRules(ids: [UUID], context: NSManagedObjectContext? = nil) {
        let ctx = context ?? CoreDataStack.shared.viewContext
        
        let request = ReplaceRule.fetchRequest()
        request.predicate = NSPredicate(format: "ruleId IN %@", ids.map { $0 as CVarArg })
        
        guard let rules = try? ctx.fetch(request) else { return }
        
        for rule in rules {
            ctx.delete(rule)
        }
        
        try? CoreDataStack.shared.save()
        clearCache()
    }
    
    // MARK: - 导入导出
    
    /// 导出规则为 JSON
    func exportRules(scope: String? = nil, context: NSManagedObjectContext? = nil) -> Data? {
        let ctx = context ?? CoreDataStack.shared.viewContext
        
        let request = ReplaceRule.fetchRequest()
        if let scope = scope {
            request.predicate = NSPredicate(format: "scope == %@", scope)
        }
        
        guard let rules = try? ctx.fetch(request) else { return nil }
        
        let items = rules.map { ReplaceRuleItem(from: $0) }
        
        return try? JSONEncoder().encode(items)
    }
    
    /// 从 JSON 导入规则
    func importRules(from data: Data, replaceExisting: Bool = false, context: NSManagedObjectContext? = nil) throws -> Int {
        let items = try JSONDecoder().decode([ReplaceRuleItem].self, from: data)
        
        if replaceExisting {
            // 删除所有现有规则
            let ctx = context ?? CoreDataStack.shared.viewContext
            let request = ReplaceRule.fetchRequest()
            if let rules = try? ctx.fetch(request) {
                for rule in rules {
                    ctx.delete(rule)
                }
            }
        }
        
        addRules(items, context: context)
        
        return items.count
    }
    
    // MARK: - 预设规则
    
    /// 获取常用替换规则预设
    static var presetRules: [ReplaceRuleItem] {
        [
            // 广告过滤
            ReplaceRuleItem(
                name: "过滤HTML标签",
                pattern: "<[^>]+>",
                replacement: "",
                isRegex: true,
                priority: 100
            ),
            ReplaceRuleItem(
                name: "过滤特殊字符",
                pattern: "[\\u0000-\\u001F\\u007F-\\u009F]",
                replacement: "",
                isRegex: true,
                priority: 99
            ),
            ReplaceRuleItem(
                name: "过滤网站水印",
                pattern: "(本章未完，请翻页|手机用户请浏览|m\\.biquge\\.com|笔趣阁|看书神器)",
                replacement: "",
                isRegex: true,
                priority: 90
            ),
            
            // 格式化
            ReplaceRuleItem(
                name: "合并多余空行",
                pattern: "\n{3,}",
                replacement: "\n\n",
                isRegex: true,
                priority: 50
            ),
            ReplaceRuleItem(
                name: "修复引号",
                pattern: "\"([^\"]+)\"",
                replacement: "「$1」",
                isRegex: true,
                priority: 40
            ),
            
            // 内容净化
            ReplaceRuleItem(
                name: "移除章节标题重复",
                pattern: "^(第[一二三四五六七八九十百千万零0-9]+[章节回].*)\\n\\1",
                replacement: "$1",
                isRegex: true,
                priority: 30
            )
        ]
    }
    
    /// 应用预设规则
    func applyPresetRules(context: NSManagedObjectContext? = nil) {
        addRules(Self.presetRules, context: context)
    }
}

// MARK: - 替换规则测试器

class ReplaceRuleTester {
    
    /// 测试单个规则
    static func testRule(_ rule: ReplaceRuleItem, text: String) -> ReplaceTestResult {
        let startTime = Date()
        
        var result = text
        var matchCount = 0
        var error: String?
        
        do {
            if rule.isRegex {
                let regex = try NSRegularExpression(pattern: rule.pattern)
                let range = NSRange(text.startIndex..., in: text)
                
                // 统计匹配次数
                matchCount = regex.numberOfMatches(in: text, range: range)
                
                // 执行替换
                result = regex.stringByReplacingMatches(
                    in: text,
                    range: range,
                    withTemplate: rule.replacement
                )
            } else {
                // 普通文本替换，统计匹配次数
                matchCount = text.components(separatedBy: rule.pattern).count - 1
                result = text.replacingOccurrences(of: rule.pattern, with: rule.replacement)
            }
        } catch let err {
            error = err.localizedDescription
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return ReplaceTestResult(
            ruleId: rule.id,
            originalText: text,
            resultText: result,
            matchCount: matchCount,
            duration: duration,
            error: error
        )
    }
    
    /// 测试多个规则
    static func testRules(_ rules: [ReplaceRuleItem], text: String) -> [ReplaceTestResult] {
        var results: [ReplaceTestResult] = []
        var currentText = text
        
        for rule in rules {
            let result = testRule(rule, text: currentText)
            results.append(result)
            
            if result.error == nil {
                currentText = result.resultText
            }
        }
        
        return results
    }
}

// MARK: - 测试结果

struct ReplaceTestResult {
    let ruleId: UUID
    let originalText: String
    let resultText: String
    let matchCount: Int
    let duration: TimeInterval
    let error: String?
    
    var isSuccess: Bool {
        error == nil
    }
    
    var diff: String {
        // 简单的差异显示
        guard isSuccess else { return "测试失败" }
        
        if originalText == resultText {
            return "无变化"
        }
        
        return "替换 \(matchCount) 处"
    }
}