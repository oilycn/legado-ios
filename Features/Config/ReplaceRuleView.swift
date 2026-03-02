//
//  ReplaceRuleView.swift
//  Legado-iOS
//
//  替换规则管理界面（集成 CoreData）
//

import SwiftUI
import CoreData

// MARK: - 替换规则 ViewModel
@MainActor
class ReplaceRuleViewModel: ObservableObject {
    @Published var rules: [ReplaceRuleItem] = []
    
    private let storageKey = "replace_rules"
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        loadRules()
        // 迁移旧数据
        migrateFromUserDefaults()
    }
    
    /// 从 CoreData 加载规则
    func loadRules() {
        let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReplaceRule.priority, ascending: false)]
        
        do {
            let coreDataRules = try context.fetch(request)
            rules = coreDataRules.map { ReplaceRuleItem(from: $0) }
        } catch {
            print("加载替换规则失败: \(error)")
            // 降级到 UserDefaults
            loadFromUserDefaults()
        }
    }
    
    /// 从 UserDefaults 加载（兼容旧数据）
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ReplaceRuleItem].self, from: data) {
            rules = decoded
        }
    }
    
    /// 迁移旧数据到 CoreData
    private func migrateFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let oldRules = try? JSONDecoder().decode([ReplaceRuleItem].self, from: data),
              !oldRules.isEmpty else { return }
        
        // 检查是否已有 CoreData 数据
        let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
        guard (try? context.count(for: request)) == 0 else { return }
        
        // 迁移数据
        for item in oldRules {
            _ = ReplaceRule.from(item: item, in: context)
        }
        
        try? CoreDataStack.shared.save()
        loadRules()
        
        // 清除旧数据
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    func addRule(_ item: ReplaceRuleItem) {
        _ = ReplaceRule.from(item: item, in: context)
        try? CoreDataStack.shared.save()
        loadRules()
    }
    
    func removeRules(at offsets: IndexSet) {
        let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
        
        do {
            let allRules = try context.fetch(request)
            for index in offsets {
                if index < allRules.count {
                    context.delete(allRules[index])
                }
            }
            try CoreDataStack.shared.save()
            loadRules()
        } catch {
            print("删除规则失败: \(error)")
        }
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        var reordered = rules
        reordered.move(fromOffsets: source, toOffset: destination)
        
        // 更新 order 字段
        for (index, item) in reordered.enumerated() {
            if let rule = findRule(by: item.id) {
                rule.order = Int32(index)
            }
        }
        
        try? CoreDataStack.shared.save()
        loadRules()
    }
    
    func toggleRule(_ item: ReplaceRuleItem) {
        if let rule = findRule(by: item.id) {
            rule.enabled.toggle()
            try? CoreDataStack.shared.save()
            loadRules()
        }
    }
    
    func updateRule(_ item: ReplaceRuleItem) {
        if let rule = findRule(by: item.id) {
            rule.name = item.name
            rule.pattern = item.pattern
            rule.replacement = item.replacement
            rule.scope = item.scope
            rule.scopeId = item.scopeId
            rule.isRegex = item.isRegex
            rule.enabled = item.enabled
            rule.priority = Int32(item.priority)
            
            try? CoreDataStack.shared.save()
            loadRules()
        }
    }
    
    private func findRule(by id: UUID) -> ReplaceRule? {
        let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
        request.predicate = NSPredicate(format: "ruleId == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
}

// MARK: - 替换规则管理视图
struct ReplaceRuleView: View {
    @StateObject private var viewModel = ReplaceRuleViewModel()
    @State private var showingAdd = false
    @State private var showingDebug = false
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
                    Button(action: { showingDebug = true }) {
                        Image(systemName: "bug")
                    }
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
        .sheet(isPresented: $showingDebug) {
            NavigationView {
                ReplaceRuleDebugView()
            }
        }
    }
}

// MARK: - 编辑界面
struct ReplaceRuleEditView: View {
    var viewModel: ReplaceRuleViewModel
    let rule: ReplaceRuleItem?
    @Environment(\.dismiss) var dismiss
struct ReplaceRuleEditView: View {
    var viewModel: ReplaceRuleViewModel
    let rule: ReplaceRuleItem?
    @Environment(\.dismiss) var dismiss
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
        if let existing = rule {
            let updated = ReplaceRuleItem(
                id: existing.id,
                name: name,
                pattern: pattern,
                replacement: replacement,
                scope: scope,
                scopeId: existing.scopeId,
                isRegex: isRegex,
                enabled: enabled,
                priority: existing.priority
            )
            viewModel.updateRule(updated)
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

// MARK: - 预览
#Preview {
    NavigationView {
        ReplaceRuleView()
    }
}
