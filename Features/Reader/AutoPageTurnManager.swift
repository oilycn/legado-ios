//
//  AutoPageTurnManager.swift
//  Legado-iOS
//
//  自动翻页管理器
//  P1-T2 实现
//

import Foundation
import Combine

// MARK: - 自动翻页状态

enum AutoPageTurnState {
    case stopped
    case countdown(Int) // 倒计时秒数
    case paused
    
    var isRunning: Bool {
        switch self {
        case .countdown: return true
        default: return false
        }
    }
    
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

// MARK: - 自动翻页配置

struct AutoPageTurnConfig {
    var interval: TimeInterval // 翻页间隔（秒）
    var autoNextChapter: Bool // 到达章节末尾时自动跳转下一章
    var showCountdown: Bool // 显示倒计时
    var pauseOnTouch: Bool // 触摸时暂停
    
    static var `default`: AutoPageTurnConfig {
        AutoPageTurnConfig(
            interval: 5.0,
            autoNextChapter: true,
            showCountdown: true,
            pauseOnTouch: true
        )
    }
    
    static let presetIntervals: [TimeInterval] = [3, 5, 8, 10, 15, 20, 30, 60]
}

// MARK: - 自动翻页管理器

@MainActor
class AutoPageTurnManager: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published private(set) var state: AutoPageTurnState = .stopped
    @Published private(set) var progress: Double = 0 // 0.0 - 1.0
    @Published private(set) var remainingSeconds: Int = 0
    
    // MARK: - 配置
    
    var config: AutoPageTurnConfig {
        didSet { saveConfig() }
    }
    
    // MARK: - 回调
    
    var onTurnPage: (() -> Bool)? // 返回是否成功翻页
    var onChapterComplete: (() -> Void)? // 章节完成回调
    
    // MARK: - 私有属性
    
    private var timer: Timer?
    private var startTime: Date?
    private var pausedTime: Date?
    private var accumulatedTime: TimeInterval = 0
    
    // MARK: - 初始化
    
    init() {
        self.config = .default
        loadConfig()
    }
    
    nonisolated deinit {
        timer?.invalidate()
        timer = nil
    }

        timer?.invalidate()
        timer = nil
    }
        stop()
    }
    
    // MARK: - 公开方法
    
    /// 开始自动翻页
    func start() {
        guard !state.isRunning else { return }
        
        stop()
        
        state = .countdown(Int(config.interval))
        remainingSeconds = Int(config.interval)
        progress = 0
        accumulatedTime = 0
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    
    /// 停止自动翻页
    func stop() {
        timer?.invalidate()
        timer = nil
        state = .stopped
        progress = 0
        remainingSeconds = 0
        startTime = nil
        pausedTime = nil
        accumulatedTime = 0
    }
    
    /// 暂停
    func pause() {
        guard state.isRunning else { return }
        
        timer?.invalidate()
        timer = nil
        pausedTime = Date()
        state = .paused
    }
    
    /// 继续
    func resume() {
        guard state.isPaused else { return }
        
        if let paused = pausedTime, let start = startTime {
            // 累加暂停时间
            accumulatedTime += Date().timeIntervalSince(paused)
        }
        
        pausedTime = nil
        state = .countdown(remainingSeconds)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    
    /// 切换状态
    func toggle() {
        switch state {
        case .stopped:
            start()
        case .countdown:
            pause()
        case .paused:
            resume()
        }
    }
    
    /// 重置计时器（用于手动翻页后重置）
    func reset() {
        guard state.isRunning || state.isPaused else { return }
        
        accumulatedTime = 0
        startTime = Date()
        pausedTime = nil
        remainingSeconds = Int(config.interval)
        progress = 0
        
        if state.isPaused {
            state = .paused
        } else {
            state = .countdown(remainingSeconds)
        }
    }
    
    /// 设置间隔
    func setInterval(_ interval: TimeInterval) {
        config.interval = interval
        reset()
    }
    
    /// 触摸暂停（配置开启时调用）
    func handleTouch() {
        guard config.pauseOnTouch else { return }
        if state.isRunning {
            pause()
        }
    }
    
    // MARK: - 私有方法
    
    private func updateProgress() {
        guard let start = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(start) - accumulatedTime
        progress = min(elapsed / config.interval, 1.0)
        remainingSeconds = max(0, Int(config.interval - elapsed))
        
        state = .countdown(remainingSeconds)
        
        if progress >= 1.0 {
            performPageTurn()
        }
    }
    
    private func performPageTurn() {
        // 重置计时
        reset()
        
        // 执行翻页
        if let onTurnPage = onTurnPage {
            let success = onTurnPage()
            if !success {
                // 翻页失败（已到章节末尾）
                if config.autoNextChapter {
                    onChapterComplete?()
                } else {
                    stop()
                }
            }
        }
    }
    
    private func loadConfig() {
        let defaults = UserDefaults.standard
        config.interval = defaults.double(forKey: "autoPageTurn.interval")
        if config.interval == 0 { config.interval = 5.0 }
        
        config.autoNextChapter = defaults.bool(forKey: "autoPageTurn.autoNextChapter")
        config.showCountdown = defaults.bool(forKey: "autoPageTurn.showCountdown")
        if !defaults.bool(forKey: "autoPageTurn.configured") {
            config.showCountdown = true
        }
        
        config.pauseOnTouch = defaults.bool(forKey: "autoPageTurn.pauseOnTouch")
        if !defaults.bool(forKey: "autoPageTurn.configured") {
            config.pauseOnTouch = true
        }
    }
    
    private func saveConfig() {
        let defaults = UserDefaults.standard
        defaults.set(config.interval, forKey: "autoPageTurn.interval")
        defaults.set(config.autoNextChapter, forKey: "autoPageTurn.autoNextChapter")
        defaults.set(config.showCountdown, forKey: "autoPageTurn.showCountdown")
        defaults.set(config.pauseOnTouch, forKey: "autoPageTurn.pauseOnTouch")
        defaults.set(true, forKey: "autoPageTurn.configured")
    }
}