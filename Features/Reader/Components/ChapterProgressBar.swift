//
//  ChapterProgressBar.swift
//  Legado-iOS
//
//  章节进度条 - 阅读器底部进度控制
//

import SwiftUI

struct ChapterProgressBar: View {
    let currentChapter: Int
    let totalChapters: Int
    let onJumpToChapter: (Int) -> Void
    
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var previewChapter: Int?
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度显示
            HStack {
                Text("\(currentChapter + 1)/\(totalChapters)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isDragging, let preview = previewChapter {
                    Text("第 \(preview + 1) 章")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // 进度滑块
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // 已读进度
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(sliderValue), height: 4)
                        .cornerRadius(2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let newValue = max(0, min(1, value.location.x / geometry.size.width))
                            sliderValue = newValue
                            previewChapter = Int(newValue * Double(totalChapters - 1))
                        }
                        .onEnded { value in
                            isDragging = false
                            let chapter = Int(sliderValue * Double(totalChapters - 1))
                            onJumpToChapter(chapter)
                            previewChapter = nil
                        }
                )
            }
            .frame(height: 20)
            
            // 快捷按钮
            HStack {
                Button("第一页") {
                    sliderValue = 0
                    onJumpToChapter(0)
                }
                .font(.caption2)
                
                Spacer()
                
                Button("最新") {
                    sliderValue = 1.0
                    onJumpToChapter(totalChapters - 1)
                }
                .font(.caption2)
            }
        }
        .padding(.horizontal)
        .onAppear {
            sliderValue = totalChapters > 1 ? Double(currentChapter) / Double(totalChapters - 1) : 0
        }
        .onChange(of: currentChapter) { newValue in
            if !isDragging {
                sliderValue = totalChapters > 1 ? Double(newValue) / Double(totalChapters - 1) : 0
            }
        }
    }
}

// MARK: - 简化版进度条

struct SimpleProgressBar: View {
    let progress: Double // 0.0 - 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 3)
                    .cornerRadius(1.5)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 3)
                    .cornerRadius(1.5)
            }
        }
        .frame(height: 3)
    }
}