//
//  AudioPlayerView.swift
//  Legado-iOS
//
//  音频书播放界面 - 支持 type=1 书源
//

import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    @StateObject private var playerManager = AudioPlayManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingChapterList = false
    @State private var showingSpeedPicker = false
    @State private var showingSleepTimer = false
    @State private var sleepTime: Int?
    @State private var sleepEndDate: Date?
    
    let book: Book
    
    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1a1a2e") ?? .black, Color(hex: "#16213e") ?? .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航
                HStack {
                    Button { playerManager.stop(); dismiss() } label: {
                        Image(systemName: "chevron.down").font(.title2).foregroundColor(.white)
                    }
                    Spacer()
                    Button { showingChapterList = true } label: {
                        Image(systemName: "list.bullet").font(.title2).foregroundColor(.white)
                    }
                }
                .padding()
                
                Spacer()
                
                // 封面图
                AsyncImage(url: URL(string: book.displayCoverUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    case .failure: Image(systemName: "book.fill").font(.system(size: 60)).foregroundColor(.gray)
                    default: ProgressView()
                    }
                }
                .frame(width: 200, height: 280)
                .cornerRadius(12)
                .shadow(radius: 10)
                
                // 书籍信息
                VStack(spacing: 8) {
                    Text(book.name).font(.title2).fontWeight(.bold).foregroundColor(.white).lineLimit(2)
                    Text(book.author).font(.subheadline).foregroundColor(.gray)
                    Text(playerManager.currentChapter?.title ?? "").font(.caption).foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 24)
                
                Spacer()
                
                // 进度条
                VStack(spacing: 8) {
                    Slider(value: Binding(get: { playerManager.currentTime }, set: { Task { await playerManager.seekTo($0) } }), in: 0...max(1, playerManager.duration))
                        .accentColor(.white).padding(.horizontal)
                    HStack {
                        Text(formatTime(playerManager.currentTime)).font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text(formatTime(playerManager.duration)).font(.caption).foregroundColor(.gray)
                    }.padding(.horizontal)
                }.padding(.bottom)
                
                // 主控制区
                HStack(spacing: 40) {
                    Button { Task { await playerManager.prevChapter() } } label: {
                        Image(systemName: "backward.end.fill").font(.title).foregroundColor(.white)
                    }.disabled(playerManager.currentChapterIndex <= 0)
                    
                    Button { playerManager.seek(by: -15) } label: {
                        Image(systemName: "gobackward.15").font(.title).foregroundColor(.white)
                    }
                    
                    Button { playerManager.togglePlayPause() } label: {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 72, height: 72)
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 32)).foregroundColor(.black)
                        }
                    }
                    
                    Button { playerManager.seek(by: 15) } label: {
                        Image(systemName: "goforward.15").font(.title).foregroundColor(.white)
                    }
                    
                    Button { Task { await playerManager.nextChapter() } } label: {
                        Image(systemName: "forward.end.fill").font(.title).foregroundColor(.white)
                    }.disabled(playerManager.currentChapterIndex >= playerManager.totalChapters - 1)
                }
                .padding(.vertical)
                
                // 底部控制
                HStack(spacing: 40) {
                    Button { showingSpeedPicker = true } label: {
                        VStack {
                            Image(systemName: "speedometer")
                            Text("\(playerManager.playbackRate, specifier: "%.2f")x").font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    
                    Button { showingSleepTimer = true } label: {
                        VStack {
                            Image(systemName: "moon.zzz")
                            if let endTime = sleepEndDate {
                                Text(formatRemainingTime(until: endTime)).font(.caption2)
                            } else {
                                Text("定时").font(.caption2)
                            }
                        }
                        .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingChapterList) {
            AudioChapterListView(playerManager: playerManager, chapters: playerManager.chapters)
        }
        .confirmationDialog("播放速度", isPresented: $showingSpeedPicker) {
            ForEach(speedOptions, id: \.self) { speed in
                Button("\(speed)x") { playerManager.setPlaybackRate(speed) }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("定时停止", isPresented: $showingSleepTimer) {
            Button("15分钟") { setSleepTimer(15 * 60) }
            Button("30分钟") { setSleepTimer(30 * 60) }
            Button("45分钟") { setSleepTimer(45 * 60) }
            Button("60分钟") { setSleepTimer(60 * 60) }
            Button("本章结束") { setSleepTimerToEndOfChapter() }
            Button("关闭定时") { clearSleepTimer() }
            Button("取消", role: .cancel) {}
        }
        .onAppear { Task { await playerManager.loadBook(book); playerManager.play() } }
        .onDisappear { playerManager.stop() }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatRemainingTime(until date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func setSleepTimer(_ seconds: Int) {
        sleepTime = seconds
        sleepEndDate = Date().addingTimeInterval(TimeInterval(seconds))
    }
    
    private func setSleepTimerToEndOfChapter() {
        let remaining = playerManager.duration - playerManager.currentTime
        if remaining > 0 {
            setSleepTimer(Int(remaining))
        }
    }
    
    private func clearSleepTimer() {
        sleepTime = nil
        sleepEndDate = nil
    }
}

// MARK: - 章节列表

struct AudioChapterListView: View {
    @ObservedObject var playerManager: AudioPlayManager
    let chapters: [BookChapter]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(chapters, id: \.chapterId) { chapter in
                Button {
                    Task {
                        await playerManager.jumpToChapter(Int(chapter.index))
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(chapter.title)
                            .foregroundColor(playerManager.currentChapterIndex == Int(chapter.index) ? .blue : .primary)
                        Spacer()
                        if playerManager.currentChapterIndex == Int(chapter.index) {
                            Image(systemName: "play.fill").foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() } } }
        }
    }
}