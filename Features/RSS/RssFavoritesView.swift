//
//  RssFavoritesView.swift
//  Legado-iOS
//
//  RSS 收藏管理 - Phase 5
//

import SwiftUI
import CoreData

struct RssFavoritesView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "starDate", ascending: false)])
    private var favorites: FetchedResults<RssStar>
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            Group {
                if favorites.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star").font(.system(size: 48)).foregroundColor(.gray)
                        Text("暂无收藏").foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(filteredFavorites) { star in
                            RssStarRow(star: star)
                        }
                        .onDelete(perform: deleteFavorites)
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var filteredFavorites: [RssStar] {
        if searchText.isEmpty { return Array(favorites) }
        return favorites.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func deleteFavorites(at offsets: IndexSet) {
        let context = CoreDataStack.shared.viewContext
        for index in offsets {
            context.delete(filteredFavorites[index])
        }
        try? context.save()
    }
}

struct RssStarRow: View {
    let star: RssStar
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(star.title)
                .font(.headline)
                .lineLimit(2)
            
            if let desc = star.articleDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Text(formatDate(star.starDate))
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}