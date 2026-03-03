//
//  PageSplitter.swift
//  Legado-iOS
//
//  基于 CoreText 的文本分页引擎
//  将长文本精确分割为屏幕大小的页面
//

import Foundation
import CoreText
import UIKit

// MARK: - 分页配置

struct PageConfig {
    var fontSize: CGFloat = 18
    var lineSpacing: CGFloat = 8
    var paragraphSpacing: CGFloat = 12
    var margins: UIEdgeInsets = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
    var containerSize: CGSize
    var font: UIFont
    
    /// 实际可用于排版的区域大小
    var contentSize: CGSize {
        CGSize(
            width: containerSize.width - margins.left - margins.right,
            height: containerSize.height - margins.top - margins.bottom
        )
    }
    
    /// 便捷构造：用系统字体
    static func `default`(containerSize: CGSize) -> PageConfig {
        let font = UIFont.systemFont(ofSize: 18)
        return PageConfig(containerSize: containerSize, font: font)
    }
    
    /// 从 ReaderViewModel 设置构造
    static func from(
        fontSize: CGFloat,
        lineSpacing: CGFloat,
        padding: UIEdgeInsets,
        containerSize: CGSize,
        fontFamily: String? = nil
    ) -> PageConfig {
        let font: UIFont
        if let family = fontFamily, !family.isEmpty, family != "System" {
            font = UIFont(name: family, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
        }
        return PageConfig(
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            margins: padding,
            containerSize: containerSize,
            font: font
        )
    }
}

// MARK: - 分页结果

struct PageSplitResult {
    /// 每页的文本内容
    let pages: [String]
    /// 每页对应原文的 Range
    let pageRanges: [Range<String.Index>]
    /// 总页数
    var totalPages: Int { pages.count }
}

// MARK: - PageSplitter

final class PageSplitter {
    
    // MARK: - 公开接口
    
    /// 将文本分割为多页
    /// - Parameters:
    ///   - text: 原始文本
    ///   - config: 分页配置
    /// - Returns: 分页后的文本数组
    static func split(text: String, config: PageConfig) -> [String] {
        let result = splitWithRanges(text: text, config: config)
        return result.pages
    }
    
    /// 将文本分割为多页，同时返回每页对应的原文范围
    static func splitWithRanges(text: String, config: PageConfig) -> PageSplitResult {
        guard !text.isEmpty else {
            return PageSplitResult(pages: [], pageRanges: [])
        }
        
        let contentSize = config.contentSize
        guard contentSize.width > 0, contentSize.height > 0 else {
            return PageSplitResult(pages: [text], pageRanges: [text.startIndex..<text.endIndex])
        }
        
        // 构建 NSAttributedString
        let attributedString = buildAttributedString(text: text, config: config)
        
        // 使用 CTFramesetter 进行分页
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: contentSize), transform: nil)
        
        var pages: [String] = []
        var pageRanges: [Range<String.Index>] = []
        var currentIndex: CFIndex = 0
        let totalLength = attributedString.length
        
        while currentIndex < totalLength {
            // 计算当前页能容纳的文本范围
            let frameRange = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRangeMake(currentIndex, 0),
                nil,
                contentSize,
                nil
            )
            _ = frameRange // 仅用于触发计算
            
            // 创建 CTFrame 获取精确范围
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRangeMake(currentIndex, 0),
                path,
                nil
            )
            
            let frameVisibleRange = CTFrameGetVisibleStringRange(frame)
            
            // 安全检查：如果没有可见范围，说明剩余文本太少或排版异常
            if frameVisibleRange.length <= 0 {
                // 将剩余文本作为最后一页
                let nsString = attributedString.string as NSString
                let remaining = nsString.substring(from: currentIndex)
                if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pages.append(remaining)
                    let startIdx = text.index(text.startIndex, offsetBy: currentIndex, limitedBy: text.endIndex) ?? text.endIndex
                    pageRanges.append(startIdx..<text.endIndex)
                }
                break
            }
            
            // 提取当前页文本
            let nsString = attributedString.string as NSString
            let pageLength = frameVisibleRange.length
            let pageText = nsString.substring(with: NSRange(location: currentIndex, length: pageLength))
            
            // 记录页面
            if !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(pageText)
                
                let startIdx = text.index(text.startIndex, offsetBy: currentIndex, limitedBy: text.endIndex) ?? text.endIndex
                let endOffset = currentIndex + pageLength
                let endIdx = text.index(text.startIndex, offsetBy: endOffset, limitedBy: text.endIndex) ?? text.endIndex
                pageRanges.append(startIdx..<endIdx)
            }
            
            currentIndex += pageLength
        }
        
        // 保证至少有一页
        if pages.isEmpty {
            pages.append(text)
            pageRanges.append(text.startIndex..<text.endIndex)
        }
        
        return PageSplitResult(pages: pages, pageRanges: pageRanges)
    }
    
    /// 获取指定页的原文范围
    static func pageRange(
        text: String,
        pageIndex: Int,
        config: PageConfig
    ) -> Range<String.Index>? {
        let result = splitWithRanges(text: text, config: config)
        guard pageIndex >= 0, pageIndex < result.pageRanges.count else { return nil }
        return result.pageRanges[pageIndex]
    }
    
    // MARK: - 内部实现
    
    /// 构建带排版属性的 NSAttributedString
    private static func buildAttributedString(text: String, config: PageConfig) -> NSAttributedString {
        // 段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = config.lineSpacing
        paragraphStyle.paragraphSpacing = config.paragraphSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping
        // CJK 文本优化：允许字符间断行
        paragraphStyle.lineBreakStrategy = .hangulWordPriority
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: config.font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.label
        ]
        
        // 预处理文本：规范化换行符
        let normalizedText = normalizeText(text)
        
        return NSAttributedString(string: normalizedText, attributes: attributes)
    }
    
    /// 规范化文本，统一换行符并处理 CJK 排版
    private static func normalizeText(_ text: String) -> String {
        var result = text
        // 统一换行符
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // 移除首尾多余空白
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 连续空行压缩为单个空行
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return result
    }
}

// MARK: - 分页缓存

final class PageSplitCache {
    static let shared = PageSplitCache()
    
    private struct CacheKey: Hashable {
        let textHash: Int
        let configHash: Int
    }
    
    private var cache: [CacheKey: PageSplitResult] = [:]
    private let queue = DispatchQueue(label: "com.legado.pagesplit.cache", attributes: .concurrent)
    private let maxCacheCount = 10
    
    private init() {}
    
    /// 获取缓存的分页结果，若无缓存则计算并缓存
    func getOrSplit(text: String, config: PageConfig) -> PageSplitResult {
        let key = CacheKey(
            textHash: text.hashValue,
            configHash: configHashValue(config)
        )
        
        // 读缓存
        var cached: PageSplitResult?
        queue.sync {
            cached = cache[key]
        }
        if let result = cached {
            return result
        }
        
        // 计算分页
        let result = PageSplitter.splitWithRanges(text: text, config: config)
        
        // 写缓存
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            // LRU 简单策略：超出上限时清空
            if self.cache.count >= self.maxCacheCount {
                self.cache.removeAll()
            }
            self.cache[key] = result
        }
        
        return result
    }
    
    /// 清除所有缓存（配置变更时调用）
    func invalidate() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
        }
    }
    
    private func configHashValue(_ config: PageConfig) -> Int {
        var hasher = Hasher()
        hasher.combine(config.fontSize)
        hasher.combine(config.lineSpacing)
        hasher.combine(config.paragraphSpacing)
        hasher.combine(config.margins.top)
        hasher.combine(config.margins.left)
        hasher.combine(config.margins.bottom)
        hasher.combine(config.margins.right)
        hasher.combine(config.containerSize.width)
        hasher.combine(config.containerSize.height)
        hasher.combine(config.font.fontName)
        return hasher.finalize()
    }
}
