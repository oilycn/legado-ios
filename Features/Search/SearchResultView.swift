//
//  SearchResultView.swift
//  Legado-iOS
//
//  搜索结果视图
//

import SwiftUI

struct SearchResultView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showingSourcePicker = false
    
    var body: some View {
        VStack {
            if viewModel.isSearching {
                ProgressView("搜索中...")
                    .padding()
            } else if viewModel.searchResults.isEmpty {
                EmptyStateView(
                    title: "搜索结果",
                    subtitle: "输入关键词搜索书籍",
                    imageName: "magnifyingglass"
                )
            } else {
                List(viewModel.searchResults) { result in
                    SearchResultItemView(result: result)
                }
            }
        }
        .navigationTitle("搜索")
        .searchable(text: $viewModel.searchText, prompt: "搜索书籍")
        .onSubmit(of: .search) {
            Task {
                await viewModel.search(keyword: viewModel.searchText, sources: viewModel.selectedSources)
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: { showingSourcePicker = true }) {
                    Label("书源", systemImage: "square.grid.2x2")
                }
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(selectedSources: $viewModel.selectedSources)
        }
    }
}

struct SearchResultItemView: View {
    let result: SearchViewModel.SearchResult
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            BookCoverView(url: result.coverUrl)
                .frame(width: 60, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                // 书名
                Text(result.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // 作者
                Text(result.displayAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 书源
                Text(result.sourceName)
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                // 简介
                if let intro = result.intro {
                    Text(intro)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .onTapGesture {
            showingDetail = true
        }
    }
}

struct SourcePickerView: View {
    @Binding var selectedSources: [BookSource]
    @Environment(\.dismiss) var dismiss
    @State private var sources: [BookSource] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sources, id: \.sourceId) { source in
                    HStack {
                        Text(source.displayName)
                        
                        Spacer()
                        
                        if selectedSources.contains(where: { $0.sourceId == source.sourceId }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSource(source)
                    }
                }
            }
            .navigationTitle("选择书源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSources()
            }
        }
    }
    
    private func loadSources() async {
        do {
            sources = try CoreDataStack.shared.viewContext.fetch(BookSource.fetchRequest())
        } catch {
            print("加载书源失败：\(error)")
        }
    }
    
    private func toggleSource(_ source: BookSource) {
        if let index = selectedSources.firstIndex(where: { $0.sourceId == source.sourceId }) {
            selectedSources.remove(at: index)
        } else {
            selectedSources.append(source)
        }
    }
}

#Preview {
    SearchResultView()
}
