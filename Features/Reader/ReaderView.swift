//
//  ReaderView.swift
//  Legado-iOS
//
//  阅读器主界面
//

import SwiftUI
import CoreData

struct ReaderView: View {
    @StateObject private var viewModel = ReaderViewModel()
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showUI = true
    
    let book: Book
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                viewModel.backgroundColor
                    .ignoresSafeArea()
                
                // 内容区域
                PagedReaderView(viewModel: viewModel) {
                    withAnimation { showUI.toggle() }
                }
                
                // 顶部工具栏
                VStack {
                    ReaderTopBar(
                        title: book.name,
                        chapterTitle: viewModel.currentChapter?.title ?? "",
                        onBack: { viewModel.goBack() },
                        onChapterList: { showingChapterList = true },
                        onSettings: { showingSettings = true }
                    )
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut, value: showUI)
                    
                    Spacer()
                    
                    // 底部工具栏
                    ReaderBottomBar(
                        currentChapter: viewModel.currentChapterIndex,
                        totalChapters: viewModel.totalChapters,
                        onPrevChapter: { Task { await viewModel.prevChapter() } },
                        onNextChapter: { Task { await viewModel.nextChapter() } },
                        onSliderChange: { viewModel.jumpToChapter($0) }
                    )
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut, value: showUI)
                }
                
                // 设置面板
                if showingSettings {
                    ReaderSettingsView(viewModel: viewModel, isPresented: $showingSettings)
                        .transition(.move(edge: .bottom))
                }
                
                // 加载指示器
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // 错误提示
                if let error = viewModel.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .onTapGesture {
                // 点击手势由 PagedReaderView 内部处理
                // 仅在滚动模式下由外层处理
            }
            .onAppear {
                viewModel.loadBook(book)
            }
            .onDisappear {
                viewModel.saveProgress()
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(viewModel: viewModel, book: book)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showUI)
    }
}

// MARK: - 顶部工具栏
struct ReaderTopBar: View {
    let title: String
    let chapterTitle: String
    let onBack: () -> Void
    let onChapterList: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                Text(chapterTitle)
                    .font(.caption2)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onChapterList) {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
            
            Button(action: onSettings) {
                Image(systemName: "a.square")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - 底部工具栏
struct ReaderBottomBar: View {
    let currentChapter: Int
    let totalChapters: Int
    let onPrevChapter: () -> Void
    let onNextChapter: () -> Void
    let onSliderChange: (Int) -> Void
    
    @State private var sliderValue: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度滑块
            Slider(value: $sliderValue, in: 0...Double(max(1, totalChapters - 1)), step: 1) {
                Text("章节")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("\(totalChapters)")
            } onEditingChanged: { _ in
                onSliderChange(Int(sliderValue))
            }
            .padding(.horizontal)
            
            // 章节控制
            HStack {
                Button(action: onPrevChapter) {
                    Label("上一章", systemImage: "chevron.left")
                }
                .disabled(currentChapter <= 0)
                
                Spacer()
                
                Text("第\(currentChapter + 1)/\(totalChapters)章")
                    .font(.caption)
                
                Spacer()
                
                Button(action: onNextChapter) {
                    Label("下一章", systemImage: "chevron.right")
                }
                .disabled(currentChapter >= totalChapters - 1)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .onChange(of: currentChapter, perform: { newValue in
            sliderValue = Double(newValue)
        })
    }
}

// MARK: - 旧分页视图（保留向后兼容）
/// @available(*, deprecated, message: "请使用 PagedReaderView")
struct ReaderPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        PagedReaderView(viewModel: viewModel) {
            // 默认无操作
        }
    }
}

#Preview {
    Text("ReaderView Preview")
}
