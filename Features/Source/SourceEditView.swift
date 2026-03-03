import SwiftUI

struct SourceEditView: View {
    @ObservedObject var viewModel: SourceEditViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                BasicInfoSection(viewModel: viewModel)
                SearchRuleSection(viewModel: viewModel)
                ExploreRuleSection(viewModel: viewModel)
                BookInfoRuleSection(viewModel: viewModel)
                TocRuleSection(viewModel: viewModel)
                ContentRuleSection(viewModel: viewModel)
            }
            .navigationTitle(viewModel.isNewSource ? "新书源" : "编辑书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        viewModel.save()
                    }
                }
            }
        }
        .onChange(of: viewModel.didSave) { saved in
            if saved {
                dismiss()
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }
}
