//
//  ReplaceRuleView.swift
//  Legado-iOS
//
//  替换规则管理界面
//

import SwiftUI

// MARK: - 替换规则模型
struct ReplaceRuleItem: Identifiable, Codable {
    var id = UUID()
    var name: String = ""
    var pattern: String = ""
    var replacement: String = ""
    var scope: String = "global"
    var scopeId: String?
    var isRegex: Bool = true
    var enabled: Bool = true
    var priority: Int = 0
}

// MARK: - 替换规则 ViewModel
@MainActor
class ReplaceRuleViewModel: ObservableObject {
    @Published var rules: [ReplaceRuleItem] = []
    
    private let storageKey = "replace_rules"
    
    init() {
        loadRules()
    }
    
    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ReplaceRuleItem].self, from: data) {
            rules = decoded
        }
    }
    
    func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func addRule(_ rule: ReplaceRuleItem) {
        rules.append(rule)
        saveRules()
    }
    
    func removeRules(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        saveRules()
    }
    
    func toggleRule(_ rule: ReplaceRuleItem) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx].enabled.toggle()
            saveRules()
        }
    }
    
    func updateRule(_ rule: ReplaceRuleItem) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
            saveRules()
        }
    }
}

// MARK: - 替换规则管理视图
struct ReplaceRuleView: View {
    @StateObject private var viewModel = ReplaceRuleViewModel()
    @State private var showingAdd = false
    @State private var editingRule: ReplaceRuleItem?
    
    var body: some View {
        List {
            if viewModel.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("暂无替换规则")
                        .font(.headline)
                    Text("点击右上角添加替换规则")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.rules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(rule.name.isEmpty ? "未命名规则" : rule.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                if rule.isRegex {
                                    Text("正则")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundColor(.purple)
                                        .cornerRadius(3)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Text(rule.pattern)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(rule.replacement.isEmpty ? "(删除)" : rule.replacement)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { rule.enabled },
                            set: { _ in viewModel.toggleRule(rule) }
                        ))
                        .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingRule = rule
                    }
                }
                .onDelete(perform: viewModel.removeRules)
                .onMove(perform: viewModel.moveRule)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("替换规则")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    EditButton()
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ReplaceRuleEditView(viewModel: viewModel, rule: nil)
        }
        .sheet(item: $editingRule) { rule in
            ReplaceRuleEditView(viewModel: viewModel, rule: rule)
        }
    }
}

// MARK: - 编辑界面
struct ReplaceRuleEditView: View {
    @ObservedObject var viewModel: ReplaceRuleViewModel
    let rule: ReplaceRuleItem?
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var isRegex = true
    @State private var enabled = true
    @State private var scope = "global"
    
    var body: some View {
        NavigationView {
            Form {
                Section("规则信息") {
                    TextField("规则名称", text: $name)
                    TextField("匹配模式", text: $pattern)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("替换内容（留空则删除匹配内容）", text: $replacement)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section("设置") {
                    Toggle("正则表达式", isOn: $isRegex)
                    Toggle("启用", isOn: $enabled)
                    Picker("作用域", selection: $scope) {
                        Text("全局").tag("global")
                        Text("正文").tag("content")
                        Text("标题").tag("title")
                    }
                }
                
                Section("示例") {
                    Text("• \\s+ → 匹配空白字符\n• <.*?> → 匹配 HTML 标签\n• 广告.+?广告 → 匹配广告文本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(rule == nil ? "新建规则" : "编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(pattern.isEmpty)
                }
            }
            .onAppear {
                if let rule = rule {
                    name = rule.name
                    pattern = rule.pattern
                    replacement = rule.replacement
                    isRegex = rule.isRegex
                    enabled = rule.enabled
                    scope = rule.scope
                }
            }
        }
    }
    
    private func save() {
        if var existing = rule {
            existing.name = name
            existing.pattern = pattern
            existing.replacement = replacement
            existing.isRegex = isRegex
            existing.enabled = enabled
            existing.scope = scope
            viewModel.updateRule(existing)
        } else {
            let newRule = ReplaceRuleItem(
                name: name,
                pattern: pattern,
                replacement: replacement,
                scope: scope,
                isRegex: isRegex,
                enabled: enabled
            )
            viewModel.addRule(newRule)
        }
    }
}
