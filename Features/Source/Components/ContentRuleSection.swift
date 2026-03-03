import SwiftUI

struct ContentRuleSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    var body: some View {
        Section(header: Text("正文规则")) {
            RuleFieldEditor(title: "正文", text: $viewModel.contentRule.content.orEmpty, isMultiline: true)
            RuleFieldEditor(title: "标题", text: $viewModel.contentRule.title.orEmpty)
            RuleFieldEditor(title: "下一页正文链接", text: $viewModel.contentRule.nextContentUrl.orEmpty)
            RuleFieldEditor(title: "网页 JS", text: $viewModel.contentRule.webJs.orEmpty, isMultiline: true)
            RuleFieldEditor(title: "来源正则", text: $viewModel.contentRule.sourceRegex.orEmpty)
            RuleFieldEditor(title: "替换正则", text: $viewModel.contentRule.replaceRegex.orEmpty)
            RuleFieldEditor(title: "图片样式", text: $viewModel.contentRule.imageStyle.orEmpty)
            RuleFieldEditor(title: "付费动作", text: $viewModel.contentRule.payAction.orEmpty, isMultiline: true)
        }
    }
}
