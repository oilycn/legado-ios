//
//  RuleEngine.swift
//  Legado-iOS
//
//  书源规则解析引擎
//

import Foundation
import JavaScriptCore
import SwiftSoup
import Kanna

// MARK: - 结果类型
enum RuleResult {
    case string(String)
    case list([String])
    case none
    
    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var list: [String]? {
        if case .list(let value) = self { return value }
        return nil
    }
}

// MARK: - 执行上下文
class ExecutionContext {
    var document: Any?
    var jsonString: String?
    var jsonDict: [String: Any]?
    var baseURL: URL?
    var variables: [String: String] = [:]
    var lastResult: RuleResult = .none
    
    lazy var jsContext: JSContext = {
        let context = JSContext()!
        
        // 注入getVar/setVar
        context.setValue({ [weak self] (key: String) -> String in
            self?.variables[key] ?? ""
        }, forKey: "getVar")
        
        context.setValue({ [weak self] (key: String, value: String) in
            self?.variables[key] = value
        }, forKey: "setVar")
        
        // 注入 result
        context.setValue({ [weak self] () -> String? in
            self?.lastResult.string
        }, forKey: "result")
        
        return context
    }()
}

// MARK: - 解析器协议
protocol RuleExecutor {
    var kind: RuleKind { get }
    func canExecute(_ rule: String) -> Bool
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult
}

enum RuleKind: String, CaseIterable {
    case jsonPath = "json"
    case xpath = "xpath"
    case css = "css"
    case regex = "regex"
    case js = "js"
}

// MARK: - 规则引擎
class RuleEngine {
    private var executors: [RuleExecutor] = []
    
    init() {
        // 按优先级注册解析器
        executors.append(JSONPathParser())
        executors.append(XPathParser())
        executors.append(CSSParser())
        executors.append(RegexParser())
        executors.append(JavaScriptParser())
    }
    
    func execute(
        rules: [String],
        context: ExecutionContext
    ) throws -> RuleResult {
        var lastResult: RuleResult = .none
        
        for rule in rules {
            guard let executor = executors.first(where: { $0.canExecute(rule) }) else {
                continue
            }
            
            do {
                lastResult = try executor.execute(rule, context: context)
                context.lastResult = lastResult
            } catch {
                print("规则执行错误 [\(rule)]: \(error)")
            }
        }
        
        return lastResult
    }
    
    func executeSingle(
        rule: String,
        context: ExecutionContext
    ) throws -> RuleResult {
        guard let executor = executors.first(where: { $0.canExecute(rule) }) else {
            throw RuleError.unsupportedRule(rule)
        }
        
        return try executor.execute(rule, context: context)
    }
}

// MARK: - CSS 解析器 (SwiftSoup)
class CSSParser: RuleExecutor {
    var kind: RuleKind { .css }
    
    func canExecute(_ rule: String) -> Bool {
        return !rule.hasPrefix("//") && !rule.hasPrefix("$.") && !rule.hasPrefix("{{")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        guard let document = context.document as? SwiftSoup.Document else {
            throw RuleError.noDocument
        }
        
        let (selector, attr) = parseSelector(rule)
        let elements = try document.select(selector)
        
        if let first = elements.first() {
            switch attr {
            case "text":
                return .string(try first.text())
            case "html":
                return .string(try first.html())
            case "href":
                return .string(try first.attr("href"))
            case "src":
                return .string(try first.attr("src"))
            default:
                return .string(try first.text())
            }
        }
        
        return .none
    }
    
    private func parseSelector(_ rule: String) -> (String, String) {
        var selector = rule
        var attr = "text"
        
        if let range = rule.range(of: "@") {
            selector = String(rule[..<range.lowerBound])
            attr = String(rule[range.upperBound...])
        }
        
        return (selector, attr)
    }
}

// MARK: - XPath 解析器 (Kanna)
class XPathParser: RuleExecutor {
    var kind: RuleKind { .xpath }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.hasPrefix("//")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        guard let html = context.document as? String else {
            throw RuleError.noDocument
        }
        
        let doc = try Kanna.HTML(html: html, encoding: .utf8)
        
        var results: [String] = []
        for node in doc.xpath(rule) {
            if let text = node.text {
                results.append(text)
            }
        }
        
        if results.count == 1 {
            return .string(results[0])
        } else if !results.isEmpty {
            return .list(results)
        }
        
        return .none
    }
}

// MARK: - JSONPath 解析器
class JSONPathParser: RuleExecutor {
    var kind: RuleKind { .jsonPath }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.hasPrefix("$.")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        if context.jsonDict == nil, let jsonString = context.jsonString {
            let data = jsonString.data(using: .utf8)!
            context.jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        
        guard let dict = context.jsonDict else {
            throw RuleError.noDocument
        }
        
        let value = evaluateJSONPath(rule, json: dict)
        
        if let string = value as? String {
            return .string(string)
        } else if let array = value as? [Any] {
            let strings = array.compactMap { $0 as? String }
            return .list(strings)
        }
        
        return .none
    }
    
    private func evaluateJSONPath(_ path: String, json: [String: Any]) -> Any? {
        let cleanPath = path.replacingOccurrences(of: "$.", with: "")
        let keys = cleanPath.split(separator: ".").map { String($0) }
        
        var current: Any? = json
        for key in keys {
            guard let dict = current as? [String: Any] else { return nil }
            
            if let bracketRange = key.range(of: "["), key.hasSuffix("]") {
                let arrayKey = String(key[..<bracketRange.lowerBound])
                let indexStr = String(key[bracketRange.upperBound...].dropLast())
                guard let index = Int(indexStr),
                      let array = dict[arrayKey] as? [[String: Any]],
                      index < array.count else { return nil }
                current = array[index]
            } else {
                current = dict[key]
            }
        }
        
        return current
    }
}

// MARK: - 正则解析器
class RegexParser: RuleExecutor {
    var kind: RuleKind { .regex }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.hasPrefix("regex:") || rule.contains("{{regex")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        guard let input = context.lastResult.string ?? (context.document as? String) else {
            throw RuleError.noDocument
        }
        
        let pattern = rule.replacingOccurrences(of: "regex:", with: "")
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw RuleError.invalidRule("无效正则：\(pattern)")
        }
        
        let range = NSRange(input.startIndex..., in: input)
        var results: [String] = []
        
        for match in regex.matches(in: input, range: range) {
            if let matchRange = Range(match.range, in: input) {
                results.append(String(input[matchRange]))
            }
        }
        
        if results.count == 1 {
            return .string(results[0])
        } else if !results.isEmpty {
            return .list(results)
        }
        
        return .none
    }
}

// MARK: - JavaScript 解析器
class JavaScriptParser: RuleExecutor {
    var kind: RuleKind { .js }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.contains("{{js") || rule.contains("<js>")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        let jsCode = extractJS(rule)
        
        context.jsContext.setValue(context.lastResult.string, forKey: "result")
        context.jsContext.setValue(context.baseURL?.absoluteString, forKey: "baseUrl")
        
        let jsValue = context.jsContext.evaluateScript(jsCode)
        
        if let string = jsValue?.toString() {
            return .string(string)
        }
        
        return .none
    }
    
    private func extractJS(_ rule: String) -> String {
        let patterns = [
            #"{{js(.*?)}}"#,
            #"<js>(.*?)</js>"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                in: rule,
                range: NSRange(rule.startIndex..., in: rule)
               ),
               let range = Range(match.range(at: 1), in: rule) {
                return String(rule[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return rule
    }
}

// MARK: - 错误类型
enum RuleError: LocalizedError {
    case noDocument
    case invalidRule(String)
    case unsupportedRule(String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noDocument: return "缺少文档"
        case .invalidRule(let rule): return "无效规则：\(rule)"
        case .unsupportedRule(let rule): return "不支持的规则：\(rule)"
        case .executionFailed(let error): return "执行失败：\(error)"
        }
    }
}
