//
//  SourceDebugView.swift
//  Legado-iOS
//
//  书源调试器：实时测试书源规则执行结果
//  P0-T8 实现
//

import SwiftUI

struct SourceDebugView: View {
    @ObservedObject var viewModel: SourceDebugViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 规则输入区
                ruleInputSection
                
                Divider()
                
                // 执行按钮
                actionButtons
                
                Divider()
                
                // 结果输出区
                resultSection
            }
            .navigationTitle("书源调试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        viewModel.clearResults()
                    }
                }
            }
        }
    }
    
    // MARK: - 规则输入区
    
    private var ruleInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("调试类型", selection: $viewModel.debugType) {
                ForEach(SourceDebugViewModel.DebugType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            switch viewModel.debugType {
            case .search:
                searchDebugInput
            case .explore:
                exploreDebugInput
            case .bookInfo:
                bookInfoDebugInput
            case .content:
                contentDebugInput
            }
        }
    }
    
    // MARK: - 搜索调试输入
    
    private var searchDebugInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("搜索关键词:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("输入搜索关键词", text: $viewModel.searchKeyword)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("搜索 URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.searchUrl ?? "未配置")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(viewModel.searchUrl == nil ? .secondary : .primary)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 发现调试输入
    
    private var exploreDebugInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("发现 URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("输入发现 URL", text: $viewModel.exploreUrl)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("发现规则:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.exploreRuleSummary)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 书籍信息调试输入
    
    private var bookInfoDebugInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("书籍 URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("输入书籍详情页 URL", text: $viewModel.bookInfoUrl)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 正文调试输入
    
    private var contentDebugInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("章节 URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("输入章节页 URL", text: $viewModel.contentUrl)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("正文规则:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.contentRuleSummary)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 执行按钮
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                Task { await viewModel.executeDebug() }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("执行")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExecuting)
            
            Button {
                Task { await viewModel.executeStepByStep() }
            } label: {
                HStack {
                    Image(systemName: "forward.end.fill")
                    Text("单步执行")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isExecuting)
        }
        .padding()
    }
    
    // MARK: - 结果区
    
    private var resultSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 执行状态
                if viewModel.isExecuting {
                    HStack {
                        ProgressView()
                        Text("执行中...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // 错误信息
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // 调试日志
                ForEach(viewModel.debugLogs) { log in
                    DebugLogItem(log: log)
                }
                
                // 结果数据
                if !viewModel.resultItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("结果 (\(viewModel.resultItems.count) 条)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.resultItems) { item in
                            ResultItemRow(item: item, onTap: {
                                viewModel.selectResultItem(item)
                            })
                        }
                    }
                }
                
                // 原始响应
                if let rawResponse = viewModel.rawResponse {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("原始响应")
                                .font(.headline)
                            Spacer()
                            Button("复制") {
                                UIPasteboard.general.string = rawResponse
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(rawResponse)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - 调试日志项

struct DebugLogItem: View {
    let log: DebugLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: log.level.icon)
                .foregroundColor(log.level.color)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(.system(.caption, design: .monospaced))
                
                if let detail = log.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(log.level.backgroundColor)
        .cornerRadius(6)
        .padding(.horizontal)
    }
}

// MARK: - 结果项行

struct ResultItemRow: View {
    let item: DebugResultItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - 预览

#Preview {
    SourceDebugView(viewModel: SourceDebugViewModel(source: nil))
}