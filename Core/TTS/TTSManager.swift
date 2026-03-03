//
//  TTSManager.swift
//  Legado-iOS
//
//  TTS 语音朗读管理器
//  P1-T1 实现
//

import Foundation
import AVFoundation
import Combine

// MARK: - TTS 状态

enum TTSState {
    case idle
    case speaking
    case paused
    case error(String)
    
    var isSpeaking: Bool {
        switch self {
        case .speaking: return true
        default: return false
        }
    }
    
    var isPaused: Bool {
        switch self {
        case .paused: return true
        default: return false
        }
    }
}

// MARK: - TTS 配置

struct TTSConfig {
    var rate: Float // 0.0 - 1.0, default 0.5
    var pitch: Float // 0.5 - 2.0, default 1.0
    var volume: Float // 0.0 - 1.0, default 1.0
    var voiceIdentifier: String? // nil = system default
    var language: String // default "zh-CN"
    
    static var `default`: TTSConfig {
        TTSConfig(
            rate: 0.5,
            pitch: 1.0,
            volume: 1.0,
            voiceIdentifier: nil,
            language: "zh-CN"
        )
    }
}

// MARK: - TTS 管理器

@MainActor
class TTSManager: NSObject, ObservableObject {
    // MARK: - Published 属性
    
    @Published private(set) var state: TTSState = .idle
    @Published private(set) var currentText: String = ""
    @Published private(set) var totalCharacters: Int = 0
    @Published private(set) var spokenCharacters: Int = 0
    @Published private(set) var availableVoices: [AVSpeechSynthesisVoice] = []
    
    // MARK: - 配置
    
    var config: TTSConfig {
        didSet { applyConfig() }
    }
    
    // MARK: - 私有属性
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var textQueue: [String] = []
    private var currentQueueIndex: Int = 0
    private var onParagraphComplete: (() -> Void)?
    private var onTextComplete: (() -> Void)?
    
    // MARK: - 初始化
    
    override init() {
        self.config = .default
        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
        loadSavedConfig()
    }
    
    // MARK: - 公开方法
    
    /// 开始朗读文本
    func speak(_ text: String, onParagraphComplete: (() -> Void)? = nil, onTextComplete: (() -> Void)? = nil) {
        guard !text.isEmpty else { return }
        
        stop()
        
        // 分段处理长文本
        let paragraphs = splitIntoParagraphs(text)
        textQueue = paragraphs
        currentQueueIndex = 0
        totalCharacters = text.count
        spokenCharacters = 0
        
        self.onParagraphComplete = onParagraphComplete
        self.onTextComplete = onTextComplete
        
        speakNextParagraph()
    }
    
    /// 继续朗读（段落列表）
    func speakParagraphs(_ paragraphs: [String], startIndex: Int = 0, onParagraphComplete: (() -> Void)? = nil, onTextComplete: (() -> Void)? = nil) {
        guard !paragraphs.isEmpty, startIndex < paragraphs.count else { return }
        
        stop()
        
        textQueue = paragraphs
        currentQueueIndex = startIndex
        totalCharacters = paragraphs.reduce(0) { $0 + $1.count }
        spokenCharacters = 0
        
        self.onParagraphComplete = onParagraphComplete
        self.onTextComplete = onTextComplete
        
        speakNextParagraph()
    }
    
    /// 暂停朗读
    func pause() {
        guard state.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        state = .paused
    }
    
    /// 继续朗读
    func resume() {
        guard state.isPaused else { return }
        synthesizer.continueSpeaking()
        state = .speaking
    }
    
    /// 停止朗读
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        textQueue = []
        currentQueueIndex = 0
        currentText = ""
        spokenCharacters = 0
        state = .idle
    }
    
    /// 切换朗读状态
    func toggle() {
        switch state {
        case .idle:
            break // 需要外部提供文本
        case .speaking:
            pause()
        case .paused:
            resume()
        case .error:
            stop()
        }
    }
    
    /// 跳转到指定段落
    func jumpToParagraph(_ index: Int) {
        guard index >= 0, index < textQueue.count else { return }
        
        stop()
        currentQueueIndex = index
        speakNextParagraph()
    }
    
    /// 上一段
    func previousParagraph() {
        if currentQueueIndex > 0 {
            jumpToParagraph(currentQueueIndex - 1)
        }
    }
    
    /// 下一段
    func nextParagraph() {
        if currentQueueIndex < textQueue.count - 1 {
            jumpToParagraph(currentQueueIndex + 1)
        }
    }
    
    /// 设置语速
    func setRate(_ rate: Float) {
        config.rate = max(0.0, min(1.0, rate))
        saveConfig()
    }
    
    /// 设置音调
    func setPitch(_ pitch: Float) {
        config.pitch = max(0.5, min(2.0, pitch))
        saveConfig()
    }
    
    /// 设置声音
    func setVoice(_ voice: AVSpeechSynthesisVoice?) {
        config.voiceIdentifier = voice?.identifier
        saveConfig()
    }
    
    // MARK: - 私有方法
    
    private func speakNextParagraph() {
        guard currentQueueIndex < textQueue.count else {
            // 所有段落朗读完成
            state = .idle
            onTextComplete?()
            return
        }
        
        let paragraph = textQueue[currentQueueIndex]
        currentText = paragraph
        
        let utterance = AVSpeechUtterance(string: paragraph)
        applyConfig(to: utterance)
        
        currentUtterance = utterance
        synthesizer.speak(utterance)
        state = .speaking
    }
    
    private func applyConfig(to utterance: AVSpeechUtterance) {
        utterance.rate = config.rate
        utterance.pitchMultiplier = config.pitch
        utterance.volume = config.volume
        
        if let voiceId = config.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: config.language)
        }
    }
    
    private func applyConfig() {
        // 配置变更会在下一次创建 utterance 时生效
    }
    
    private func splitIntoParagraphs(_ text: String) -> [String] {
        // 按换行符分段，过滤空段落
        let paragraphs = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // 如果段落过长，进一步分割
        var result: [String] = []
        let maxChunkSize = 500
        
        for paragraph in paragraphs {
            if paragraph.count <= maxChunkSize {
                result.append(paragraph)
            } else {
                // 按句子分割
                let sentences = splitIntoSentences(paragraph, maxLength: maxChunkSize)
                result.append(contentsOf: sentences)
            }
        }
        
        return result
    }
    
    private func splitIntoSentences(_ text: String, maxLength: Int) -> [String] {
        var result: [String] = []
        var current = ""
        
        let sentenceEnders = CharacterSet(charactersIn: "。！？；…\"」』")
        
        for char in text {
            current.append(char)
            
            if sentenceEnders.contains(char.unicodeScalars.first!) && current.count >= 50 {
                if current.count >= maxLength {
                    // 强制分割
                    result.append(current)
                    current = ""
                } else if current.count >= maxLength / 2 {
                    result.append(current)
                    current = ""
                }
            } else if current.count >= maxLength {
                result.append(current)
                current = ""
            }
        }
        
        if !current.isEmpty {
            result.append(current)
        }
        
        return result
    }
    
    private func loadAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("en") }
        availableVoices = voices
    }
    
    private func loadSavedConfig() {
        let defaults = UserDefaults.standard
        config.rate = Float(defaults.double(forKey: "tts.rate"))
        if config.rate == 0 { config.rate = 0.5 }
        
        config.pitch = Float(defaults.double(forKey: "tts.pitch"))
        if config.pitch == 0 { config.pitch = 1.0 }
        
        config.volume = Float(defaults.double(forKey: "tts.volume"))
        if config.volume == 0 { config.volume = 1.0 }
        
        config.voiceIdentifier = defaults.string(forKey: "tts.voiceId")
    }
    
    private func saveConfig() {
        let defaults = UserDefaults.standard
        defaults.set(config.rate, forKey: "tts.rate")
        defaults.set(config.pitch, forKey: "tts.pitch")
        defaults.set(config.volume, forKey: "tts.volume")
        defaults.set(config.voiceIdentifier, forKey: "tts.voiceId")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // 更新已朗读字符数
            spokenCharacters += utterance.speechString.count
            
            // 回调段落完成
            onParagraphComplete?()
            
            // 朗读下一段
            currentQueueIndex += 1
            speakNextParagraph()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .idle
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didEncounterError error: Error, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .error(error.localizedDescription)
        }
    }
}