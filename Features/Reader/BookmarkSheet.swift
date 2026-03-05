//
//  BookmarkSheet.swift
//  Legado-iOS
//
//  书签管理视图 - 添加/查看/删除书签
//  参考 Android BookmarkDialog
//

import SwiftUI
import CoreData

// MARK: - 书签管理 Sheet

struct BookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReaderViewModel
    let book: Book
    
    @State private var bookmarks: [Bookmark] = []
    @State private var showingAddBookmark = false
    @State private var bookmarkContent = ""
    
    var body: some View {
        NavigationView {
            Group {
                if bookmarks.isEmpty {
                    emptyStateView
                } else {
                    bookmarkListView
                }
            }
            .navigationTitle("书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddBookmark = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadBookmarks() }
            .alert("添加书签", isPresented: $showingAddBookmark) {
                TextField("书签备注（可选）", text: $bookmarkContent)
                Button("添加") { addBookmark() }
                Button("取消", role: .cancel) { bookmarkContent = "" }
            } message: {
                Text("为「\(viewModel.currentChapter?.title ?? "当前章节")」添加书签")
            }
        }
    }
    
    // MARK: - 空状态
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("还没有书签")
                .foregroundColor(.secondary)
            
            Button("添加当前位置") {
                showingAddBookmark = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 书签列表
    
    private var bookmarkListView: some View {
        List {
            ForEach(bookmarks, id: \.bookmarkId) { bookmark in
                BookmarkRow(bookmark: bookmark) {
                    // 跳转到书签位置
                    viewModel.jumpToChapter(Int(bookmark.chapterIndex))
                    dismiss()
                }
            }
            .onDelete(perform: deleteBookmarks)
        }
        .listStyle(.plain)
    }
    
    // MARK: - 操作
    
    private func loadBookmarks() {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createDate", ascending: false)]
        
        do {
            bookmarks = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            print("加载书签失败: \(error)")
        }
    }
    
    private func addBookmark() {
        let context = CoreDataStack.shared.viewContext
        let bookmark = Bookmark.create(in: context)
        bookmark.bookId = book.bookId
        bookmark.chapterIndex = Int32(viewModel.currentChapterIndex)
        bookmark.chapterTitle = viewModel.currentChapter?.title ?? "未知章节"
        bookmark.content = bookmarkContent.isEmpty
            ? "第\(viewModel.currentPageIndex + 1)页"
            : bookmarkContent
        bookmark.book = book
        
        do {
            try context.save()
            bookmarkContent = ""
            loadBookmarks()
        } catch {
            print("添加书签失败: \(error)")
        }
    }
    
    private func deleteBookmarks(at offsets: IndexSet) {
        let context = CoreDataStack.shared.viewContext
        for index in offsets {
            context.delete(bookmarks[index])
        }
        
        do {
            try context.save()
            loadBookmarks()
        } catch {
            print("删除书签失败: \(error)")
        }
    }
}

// MARK: - 书签行视图

struct BookmarkRow: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: bookmark.createDate)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.chapterTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !bookmark.content.isEmpty {
                        Text(bookmark.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
    }
}
