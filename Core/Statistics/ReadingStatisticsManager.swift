//
//  ReadingStatisticsManager.swift
//  Legado-iOS
//
//  阅读统计管理器
//  P2-T1 实现
//

import Foundation
import CoreData

// MARK: - 阅读统计数据

struct ReadingStatistics: Codable {
    var totalReadingTime: TimeInterval = 0 // 总阅读时长（秒）
    var totalWords: Int = 0 // 总阅读字数
    var totalChapters: Int = 0 // 总阅读章节数
    var totalBooks: Int = 0 // 阅读书籍数
    var dailyStats: [DailyReadingStats] = [] // 每日统计
    var weeklyStats: [WeeklyReadingStats] = [] // 每周统计
    var monthlyStats: [MonthlyReadingStats] = [] // 每月统计
    
    var averageDailyTime: TimeInterval {
        let days = dailyStats.count
        return days > 0 ? totalReadingTime / Double(days) : 0
    }
    
    var averageDailyWords: Int {
        let days = dailyStats.count
        return days > 0 ? totalWords / days : 0
    }
}

// MARK: - 每日统计

struct DailyReadingStats: Identifiable, Codable {
    var id: String { date }
    let date: String // yyyy-MM-dd
    var readingTime: TimeInterval = 0
    var wordsRead: Int = 0
    var chaptersRead: Int = 0
    var booksRead: Set<String> = [] // 书籍 ID 集合
    var sessions: Int = 0 // 阅读次数
    
    var formattedTime: String {
        let hours = Int(readingTime) / 3600
        let minutes = (Int(readingTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }
}

// MARK: - 每周统计

struct WeeklyReadingStats: Identifiable, Codable {
    var id: String { weekIdentifier }
    let weekIdentifier: String // yyyy-Www
    let year: Int
    let week: Int
    var readingTime: TimeInterval = 0
    var wordsRead: Int = 0
    var chaptersRead: Int = 0
}

// MARK: - 每月统计

struct MonthlyReadingStats: Identifiable, Codable {
    var id: String { monthIdentifier }
    let monthIdentifier: String // yyyy-MM
    let year: Int
    let month: Int
    var readingTime: TimeInterval = 0
    var wordsRead: Int = 0
    var chaptersRead: Int = 0
}

// MARK: - 阅读记录

struct ReadingRecord: Codable {
    let id: UUID
    let bookId: UUID
    let bookName: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    var startChapter: Int
    var endChapter: Int?
    var wordsRead: Int = 0
    
    var isActive: Bool {
        endTime == nil
    }
}

// MARK: - 阅读统计管理器

@MainActor
class ReadingStatisticsManager: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published private(set) var statistics: ReadingStatistics = ReadingStatistics()
    @Published private(set) var currentSession: ReadingRecord?
    @Published private(set) var todayStats: DailyReadingStats?
    
    // MARK: - 私有属性
    
    private let statsKey = "reading_statistics"
    private let dailyKey = "daily_stats"
    private var sessionTimer: Timer?
    
    // MARK: - 初始化
    
    init() {
        loadStatistics()
        loadTodayStats()
    }
    
    // MARK: - 公开方法
    
    /// 开始阅读会话
    func startReadingSession(bookId: UUID, bookName: String, startChapter: Int) {
        // 如果有未结束的会话，先结束
        if currentSession != nil {
            endReadingSession()
        }
        
        let record = ReadingRecord(
            id: UUID(),
            bookId: bookId,
            bookName: bookName,
            startTime: Date(),
            endTime: nil,
            duration: 0,
            startChapter: startChapter,
            endChapter: nil,
            wordsRead: 0
        )
        
        currentSession = record
        
        // 开始计时
        startSessionTimer()
    }
    
    /// 结束阅读会话
    func endReadingSession(wordsRead: Int = 0, endChapter: Int? = nil) {
        guard var session = currentSession else { return }
        
        stopSessionTimer()
        
        session.endTime = Date()
        session.duration = session.endTime!.timeIntervalSince(session.startTime)
        session.wordsRead = wordsRead
        session.endChapter = endChapter ?? session.startChapter
        
        // 更新统计
        updateStatistics(with: session)
        
        // 保存记录
        saveReadingRecord(session)
        
        currentSession = nil
    }
    
    /// 更新当前章节
    func updateCurrentChapter(_ chapter: Int) {
        guard var session = currentSession else { return }
        session.endChapter = chapter
        currentSession = session
    }
    
    /// 记录阅读字数
    func recordWordsRead(_ words: Int) {
        guard var session = currentSession else { return }
        session.wordsRead += words
        currentSession = session
    }
    
    /// 获取指定日期的统计
    func getStats(for date: Date) -> DailyReadingStats? {
        let dateStr = formatDate(date)
        return statistics.dailyStats.first { $0.date == dateStr }
    }
    
    /// 获取最近 N 天的统计
    func getRecentDaysStats(days: Int) -> [DailyReadingStats] {
        return Array(statistics.dailyStats.suffix(days))
    }
    
    /// 获取本周统计
    func getThisWeekStats() -> WeeklyReadingStats? {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        return statistics.weeklyStats.first { $0.year == year && $0.week == week }
    }
    
    /// 获取本月统计
    func getThisMonthStats() -> MonthlyReadingStats? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        return statistics.monthlyStats.first { $0.year == year && $0.month == month }
    }
    
    /// 获取阅读排行榜
    func getReadingRanking(limit: Int = 10) -> [(bookId: UUID, bookName: String, totalTime: TimeInterval)] {
        // 从 CoreData 获取按阅读时间排序的书籍
        let context = CoreDataStack.shared.viewContext
        let request = Book.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
        request.fetchLimit = limit
        
        guard let books = try? context.fetch(request) else { return [] }
        
        return books.compactMap { book in
            (book.bookId, book.name, TimeInterval(book.durChapterTime))
        }
    }
    
    /// 清除所有统计
    func clearAllStatistics() {
        statistics = ReadingStatistics()
        todayStats = nil
        saveStatistics()
    }
    
    // MARK: - 私有方法
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionDuration()
            }
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    private func updateSessionDuration() {
        guard var session = currentSession else { return }
        session.duration = Date().timeIntervalSince(session.startTime)
        currentSession = session
    }
    
    private func updateStatistics(with session: ReadingRecord) {
        // 更新总统计
        statistics.totalReadingTime += session.duration
        statistics.totalWords += session.wordsRead
        
        if let endChapter = session.endChapter {
            statistics.totalChapters += abs(endChapter - session.startChapter)
        }
        
        // 更新每日统计
        updateDailyStats(session)
        
        // 更新每周统计
        updateWeeklyStats(session)
        
        // 更新每月统计
        updateMonthlyStats(session)
        
        saveStatistics()
    }
    
    private func updateDailyStats(_ session: ReadingRecord) {
        let dateStr = formatDate(session.startTime)
        
        if let index = statistics.dailyStats.firstIndex(where: { $0.date == dateStr }) {
            statistics.dailyStats[index].readingTime += session.duration
            statistics.dailyStats[index].wordsRead += session.wordsRead
            statistics.dailyStats[index].booksRead.insert(session.bookId.uuidString)
            statistics.dailyStats[index].sessions += 1
        } else {
            var dailyStats = DailyReadingStats(date: dateStr)
            dailyStats.readingTime = session.duration
            dailyStats.wordsRead = session.wordsRead
            dailyStats.booksRead = [session.bookId.uuidString]
            dailyStats.sessions = 1
            statistics.dailyStats.append(dailyStats)
        }
        
        // 保持最近 365 天的统计
        if statistics.dailyStats.count > 365 {
            statistics.dailyStats = Array(statistics.dailyStats.suffix(365))
        }
        
        // 更新今日统计
        todayStats = statistics.dailyStats.last { $0.date == formatDate(Date()) }
    }
    
    private func updateWeeklyStats(_ session: ReadingRecord) {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: session.startTime)
        let year = calendar.component(.year, from: session.startTime)
        let weekId = String(format: "%d-W%02d", year, week)
        
        if let index = statistics.weeklyStats.firstIndex(where: { $0.weekIdentifier == weekId }) {
            statistics.weeklyStats[index].readingTime += session.duration
            statistics.weeklyStats[index].wordsRead += session.wordsRead
        } else {
            var weeklyStats = WeeklyReadingStats(weekIdentifier: weekId, year: year, week: week)
            weeklyStats.readingTime = session.duration
            weeklyStats.wordsRead = session.wordsRead
            statistics.weeklyStats.append(weeklyStats)
        }
        
        // 保持最近 52 周的统计
        if statistics.weeklyStats.count > 52 {
            statistics.weeklyStats = Array(statistics.weeklyStats.suffix(52))
        }
    }
    
    private func updateMonthlyStats(_ session: ReadingRecord) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: session.startTime)
        let year = calendar.component(.year, from: session.startTime)
        let monthId = String(format: "%d-%02d", year, month)
        
        if let index = statistics.monthlyStats.firstIndex(where: { $0.monthIdentifier == monthId }) {
            statistics.monthlyStats[index].readingTime += session.duration
            statistics.monthlyStats[index].wordsRead += session.wordsRead
        } else {
            var monthlyStats = MonthlyReadingStats(monthIdentifier: monthId, year: year, month: month)
            monthlyStats.readingTime = session.duration
            monthlyStats.wordsRead = session.wordsRead
            statistics.monthlyStats.append(monthlyStats)
        }
        
        // 保持最近 24 个月的统计
        if statistics.monthlyStats.count > 24 {
            statistics.monthlyStats = Array(statistics.monthlyStats.suffix(24))
        }
    }
    
    private func saveReadingRecord(_ record: ReadingRecord) {
        // 保存到 UserDefaults 或 CoreData
        var records = loadReadingRecords()
        records.append(record)
        
        // 保持最近 1000 条记录
        if records.count > 1000 {
            records = Array(records.suffix(1000))
        }
        
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "reading_records")
        }
    }
    
    private func loadReadingRecords() -> [ReadingRecord] {
        guard let data = UserDefaults.standard.data(forKey: "reading_records"),
              let records = try? JSONDecoder().decode([ReadingRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func loadStatistics() {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(ReadingStatistics.self, from: data) else {
            statistics = ReadingStatistics()
            return
        }
        statistics = stats
    }
    
    private func saveStatistics() {
        guard let data = try? JSONEncoder().encode(statistics) else { return }
        UserDefaults.standard.set(data, forKey: statsKey)
    }
    
    private func loadTodayStats() {
        let today = formatDate(Date())
        todayStats = statistics.dailyStats.first { $0.date == today }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}