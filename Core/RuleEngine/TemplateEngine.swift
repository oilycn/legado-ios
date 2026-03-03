//
//  TemplateEngine.swift
//  Legado-iOS
//
//  模板与变量引擎
//

import Foundation

class TemplateEngine {
    private static let maxRenderDepth = 20
    private static let placeholderRegex = try? NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)

    static func render(_ template: String, context: ExecutionContext) -> String {
        guard template.contains("{{"), let placeholderRegex else { return template }

        var result = template

        for _ in 0..<maxRenderDepth {
            let range = NSRange(result.startIndex..., in: result)
            let matches = placeholderRegex.matches(in: result, range: range)
            if matches.isEmpty { break }

            var rendered = result
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: rendered),
                      let tokenRange = Range(match.range(at: 1), in: rendered) else {
                    continue
                }

                let token = String(rendered[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let replacement = resolveTemplateToken(token, context: context)
                rendered.replaceSubrange(fullRange, with: replacement)
            }

            if rendered == result { break }
            result = rendered
        }

        return result
    }

    static func parsePut(_ rule: String) -> [(key: String, rule: String)]? {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("@put:{"), trimmed.hasSuffix("}") else { return nil }

        let start = trimmed.index(trimmed.startIndex, offsetBy: 6)
        let end = trimmed.index(before: trimmed.endIndex)
        guard start <= end else { return nil }

        let payload = String(trimmed[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }

        let assignments = splitTopLevel(payload, separator: ",")
        guard !assignments.isEmpty else { return nil }

        var parsed: [(key: String, rule: String)] = []
        for assignment in assignments {
            guard let colonIndex = firstTopLevelColon(in: assignment) else { return nil }

            let key = String(assignment[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStart = assignment.index(after: colonIndex)
            let value = String(assignment[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !key.isEmpty, !value.isEmpty else { return nil }
            parsed.append((key: key, rule: value))
        }

        return parsed.isEmpty ? nil : parsed
    }

    static func executePut(_ rule: String, context: ExecutionContext, ruleEngine: RuleEngine) -> Bool {
        guard let assignments = parsePut(rule) else { return false }

        var lastValue = ""
        for assignment in assignments {
            let renderedRule: String
            if assignment.rule.contains("{{js") || assignment.rule.contains("{{regex") || assignment.rule.contains("{{result}}") {
                renderedRule = assignment.rule
            } else {
                renderedRule = render(assignment.rule, context: context)
            }
            do {
                let result = try ruleEngine.executeSingle(rule: renderedRule, context: context)
                let value = valueString(from: result)
                context.variables[assignment.key] = value
                context.lastResult = .string(value)
                lastValue = value
            } catch {
                print("@put 执行失败 [\(assignment.key)]: \(error)")
                return false
            }
        }

        context.lastResult = .string(lastValue)
        return true
    }

    static func executeGet(_ key: String, context: ExecutionContext) -> String {
        context.variables[key] ?? ""
    }

    static func parseGet(_ rule: String) -> String? {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("@get:{"), trimmed.hasSuffix("}") else { return nil }

        let start = trimmed.index(trimmed.startIndex, offsetBy: 6)
        let end = trimmed.index(before: trimmed.endIndex)
        guard start <= end else { return nil }

        let key = String(trimmed[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    private static func resolveTemplateToken(_ token: String, context: ExecutionContext) -> String {
        guard !token.isEmpty else { return "" }

        if token.hasPrefix("$.") {
            return resolveJSONPath(token, context: context)
        }

        let parts = token.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        if let value = context.variables[key] {
            return value
        }

        if let fallback {
            return render(fallback, context: context)
        }

        return ""
    }

    private static func valueString(from result: RuleResult) -> String {
        switch result {
        case .string(let value):
            return value
        case .list(let values):
            return values.joined(separator: "\n")
        case .none:
            return ""
        }
    }

    private static func splitTopLevel(_ input: String, separator: Character) -> [String] {
        var parts: [String] = []
        var buffer = ""
        var braceDepth = 0
        var bracketDepth = 0
        var parenthesisDepth = 0
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaping = false

        for char in input {
            if escaping {
                buffer.append(char)
                escaping = false
                continue
            }

            if char == "\\" {
                buffer.append(char)
                escaping = true
                continue
            }

            if char == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
                buffer.append(char)
                continue
            }

            if char == "'", !inDoubleQuote {
                inSingleQuote.toggle()
                buffer.append(char)
                continue
            }

            if !inSingleQuote && !inDoubleQuote {
                switch char {
                case "{": braceDepth += 1
                case "}": braceDepth = max(0, braceDepth - 1)
                case "[": bracketDepth += 1
                case "]": bracketDepth = max(0, bracketDepth - 1)
                case "(": parenthesisDepth += 1
                case ")": parenthesisDepth = max(0, parenthesisDepth - 1)
                default: break
                }

                if char == separator && braceDepth == 0 && bracketDepth == 0 && parenthesisDepth == 0 {
                    let part = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !part.isEmpty { parts.append(part) }
                    buffer.removeAll(keepingCapacity: true)
                    continue
                }
            }

            buffer.append(char)
        }

        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            parts.append(tail)
        }

        return parts
    }

    private static func firstTopLevelColon(in input: String) -> String.Index? {
        var braceDepth = 0
        var bracketDepth = 0
        var parenthesisDepth = 0
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaping = false

        for index in input.indices {
            let char = input[index]

            if escaping {
                escaping = false
                continue
            }

            if char == "\\" {
                escaping = true
                continue
            }

            if char == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if char == "'", !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if inSingleQuote || inDoubleQuote { continue }

            switch char {
            case "{": braceDepth += 1
            case "}": braceDepth = max(0, braceDepth - 1)
            case "[": bracketDepth += 1
            case "]": bracketDepth = max(0, bracketDepth - 1)
            case "(": parenthesisDepth += 1
            case ")": parenthesisDepth = max(0, parenthesisDepth - 1)
            case ":":
                if braceDepth == 0 && bracketDepth == 0 && parenthesisDepth == 0 {
                    return index
                }
            default:
                break
            }
        }

        return nil
    }

    private static func resolveJSONPath(_ path: String, context: ExecutionContext) -> String {
        guard let root = loadJSONRoot(context: context) else { return "" }
        guard let value = evaluateJSONPath(path, root: root) else { return "" }

        if let text = value as? String { return text }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let number = value as? NSNumber { return number.stringValue }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let jsonText = String(data: data, encoding: .utf8) {
            return jsonText
        }

        return ""
    }

    private static func loadJSONRoot(context: ExecutionContext) -> Any? {
        if let jsonDict = context.jsonDict {
            return jsonDict
        }

        guard let jsonString = context.jsonString,
              let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let dict = object as? [String: Any] {
            context.jsonDict = dict
        }

        return object
    }

    private static func evaluateJSONPath(_ path: String, root: Any) -> Any? {
        guard path.hasPrefix("$.") else { return nil }

        var current: Any? = root
        var index = path.index(path.startIndex, offsetBy: 2)
        var token = ""

        while index < path.endIndex {
            let char = path[index]

            if char == "." {
                if !token.isEmpty {
                    current = applyJSONKey(current, key: token)
                    token.removeAll(keepingCapacity: true)
                }
                index = path.index(after: index)
                continue
            }

            if char == "[" {
                if !token.isEmpty {
                    current = applyJSONKey(current, key: token)
                    token.removeAll(keepingCapacity: true)
                }

                guard let closingIndex = path[index...].firstIndex(of: "]") else { return nil }
                let indexString = path[path.index(after: index)..<closingIndex]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let arrayIndex = Int(indexString) else { return nil }

                current = applyJSONArrayIndex(current, index: arrayIndex)
                index = path.index(after: closingIndex)
                continue
            }

            token.append(char)
            index = path.index(after: index)
        }

        if !token.isEmpty {
            current = applyJSONKey(current, key: token)
        }

        return current
    }

    private static func applyJSONKey(_ value: Any?, key: String) -> Any? {
        if let dict = value as? [String: Any] {
            return dict[key]
        }

        if let array = value as? [Any], let index = Int(key), index >= 0, index < array.count {
            return array[index]
        }

        return nil
    }

    private static func applyJSONArrayIndex(_ value: Any?, index: Int) -> Any? {
        guard index >= 0 else { return nil }
        guard let array = value as? [Any], index < array.count else { return nil }
        return array[index]
    }
}
