//
//  AudioPlayManager.swift
//  Legado-iOS
//
//  音频播放管理器 - 支持音频书播放 (type=1)
//  AVPlayer + NowPlayingCenter + 后台音频
//

import Foundation
import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayManager: ObservableObject {
    // MARK: - Published 属性
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentChapterIndex: Int = 0
    @Published var totalChapters: Int = 0
    @Published var playbackRate: Float = 1.0
    @Published var currentBook: Book?
    @Published var currentChapter: BookChapter?
    @Published var chapters: [BookChapter] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - 私有属性
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var ruleEngine = RuleEngine()
    
    // MARK: - 初始化
    
    init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - 音频会话配置
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowsAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    // MARK: - 远程控制配置
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { await self?.nextChapter() }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { await self?.prevChapter() }
            return .success
        }
        
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.seek(by: skipEvent.interval)
            return .success
        }
        
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.seek(by: -skipEvent.interval)
            return .success
        }
        
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let rateEvent = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            self?.setPlaybackRate(rateEvent.playbackRate)
            return .success
        }
    }
    
    // MARK: - 公开方法
    
    /// 加载书籍
    func loadBook(_ book: Book) async {
        currentBook = book
        isLoading = true
        errorMessage = nil
        
        // 获取章节列表
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            chapters = try context.fetch(request)
            totalChapters = chapters.count
            
            // 从上次位置继续
            if book.durChapterIndex < chapters.count {
                currentChapterIndex = Int(book.durChapterIndex)
            }
            
            if let chapter = chapters[safe: currentChapterIndex] {
                await loadChapter(chapter)
            }
        } catch {
            errorMessage = "加载章节失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 加载章节
    func loadChapter(_ chapter: BookChapter) async {
        currentChapter = chapter
        isLoading = true
        
        do {
            // 获取音频 URL
            let audioURL = try await getAudioURL(for: chapter)
            
            // 创建播放器
            let playerItem = AVPlayerItem(url: audioURL)
            player = AVPlayer(playerItem: playerItem)
            
            // 添加时间观察者
            addTimeObserver()
            
            // 更新锁屏信息
            updateNowPlayingInfo()
            
            // 恢复播放位置
            if let book = currentBook, chapter.index == Int32(currentChapterIndex) {
                await seekTo(book.durChapterPos)
            }
            
        } catch {
            errorMessage = "加载音频失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 获取音频 URL
    private func getAudioURL(for chapter: BookChapter) async throws -> URL {
        // 如果章节有缓存，使用缓存
        if let cachePath = chapter.cachePath,
           FileManager.default.fileExists(atPath: cachePath) {
            return URL(fileURLWithPath: cachePath)
        }
        
        // 通过书源规则获取音频 URL
        guard let book = currentBook,
              let source = book.source else {
            throw AudioError.noSource
        }
        
        let content = try await WebBook.getContent(
            source: source,
            book: book,
            chapter: chapter
        )
        
        // 解析音频 URL
        guard let audioURLString = content.audioURL,
              let url = URL(string: audioURLString) else {
            throw AudioError.invalidAudioURL
        }
        
        return url
    }
    
    /// 播放
    func play() {
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    /// 暂停
    func pause() {
        player?.pause()
        isPlaying = false
        saveProgress()
        updateNowPlayingInfo()
    }
    
    /// 切换播放/暂停
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// 停止
    func stop() {
        player?.pause()
        saveProgress()
        isPlaying = false
        player = nil
    }
    
    /// 下一章
    func nextChapter() async {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        if let chapter = chapters[safe: currentChapterIndex] {
            await loadChapter(chapter)
            play()
        }
    }
    
    /// 上一章
    func prevChapter() async {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        if let chapter = chapters[safe: currentChapterIndex] {
            await loadChapter(chapter)
            play()
        }
    }
    
    /// 跳转到指定章节
    func jumpToChapter(_ index: Int) async {
        guard index >= 0, index < chapters.count else { return }
        currentChapterIndex = index
        if let chapter = chapters[safe: index] {
            await loadChapter(chapter)
            play()
        }
    }
    
    /// 跳转到指定时间
    func seekTo(_ time: Double) async {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player?.seek(to: cmTime)
    }
    
    /// 相对跳转
    func seek(by interval: TimeInterval) {
        let newTime = currentTime + interval
        Task {
            await seekTo(max(0, min(duration, newTime)))
        }
    }
    
    /// 设置播放速度
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }
    
    // MARK: - 私有方法
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.duration = self.player?.currentItem?.duration.seconds ?? 0
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func updateNowPlayingInfo() {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentChapter?.title ?? "未知章节",
            MPMediaItemPropertyArtist: currentBook?.author ?? "未知作者",
            MPMediaItemPropertyAlbumTitle: currentBook?.name ?? "未知书籍",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0,
            MPNowPlayingInfoPropertyCurrentPlaybackDate: Date()
        ]
        
        nowPlayingInfoCenter.nowPlayingInfo = info
    }
    
    private func saveProgress() {
        guard let book = currentBook else { return }
        let context = CoreDataStack.shared.viewContext
        
        context.perform {
            book.durChapterIndex = Int32(self.currentChapterIndex)
            book.durChapterPos = Int32(self.currentTime)
            book.durChapterTime = Int64(Date().timeIntervalSince1970)
            book.durChapterTitle = self.currentChapter?.title
            try? context.save()
        }
    }
    
    private func cleanup() {
        removeTimeObserver()
        player?.pause()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - 错误类型

enum AudioError: LocalizedError {
    case noSource
    case invalidAudioURL
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .noSource: return "没有可用的书源"
        case .invalidAudioURL: return "无效的音频地址"
        case .playbackFailed: return "播放失败"
        }
    }
}

// MARK: - 数组安全访问

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}