import SwiftUI

struct ExploreRuleSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    var body: some View {
        Section(header: Text("发现规则")) {
            RuleFieldEditor(
                title: "发现地址",
                text: $viewModel.source.exploreUrl.orEmpty,
                placeholder: "https://example.com/explore"
            )

            RuleFieldEditor(
                title: "发现筛选",
                text: $viewModel.source.exploreScreen.orEmpty,
                placeholder: "可选筛选规则"
            )

            RuleFieldEditor(title: "发现列表", text: $viewModel.exploreRule.exploreList.orEmpty)
            RuleFieldEditor(title: "书名", text: $viewModel.exploreRule.name.orEmpty)
            RuleFieldEditor(title: "作者", text: $viewModel.exploreRule.author.orEmpty)
            RuleFieldEditor(title: "书籍链接", text: $viewModel.exploreRule.bookUrl.orEmpty)
            RuleFieldEditor(title: "封面链接", text: $viewModel.exploreRule.coverUrl.orEmpty)
            RuleFieldEditor(title: "简介", text: $viewModel.exploreRule.intro.orEmpty)
            RuleFieldEditor(title: "最新章节", text: $viewModel.exploreRule.lastChapter.orEmpty)
        }
    }
}
