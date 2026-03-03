import Foundation
import CoreData

@MainActor
class SourceEditViewModel: ObservableObject {
    @Published var source: BookSource
    @Published var searchRule: BookSource.SearchRule
    @Published var exploreRule: BookSource.ExploreRule
    @Published var bookInfoRule: BookSource.BookInfoRule
    @Published var tocRule: BookSource.TocRule
    @Published var contentRule: BookSource.ContentRule
    @Published var errorMessage: String?
    @Published var didSave = false

    private let context: NSManagedObjectContext
    private var persistedSource: BookSource?

    var isNewSource: Bool {
        persistedSource == nil
    }

    init(source: BookSource? = nil, context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        self.persistedSource = source

        let draftSource = Self.makeDraftSource(in: context)
        if let source {
            Self.copyEditableFields(from: source, to: draftSource)
            self.searchRule = source.getSearchRule() ?? BookSource.SearchRule()
            self.exploreRule = source.getExploreRule() ?? BookSource.ExploreRule()
            self.bookInfoRule = source.getBookInfoRule() ?? BookSource.BookInfoRule()
            self.tocRule = source.getTocRule() ?? BookSource.TocRule()
            self.contentRule = source.getContentRule() ?? BookSource.ContentRule()
        } else {
            self.searchRule = BookSource.SearchRule()
            self.exploreRule = BookSource.ExploreRule()
            self.bookInfoRule = BookSource.BookInfoRule()
            self.tocRule = BookSource.TocRule()
            self.contentRule = BookSource.ContentRule()
        }
        self.source = draftSource
    }

    func save() {
        didSave = false

        let name = source.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = source.bookSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty else {
            errorMessage = "书源名称和书源地址不能为空"
            return
        }

        do {
            try validateHeaderJSON(source.header)

            let target = persistedSource ?? BookSource.create(in: context)
            Self.copyEditableFields(from: source, to: target)
            target.setSearchRule(searchRule)
            target.setExploreRule(exploreRule)
            target.setBookInfoRule(bookInfoRule)
            target.setTocRule(tocRule)
            target.setContentRule(contentRule)

            try CoreDataStack.shared.save(context: context)

            persistedSource = target
            errorMessage = nil
            didSave = true
        } catch {
            context.rollback()
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func testSearch() {
        errorMessage = "搜索测试功能开发中"
    }

    func exportJSON() -> String {
        do {
            let payload = SourcePayload(
                bookSourceUrl: source.bookSourceUrl,
                bookSourceName: source.bookSourceName,
                bookSourceGroup: source.bookSourceGroup,
                bookSourceType: source.bookSourceType,
                header: source.header,
                loginUrl: source.loginUrl,
                searchUrl: source.searchUrl,
                exploreUrl: source.exploreUrl,
                exploreScreen: source.exploreScreen,
                ruleSearch: searchRule,
                ruleExplore: exploreRule,
                ruleBookInfo: bookInfoRule,
                ruleToc: tocRule,
                ruleContent: contentRule
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
            return ""
        }
    }

    func importJSON(_ json: String) {
        didSave = false
        guard let data = json.data(using: .utf8) else {
            errorMessage = "导入失败：文本编码无效"
            return
        }

        do {
            let payload = try JSONDecoder().decode(SourcePayload.self, from: data)

            source.bookSourceUrl = payload.bookSourceUrl ?? ""
            source.bookSourceName = payload.bookSourceName ?? ""
            source.bookSourceGroup = payload.bookSourceGroup
            source.bookSourceType = payload.bookSourceType ?? 0
            source.header = payload.header
            source.loginUrl = payload.loginUrl
            source.searchUrl = payload.searchUrl
            source.exploreUrl = payload.exploreUrl
            source.exploreScreen = payload.exploreScreen

            searchRule = payload.ruleSearch ?? BookSource.SearchRule()
            exploreRule = payload.ruleExplore ?? BookSource.ExploreRule()
            bookInfoRule = payload.ruleBookInfo ?? BookSource.BookInfoRule()
            tocRule = payload.ruleToc ?? BookSource.TocRule()
            contentRule = payload.ruleContent ?? BookSource.ContentRule()
            errorMessage = nil
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func validateHeaderJSON(_ header: String?) throws {
        guard let header else { return }
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = trimmed.data(using: .utf8) else {
            throw SourceEditError.invalidHeaderEncoding
        }
        _ = try JSONSerialization.jsonObject(with: data)
    }

    private static func makeDraftSource(in context: NSManagedObjectContext) -> BookSource {
        let entity = NSEntityDescription.entity(forEntityName: "BookSource", in: context)!
        let source = BookSource(entity: entity, insertInto: nil)
        source.sourceId = UUID()
        source.bookSourceUrl = ""
        source.bookSourceName = ""
        source.bookSourceType = 0
        source.enabled = true
        source.enabledExplore = true
        source.enabledCookieJar = false
        source.customOrder = 0
        source.weight = 0
        source.respondTime = 180000
        source.lastUpdateTime = 0
        return source
    }

    private static func copyEditableFields(from source: BookSource, to target: BookSource) {
        target.bookSourceUrl = source.bookSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        target.bookSourceName = source.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.bookSourceGroup = normalizeOptional(source.bookSourceGroup)
        target.bookSourceType = source.bookSourceType
        target.header = normalizeOptional(source.header)
        target.loginUrl = normalizeOptional(source.loginUrl)
        target.searchUrl = normalizeOptional(source.searchUrl)
        target.exploreUrl = normalizeOptional(source.exploreUrl)
        target.exploreScreen = normalizeOptional(source.exploreScreen)
    }

    private static func normalizeOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum SourceEditError: LocalizedError {
    case invalidHeaderEncoding

    var errorDescription: String? {
        switch self {
        case .invalidHeaderEncoding:
            return "Header 编码无效"
        }
    }
}

private struct SourcePayload: Codable {
    var bookSourceUrl: String?
    var bookSourceName: String?
    var bookSourceGroup: String?
    var bookSourceType: Int32?
    var header: String?
    var loginUrl: String?
    var searchUrl: String?
    var exploreUrl: String?
    var exploreScreen: String?
    var ruleSearch: BookSource.SearchRule?
    var ruleExplore: BookSource.ExploreRule?
    var ruleBookInfo: BookSource.BookInfoRule?
    var ruleToc: BookSource.TocRule?
    var ruleContent: BookSource.ContentRule?
}
