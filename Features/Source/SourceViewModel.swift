//
//  SourceViewModel.swift
//  Legado-iOS
//
//  书源管理 ViewModel
//

import Foundation
import CoreData

@MainActor
class SourceViewModel: ObservableObject {
    @Published var sources: [BookSource] = []
    @Published var errorMessage: String?
    
    func loadSources() async {
        do {
            let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "customOrder", ascending: true)]
            request.includesPendingChanges = false
            
            sources = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            errorMessage = "加载书源失败：\(error.localizedDescription)"
        }
    }
    
    func createSource(
        name: String,
        url: String,
        group: String,
        type: Int32,
        searchUrl: String,
        exploreUrl: String,
        ruleSearch: String,
        ruleBookInfo: String,
        ruleToc: String,
        ruleContent: String
    ) -> Bool {
        let context = CoreDataStack.shared.viewContext
        let source = BookSource.create(in: context)
        
        source.bookSourceName = name
        source.bookSourceUrl = url
        source.bookSourceGroup = group.isEmpty ? nil : group
        source.bookSourceType = type
        source.searchUrl = searchUrl.isEmpty ? nil : searchUrl
        source.exploreUrl = exploreUrl.isEmpty ? nil : exploreUrl
        do {
            source.ruleSearchData = try encodeRuleJSON(from: ruleSearch)
            source.ruleBookInfoData = try encodeRuleJSON(from: ruleBookInfo)
            source.ruleTocData = try encodeRuleJSON(from: ruleToc)
            source.ruleContentData = try encodeRuleJSON(from: ruleContent)
        } catch {
            context.rollback()
            errorMessage = "保存失败：\(error.localizedDescription)"
            return false
        }
        
        do {
            try CoreDataStack.shared.save()
            Task { await loadSources() }
            return true
        } catch {
            context.rollback()
            errorMessage = "保存失败：\(error.localizedDescription)"
            Task { await loadSources() }
            return false
        }
    }
    
    func updateSource(
        _ source: BookSource,
        name: String,
        url: String,
        group: String,
        type: Int32,
        searchUrl: String,
        exploreUrl: String,
        ruleSearch: String,
        ruleBookInfo: String,
        ruleToc: String,
        ruleContent: String
    ) -> Bool {
        let context = CoreDataStack.shared.viewContext
        source.bookSourceName = name
        source.bookSourceUrl = url
        source.bookSourceGroup = group.isEmpty ? nil : group
        source.bookSourceType = type
        source.searchUrl = searchUrl.isEmpty ? nil : searchUrl
        source.exploreUrl = exploreUrl.isEmpty ? nil : exploreUrl
        do {
            source.ruleSearchData = try encodeRuleJSON(from: ruleSearch)
            source.ruleBookInfoData = try encodeRuleJSON(from: ruleBookInfo)
            source.ruleTocData = try encodeRuleJSON(from: ruleToc)
            source.ruleContentData = try encodeRuleJSON(from: ruleContent)
        } catch {
            context.rollback()
            errorMessage = "保存失败：\(error.localizedDescription)"
            return false
        }
        
        do {
            try CoreDataStack.shared.save()
            Task { await loadSources() }
            return true
        } catch {
            context.rollback()
            errorMessage = "保存失败：\(error.localizedDescription)"
            Task { await loadSources() }
            return false
        }
    }
    
    func deleteSource(_ source: BookSource) {
        let context = CoreDataStack.shared.viewContext
        context.delete(source)
        do {
            try CoreDataStack.shared.save()
        } catch {
            context.rollback()
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
        Task {
            await loadSources()
        }
    }
    
    func deleteSources(at indexSet: IndexSet) {
        let context = CoreDataStack.shared.viewContext
        for index in indexSet {
            context.delete(sources[index])
        }
        do {
            try CoreDataStack.shared.save()
        } catch {
            context.rollback()
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
        Task {
            await loadSources()
        }
    }
    
    func importFromURL(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            errorMessage = "无效的 URL"
            return false
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return importFromJSON(json)
            }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return importSingleSource(json)
            }
            errorMessage = "导入失败：不支持的 JSON 格式"
            return false
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
            return false
        }
    }
    
    func importFromText(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else {
            errorMessage = "无效的文本"
            return false
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return importFromJSON(json)
            } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return importSingleSource(json)
            }
            errorMessage = "导入失败：不支持的 JSON 格式"
            return false
        } catch {
            errorMessage = "解析 JSON 失败：\(error.localizedDescription)"
            return false
        }
    }
    
    private func importFromJSON(_ sources: [[String: Any]]) -> Bool {
        let context = CoreDataStack.shared.viewContext
        
        for sourceData in sources {
            let source = findOrCreateSource(for: sourceData, in: context)
            applySourceData(source, sourceData)
        }
        
        do {
            try CoreDataStack.shared.save()
            Task { await loadSources() }
            return true
        } catch {
            context.rollback()
            errorMessage = "导入失败：\(error.localizedDescription)"
            Task { await loadSources() }
            return false
        }
    }
    
    private func importSingleSource(_ sourceData: [String: Any]) -> Bool {
        let context = CoreDataStack.shared.viewContext
        let source = findOrCreateSource(for: sourceData, in: context)
        applySourceData(source, sourceData)

        do {
            try CoreDataStack.shared.save()
            Task { await loadSources() }
            return true
        } catch {
            context.rollback()
            errorMessage = "导入失败：\(error.localizedDescription)"
            Task { await loadSources() }
            return false
        }
    }

    private func findOrCreateSource(for data: [String: Any], in context: NSManagedObjectContext) -> BookSource {
        let url = data["bookSourceUrl"] as? String ?? ""
        if !url.isEmpty {
            let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "bookSourceUrl == %@", url)
            if let existing = try? context.fetch(request).first {
                return existing
            }
        }
        return BookSource.create(in: context)
    }

    private func encodeRuleJSON(from text: String) throws -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw SourceValidationError.invalidEncoding
        }
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: jsonObject)
    }
    
    private func applySourceData(_ source: BookSource, _ data: [String: Any]) {
        source.bookSourceName = data["bookSourceName"] as? String ?? ""
        source.bookSourceUrl = data["bookSourceUrl"] as? String ?? ""
        source.bookSourceGroup = data["bookSourceGroup"] as? String
        source.bookSourceType = data["bookSourceType"] as? Int32 ?? 0
        source.searchUrl = data["searchUrl"] as? String
        source.exploreUrl = data["exploreUrl"] as? String
        
        // 保存规则 JSON
        if let ruleSearch = data["ruleSearch"] {
            source.ruleSearchData = try? JSONSerialization.data(withJSONObject: ruleSearch)
        }
        if let ruleContent = data["ruleContent"] {
            source.ruleContentData = try? JSONSerialization.data(withJSONObject: ruleContent)
        }
        if let ruleBookInfo = data["ruleBookInfo"] {
            source.ruleBookInfoData = try? JSONSerialization.data(withJSONObject: ruleBookInfo)
        }
        if let ruleToc = data["ruleToc"] {
            source.ruleTocData = try? JSONSerialization.data(withJSONObject: ruleToc)
        }
    }
    
    func exportAllSources() {
        let sources = sources.map { source -> [String: Any] in
            var dict: [String: Any] = [
                "bookSourceName": source.bookSourceName,
                "bookSourceUrl": source.bookSourceUrl
            ]
            
            if let group = source.bookSourceGroup {
                dict["bookSourceGroup"] = group
            }
            
            dict["bookSourceType"] = source.bookSourceType
            dict["searchUrl"] = source.searchUrl
            dict["exploreUrl"] = source.exploreUrl
            
            // 导出规则
            if let searchData = source.ruleSearchData,
               let searchJson = try? JSONSerialization.jsonObject(with: searchData) {
                dict["ruleSearch"] = searchJson
            }
            
            if let contentData = source.ruleContentData,
               let contentJson = try? JSONSerialization.jsonObject(with: contentData) {
                dict["ruleContent"] = contentJson
            }
            
            return dict
        }
        
        // TODO: 导出为文件
        print("导出 \(sources.count) 个书源")
    }
}

private enum SourceValidationError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "规则内容编码无效"
        }
    }
}
