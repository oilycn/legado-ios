import SwiftUI

struct SearchRuleSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    var body: some View {
        Section(header: Text("搜索规则")) {
            RuleFieldEditor(
                title: "搜索地址",
                text: $viewModel.source.searchUrl.orEmpty,
                placeholder: "https://example.com/search?key={{key}}"
            )

            RuleFieldEditor(
                title: "关键词校验",
                text: $viewModel.searchRule.checkKeyWord.orEmpty,
                placeholder: "关键字"
            )

            RuleFieldEditor(title: "书籍列表", text: $viewModel.searchRule.bookList.orEmpty)
            RuleFieldEditor(title: "书名", text: $viewModel.searchRule.name.orEmpty)
            RuleFieldEditor(title: "作者", text: $viewModel.searchRule.author.orEmpty)
            RuleFieldEditor(title: "书籍链接", text: $viewModel.searchRule.bookUrl.orEmpty)
            RuleFieldEditor(title: "封面链接", text: $viewModel.searchRule.coverUrl.orEmpty)
            RuleFieldEditor(title: "简介", text: $viewModel.searchRule.intro.orEmpty)
            RuleFieldEditor(title: "最新章节", text: $viewModel.searchRule.lastChapter.orEmpty)
            RuleFieldEditor(title: "字数", text: $viewModel.searchRule.wordCount.orEmpty)
            RuleFieldEditor(title: "分类", text: $viewModel.searchRule.kind.orEmpty)
        }
    }
}
