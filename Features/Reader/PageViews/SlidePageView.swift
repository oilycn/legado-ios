//
//  SlidePageView.swift
//  Legado-iOS
//
//  滑动翻页动画：使用 TabView 实现平滑水平滑动
//

import SwiftUI

struct SlidePageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                SinglePageContent(
                    text: page,
                    viewModel: viewModel,
                    onTap: onTap
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: currentPage) { newValue in
            viewModel.currentPageIndex = newValue
        }
    }
}

// MARK: - 单页内容

private struct SinglePageContent: View {
    let text: String
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            viewModel.backgroundColor
            
            ScrollView(.vertical, showsIndicators: false) {
                Text(text)
                    .font(.system(size: viewModel.fontSize))
                    .foregroundColor(viewModel.textColor)
                    .lineSpacing(viewModel.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(viewModel.pagePadding)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
