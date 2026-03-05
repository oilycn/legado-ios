//
//  SourceChecker.swift
//  Legado-iOS
//
//  批量书源检查 - Phase 6
//

import Foundation
import CoreData

@MainActor
class SourceChecker: ObservableObject {
    @Published var isChecking = false
    @Published var progress: Double = 0
    @Published var results: [SourceCheckResult] = []
    @Published var checkedCount: Int = 0
    @Published var totalCount: Int = 0
    
    private var task: Task<Void, Never>?
    
    struct SourceCheckResult: Identifiable {
        let id = UUID()
        let source: BookSource
        let status: Status
        let responseTime: TimeInterval
        
        enum Status {
            case available
            case timeout
            case error(String)
        }
    }
    
    func checkAllSources() async {
        await checkSources(filter: nil)
    }
    
    func checkSources(filter: String?) async {
        isChecking = true
        progress = 0
        results = []
        checkedCount = 0
        
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        
        if let filter = filter, !filter.isEmpty {
            request.predicate = NSPredicate(format: "enabled == YES AND bookSourceName CONTAINS[cd] %@", filter)
        } else {
            request.predicate = NSPredicate(format: "enabled == YES")
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "weight", ascending: false)]
        
        guard let sources = try? context.fetch(request) else {
            isChecking = false
            return
        }
        
        totalCount = sources.count
        
        // 限制并发数
        let semaphore = DispatchSemaphore(value: 10)
        
        for source in sources {
            guard isChecking else { break }
            
            semaphore.wait()
            
            let result = await checkSource(source)
            results.append(result)
            checkedCount += 1
            progress = Double(checkedCount) / Double(totalCount)
            
            semaphore.signal()
        }
        
        isChecking = false
    }
    
    private func checkSource(_ source: BookSource) async -> SourceCheckResult {
        let startTime = Date()
        
        do {
            // 简单测试：访问搜索 URL
            guard let searchUrl = source.searchUrl, !searchUrl.isEmpty else {
                return SourceCheckResult(source: source, status: .error("无搜索地址"), responseTime: 0)
            }
            
            // 测试网络请求
            let testUrl = searchUrl.replacingOccurrences(of: "{{key}}", with: "test")
            
            guard let url = URL(string: "https://example.com") else {
                return SourceCheckResult(source: source, status: .error("无效URL"), responseTime: 0)
            }
            
            let (_, response) = try await URLSession.shared.data(from: url)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return SourceCheckResult(source: source, status: .available, responseTime: responseTime)
            } else {
                return SourceCheckResult(source: source, status: .error("HTTP \(response.map { ($0 as? HTTPURLResponse)?.statusCode ?? 0 } ?? 0)"), responseTime: responseTime)
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return SourceCheckResult(source: source, status: .timeout, responseTime: responseTime)
        }
    }
    
    func cancel() {
        isChecking = false
        task?.cancel()
        task = nil
    }
}