//
//  RssSourceEditView.swift
//  Legado-iOS
//
//  RSS 源编辑器 - Phase 5
//

import SwiftUI
import CoreData

struct RssSourceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RssSourceEditViewModel
    
    init(source: RssSource?, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RssSourceEditViewModel(source: source, onSave: onSave))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("源名称", text: $viewModel.sourceName)
                    TextField("源地址", text: $viewModel.sourceUrl)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("分组", text: $viewModel.sourceGroup)
                }
                
                Section("规则配置") {
                    TextField("文章列表规则", text: $viewModel.ruleArticles)
                    TextField("标题规则", text: $viewModel.ruleTitle)
                    TextField("链接规则", text: $viewModel.ruleLink)
                    TextField("描述规则", text: $viewModel.ruleDescription)
                    TextField("图片规则", text: $viewModel.ruleImage)
                    TextField("内容规则", text: $viewModel.ruleContent)
                    TextField("下一页规则", text: $viewModel.ruleNextPage)
                }
                
                Section("高级设置") {
                    TextField("请求头", text: $viewModel.header)
                        .font(.system(.caption, design: .monospaced))
                    Toggle("启用", isOn: $viewModel.enabled)
                }
            }
            .navigationTitle(viewModel.isEditing ? "编辑源" : "新建源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(viewModel.sourceName.isEmpty || viewModel.sourceUrl.isEmpty)
                }
            }
        }
    }
}

@MainActor
class RssSourceEditViewModel: ObservableObject {
    @Published var sourceName: String = ""
    @Published var sourceUrl: String = ""
    @Published var sourceGroup: String = ""
    @Published var ruleArticles: String = ""
    @Published var ruleTitle: String = ""
    @Published var ruleLink: String = ""
    @Published var ruleDescription: String = ""
    @Published var ruleImage: String = ""
    @Published var ruleContent: String = ""
    @Published var ruleNextPage: String = ""
    @Published var header: String = ""
    @Published var enabled: Bool = true
    
    let isEditing: Bool
    private let source: RssSource?
    private let onSave: () -> Void
    private let context = CoreDataStack.shared.viewContext
    
    init(source: RssSource?, onSave: @escaping () -> Void) {
        self.source = source
        self.onSave = onSave
        self.isEditing = source != nil
        
        if let source = source {
            sourceName = source.sourceName
            sourceUrl = source.sourceUrl
            sourceGroup = source.sourceGroup ?? ""
            ruleArticles = source.ruleArticles ?? ""
            ruleTitle = source.ruleTitle ?? ""
            ruleLink = source.ruleLink ?? ""
            ruleDescription = source.ruleDescription ?? ""
            ruleImage = source.ruleImage ?? ""
            ruleContent = source.ruleContent ?? ""
            ruleNextPage = source.ruleNextPage ?? ""
            header = source.header ?? ""
            enabled = source.enabled
        }
    }
    
    func save() {
        let entity: RssSource
        if let existing = source {
            entity = existing
        } else {
            entity = RssSource(context: context)
        }
        
        entity.sourceName = sourceName
        entity.sourceUrl = sourceUrl
        entity.sourceGroup = sourceGroup.isEmpty ? nil : sourceGroup
        entity.ruleArticles = ruleArticles.isEmpty ? nil : ruleArticles
        entity.ruleTitle = ruleTitle.isEmpty ? nil : ruleTitle
        entity.ruleLink = ruleLink.isEmpty ? nil : ruleLink
        entity.ruleDescription = ruleDescription.isEmpty ? nil : ruleDescription
        entity.ruleImage = ruleImage.isEmpty ? nil : ruleImage
        entity.ruleContent = ruleContent.isEmpty ? nil : ruleContent
        entity.ruleNextPage = ruleNextPage.isEmpty ? nil : ruleNextPage
        entity.header = header.isEmpty ? nil : header
        entity.enabled = enabled
        entity.lastUpdateTime = Int64(Date().timeIntervalSince1970)
        
        try? context.save()
        onSave()
    }
}