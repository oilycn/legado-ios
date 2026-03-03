//
//  TTSControlsView.swift
//  Legado-iOS
//
//  TTS 控制面板视图
//  P1-T1 实现
//

import SwiftUI

struct TTSControlsView: View {
    @ObservedObject var ttsManager: TTSManager
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool
    
    @State private var showVoicePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题栏
            HStack {
                Text("语音朗读")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 状态显示
            statusView
            
            // 进度显示
            if ttsManager.state.isSpeaking || ttsManager.state.isPaused {
                progressView
            }
            
            // 控制按钮
            controlButtons
            
            Divider()
            
            // 设置区
            settingsSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
    
    // MARK: - 状态视图
    
    private var statusView: some View {
        HStack {
            switch ttsManager.state {
            case .idle:
                Image(systemName: "speaker.slash")
                    .foregroundColor(.secondary)
                Text("未开始")
                    .foregroundColor(.secondary)
                
            case .speaking:
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(.blue)
                Text("正在朗读...")
                    .foregroundColor(.primary)
                
            case .paused:
                Image(systemName: "speaker.wave.1")
                    .foregroundColor(.orange)
                Text("已暂停")
                    .foregroundColor(.orange)
                
            case .error(let message):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - 进度视图
    
    private var progressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(ttsManager.spokenCharacters), total: Double(ttsManager.totalCharacters))
                .progressViewStyle(.linear)
            
            HStack {
                Text("已朗读 \(ttsManager.spokenCharacters) / \(ttsManager.totalCharacters) 字")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(Double(ttsManager.spokenCharacters) / Double(max(1, ttsManager.totalCharacters)) * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 控制按钮
    
    private var controlButtons: some View {
        HStack(spacing: 24) {
            // 上一段
            Button {
                ttsManager.previousParagraph()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .disabled(!canNavigateBack)
            
            // 播放/暂停
            Button {
                if ttsManager.state.isSpeaking {
                    ttsManager.pause()
                } else if ttsManager.state.isPaused {
                    ttsManager.resume()
                } else {
                    startReading()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: ttsManager.state.isSpeaking ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            // 下一段
            Button {
                ttsManager.nextParagraph()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .disabled(!canNavigateForward)
            
            // 停止
            Button {
                ttsManager.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .foregroundColor(.primary)
    }
    
    private var canNavigateBack: Bool {
        ttsManager.state.isSpeaking || ttsManager.state.isPaused
    }
    
    private var canNavigateForward: Bool {
        ttsManager.state.isSpeaking || ttsManager.state.isPaused
    }
    
    // MARK: - 设置区
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // 语速
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("语速")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", ttsManager.config.rate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "tortoise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { ttsManager.config.rate },
                        set: { ttsManager.setRate($0) }
                    ), in: 0.0...1.0)
                    
                    Image(systemName: "hare")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 音调
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("音调")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", ttsManager.config.pitch))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { ttsManager.config.pitch },
                    set: { ttsManager.setPitch($0) }
                ), in: 0.5...2.0)
            }
            
            // 声音选择
            Button {
                showVoicePicker = true
            } label: {
                HStack {
                    Text("声音")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(currentVoiceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(ttsManager: ttsManager, isPresented: $showVoicePicker)
            }
        }
    }
    
    private var currentVoiceName: String {
        if let voiceId = ttsManager.config.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            return voice.name
        }
        return "系统默认"
    }
    
    // MARK: - 操作
    
    private func startReading() {
        guard let content = viewModel.chapterContent else { return }
        
        // 将内容分页
        let pages = content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        ttsManager.speakParagraphs(
            pages,
            onParagraphComplete: {
                // 段落完成回调
            },
            onTextComplete: {
                // 全部完成回调
            }
        )
    }
}

// MARK: - 声音选择器

struct VoicePickerView: View {
    @ObservedObject var ttsManager: TTSManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                // 默认声音
                Button {
                    ttsManager.setVoice(nil)
                    isPresented = false
                } label: {
                    HStack {
                        Text("系统默认")
                        Spacer()
                        if ttsManager.config.voiceIdentifier == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 可用声音列表
                ForEach(groupedVoices.keys.sorted(), id: \.self) { language in
                    Section(header: Text(languageDisplayName(language))) {
                        ForEach(groupedVoices[language] ?? []) { voice in
                            Button {
                                ttsManager.setVoice(voice)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(voice.name)
                                        Text(voice.identifier)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if ttsManager.config.voiceIdentifier == voice.identifier {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var groupedVoices: [String: [AVSpeechSynthesisVoice]] {
        Dictionary(grouping: ttsManager.availableVoices) { voice in
            voice.language
        }
    }
    
    private func languageDisplayName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        TTSControlsView(
            ttsManager: TTSManager(),
            viewModel: ReaderViewModel(),
            isPresented: .constant(true)
        )
    }
}