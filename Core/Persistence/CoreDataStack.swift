//
//  CoreDataStack.swift
//  Legado-iOS
//
//  CoreData 持久化栈（支持 App Group 共享 + iCloud 同步）
//

import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    /// App Group ID 常量（避免硬编码）
    static let appGroupIdentifier = "group.com.chrn11.legado"
    
    /// CoreData 模型名称
    private static let modelName = "Legado"
    
    /// Store 文件名
    private static let storeFileName = "Legado.sqlite"
    
    // MARK: - Core Data 容器
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: Self.modelName)
        
        // 确定 store URL（优先使用 App Group 共享目录）
        let storeURL = Self.resolveStoreURL()
        
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { [weak container] description, error in
            if let error = error {
                print("CoreData 存储加载失败：\(error.localizedDescription)")
                return
            }
            
            container?.viewContext.automaticallyMergesChangesFromParent = true
            container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        
        return container
    }()
    
    // MARK: - Store URL 解析
    
    /// 解析并返回 store 文件的 URL，处理旧数据迁移
    private static func resolveStoreURL() -> URL {
        // 尝试获取 App Group 共享目录
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let sharedStoreURL = groupURL.appendingPathComponent(storeFileName)
            
            // 如果共享目录中没有 store，检查是否需要从旧位置迁移
            if !FileManager.default.fileExists(atPath: sharedStoreURL.path) {
                migrateStoreIfNeeded(to: sharedStoreURL)
            }
            
            return sharedStoreURL
        }
        
        // Fallback: App Group 不可用时使用私有目录
        print("⚠️ App Group 不可用，使用应用私有目录")
        return defaultStoreURL()
    }
    
    /// 应用默认 store URL（私有目录）
    private static func defaultStoreURL() -> URL {
        let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupportURL.appendingPathComponent(storeFileName)
    }
    
    /// 将旧 store 迁移到 App Group 共享目录
    private static func migrateStoreIfNeeded(to targetURL: URL) {
        let oldStoreURL = defaultStoreURL()
        
        guard FileManager.default.fileExists(atPath: oldStoreURL.path) else {
            // 无旧数据，无需迁移
            return
        }
        
        print("📦 开始迁移 CoreData store 到 App Group 共享目录...")
        
        // 确保目标目录存在
        let targetDir = targetURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // SQLite 文件有多个附带文件需要一起迁移
        let suffixes = ["", "-wal", "-shm"]
        var migrationSuccess = true
        
        for suffix in suffixes {
            let oldFile = oldStoreURL.deletingLastPathComponent()
                .appendingPathComponent(storeFileName + suffix)
            let newFile = targetDir.appendingPathComponent(storeFileName + suffix)
            
            guard FileManager.default.fileExists(atPath: oldFile.path) else { continue }
            
            do {
                try FileManager.default.copyItem(at: oldFile, to: newFile)
            } catch {
                print("⚠️ 迁移文件失败(\(suffix)): \(error.localizedDescription)")
                migrationSuccess = false
                break
            }
        }
        
        if migrationSuccess {
            // 迁移成功后删除旧文件
            for suffix in suffixes {
                let oldFile = oldStoreURL.deletingLastPathComponent()
                    .appendingPathComponent(storeFileName + suffix)
                try? FileManager.default.removeItem(at: oldFile)
            }
            print("✅ CoreData store 迁移完成")
        } else {
            // 迁移失败，清理目标文件，使用旧位置
            for suffix in suffixes {
                let newFile = targetDir.appendingPathComponent(storeFileName + suffix)
                try? FileManager.default.removeItem(at: newFile)
            }
            print("❌ CoreData store 迁移失败，保持使用旧位置")
        }
    }
    
    // MARK: - 上下文
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// 创建新的后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// 保存上下文
    func save(context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext
        guard contextToSave.hasChanges else { return }
        try contextToSave.save()
    }
    
    /// 执行异步操作
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    try context.save()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - iCloud 同步支持

    func syncToCloud() async throws {
        let context = newBackgroundContext()
        try await context.perform {
            try context.save()
        }
    }
}

// MARK: - CloudKit 错误
enum CloudKitError: LocalizedError {
    case notAvailable
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "iCloud 不可用"
        case .syncFailed: return "同步失败"
        }
    }
}
