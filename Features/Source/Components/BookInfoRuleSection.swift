import SwiftUI

struct BookInfoRuleSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    private var initRuleBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.bookInfoRule.init ?? "" },
            set: { viewModel.bookInfoRule.init = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Section(header: Text("书详规则")) {
            RuleFieldEditor(title: "初始化", text: initRuleBinding)
            RuleFieldEditor(title: "书名", text: $viewModel.bookInfoRule.name.orEmpty)
            RuleFieldEditor(title: "作者", text: $viewModel.bookInfoRule.author.orEmpty)
            RuleFieldEditor(title: "简介", text: $viewModel.bookInfoRule.intro.orEmpty)
            RuleFieldEditor(title: "封面链接", text: $viewModel.bookInfoRule.coverUrl.orEmpty)
            RuleFieldEditor(title: "目录链接", text: $viewModel.bookInfoRule.tocUrl.orEmpty)
            RuleFieldEditor(title: "最新章节", text: $viewModel.bookInfoRule.lastChapter.orEmpty)
            RuleFieldEditor(title: "字数", text: $viewModel.bookInfoRule.wordCount.orEmpty)
        }
    }
}
