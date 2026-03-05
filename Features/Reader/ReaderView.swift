//
//  ReaderView.swift
//  Legado-iOS
//
//  阅读器主界面
//

import SwiftUI
import CoreData

struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReaderViewModel()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var autoPageTurnManager = AutoPageTurnManager()
    @StateObject private var readingEnhancementManager = ReadingEnhancementManager()
    @StateObject private var textSelectionCoordinator = TextSelectionCoordinator()
    
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingTTSControls = false
    @State private var showingAutoPageTurn = false
    @State private var showingChangeSource = false
    @State private var showingBookmarks = false
    @State private var showUI = true
    
    // Phase 1 新增状态
    @State private var showingBrightness = false
    @State private var showingBgTextConfig = false
    @State private var showingReadStyle = false
    @State private var showingTipConfig = false
    @State private var showingContentEdit = false
    @State private var showingEffectiveReplaces = false
    @State private var hideTimer: Timer?
    
    let book: Book
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                viewModel.backgroundColor
                    .ignoresSafeArea()
                
                // 内容区域
                PagedReaderView(viewModel: viewModel) {
                    autoPageTurnManager.handleTouch()
                    withAnimation { showUI.toggle() }
                    resetHideTimer()
                }
                
                // 顶部工具栏
                VStack {
                    ReaderTopBar(
                        title: book.name,
                        chapterTitle: viewModel.currentChapter?.title ?? "",
                        onBack: {
                            viewModel.saveProgress()
                            dismiss()
                        },
                        onChapterList: { showingChapterList = true },
                        onChangeSource: { showingChangeSource = true },
                        onBookmarks: { showingBookmarks = true },
                        onTTS: { showingTTSControls = true },
                        onAutoPage: { showingAutoPageTurn = true },
                        onSettings: { showingSettings = true },
                        onContentEdit: { showingContentEdit = true },
                        onReplaces: { showingEffectiveReplaces = true }
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
                        onSliderChange: { viewModel.jumpToChapter($0) },
                        onBrightness: { showingBrightness = true },
                        onBgTextConfig: { showingBgTextConfig = true },
                        onReadStyle: { showingReadStyle = true }
                    )
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut, value: showUI)
                }
                
                // 设置面板
                if showingSettings {
                    ReaderSettingsView(viewModel: viewModel, isPresented: $showingSettings)
                        .transition(.move(edge: .bottom))
                }
                
                if showingTTSControls {
                    TTSControlsView(ttsManager: ttsManager, viewModel: viewModel, isPresented: $showingTTSControls)
                        .transition(.opacity)
                }
                
                if showingAutoPageTurn {
                    AutoPageTurnControlsView(manager: autoPageTurnManager, isPresented: $showingAutoPageTurn)
                        .transition(.opacity)
                }
                
                // Phase 1 新增 Sheet
                if showingBrightness {
                    BrightnessSlider(isPresented: $showingBrightness)
                        .transition(.opacity)
                }
                
                if showingBgTextConfig {
                    BgTextConfigSheet(isPresented: $showingBgTextConfig, viewModel: viewModel)
                        .transition(.move(edge: .bottom))
                }
                
                if showingReadStyle {
                    ReadStyleSheet(isPresented: $showingReadStyle, viewModel: viewModel)
                        .transition(.move(edge: .bottom))
                }
                
                if showingContentEdit, let chapter = viewModel.currentChapter {
                    ContentEditSheet(isPresented: $showingContentEdit, chapter: chapter) {
                        Task { await viewModel.loadCurrentChapter() }
                    }
                }
                
                if showingEffectiveReplaces {
                    EffectiveReplacesSheet(isPresented: $showingEffectiveReplaces, bookSourceUrl: book.origin)
                }
                
                AutoPageTurnOverlay(manager: autoPageTurnManager)
                
                // 文本选择菜单
                if textSelectionCoordinator.showMenu {
                    TextActionMenu(
                        selectedText: textSelectionCoordinator.selectedText,
                        chapterIndex: textSelectionCoordinator.chapterIndex,
                        positionInChapter: textSelectionCoordinator.positionInChapter,
                        onCopy: {},
                        onBookmark: {
                            // 创建书签
                            let context = CoreDataStack.shared.viewContext
                            let bookmark = Bookmark(context: context)
                            bookmark.bookmarkId = UUID()
                            bookmark.bookId = book.bookId
                            bookmark.chapterIndex = Int32(textSelectionCoordinator.chapterIndex)
                            bookmark.chapterTitle = viewModel.currentChapter?.title ?? ""
                            bookmark.content = textSelectionCoordinator.selectedText
                            bookmark.createDate = Date()
                            try? context.save()
                        },
                        onSearch: {},
                        onDictionary: {
                            textSelectionCoordinator.showDictionaryForWord(textSelectionCoordinator.selectedText)
                        },
                        onDismiss: {
                            textSelectionCoordinator.hideMenu()
                        }
                    )
                    .position(x: textSelectionCoordinator.selectionRect.midX,
                              y: textSelectionCoordinator.selectionRect.minY - 40)
                    .transition(.opacity)
                }
                
                // 字典视图
                if textSelectionCoordinator.showDictionary {
                    DictionaryLookupView(word: textSelectionCoordinator.dictionaryWord)
                        .ignoresSafeArea()
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
            }
            .onAppear {
                viewModel.loadBook(book)
                autoPageTurnManager.onTurnPage = { viewModel.turnToNextPage() }
                autoPageTurnManager.onChapterComplete = {
                    Task { @MainActor in
                        await viewModel.nextChapter()
                    }
                }
                readingEnhancementManager.onNightModeChanged = { isNight in
                    viewModel.applyTheme(isNight ? .dark : .light)
                }
                readingEnhancementManager.startReadingSession()
                startHideTimer()
            }
            .onDisappear {
                viewModel.saveProgress()
                ttsManager.stop()
                autoPageTurnManager.stop()
                readingEnhancementManager.endReadingSession()
                hideTimer?.invalidate()
            }
            .onChange(of: viewModel.currentPageIndex) { _ in
                autoPageTurnManager.reset()
            }
            .alert("阅读提醒", isPresented: Binding(
                get: { readingEnhancementManager.showReminder },
                set: { newValue in
                    if !newValue {
                        readingEnhancementManager.dismissReminder()
                    }
                }
            )) {
                Button("知道了") {
                    readingEnhancementManager.dismissReminder()
                }
            } message: {
                Text("阅读一段时间了，休息一下眼睛。")
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(viewModel: viewModel, book: book)
            }
            .sheet(isPresented: $showingChangeSource) {
                ChangeSourceSheet(isPresented: $showingChangeSource, book: book) {
                    viewModel.loadBook(book)
                }
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarkSheet(viewModel: viewModel, book: book)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showUI)
    }
    
    // MARK: - 自动隐藏定时器
    
    private func startHideTimer() {
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation {
                showUI = false
            }
        }
    }
    
    private func resetHideTimer() {
        hideTimer?.invalidate()
        startHideTimer()
    }
}

// MARK: - 顶部工具栏
struct ReaderTopBar: View {
    let title: String
    let chapterTitle: String
    let onBack: () -> Void
    let onChapterList: () -> Void
    let onChangeSource: () -> Void
    let onBookmarks: () -> Void
    let onTTS: () -> Void
    let onAutoPage: () -> Void
    let onSettings: () -> Void
    let onContentEdit: () -> Void
    let onReplaces: () -> Void
    
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
            
            Menu {
                Button(action: onChapterList) {
                    Label("目录", systemImage: "list.bullet")
                }
                Button(action: onChangeSource) {
                    Label("换源", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(action: onBookmarks) {
                    Label("书签", systemImage: "bookmark")
                }
                Button(action: onContentEdit) {
                    Label("编辑内容", systemImage: "pencil")
                }
                Button(action: onReplaces) {
                    Label("替换规则", systemImage: "text.badge.checkmark")
                }
                Divider()
                Button(action: onTTS) {
                    Label("朗读", systemImage: "speaker.wave.2")
                }
                Button(action: onAutoPage) {
                    Label("自动翻页", systemImage: "timer")
                }
                Button(action: onSettings) {
                    Label("设置", systemImage: "a.square")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
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
    let onBrightness: () -> Void
    let onBgTextConfig: () -> Void
    let onReadStyle: () -> Void
    
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
            
            // 新增按钮行
            HStack(spacing: 20) {
                Button(action: onBrightness) {
                    VStack(spacing: 2) {
                        Image(systemName: "sun.max")
                        Text("亮度")
                            .font(.caption2)
                    }
                }
                
                Button(action: onBgTextConfig) {
                    VStack(spacing: 2) {
                        Image(systemName: "paintpalette")
                        Text("背景")
                            .font(.caption2)
                    }
                }
                
                Button(action: onReadStyle) {
                    VStack(spacing: 2) {
                        Image(systemName: "textformat.size")
                        Text("样式")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .onChange(of: currentChapter, perform: { newValue in
            sliderValue = Double(newValue)
        })
    }
}

// MARK: - 旧分页视图（保留向后兼容）
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