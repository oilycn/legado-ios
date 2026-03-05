//
//  RemoteCommandHandler.swift
//  Legado-iOS
//
//  媒体按钮处理 - 耳机/蓝牙设备媒体按钮
//  统一管理 MPRemoteCommandCenter
//

import Foundation
import MediaPlayer

class RemoteCommandHandler {
    static let shared = RemoteCommandHandler()
    
    private var audioPlayManager: AudioPlayManager?
    private var ttsManager: TTSManager?
    
    private init() {
        setupCommands()
    }
    
    func setAudioPlayManager(_ manager: AudioPlayManager?) {
        self.audioPlayManager = manager
    }
    
    func setTTSManager(_ manager: TTSManager?) {
        self.ttsManager = manager
    }
    
    private func setupCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handlePlay()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handlePause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.handleNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.handlePrevious()
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15, 30]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.handleSkipForward(interval: skipEvent.interval)
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15, 30]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.handleSkipBackward(interval: skipEvent.interval)
            return .success
        }
    }
    
    private func handlePlay() {
        if let audioManager = audioPlayManager, audioManager.isPlaying == false {
            audioManager.play()
        } else if let tts = ttsManager, tts.isPlaying == false {
            tts.play()
        }
    }
    
    private func handlePause() {
        audioPlayManager?.pause()
        ttsManager?.pause()
    }
    
    private func handleNext() {
        Task { await audioPlayManager?.nextChapter() }
    }
    
    private func handlePrevious() {
        Task { await audioPlayManager?.prevChapter() }
    }
    
    private func handleSkipForward(interval: TimeInterval) {
        audioPlayManager?.seek(by: interval)
    }
    
    private func handleSkipBackward(interval: TimeInterval) {
        audioPlayManager?.seek(by: -interval)
    }
}