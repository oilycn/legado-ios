//
//  SourceManageView.swift
//  Legado-iOS
//
//  书源管理界面
//

import SwiftUI
import CoreData

struct SourceManageView: View {
    @StateObject private var viewModel = SourceViewModel()
    @State private var showingEdit = false
    @State private var showingImport = false
    @State private var selectedSource: BookSource?
    
    var body: some View {
            List {
                if viewModel.sources.isEmpty {
                    EmptyStateView(
                        title: "暂无书源",
                        subtitle: "点击右上角导入或创建书源",
                        imageName: "square.grid.2x2"
                    )
                } else {
                    ForEach(viewModel.sources, id: \.sourceId) { source in
                        SourceItemView(source: source)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteSource(source)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    selectedSource = source
                                    showingEdit = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { indexSet in
                        viewModel.deleteSources(at: indexSet)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("书源管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button(action: { showingImport = true }) {
                                Label("导入书源", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: viewModel.exportAllSources) {
                                Label("导出全部", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        
                        Button(action: {
                            selectedSource = nil
                            showingEdit = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let source = selectedSource {
                    SourceEditView(source: source, viewModel: viewModel)
                } else {
                    SourceEditView(source: nil, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingImport) {
                SourceImportView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadSources()
            }
            .alert("操作失败", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
    }
}

// MARK: - 书源列表项
struct SourceItemView: View {
    let source: BookSource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(source.bookSourceName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                // 状态指示
                Circle()
                    .fill(source.enabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                // 类型图标
                if source.isAudio {
                    Image(systemName: "headphones")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if source.isImage {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if let group = source.bookSourceGroup {
                Text(group)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("响应：\(source.respondTime / 1000)s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(source.bookSourceUrl)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 书源编辑界面
struct SourceEditView: View {
    let source: BookSource?
    @ObservedObject var viewModel: SourceViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var url = ""
    @State private var group = ""
    @State private var type = 0
    @State private var searchUrl = ""
    @State private var exploreUrl = ""
    @State private var ruleSearch = ""
    @State private var ruleBookInfo = ""
    @State private var ruleToc = ""
    @State private var ruleContent = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基础信息")) {
                    TextField("书源名称", text: $name)
                    TextField("书源 URL", text: $url)
                    TextField("分组", text: $group)
                    
                    Picker("类型", selection: $type) {
                        Text("文本").tag(0)
                        Text("音频").tag(1)
                        Text("图片").tag(2)
                    }
                }
                
                Section(header: Text("搜索与发现")) {
                    TextField("搜索 URL", text: $searchUrl)
                    TextField("发现 URL", text: $exploreUrl)
                }
                
                Section(header: Text("规则（JSON 格式）")) {
                    TextEditor(text: $ruleSearch)
                        .frame(minHeight: 80)
                        .font(.system(.caption, design: .monospaced))
                    
                    TextField("书籍信息规则", text: $ruleBookInfo)
                    TextField("目录规则", text: $ruleToc)
                    TextEditor(text: $ruleContent)
                        .frame(minHeight: 80)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle(source == nil ? "新书源" : "编辑书源")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
            .onAppear {
                if let source = source {
                    name = source.bookSourceName
                    url = source.bookSourceUrl
                    group = source.bookSourceGroup ?? ""
                    type = Int(source.bookSourceType)
                    searchUrl = source.searchUrl ?? ""
                    exploreUrl = source.exploreUrl ?? ""
                    
                    if let data = source.ruleSearchData,
                       let json = String(data: data, encoding: .utf8) {
                        ruleSearch = json
                    }
                    
                    if let data = source.ruleContentData,
                       let json = String(data: data, encoding: .utf8) {
                        ruleContent = json
                    }
                    
                    if let data = source.ruleBookInfoData,
                       let json = String(data: data, encoding: .utf8) {
                        ruleBookInfo = json
                    }
                    
                    if let data = source.ruleTocData,
                       let json = String(data: data, encoding: .utf8) {
                        ruleToc = json
                    }
                }
            }
        }
    }
    
    private func save() {
        let saved: Bool
        if let source = source {
            saved = viewModel.updateSource(
                source,
                name: name,
                url: url,
                group: group,
                type: Int32(type),
                searchUrl: searchUrl,
                exploreUrl: exploreUrl,
                ruleSearch: ruleSearch,
                ruleBookInfo: ruleBookInfo,
                ruleToc: ruleToc,
                ruleContent: ruleContent
            )
        } else {
            saved = viewModel.createSource(
                name: name,
                url: url,
                group: group,
                type: Int32(type),
                searchUrl: searchUrl,
                exploreUrl: exploreUrl,
                ruleSearch: ruleSearch,
                ruleBookInfo: ruleBookInfo,
                ruleToc: ruleToc,
                ruleContent: ruleContent
            )
        }
        if saved {
            dismiss()
        }
    }
}

// MARK: - 书源导入界面
struct SourceImportView: View {
    @ObservedObject var viewModel: SourceViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var importText = ""
    @State private var importURL = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("从 URL 导入")) {
                    TextField("书源 URL", text: $importURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    Button(action: {
                        Task {
                            if await viewModel.importFromURL(importURL) {
                                dismiss()
                            }
                        }
                    }) {
                        Text("导入")
                    }
                    .disabled(importURL.isEmpty)
                }
                
                Section(header: Text("从文本导入")) {
                    TextEditor(text: $importText)
                        .frame(minHeight: 200)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button(action: {
                        if viewModel.importFromText(importText) {
                            dismiss()
                        }
                    }) {
                        Text("导入")
                    }
                    .disabled(importText.isEmpty)
                }
                
                Section {
                    Text("支持 JSON 格式的书源文件，可以复制书源链接或粘贴书源 JSON 内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("导入书源")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SourceManageView()
}
