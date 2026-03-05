//
//  BrightnessSlider.swift
//  Legado-iOS
//
//  亮度控制滑块 - 阅读器亮度调节
//

import SwiftUI

struct BrightnessSlider: View {
    @Binding var isPresented: Bool
    @State private var brightness: Double = UIScreen.main.brightness
    @AppStorage("readerBrightness") private var savedBrightness: Double = 0.5
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题栏
            HStack {
                Text("亮度调节")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    isPresented = false
                }
            }
            
            // 亮度滑块
            HStack(spacing: 16) {
                Image(systemName: "sun.min")
                    .foregroundColor(.secondary)
                
                Slider(value: $brightness, in: 0.1...1.0) { _ in
                    applyBrightness()
                }
                
                Image(systemName: "sun.max")
                    .foregroundColor(.secondary)
            }
            
            // 预设按钮
            HStack(spacing: 12) {
                BrightnessPresetButton(title: "暗", value: 0.2, current: $brightness)
                BrightnessPresetButton(title: "中", value: 0.5, current: $brightness)
                BrightnessPresetButton(title: "亮", value: 0.8, current: $brightness)
                BrightnessPresetButton(title: "最亮", value: 1.0, current: $brightness)
            }
            
            // 自动亮度跟随系统
            Button("跟随系统") {
                brightness = UIScreen.main.brightness
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
        .onAppear {
            brightness = UIScreen.main.brightness
        }
    }
    
    private func applyBrightness() {
        UIScreen.main.brightness = brightness
        savedBrightness = brightness
    }
}

private struct BrightnessPresetButton: View {
    let title: String
    let value: Double
    @Binding var current: Double
    
    var body: some View {
        Button(title) {
            current = value
            UIScreen.main.brightness = value
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(abs(current - value) < 0.1 ? Color.blue : Color(.systemGray5))
        .foregroundColor(abs(current - value) < 0.1 ? .white : .primary)
        .cornerRadius(8)
    }
}