//
//  ReplaceEngine.swift
//  Legado-iOS
//
//  替换规则引擎
//

import Foundation
import CoreData

class ReplaceEngine {
    static let shared = ReplaceEngine()
    
    /// 应用替换规则
    func apply(text: String, rules: [ReplaceRule]) -> String {
        var result = text
        
        // 按优先级排序
        let sortedRules = rules.sorted { $0.priority > $1.priority }
        
        for rule in sortedRules where rule.enabled {
            if rule.isRegex {
                // 正则替换
                if let regex = try? NSRegularExpression(pattern: rule.pattern) {
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: range,
                        withTemplate: rule.replacement
                    )
                }
            } else {
                // 普通文本替换
                result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement)
            }
        }
        
        return result
    }
    
    /// 应用替换规则（使用 ReplaceRuleItem）
    func apply(text: String, items: [ReplaceRuleItem]) -> String {
        var result = text
        
        // 按优先级排序
        let sortedItems = items.sorted { $0.priority > $1.priority }
        
        for item in sortedItems where item.enabled {
            if item.isRegex {
                // 正则替换
                if let regex = try? NSRegularExpression(pattern: item.pattern) {
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: range,
                        withTemplate: item.replacement
                    )
                }
            } else {
                // 普通文本替换
                result = result.replacingOccurrences(of: item.pattern, with: item.replacement)
            }
        }
        
        return result
    }
    
    /// 净化内容（广告替换等）
    func purify(content: String, rules: [ReplaceRule]) -> String {
        return apply(text: content, rules: rules.filter { $0.scope == "global" })
    }
    
    /// 测试规则效果
    func testRule(pattern: String, replacement: String, isRegex: Bool, testText: String) -> String {
        if isRegex {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return testText
            }
            let range = NSRange(testText.startIndex..., in: testText)
            return regex.stringByReplacingMatches(
                in: testText,
                range: range,
                withTemplate: replacement
            )
        } else {
            return testText.replacingOccurrences(of: pattern, with: replacement)
        }
    }
}
