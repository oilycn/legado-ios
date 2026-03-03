//
//  CoverPageView.swift
//  Legado-iOS
//
//  覆盖翻页动画：新页从右侧滑入覆盖旧页
//

import SwiftUI

struct CoverPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var gestureOffset: CGFloat = 0
    
    private let swipeThreshold: CGFloat = 80
    private let velocityThreshold: CGFloat = 300
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            ZStack {
                // 底层：当前页
                pageContent(at: currentPage)
                    .frame(width: width, height: geometry.size.height)
                
                // 向左拖（翻到下一页）：下一页从右侧滑入
                if dragOffset < 0, currentPage + 1 < pages.count {
                    pageContent(at: currentPage + 1)
                        .frame(width: width, height: geometry.size.height)
                        .offset(x: width + dragOffset)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: -4, y: 0)
                }
                
                // 向右拖（翻到上一页）：上一页从左侧滑入
                if dragOffset > 0, currentPage > 0 {
                    pageContent(at: currentPage - 1)
                        .frame(width: width, height: geometry.size.height)
                        .offset(x: -width + dragOffset)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 4, y: 0)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        let translation = value.translation.width
                        
                        // 边界限制：第一页不能向右翻，最后一页不能向左翻
                        if currentPage <= 0 && translation > 0 {
                            dragOffset = translation * 0.3 // 阻尼效果
                        } else if currentPage >= pages.count - 1 && translation < 0 {
                            dragOffset = translation * 0.3
                        } else {
                            dragOffset = translation
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let shouldSwipe = abs(dragOffset) > swipeThreshold || abs(velocity) > velocityThreshold
                        
                        withAnimation(.easeOut(duration: 0.25)) {
                            if shouldSwipe && dragOffset < 0 && currentPage + 1 < pages.count {
                                // 翻到下一页
                                dragOffset = -width
                            } else if shouldSwipe && dragOffset > 0 && currentPage > 0 {
                                // 翻到上一页
                                dragOffset = width
                            } else {
                                // 回弹
                                dragOffset = 0
                            }
                        }
                        
                        // 延迟更新页码，等动画完成
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                            if dragOffset == -width && currentPage + 1 < pages.count {
                                currentPage += 1
                                viewModel.currentPageIndex = currentPage
                            } else if dragOffset == width && currentPage > 0 {
                                currentPage -= 1
                                viewModel.currentPageIndex = currentPage
                            }
                            dragOffset = 0
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        if !isDragging {
                            onTap()
                        }
                    }
            )
        }
    }
    
    @ViewBuilder
    private func pageContent(at index: Int) -> some View {
        if index >= 0 && index < pages.count {
            ScrollView(.vertical, showsIndicators: false) {
                Text(pages[index])
                    .font(.system(size: viewModel.fontSize))
                    .foregroundColor(viewModel.textColor)
                    .lineSpacing(viewModel.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(viewModel.pagePadding)
            }
            .background(viewModel.backgroundColor)
        } else {
            Color.clear
        }
    }
}
