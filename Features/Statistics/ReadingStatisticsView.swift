//
//  ReadingStatisticsView.swift
//  Legado-iOS
//
//  阅读统计视图
//  P2-T1 实现
//

import SwiftUI

struct ReadingStatisticsView: View {
    @StateObject private var viewModel = ReadingStatisticsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 总览卡片
                overviewCard
                
                // 今日统计
                todayStatsCard
                
                // 本周统计图表
                weeklyChart
                
                // 排行榜
                rankingSection
            }
            .padding()
        }
        .navigationTitle("阅读统计")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - 总览卡片
    
    private var overviewCard: some View {
        VStack(spacing: 16) {
            Text("累计阅读")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 30) {
                StatItem(
                    title: "总时长",
                    value: viewModel.formattedTotalTime,
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatItem(
                    title: "总字数",
                    value: "\(viewModel.totalWords)",
                    icon: "character.textbox",
                    color: .green
                )
                
                StatItem(
                    title: "书籍数",
                    value: "\(viewModel.totalBooks)",
                    icon: "books.vertical.fill",
                    color: .orange
                )
            }
            
            Divider()
            
            HStack {
                Text("日均阅读")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(viewModel.formattedAverageDaily)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 今日统计
    
    private var todayStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日阅读")
                    .font(.headline)
                
                Spacer()
                
                Text(viewModel.todayDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let today = viewModel.todayStats {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(today.formattedTime)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("阅读时长")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(today.wordsRead)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("阅读字数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 进度条
                ProgressView(value: viewModel.todayProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            } else {
                Text("今天还没有阅读记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 本周图表
    
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 7 天")
                .font(.headline)
            
            ChartView(data: viewModel.weeklyData)
                .frame(height: 150)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 排行榜
    
    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("阅读排行")
                    .font(.headline)
                
                Spacer()
                
                Text("共 \(viewModel.ranking.count) 本")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.ranking.isEmpty {
                Text("暂无阅读记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.ranking.prefix(5)) { item in
                    HStack(spacing: 12) {
                        Text("\(item.rank)")
                            .font(.headline)
                            .foregroundColor(item.rank <= 3 ? .orange : .secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.bookName)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Text(item.formattedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if item.rank < min(5, viewModel.ranking.count) {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 统计项组件

private struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 图表视图

private struct ChartView: View {
    let data: [(day: String, minutes: Int)]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data, id: \.day) { item in
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 30, height: CGFloat(item.minutes) / maxMinutes * 100)
                        .cornerRadius(4)
                    
                    Text(item.day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var maxMinutes: Int {
        max(data.map { $0.minutes }.max() ?? 1, 1)
    }
}

// MARK: - ViewModel

@MainActor
class ReadingStatisticsViewModel: ObservableObject {
    @Published var totalTime: TimeInterval = 0
    @Published var totalWords: Int = 0
    @Published var totalBooks: Int = 0
    @Published var todayStats: DailyReadingStats?
    @Published var weeklyData: [(day: String, minutes: Int)] = []
    @Published var ranking: [RankingItem] = []
    
    private let statsManager = ReadingStatisticsManager()
    
    var formattedTotalTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }
    
    var formattedAverageDaily: String {
        let avg = statsManager.statistics.averageDailyTime
        let minutes = Int(avg) / 60
        return "\(minutes)分钟"
    }
    
    var todayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: Date())
    }
    
    var todayProgress: Double {
        guard let today = todayStats else { return 0 }
        let dailyGoal: TimeInterval = 3600 // 1小时目标
        return min(today.readingTime / dailyGoal, 1.0)
    }
    
    init() {
        loadData()
    }
    
    private func loadData() {
        let stats = statsManager.statistics
        
        totalTime = stats.totalReadingTime
        totalWords = stats.totalWords
        totalBooks = stats.totalBooks
        
        todayStats = statsManager.todayStats
        
        // 加载最近 7 天数据
        loadWeeklyData()
        
        // 加载排行榜
        loadRanking()
    }
    
    private func loadWeeklyData() {
        let calendar = Calendar.current
        let today = Date()
        
        var data: [(day: String, minutes: Int)] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -6 + i, to: today) {
                let dayStr = DateFormatter.shortDay.string(from: date)
                let stats = statsManager.getStats(for: date)
                let minutes = Int((stats?.readingTime ?? 0) / 60)
                data.append((day: dayStr, minutes: minutes))
            }
        }
        
        weeklyData = data
    }
    
    private func loadRanking() {
        let rawRanking = statsManager.getReadingRanking(limit: 10)
        
        ranking = rawRanking.enumerated().map { index, item in
            RankingItem(
                rank: index + 1,
                bookId: item.bookId,
                bookName: item.bookName,
                totalTime: item.totalTime
            )
        }
    }
}

// MARK: - 排行项

struct RankingItem: Identifiable {
    let id = UUID()
    let rank: Int
    let bookId: UUID
    let bookName: String
    let totalTime: TimeInterval
    
    var formattedTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)时\(minutes)分"
        }
        return "\(minutes)分钟"
    }
}

// MARK: - DateFormatter 扩展

extension DateFormatter {
    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "zh_Hans")
        return formatter
    }()
}

// MARK: - 预览

#Preview {
    NavigationView {
        ReadingStatisticsView()
    }
}