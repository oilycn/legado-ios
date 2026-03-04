//
//  BackupRestoreView.swift
//  Legado-iOS
//
//  备份与恢复视图
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

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
                NavigationLink {
                    WebDAVConfigView()
                } label: {
                    HStack {
                        Image(systemName: "externaldrive.badge.wifi")
                        Text("WebDAV 同步")
                    }
                }

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
        .fileImporter(
            isPresented: $viewModel.showingRestoreImporter,
            allowedContentTypes: [.json, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                viewModel.restoreFromBackupFile(fileURL)
            case .failure(let error):
                viewModel.alertMessage = "选择文件失败：\(error.localizedDescription)"
                viewModel.showingAlert = true
            }
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
    @Published var showingRestoreImporter = false
    @Published var showingAlert = false
    @Published var alertMessage: String?
    
    private let context = CoreDataStack.shared.viewContext
    
    // MARK: - 备份所有数据
    func backupAll() {
        isBackingUp = true
        
        do {
            // 从 CoreData 获取数据
            let books = try context.fetch(Book.fetchRequest())
            let sources = try context.fetch(BookSource.fetchRequest())
            let rules = try context.fetch(ReplaceRule.fetchRequest())
            
            var dataDict: [String: Any] = [
                "version": "1.0",
                "timestamp": Date().timeIntervalSince1970,
                "books": books.map { bookToDict($0) },
                "sources": sources.map { sourceToDict($0) },
                "rules": rules.map { ruleToDict($0) }
            ]
            
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
        showingRestoreImporter = true
    }

    func restoreFromBackupFile(_ fileURL: URL) {
        isRestoring = true
        defer { isRestoring = false }

        let granted = fileURL.startAccessingSecurityScopedResource()
        defer {
            if granted {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let result = try restoreFromBackupData(data)
            let summary = [
                "书籍 \(result.books) 本",
                "书源 \(result.sources) 个",
                "规则 \(result.rules) 条"
            ].joined(separator: "，")
            alertMessage = "恢复成功：\(summary)"
        } catch {
            context.rollback()
            alertMessage = "恢复失败：\(error.localizedDescription)"
        }
        showingAlert = true
    }
    
    // MARK: - 清空所有数据
    func clearAllData() {
        // 删除所有实体
        let entities = ["Book", "BookSource", "BookChapter", "Bookmark", "ReplaceRule"]
        
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
    
    private func ruleToDict(_ rule: ReplaceRule) -> [String: Any] {
        return [
            "ruleId": rule.ruleId.uuidString,
            "name": rule.name,
            "pattern": rule.pattern,
            "replacement": rule.replacement,
            "scope": rule.scope,
            "scopeId": rule.scopeId ?? "",
            "isRegex": rule.isRegex,
            "enabled": rule.enabled,
            "priority": rule.priority,
            "order": rule.order
        ]
    }

    private func restoreFromBackupData(_ data: Data) throws -> (books: Int, sources: Int, rules: Int) {
        let object = try JSONSerialization.jsonObject(with: data)
        var booksCount = 0
        var sourcesCount = 0
        var rulesCount = 0

        if let dict = object as? [String: Any] {
            if let books = dict["books"] as? [[String: Any]] {
                booksCount += importBooks(books)
            }
            if let sources = dict["sources"] as? [[String: Any]] {
                sourcesCount += importSources(sources)
            }
            if let rules = dict["rules"] as? [[String: Any]] {
                rulesCount += importRules(rules)
            }

            if booksCount == 0, sourcesCount == 0, rulesCount == 0 {
                if dict["bookSourceUrl"] != nil {
                    sourcesCount += importSources([dict])
                } else if dict["bookUrl"] != nil {
                    booksCount += importBooks([dict])
                }
            }
        } else if let array = object as? [[String: Any]] {
            if let first = array.first {
                if first["bookSourceUrl"] != nil {
                    sourcesCount += importSources(array)
                } else if first["bookUrl"] != nil {
                    booksCount += importBooks(array)
                } else if first["pattern"] != nil {
                    rulesCount += importRules(array)
                }
            }
        }

        if booksCount == 0, sourcesCount == 0, rulesCount == 0 {
            throw NSError(domain: "BackupRestore", code: 1, userInfo: [NSLocalizedDescriptionKey: "备份文件中没有可恢复的数据"]) 
        }

        try CoreDataStack.shared.save()
        return (booksCount, sourcesCount, rulesCount)
    }

    private func importBooks(_ books: [[String: Any]]) -> Int {
        var count = 0
        for bookData in books {
            let book = findOrCreateBook(bookData)
            book.name = stringValue(bookData["name"]) ?? book.name
            book.author = stringValue(bookData["author"]) ?? book.author
            book.bookUrl = stringValue(bookData["bookUrl"]) ?? book.bookUrl
            book.tocUrl = stringValue(bookData["tocUrl"]) ?? book.tocUrl
            book.coverUrl = stringValue(bookData["coverUrl"])
            book.intro = stringValue(bookData["intro"])

            if let origin = stringValue(bookData["origin"]), !origin.isEmpty {
                book.origin = origin
            }
            if let originName = stringValue(bookData["originName"]), !originName.isEmpty {
                book.originName = originName
            }

            book.durChapterIndex = int32Value(bookData["durChapterIndex"], defaultValue: book.durChapterIndex)
            book.durChapterPos = int32Value(bookData["durChapterPos"], defaultValue: book.durChapterPos)
            book.durChapterTitle = stringValue(bookData["durChapterTitle"]) ?? book.durChapterTitle
            count += 1
        }
        return count
    }

    private func importSources(_ sources: [[String: Any]]) -> Int {
        var count = 0
        for sourceData in sources {
            guard let sourceURL = stringValue(sourceData["bookSourceUrl"]), !sourceURL.isEmpty else {
                continue
            }

            let source = findOrCreateSource(sourceURL: sourceURL)
            source.bookSourceUrl = sourceURL
            source.bookSourceName = stringValue(sourceData["bookSourceName"]) ?? source.bookSourceName
            source.bookSourceGroup = stringValue(sourceData["bookSourceGroup"]) ?? source.bookSourceGroup
            source.searchUrl = stringValue(sourceData["searchUrl"]) ?? source.searchUrl
            source.exploreUrl = stringValue(sourceData["exploreUrl"]) ?? source.exploreUrl
            source.header = stringValue(sourceData["header"]) ?? source.header
            source.enabled = boolValue(sourceData["enabled"], defaultValue: source.enabled)
            source.enabledExplore = boolValue(sourceData["enabledExplore"], defaultValue: source.enabledExplore)

            if let ruleSearch = sourceData["ruleSearch"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: ruleSearch) {
                source.ruleSearchData = data
            }
            if let ruleExplore = sourceData["ruleExplore"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: ruleExplore) {
                source.ruleExploreData = data
            }
            if let ruleBookInfo = sourceData["ruleBookInfo"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: ruleBookInfo) {
                source.ruleBookInfoData = data
            }
            if let ruleToc = sourceData["ruleToc"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: ruleToc) {
                source.ruleTocData = data
            }
            if let ruleContent = sourceData["ruleContent"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: ruleContent) {
                source.ruleContentData = data
            }

            count += 1
        }
        return count
    }

    private func importRules(_ rules: [[String: Any]]) -> Int {
        var count = 0
        for ruleData in rules {
            let rule = findOrCreateRule(ruleData)
            rule.name = stringValue(ruleData["name"]) ?? rule.name
            rule.pattern = stringValue(ruleData["pattern"]) ?? rule.pattern
            rule.replacement = stringValue(ruleData["replacement"]) ?? rule.replacement
            rule.scope = stringValue(ruleData["scope"]) ?? rule.scope
            rule.scopeId = stringValue(ruleData["scopeId"]) ?? rule.scopeId
            rule.isRegex = boolValue(ruleData["isRegex"], defaultValue: rule.isRegex)
            rule.enabled = boolValue(ruleData["enabled"], defaultValue: rule.enabled)
            rule.priority = int32Value(ruleData["priority"], defaultValue: rule.priority)
            rule.order = int32Value(ruleData["order"], defaultValue: rule.order)
            count += 1
        }
        return count
    }

    private func findOrCreateBook(_ data: [String: Any]) -> Book {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.fetchLimit = 1

        if let bookUrl = stringValue(data["bookUrl"]), !bookUrl.isEmpty {
            let origin = stringValue(data["origin"]) ?? ""
            request.predicate = NSPredicate(format: "bookUrl == %@ AND origin == %@", bookUrl, origin)
            if let existing = try? context.fetch(request).first {
                return existing
            }
        }

        let book = Book.create(in: context)
        book.origin = stringValue(data["origin"]) ?? ""
        book.originName = stringValue(data["originName"]) ?? ""
        return book
    }

    private func findOrCreateSource(sourceURL: String) -> BookSource {
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "bookSourceUrl == %@", sourceURL)

        if let existing = try? context.fetch(request).first {
            return existing
        }

        return BookSource.create(in: context)
    }

    private func findOrCreateRule(_ data: [String: Any]) -> ReplaceRule {
        let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
        request.fetchLimit = 1

        if let ruleIdText = stringValue(data["ruleId"]),
           let ruleId = UUID(uuidString: ruleIdText) {
            request.predicate = NSPredicate(format: "ruleId == %@", ruleId as CVarArg)
            if let existing = try? context.fetch(request).first {
                return existing
            }
        }

        return ReplaceRule.create(in: context)
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func int32Value(_ value: Any?, defaultValue: Int32) -> Int32 {
        switch value {
        case let int32 as Int32:
            return int32
        case let int as Int:
            return Int32(int)
        case let int64 as Int64:
            return Int32(int64)
        case let number as NSNumber:
            return number.int32Value
        case let string as String:
            return Int32(string) ?? defaultValue
        default:
            return defaultValue
        }
    }

    private func boolValue(_ value: Any?, defaultValue: Bool) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            return NSString(string: string).boolValue
        default:
            return defaultValue
        }
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
                    dismiss()
                    viewModel.restoreFromBackup()
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

// MARK: - 预览
#Preview {
    BackupRestoreView()
}
