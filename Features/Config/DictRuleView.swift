//
//  DictRuleView.swift
//  Legado-iOS
//
//  词典规则管理 - 支持自定义词典查询规则
//  可配置多个在线词典源，阅读时长按查词
//

import SwiftUI

// MARK: - 词典规则模型
struct DictRuleItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var urlRule: String          // URL 模板，用 {{word}} 作为关键词占位符
    var showInPanel: Bool = true // 是否在查词面板中显示
    var enabled: Bool = true
    var sortOrder: Int = 0
    
    /// 构建查词 URL
    func buildUrl(word: String) -> URL? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlStr = urlRule.replacingOccurrences(of: "{{word}}", with: encoded)
        return URL(string: urlStr)
    }
}

// MARK: - 词典规则 ViewModel
@MainActor
class DictRuleViewModel: ObservableObject {
    @Published var rules: [DictRuleItem] = []
    
    private let storageKey = "dict_rules"
    
    init() {
        loadRules()
        if rules.isEmpty {
            loadDefaultRules()
        }
    }
    
    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DictRuleItem].self, from: data) {
            rules = decoded
        }
    }
    
    func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func addRule(_ rule: DictRuleItem) {
        rules.append(rule)
        saveRules()
    }
    
    func removeRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        for (index, _) in rules.enumerated() {
            rules[index].sortOrder = index
        }
        saveRules()
    }
    
    func toggleRule(_ rule: DictRuleItem) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].enabled.toggle()
            saveRules()
        }
    }
    
    /// 预置默认词典
    private func loadDefaultRules() {
        rules = [
            DictRuleItem(name: "百度翻译", urlRule: "https://fanyi.baidu.com/#auto/zh/{{word}}", sortOrder: 0),
            DictRuleItem(name: "有道词典", urlRule: "https://dict.youdao.com/m/result?word={{word}}&lang=en", sortOrder: 1),
            DictRuleItem(name: "Google 翻译", urlRule: "https://translate.google.com/?sl=auto&tl=zh-CN&text={{word}}", sortOrder: 2),
            DictRule(name: "有道词典", urlRule: "https://dict.youdao.com/m/result?word={{word}}&lang=en", sortOrder: 1),
            DictRule(name: "Google 翻译", urlRule: "https://translate.google.com/?sl=auto&tl=zh-CN&text={{word}}", sortOrder: 2),
            DictRule(name: "维基百科", urlRule: "https://zh.m.wikipedia.org/wiki/{{word}}", showInPanel: false, sortOrder: 3)
        ]
        saveRules()
    }
}

// MARK: - 词典规则管理视图
struct DictRuleView: View {
    @StateObject private var viewModel = DictRuleViewModel()
    @State private var showingAddRule = false
    @State private var editingRule: DictRuleItem?
    
    var body: some View {
        List {
            if viewModel.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.purple.opacity(0.6))
                    Text("没有词典规则")
                        .font(.headline)
                    Text("点击右上角 + 添加自定义词典")
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
                                Text(rule.name)
                                    .font(.headline)
                                if rule.showInPanel {
                                    Text("查词面板")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            Text(rule.urlRule)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
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
                .onDelete(perform: viewModel.removeRule)
                .onMove(perform: viewModel.moveRule)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("词典规则")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    EditButton()
                    Button(action: { showingAddRule = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            DictRuleEditView(viewModel: viewModel, rule: nil)
        }
        .sheet(item: $editingRule) { rule in
            DictRuleEditView(viewModel: viewModel, rule: rule)
        }
    }
}

// MARK: - 词典规则编辑视图
struct DictRuleEditView: View {
    @ObservedObject var viewModel: DictRuleViewModel
    let rule: DictRuleItem?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlRule = ""
    @State private var showInPanel = true
    @State private var enabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("词典名称", text: $name)
                    TextField("URL 规则（用 {{word}} 代替查询词）", text: $urlRule)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("设置") {
                    Toggle("启用", isOn: $enabled)
                    Toggle("在查词面板中显示", isOn: $showInPanel)
                }
                
                Section("说明") {
                    Text("URL 规则中使用 {{word}} 作为查询词占位符。\n例如：\nhttps://dict.youdao.com/m/result?word={{word}}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !urlRule.isEmpty {
                    Section("预览") {
                        if let url = DictRuleItem(name: name, urlRule: urlRule).buildUrl(word: "测试") {
                            Link(url.absoluteString, destination: url)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle(rule == nil ? "添加词典" : "编辑词典")
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
                    .disabled(name.isEmpty || urlRule.isEmpty)
                }
            }
            .onAppear {
                if let rule = rule {
                    name = rule.name
                    urlRule = rule.urlRule
                    showInPanel = rule.showInPanel
                    enabled = rule.enabled
                }
            }
        }
    }
    
    private func save() {
        if let existingRule = rule,
           let index = viewModel.rules.firstIndex(where: { $0.id == existingRule.id }) {
            viewModel.rules[index].name = name
            viewModel.rules[index].urlRule = urlRule
            viewModel.rules[index].showInPanel = showInPanel
            viewModel.rules[index].enabled = enabled
            viewModel.saveRules()
        } else {
            let newRule = DictRuleItem(
                name: name,
                urlRule: urlRule,
                showInPanel: showInPanel,
                enabled: enabled,
                sortOrder: viewModel.rules.count
            )
            viewModel.addRule(newRule)
        }
    }
}

// MARK: - 查词弹出面板（阅读器中使用）
struct DictLookupView: View {
    let word: String
    @StateObject private var viewModel = DictRuleViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("查询：\(word)") {
                    ForEach(viewModel.rules.filter { $0.enabled && $0.showInPanel }) { rule in
                        if let url = rule.buildUrl(word: word) {
                            Link(destination: url) {
                                HStack {
                                    Text(rule.name)
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("查词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
