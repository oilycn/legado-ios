import SwiftUI

struct TocRuleSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    var body: some View {
        Section(header: Text("目录规则")) {
            RuleFieldEditor(title: "章节列表", text: $viewModel.tocRule.chapterList.orEmpty)
            RuleFieldEditor(title: "章节名", text: $viewModel.tocRule.chapterName.orEmpty)
            RuleFieldEditor(title: "章节链接", text: $viewModel.tocRule.chapterUrl.orEmpty)
            RuleFieldEditor(title: "VIP 标记", text: $viewModel.tocRule.isVip.orEmpty)
            RuleFieldEditor(title: "付费标记", text: $viewModel.tocRule.isPay.orEmpty)
            RuleFieldEditor(title: "更新时间", text: $viewModel.tocRule.updateTime.orEmpty)
            RuleFieldEditor(title: "下一页目录链接", text: $viewModel.tocRule.nextTocUrl.orEmpty)
        }
    }
}
