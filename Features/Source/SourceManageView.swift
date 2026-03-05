//
//  SourceManageView.swift
//  Legado-iOS
//
//  书源管理界面（含批量操作）
//

import SwiftUI
import CoreData
import Foundation
import UniformTypeIdentifiers

struct SourceManageView: View {
    @StateObject private var viewModel = SourceViewModel()
    @State private var showingEdit = false
    @State private var showingImport = false
    @State private var editViewModel: SourceEditViewModel?
    
    // 批量操作状态
    @State private var isEditMode = false
    @State private var selectedSources: Set<UUID> = []
    
    @State private var showingExporter = false
    @State private var exportDocument = JSONDataDocument()
    @State private var exportFileName = "bookSource"
    
    var body: some View {
        ZStack {
            List {
                if viewModel.sources.isEmpty {
                    EmptyStateView(
                        title: "暂无书源",
                        subtitle: "点击右上角导入或创建书源",
                        imageName: "square.grid.2x2"
                    )
                } else {
                    ForEach(viewModel.sources, id: \.sourceId) { source in
                        SourceItemView(
                            source: source,
                            isSelected: selectedSources.contains(source.sourceId),
                            isEditMode: isEditMode
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                toggleSelection(source.sourceId)
                            }
                        }
                        .swipeActions {
                            if !isEditMode {
                                Button(role: .destructive) {
                                    viewModel.deleteSource(source)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    editViewModel = SourceEditViewModel(source: source)
                                    showingEdit = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditMode ? "取消" : "编辑") {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedSources.removeAll()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button(action: { showingImport = true }) {
                                Label("导入书源", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: exportAllSources) {
                                Label("导出全部", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }

                        Button(action: {
                            editViewModel = SourceEditViewModel()
                            showingEdit = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEdit, onDismiss: {
                editViewModel = nil
                Task {
                    await viewModel.loadSources()
                }
            }) {
                if let editViewModel {
                    SourceEditView(viewModel: editViewModel)
                }
            }
            .sheet(isPresented: $showingImport) {
                SourceImportView(viewModel: viewModel)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFileName
            ) { result in
                if case .failure(let error) = result {
                    viewModel.errorMessage = "导出失败：\(error.localizedDescription)"
                }
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
            
            // MARK: - 底部批量操作栏
            if isEditMode && !viewModel.sources.isEmpty {
                VStack {
                    Spacer()
                    
                    BatchActionBar(
                        selectedCount: selectedSources.count,
                        totalCount: viewModel.sources.count,
                        onSelectAll: selectAll,
                        onEnable: { batchEnable(true) },
                        onDisable: { batchEnable(false) },
                        onDelete: batchDelete
                    )
                }
            }
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedSources.contains(id) {
            selectedSources.remove(id)
        } else {
            selectedSources.insert(id)
        }
    }
    
    private func selectAll() {
        if selectedSources.count == viewModel.sources.count {
            selectedSources.removeAll()
        } else {
            selectedSources = Set(viewModel.sources.map { $0.sourceId })
        }
    }
    
    private func batchEnable(_ enabled: Bool) {
        for id in selectedSources {
            if let source = viewModel.sources.first(where: { $0.sourceId == id }) {
                source.enabled = enabled
            }
        }
        try? CoreDataStack.shared.save()
        selectedSources.removeAll()
    }
    
    private func batchDelete() {
        for id in selectedSources {
            if let source = viewModel.sources.first(where: { $0.sourceId == id }) {
                viewModel.deleteSource(source)
            }
        }
        selectedSources.removeAll()
    }

    private func exportAllSources() {
        guard let data = viewModel.exportAllSources() else { return }
        exportDocument = JSONDataDocument(data: data)
        exportFileName = makeExportFileName()
        showingExporter = true
    }

    private func makeExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "bookSource-\(formatter.string(from: Date()))"
    }
}

// MARK: - 批量操作栏
struct BatchActionBar: View {
    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onEnable: () -> Void
    let onDisable: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // 选择状态
            Button(action: onSelectAll) {
                VStack(spacing: 2) {
                    Image(systemName: selectedCount == totalCount ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                    Text(selectedCount == totalCount ? "取消全选" : "全选")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
                .frame(height: 40)
            
            // 启用
            Button(action: onEnable) {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                    Text("启用")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.5 : 1)
            
            Divider()
                .frame(height: 40)
            
            // 禁用
            Button(action: onDisable) {
                VStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                    Text("禁用")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.5 : 1)
            
            Divider()
                .frame(height: 40)
            
            // 删除
            Button(action: onDelete) {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.title3)
                    Text("删除")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.red)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.5 : 1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 书源列表项（增强版）
struct SourceItemView: View {
    let source: BookSource
    var isSelected: Bool = false
    var isEditMode: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 编辑模式下的选择指示器
            if isEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
                            let count = await viewModel.importFromURL(importURL)
                            if count > 0 {
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
                        let count = viewModel.importFromText(importText)
                        if count > 0 {
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

#Preview {
    SourceManageView()
}
