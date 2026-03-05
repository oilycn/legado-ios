//
//  EffectiveReplacesSheet.swift
//  Legado-iOS
//
//  有效替换规则显示 - 参考 Android EffectiveReplacesDialog
//  显示当前生效的所有替换规则列表
//

import SwiftUI
import CoreData

struct EffectiveReplacesSheet: View {
    @Binding var isPresented: Bool
    let bookSourceUrl: String?
    
    @FetchRequest private var allRules: FetchedResults<ReplaceRule>
    @State private var temporarilyDisabled: Set<UUID> = []
    
    init(isPresented: Binding<Bool>, bookSourceUrl: String?) {
        self._isPresented = isPresented
        self.bookSourceUrl = bookSourceUrl
        
        // 获取全局规则 + 当前书源规则
        let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "order", ascending: true)
        ]
        self._allRules = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        NavigationView {
            List {
                // 全局规则
                let globalRules = allRules.filter { $0.scope == "global" || $0.scope.isEmpty }
                if !globalRules.isEmpty {
                    Section("全局规则") {
                        ForEach(globalRules, id: \.ruleId) { rule in
                            RuleRow(
                                rule: rule,
                                isDisabled: temporarilyDisabled.contains(rule.ruleId),
                                onToggle: { toggleRule(rule) }
                            )
                        }
                    }
                }
                
                // 书源特定规则
                if let sourceUrl = bookSourceUrl {
                    let sourceRules = allRules.filter { $0.scopeId == sourceUrl }
                    if !sourceRules.isEmpty {
                        Section("书源规则") {
                            ForEach(sourceRules, id: \.ruleId) { rule in
                                RuleRow(
                                    rule: rule,
                                    isDisabled: temporarilyDisabled.contains(rule.ruleId),
                                    onToggle: { toggleRule(rule) }
                                )
                            }
                        }
                    }
                }
                
                if allRules.isEmpty {
                    Section {
                        Text("暂无生效的替换规则")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("替换规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        temporarilyDisabled.removeAll()
                    }
                    .disabled(temporarilyDisabled.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func toggleRule(_ rule: ReplaceRule) {
        if temporarilyDisabled.contains(rule.ruleId) {
            temporarilyDisabled.remove(rule.ruleId)
        } else {
            temporarilyDisabled.insert(rule.ruleId)
        }
    }
}

private struct RuleRow: View {
    let rule: ReplaceRule
    let isDisabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rule.name)
                    .font(.headline)
                    .strikethrough(isDisabled)
                
                Spacer()
                
                Button(action: onToggle) {
                    Image(systemName: isDisabled ? "eye.slash" : "eye")
                        .foregroundColor(isDisabled ? .secondary : .blue)
                }
                .buttonStyle(.plain)
            }
            
            Text("模式: \(rule.pattern)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text("替换: \(rule.replacement)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack {
                Label(rule.isRegex ? "正则" : "普通", systemImage: rule.isRegex ? "number" : "textformat")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !rule.scope.isEmpty, rule.scope != "global" {
                    Text(rule.scope)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - 扩展：检查规则是否生效

extension ReplaceRule {
    var isEffectivelyEnabled: Bool {
        enabled
    }
    
    func matches(content: String) -> Bool {
        if isRegex {
            return content.range(of: pattern, options: .regularExpression) != nil
        } else {
            return content.contains(pattern)
        }
    }
    
    func apply(to content: String) -> String {
        if isRegex {
            return content.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        } else {
            return content.replacingOccurrences(of: pattern, with: replacement)
        }
    }
}