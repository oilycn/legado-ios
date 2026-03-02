//
//  BackupRestoreView.swift
//  Legado-iOS
//
//  备份与恢复视图
//

import SwiftUI
import CoreData

struct BackupRestoreView: View {
    @StateObject private var viewModel = BackupRestoreViewModel()
    @State private var showingExport = false
    @State private var showingImport = false
    
    var body: some View {
            Form {
                Section(header: Label("备份", systemImage: "square.and.arrow.up")) {
                    Button(action: { showingExport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出数据")
                        }
                    }
                    
                    Button(action: viewModel.backupAll) {
                        HStack {
                            Image(systemName: "doc")
                            Text("完整备份")
                        }
                    }
                }
                
                Section(header: Label("恢复", systemImage: "square.and.arrow.down")) {
                    Button(action: { showingImport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入数据")
                        }
                    }
                    
                    Button(action: viewModel.restoreFromBackup) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("从备份恢复")
                        }
                    }
                }
                
                Section(header: Label("云同步", systemImage: "cloud")) {
                    Toggle("iCloud 同步", isOn: .constant(false))
                    
                    Text("iCloud 同步功能开发中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(role: .destructive, action: viewModel.clearAllData) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清空所有数据")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("备份与恢复")
            .sheet(isPresented: $showingExport) {
                ExportDataView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingImport) {
                ImportDataView(viewModel: viewModel)
            }
            .alert("提示", isPresented: $viewModel.showingAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
    }
}

// MARK: - ViewModel
class BackupRestoreViewModel: ObservableObject {
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var showingAlert = false
    @Published var alertMessage: String?
    
    // MARK: - 备份所有数据
    func backupAll() {
        isBackingUp = true
        
        do {
            // ReplaceRule 使用 UserDefaults 存储，从 UserDefaults 获取
            let rulesData = UserDefaults.standard.data(forKey: "replace_rules")
            let rules = (try? JSONDecoder().decode([ReplaceRuleItem].self, from: rulesData ?? Data())) ?? []
            var dataDict: [String: Any] = [
                "version": "1.0",
                "timestamp": Date().timeIntervalSince1970,
                "books": books.map { bookToDict($0) },
                "sources": sources.map { sourceToDict($0) },
                "rules": rules.map { ruleItemToDict($0) }
            
            let jsonData = try JSONSerialization.data(withJSONObject: dataDict, options: .prettyPrinted)
            
            // 保存到文件
            saveExportFile(data: jsonData, filename: "legado_backup_\(Date().timeIntervalSince1970).json")
            
            isBackingUp = false
            alertMessage = "备份成功！"
            showingAlert = true
        } catch {
            isBackingUp = false
            alertMessage = "备份失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // MARK: - 从备份恢复
    func restoreFromBackup() {
        isRestoring = true
        
        // TODO: 实现从文件恢复
        isRestoring = false
        alertMessage = "恢复功能开发中"
        showingAlert = true
    }
    
    // MARK: - 清空所有数据
    func clearAllData() {
        let context = CoreDataStack.shared.viewContext
        
        // 删除所有实体
        let entities = ["Book", "BookSource", "BookChapter", "Bookmark"]
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(fetchRequest) {
                for object in objects {
                    context.delete(object)
                }
            }
        }
        
        try? CoreDataStack.shared.save()
        
        alertMessage = "数据已清空"
        showingAlert = true
    }
    
    // MARK: - 辅助方法
    private func bookToDict(_ book: Book) -> [String: Any] {
        return [
            "bookUrl": book.bookUrl,
            "tocUrl": book.tocUrl,
            "name": book.name,
            "author": book.author,
            "coverUrl": book.coverUrl ?? "",
            "intro": book.intro ?? ""
        ]
    }
    
    private func sourceToDict(_ source: BookSource) -> [String: Any] {
        return [
            "bookSourceUrl": source.bookSourceUrl,
            "bookSourceName": source.bookSourceName,
            "bookSourceGroup": source.bookSourceGroup ?? "",
            "searchUrl": source.searchUrl ?? ""
        ]
    }
    
    private func ruleItemToDict(_ rule: ReplaceRuleItem) -> [String: Any] {
        return [
            "name": rule.name,
            "pattern": rule.pattern,
            "replacement": rule.replacement,
            "isRegex": rule.isRegex,
            "enabled": rule.enabled,
            "scope": rule.scope
        ]
    }
    private func saveExportFile(data: Data, filename: String) {
        // 保存到 Documents 目录
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
        
        // 使用 UIActivityViewController 分享
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - 导出数据视图
struct ExportDataView: View {
    @ObservedObject var viewModel: BackupRestoreViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var exportBooks = true
    @State private var exportSources = true
    @State private var exportRules = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("导出书籍", isOn: $exportBooks)
                    Toggle("导出书源", isOn: $exportSources)
                    Toggle("导出规则", isOn: $exportRules)
                }
                
                Section {
                    Button("导出") {
                        viewModel.backupAll()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("导出数据")
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

// MARK: - 导入数据视图
struct ImportDataView: View {
    @ObservedObject var viewModel: BackupRestoreViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("选择备份文件")
                    .font(.title2)
                
                Text("支持.json 格式的备份文件")
                    .foregroundColor(.secondary)
                
                Button("从文件选择") {
                    // TODO: 实现文件选择
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("导入数据")
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
    BackupRestoreView()
}
