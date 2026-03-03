//
//  PagedReaderView.swift
//  Legado-iOS
//
//  分页阅读容器视图
//  根据用户设置的翻页动画类型切换不同的翻页实现
//

import SwiftUI

struct PagedReaderView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @AppStorage("pageAnimation") var pageAnimationRaw: String = PageAnimationType.slide.rawValue
    let onTap: () -> Void
    
    @State private var pages: [String] = []
    @State private var currentPage: Int = 0
    @State private var containerSize: CGSize = .zero
    
    private var pageAnimation: PageAnimationType {
        PageAnimationType(rawValue: pageAnimationRaw) ?? .slide
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                viewModel.backgroundColor.ignoresSafeArea()
                
                if pages.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.chapterContent != nil {
                        // 有内容但还没分页（首次加载）
                        ProgressView("分页中...")
                    } else {
                        Text("暂无内容")
                            .foregroundColor(.secondary)
                    }
                } else {
                    pageView
                }
                
                // 页码指示器
                if !pages.isEmpty {
                    VStack {
                        Spacer()
                        pageIndicator
                    }
                }
            }
            .onAppear {
                containerSize = geometry.size
                splitPages()
            }
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
                splitPages()
            }
            .onChange(of: viewModel.chapterContent) { _ in
                splitPages()
            }
            .onChange(of: viewModel.fontSize) { _ in
                invalidateAndResplit()
            }
            .onChange(of: viewModel.lineSpacing) { _ in
                invalidateAndResplit()
            }
        }
    }
    
    // MARK: - 翻页视图切换
    
    @ViewBuilder
    private var pageView: some View {
        switch pageAnimation {
        case .cover:
            CoverPageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: $currentPage,
                onTap: onTap
            )
            
        case .slide:
            SlidePageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: $currentPage,
                onTap: onTap
            )
            
        case .scroll:
            scrollView
            
        case .simulation:
            CurlPageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: $currentPage,
                onTap: onTap
            )
            
        case .none:
            InstantPageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: $currentPage,
                onTap: onTap
            )
        }
    }
    
    // MARK: - 滚动视图（保留原有滚动模式）
    
    private var scrollView: some View {
        ScrollView {
            if let content = viewModel.chapterContent {
                Text(content)
                    .font(.system(size: viewModel.fontSize))
                    .foregroundColor(viewModel.textColor)
                    .lineSpacing(viewModel.lineSpacing)
                    .padding(viewModel.pagePadding)
                    .textSelection(.enabled)
            }
        }
        .background(viewModel.backgroundColor)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
    
    // MARK: - 页码指示器
    
    private var pageIndicator: some View {
        HStack(spacing: 4) {
            Text("\(currentPage + 1) / \(pages.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if viewModel.totalChapters > 0 {
                Text("·")
                    .foregroundColor(.secondary.opacity(0.5))
                Text("第\(viewModel.currentChapterIndex + 1)章")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .padding(.bottom, 8)
    }
    
    // MARK: - 分页逻辑
    
    private func splitPages() {
        guard let content = viewModel.chapterContent, !content.isEmpty else {
            pages = []
            return
        }
        
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        
        let padding = viewModel.pagePadding
        let config = PageConfig.from(
            fontSize: viewModel.fontSize,
            lineSpacing: viewModel.lineSpacing,
            padding: UIEdgeInsets(
                top: padding.top,
                left: padding.leading,
                bottom: padding.bottom,
                right: padding.trailing
            ),
            containerSize: containerSize
        )
        
        // 使用缓存分页
        let result = PageSplitCache.shared.getOrSplit(text: content, config: config)
        
        let oldPage = currentPage
        pages = result.pages
        viewModel.totalPages = result.totalPages
        
        // 保持页码在有效范围内
        if oldPage >= pages.count {
            currentPage = max(0, pages.count - 1)
        }
        viewModel.currentPageIndex = currentPage
    }
    
    private func invalidateAndResplit() {
        PageSplitCache.shared.invalidate()
        splitPages()
    }
}

// MARK: - 翻页动画类型（与 ReaderSettingsFullView.PageAnimation 对齐）

enum PageAnimationType: String, CaseIterable, Identifiable {
    case cover = "覆盖"
    case simulation = "仿真"
    case slide = "滑动"
    case scroll = "滚动"
    case none = "无动画"
    
    var id: String { self.rawValue }
}

// MARK: - 无动画翻页

struct InstantPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            ZStack {
                viewModel.backgroundColor
                
                if currentPage >= 0 && currentPage < pages.count {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(pages[currentPage])
                            .font(.system(size: viewModel.fontSize))
                            .foregroundColor(viewModel.textColor)
                            .lineSpacing(viewModel.lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(viewModel.pagePadding)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let tapZone = location.x / width
                if tapZone < 0.3 {
                    // 左侧：上一页
                    if currentPage > 0 {
                        currentPage -= 1
                        viewModel.currentPageIndex = currentPage
                    }
                } else if tapZone > 0.7 {
                    // 右侧：下一页
                    if currentPage + 1 < pages.count {
                        currentPage += 1
                        viewModel.currentPageIndex = currentPage
                    }
                } else {
                    // 中间：显示/隐藏 UI
                    onTap()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -50 && currentPage + 1 < pages.count {
                            currentPage += 1
                            viewModel.currentPageIndex = currentPage
                        } else if value.translation.width > 50 && currentPage > 0 {
                            currentPage -= 1
                            viewModel.currentPageIndex = currentPage
                        }
                    }
            )
        }
    }
}
