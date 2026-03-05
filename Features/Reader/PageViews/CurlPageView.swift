//
//  CurlPageView.swift
//  Legado-iOS
//
//  仿真翻页动画：使用 UIPageViewController 的 pageCurl 转场样式
//  P0-T6 实现
//

import SwiftUI
import UIKit

// MARK: - 仿真翻页视图

struct CurlPageView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    // 点击区域比例
    private let leftTapRatio: CGFloat = 0.3
    private let rightTapRatio: CGFloat = 0.3
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue]
        )
        
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        
        // 设置初始页面
        if pages.indices.contains(currentPage) {
            let firstVC = context.coordinator.viewController(at: currentPage)
            pageVC.setViewControllers([firstVC], direction: .forward, animated: false)
        }
        
        // 禁用默认点击手势，使用自定义点击区域
        for gesture in pageVC.gestureRecognizers {
            if gesture is UITapGestureRecognizer {
                gesture.isEnabled = false
            }
        }
        
        return pageVC
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        guard pages.indices.contains(currentPage) else { return }
        
        let currentVC = uiViewController.viewControllers?.first
        let currentIndex = context.coordinator.index(of: currentVC)
        
        // 仅当外部状态变更时才更新（如目录跳转）
        if currentIndex != currentPage {
            let direction: UIPageViewController.NavigationDirection = currentPage > (currentIndex ?? 0) ? .forward : .reverse
            let newVC = context.coordinator.viewController(at: currentPage)
            uiViewController.setViewControllers([newVC], direction: direction, animated: true)
        }
        
        // 更新 ViewModel 状态
        context.coordinator.parent = self
    }
}

// MARK: - Coordinator

extension CurlPageView {
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: CurlPageView
        
        init(_ parent: CurlPageView) {
            self.parent = parent
        }
        
        // MARK: - UIPageViewControllerDataSource
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let index = index(of: viewController), index > 0 else { return nil }
            return self.viewController(at: index - 1)
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = index(of: viewController), index < parent.pages.count - 1 else { return nil }
            return self.viewController(at: index + 1)
        }
        
        // MARK: - UIPageViewControllerDelegate
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            if completed,
               let visibleVC = pageViewController.viewControllers?.first,
               let index = index(of: visibleVC) {
                parent.currentPage = index
                parent.viewModel.currentPageIndex = index
            }
        }
        
        // MARK: - 辅助方法
        
        func viewController(at index: Int) -> UIViewController {
            guard parent.pages.indices.contains(index) else {
                return UIViewController()
            }
            
            let pageText = parent.pages[index]
            let hostingVC = PageContentHostingController(
                text: pageText,
                viewModel: parent.viewModel,
                onTap: parent.onTap,
                leftTapRatio: parent.leftTapRatio,
                rightTapRatio: parent.rightTapRatio,
                onTurnPage: { [weak self] forward in
                    self?.handleTapNavigation(forward: forward)
                }
            )
            hostingVC.view.tag = index
            return hostingVC
        }
        
        func index(of viewController: UIViewController?) -> Int? {
            return viewController?.view.tag
        }
        
        private func handleTapNavigation(forward: Bool) {
            let newIndex: Int
            if forward {
                newIndex = min(parent.currentPage + 1, parent.pages.count - 1)
            } else {
                newIndex = max(parent.currentPage - 1, 0)
            }
            
            if newIndex != parent.currentPage {
                parent.currentPage = newIndex
                parent.viewModel.currentPageIndex = newIndex
            }
        }
    }
}

// MARK: - 页面内容宿主控制器

private class PageContentHostingController: UIHostingController<PageContent> {
    init(
        text: String,
        viewModel: ReaderViewModel,
        onTap: @escaping () -> Void,
        leftTapRatio: CGFloat,
        rightTapRatio: CGFloat,
        onTurnPage: @escaping (Bool) -> Void
    ) {
        let content = PageContent(
            text: text,
            viewModel: viewModel,
            onTap: onTap,
            leftTapRatio: leftTapRatio,
            rightTapRatio: rightTapRatio,
            onTurnPage: onTurnPage
        )
        super.init(rootView: content)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 页面内容 SwiftUI 视图

private struct PageContent: View {
    let text: String
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void
    let leftTapRatio: CGFloat
    let rightTapRatio: CGFloat
    let onTurnPage: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                viewModel.backgroundColor.ignoresSafeArea()
                
                // 文本内容
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text)
                        .font(.system(size: viewModel.fontSize))
                        .foregroundColor(viewModel.textColor)
                        .lineSpacing(viewModel.lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(viewModel.pagePadding)
                        .textSelection(.enabled)
                }
                
                // 点击区域覆盖层
                tapZonesOverlay(width: geometry.size.width)
            }
        }
    }
    
    // MARK: - 点击区域
    
    @ViewBuilder
    private func tapZonesOverlay(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 左侧区域：上一页
            Color.clear
                .contentShape(Rectangle())
                .frame(width: width * leftTapRatio)
                .onTapGesture {
                    onTurnPage(false)
                }
            
            // 中间区域：菜单
            Color.clear
                .contentShape(Rectangle())
                .frame(width: width * (1 - leftTapRatio - rightTapRatio))
                .onTapGesture {
                    onTap()
                }
            
            // 右侧区域：下一页
            Color.clear
                .contentShape(Rectangle())
                .frame(width: width * rightTapRatio)
                .onTapGesture {
                    onTurnPage(true)
                }
        }
    }
}

// MARK: - 预览

#Preview {
    CurlPageView(
        viewModel: {
            let vm = ReaderViewModel()
            vm.chapterContent = "这是一个示例文本内容，用于预览仿真翻页效果。\n\n这是第二段落，展示多段落排版效果。\n\n这是第三段落，用于测试翻页动画。"
            return vm
        }(),
        pages: ["第一页内容", "第二页内容", "第三页内容"],
        currentPage: .constant(0),
        onTap: {}
    )
}