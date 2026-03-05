//
//  BookInfoEditView.swift
//  Legado-iOS
//
//  书籍信息编辑
//

import SwiftUI
import CoreData
import PhotosUI

struct BookInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookInfoEditViewModel
    let onSave: () -> Void
    
    init(book: Book, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BookInfoEditViewModel(book: book))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("书名", text: $viewModel.name)
                    TextField("作者", text: $viewModel.author)
                    TextField("类型", text: $viewModel.kind)
                }
                
                Section("简介") {
                    TextEditor(text: $viewModel.intro)
                        .frame(minHeight: 100)
                }
                
                Section("封面") {
                    HStack {
                        AsyncImage(url: URL(string: viewModel.coverUrl)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 60, height: 80)
                        .cornerRadius(4)
                        
                        TextField("封面URL", text: $viewModel.customCoverUrl)
                    }
                    
                    PhotosPicker(selection: $viewModel.selectedImage, matching: .images) {
                        Label("从相册选择", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("编辑书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { viewModel.save(); onSave(); dismiss() }
                }
            }
        }
    }
}

class BookInfoEditViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var author: String = ""
    @Published var kind: String = ""
    @Published var intro: String = ""
    @Published var coverUrl: String = ""
    @Published var customCoverUrl: String = ""
    @Published var selectedImage: PhotosPickerItem?
    
    private let book: Book
    private let context = CoreDataStack.shared.viewContext
    
    init(book: Book) {
        self.book = book
        name = book.name
        author = book.author
        kind = book.kind ?? ""
        intro = book.displayIntro ?? ""
        coverUrl = book.coverUrl ?? ""
        customCoverUrl = book.customCoverUrl ?? ""
    }
    
    func save() {
        book.name = name
        book.author = author
        book.kind = kind.isEmpty ? nil : kind
        book.customIntro = intro.isEmpty ? nil : intro
        book.customCoverUrl = customCoverUrl.isEmpty ? nil : customCoverUrl
        book.updatedAt = Date()
        try? context.save()
    }
}