import SwiftUI

struct BasicInfoSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    var body: some View {
        Section(header: Text("基本信息")) {
            RuleFieldEditor(
                title: "书源地址",
                text: $viewModel.source.bookSourceUrl,
                placeholder: "https://example.com"
            )

            RuleFieldEditor(
                title: "书源名称",
                text: $viewModel.source.bookSourceName,
                placeholder: "书源名称"
            )

            RuleFieldEditor(
                title: "书源分组",
                text: $viewModel.source.bookSourceGroup.orEmpty,
                placeholder: "可选分组"
            )

            Picker("书源类型", selection: $viewModel.source.bookSourceType) {
                Text("文本").tag(Int32(0))
                Text("音频").tag(Int32(1))
                Text("图片").tag(Int32(2))
            }

            RuleFieldEditor(
                title: "请求头 Header (JSON)",
                text: $viewModel.source.header.orEmpty,
                placeholder: "{\"User-Agent\":\"...\"}",
                isMultiline: true
            )

            RuleFieldEditor(
                title: "登录地址",
                text: $viewModel.source.loginUrl.orEmpty,
                placeholder: "https://example.com/login"
            )
        }
    }
}
