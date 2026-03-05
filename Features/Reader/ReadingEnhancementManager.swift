//
//  ReadingEnhancementManager.swift
//  Legado-iOS
//
//  阅读增强管理器
//  P1-T7 实现
//

import Foundation
import UIKit

// MARK: - 阅读增强配置

struct ReadingEnhancementConfig {
    // 亮度调节
    var brightness: Float = 1.0
    var autoBrightness: Bool = true
    
    // 屏幕常亮
    var keepScreenOn: Bool = true
    
    // 音量键翻页
    var volumeKeyPageTurn: Bool = true
    
    // 阅读时长提醒
    var readingReminder: Bool = true
    var reminderInterval: TimeInterval = 1800 // 30分钟
    var reminderEnabled: Bool = true
    
    // 护眼模式
    var eyeProtectionMode: Bool = false
    var blueLightFilter: Float = 0.0 // 0.0 - 1.0
    
    // 夜间模式自动切换
    var autoNightMode: Bool = false
    var nightModeStartTime: Date = {
        var components = DateComponents()
        components.hour = 22
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    var nightModeEndTime: Date = {
        var components = DateComponents()
        components.hour = 6
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    // 阅读统计
    var trackReadingTime: Bool = true
    
    static var `default`: ReadingEnhancementConfig {
        ReadingEnhancementConfig()
    }
}

// MARK: - 阅读增强管理器

@MainActor
class ReadingEnhancementManager: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published var config: ReadingEnhancementConfig {
        didSet { saveConfig() }
    }
    
    @Published private(set) var currentReadingTime: TimeInterval = 0
    @Published private(set) var isNightMode: Bool = false
    @Published private(set) var showReminder: Bool = false
    
    // MARK: - 私有属性
    
    private var readingTimer: Timer?
    private var nightModeTimer: Timer?
    private var volumeObserver: Any?
    private var lastVolumeValue: Float = 0
    
    // MARK: - 回调
    
    var onVolumeKeyUp: (() -> Void)?
    var onVolumeKeyDown: (() -> Void)?
    var onReadingReminder: (() -> Void)?
    var onNightModeChanged: ((Bool) -> Void)?
    
    // MARK: - 初始化
    
    init() {
        self.config = .default
        loadConfig()
        setupNotifications()
    }
    

    // MARK: - 公开方法
    
    /// 开始阅读会话
    func startReadingSession() {
        // 屏幕常亮
        if config.keepScreenOn {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        // 开始计时
        if config.trackReadingTime {
            startReadingTimer()
        }
        
        // 启动夜间模式检测
        if config.autoNightMode {
            startNightModeDetection()
        }
        
        // 启动音量键监听
        if config.volumeKeyPageTurn {
            startVolumeKeyMonitoring()
        }
        
        // 设置亮度
        if !config.autoBrightness {
            UIScreen.main.brightness = CGFloat(config.brightness)
        }
        
        // 应用护眼模式
        applyEyeProtection()
    }
    
    /// 结束阅读会话
    func endReadingSession() {
        // 恢复屏幕常亮设置
        UIApplication.shared.isIdleTimerDisabled = false
        
        // 停止计时
        stopReadingTimer()
        
        // 停止夜间模式检测
        stopNightModeDetection()
        
        // 停止音量键监听
        stopVolumeKeyMonitoring()
        
        // 保存阅读时长
        if config.trackReadingTime {
            saveReadingTime()
        }
    }
    
    /// 更新亮度
    func setBrightness(_ value: Float) {
        config.brightness = value
        UIScreen.main.brightness = CGFloat(value)
    }
    
    /// 检查是否应该显示夜间模式
    func checkNightMode() -> Bool {
        guard config.autoNightMode else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        
        let currentHour = calendar.component(.hour, from: now)
        let startHour = calendar.component(.hour, from: config.nightModeStartTime)
        let endHour = calendar.component(.hour, from: config.nightModeEndTime)
        
        // 处理跨午夜的情况
        if startHour > endHour {
            return currentHour >= startHour || currentHour < endHour
        } else {
            return currentHour >= startHour && currentHour < endHour
        }
    }
    
    /// 重置阅读时间
    func resetReadingTime() {
        currentReadingTime = 0
        UserDefaults.standard.set(0, forKey: "currentReadingTime")
    }

    func dismissReminder() {
        showReminder = false
    }
    
    /// 获取今日阅读时间
    func getTodayReadingTime() -> TimeInterval {
        return UserDefaults.standard.double(forKey: "todayReadingTime_\(todayDateString)")
    }
    
    /// 获取总阅读时间
    func getTotalReadingTime() -> TimeInterval {
        return UserDefaults.standard.double(forKey: "totalReadingTime")
    }
    
    // MARK: - 私有方法
    
    private func startReadingTimer() {
        readingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor [weak self] in
                self?.updateReadingTime()
            }
        }
    }
        readingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateReadingTime()
            }
        }
    }
    
    private func stopReadingTimer() {
        readingTimer?.invalidate()
        readingTimer = nil
    }
    
    private func updateReadingTime() {
        currentReadingTime += 1
        
        // 检查阅读提醒
        if config.reminderEnabled && config.readingReminder {
            let interval = Int(currentReadingTime)
            if interval > 0 && interval % Int(config.reminderInterval) == 0 {
                showReminder = true
                onReadingReminder?()
            }
        }
    }
    
    private func saveReadingTime() {
        // 保存今日阅读时间
        let todayKey = "todayReadingTime_\(todayDateString)"
        let todayTime = UserDefaults.standard.double(forKey: todayKey)
        UserDefaults.standard.set(todayTime + currentReadingTime, forKey: todayKey)
        
        // 保存总阅读时间
        let totalTime = UserDefaults.standard.double(forKey: "totalReadingTime")
        UserDefaults.standard.set(totalTime + currentReadingTime, forKey: "totalReadingTime")
        
        // 保存当前会话时间
        UserDefaults.standard.set(currentReadingTime, forKey: "currentReadingTime")
    }
    
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func startNightModeDetection() {
        // 立即检查一次
        updateNightMode()
        
        // 每分钟检查一次
        nightModeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { timer in
            Task { @MainActor [weak self] in
                self?.updateNightMode()
            }
        }
    }
        // 立即检查一次
        updateNightMode()
        
        // 每分钟检查一次
        nightModeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateNightMode()
            }
        }
    }
    
    private func stopNightModeDetection() {
        nightModeTimer?.invalidate()
        nightModeTimer = nil
    }
    
    private func updateNightMode() {
        let shouldBeNightMode = checkNightMode()
        
        if shouldBeNightMode != isNightMode {
            isNightMode = shouldBeNightMode
            onNightModeChanged?(shouldBeNightMode)
        }
    }
    
    private func startVolumeKeyMonitoring() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        
        lastVolumeValue = audioSession.outputVolume
        
        // 注意：iOS 不允许直接监听音量键，这里使用变通方案
        // 实际实现需要使用 AVAudioSession 的 outputVolume 观察
    }
    
    private func stopVolumeKeyMonitoring() {
        volumeObserver = nil
    }
    
    private func applyEyeProtection() {
        // 护眼模式可以通过调整屏幕色温实现
        // iOS 没有直接的 API，但可以通过显示一个半透明覆盖层来模拟
    }
    
    private func setupNotifications() {
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // 监听应用进入前台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // 保存当前阅读时间
        if config.trackReadingTime {
            saveReadingTime()
        }
    }
    
    @objc private func appWillEnterForeground() {
        // 重置会话计时
        currentReadingTime = 0
    }
    
    private func cleanup() {
        NotificationCenter.default.removeObserver(self)
        stopReadingTimer()
        stopNightModeDetection()
        stopVolumeKeyMonitoring()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func loadConfig() {
        let defaults = UserDefaults.standard
        
        config.brightness = Float(defaults.double(forKey: "readingEnhancement.brightness"))
        if config.brightness == 0 { config.brightness = 1.0 }
        
        config.autoBrightness = defaults.bool(forKey: "readingEnhancement.autoBrightness")
        if !defaults.bool(forKey: "readingEnhancement.configured") {
            config.autoBrightness = true
        }
        
        config.keepScreenOn = defaults.bool(forKey: "readingEnhancement.keepScreenOn")
        if !defaults.bool(forKey: "readingEnhancement.configured") {
            config.keepScreenOn = true
        }
        
        config.volumeKeyPageTurn = defaults.bool(forKey: "readingEnhancement.volumeKeyPageTurn")
        if !defaults.bool(forKey: "readingEnhancement.configured") {
            config.volumeKeyPageTurn = true
        }
        
        config.reminderEnabled = defaults.bool(forKey: "readingEnhancement.reminderEnabled")
        config.reminderInterval = defaults.double(forKey: "readingEnhancement.reminderInterval")
        if config.reminderInterval == 0 { config.reminderInterval = 1800 }
        
        config.autoNightMode = defaults.bool(forKey: "readingEnhancement.autoNightMode")
        config.trackReadingTime = defaults.bool(forKey: "readingEnhancement.trackReadingTime")
    }
    
    private func saveConfig() {
        let defaults = UserDefaults.standard
        
        defaults.set(config.brightness, forKey: "readingEnhancement.brightness")
        defaults.set(config.autoBrightness, forKey: "readingEnhancement.autoBrightness")
        defaults.set(config.keepScreenOn, forKey: "readingEnhancement.keepScreenOn")
        defaults.set(config.volumeKeyPageTurn, forKey: "readingEnhancement.volumeKeyPageTurn")
        defaults.set(config.reminderEnabled, forKey: "readingEnhancement.reminderEnabled")
        defaults.set(config.reminderInterval, forKey: "readingEnhancement.reminderInterval")
        defaults.set(config.autoNightMode, forKey: "readingEnhancement.autoNightMode")
        defaults.set(config.trackReadingTime, forKey: "readingEnhancement.trackReadingTime")
        defaults.set(true, forKey: "readingEnhancement.configured")
    }
}

// MARK: - AVAudioSession 扩展用于音量监听

import AVFoundation
