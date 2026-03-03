//
//  AutoPageTurnControlsView.swift
//  Legado-iOS
//
//  自动翻页控制视图
//  P1-T2 实现
//

import SwiftUI

struct AutoPageTurnControlsView: View {
    @ObservedObject var manager: AutoPageTurnManager
    @Binding var isPresented: Bool
    
    @State private var showingIntervalPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Text("自动翻页")
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
            
            // 进度条
            if manager.state.isRunning || manager.state.isPaused {
                progressBar
            }
            
            // 控制按钮
            controlButtons
            
            Divider()
            
            // 设置
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
        HStack(spacing: 12) {
            switch manager.state {
            case .stopped:
                Image(systemName: "forward.end")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("已停止")
                        .font(.subheadline)
                    Text("点击播放开始自动翻页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
            case .countdown(let seconds):
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动翻页中")
                        .font(.subheadline)
                    Text("\(seconds) 秒后翻页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
            case .paused:
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("已暂停")
                        .font(.subheadline)
                    Text("点击继续恢复翻页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 进度条
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            ProgressView(value: manager.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
            
            HStack {
                Text("剩余 \(manager.remainingSeconds) 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(manager.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 控制按钮
    
    private var controlButtons: some View {
        HStack(spacing: 32) {
            // 停止
            Button {
                manager.stop()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("停止")
                        .font(.caption2)
                }
            }
            .foregroundColor(.red)
            .opacity(manager.state.isRunning || manager.state.isPaused ? 1 : 0.4)
            .disabled(!manager.state.isRunning && !manager.state.isPaused)
            
            // 播放/暂停
            Button {
                manager.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: manager.state.isRunning ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            // 重置
            Button {
                manager.reset()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                    Text("重置")
                        .font(.caption2)
                }
            }
            .opacity(manager.state.isRunning || manager.state.isPaused ? 1 : 0.4)
            .disabled(!manager.state.isRunning && !manager.state.isPaused)
        }
    }
    
    // MARK: - 设置区
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // 翻页间隔
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("翻页间隔")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button {
                        showingIntervalPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(Int(manager.config.interval)) 秒")
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 预设快捷按钮
                HStack(spacing: 8) {
                    ForEach(AutoPageTurnConfig.presetIntervals.prefix(5), id: \.self) { interval in
                        Button {
                            manager.setInterval(interval)
                        } label: {
                            Text("\(Int(interval))秒")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    manager.config.interval == interval ?
                                    Color.blue.opacity(0.2) :
                                    Color(.systemGray5)
                                )
                                .foregroundColor(manager.config.interval == interval ? .blue : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // 开关设置
            Toggle("显示倒计时", isOn: Binding(
                get: { manager.config.showCountdown },
                set: { manager.config.showCountdown = $0 }
            ))
            .font(.subheadline)
            
            Toggle("自动跳转下一章", isOn: Binding(
                get: { manager.config.autoNextChapter },
                set: { manager.config.autoNextChapter = $0 }
            ))
            .font(.subheadline)
            
            Toggle("触摸时暂停", isOn: Binding(
                get: { manager.config.pauseOnTouch },
                set: { manager.config.pauseOnTouch = $0 }
            ))
            .font(.subheadline)
        }
        .sheet(isPresented: $showingIntervalPicker) {
            IntervalPickerView(manager: manager, isPresented: $showingIntervalPicker)
        }
    }
}

// MARK: - 间隔选择器

struct IntervalPickerView: View {
    @ObservedObject var manager: AutoPageTurnManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AutoPageTurnConfig.presetIntervals, id: \.self) { interval in
                    Button {
                        manager.setInterval(interval)
                        isPresented = false
                    } label: {
                        HStack {
                            Text("\(Int(interval)) 秒")
                            
                            Spacer()
                            
                            if manager.config.interval == interval {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择间隔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.height(400)])
    }
}

// MARK: - 倒计时覆盖层

struct AutoPageTurnOverlay: View {
    @ObservedObject var manager: AutoPageTurnManager
    
    var body: some View {
        if manager.config.showCountdown && (manager.state.isRunning || manager.state.isPaused) {
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    HStack(spacing: 6) {
                        ProgressView(value: manager.progress)
                            .progressViewStyle(.circular)
                            .frame(width: 16, height: 16)
                        
                        Text("\(manager.remainingSeconds)s")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                
                Spacer().frame(height: 80)
            }
        }
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        AutoPageTurnControlsView(
            manager: AutoPageTurnManager(),
            isPresented: .constant(true)
        )
    }
}