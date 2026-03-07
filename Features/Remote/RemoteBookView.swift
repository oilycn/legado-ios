import SwiftUI

struct RemoteBookView: View {
    @StateObject private var viewModel = RemoteBookViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddServer = false
    @State private var selectedFile: WebDAVFile?
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isConnected {
                    if viewModel.isLoading {
                        ProgressView("加载中...")
                    } else if let files = viewModel.currentFiles {
                        fileListView(files)
                    } else {
                        Text("请选择目录")
                    }
                } else {
                    connectionForm
                }
            }
            .navigationTitle("远程书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                if viewModel.isConnected {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("断开") {
                            viewModel.disconnect()
                        }
                    }
                }
            }
        }
    }
    
    private var connectionForm: some View {
        Form {
            Section("服务器配置") {
                TextField("服务器地址", text: $serverURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                
                TextField("用户名", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                
                SecureField("密码", text: $password)
                    .textContentType(.password)
            }
            
            Button("连接") {
                Task {
                    await viewModel.connect(
                        url: serverURL,
                        username: username,
                        password: password
                    )
                }
            }
            .disabled(serverURL.isEmpty)
            
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func fileListView(_ files: [WebDAVFile]) -> some View {
        List {
            if viewModel.currentPath != "/" {
                Button(action: { viewModel.navigateUp() }) {
                    Label("返回上级", systemImage: "chevron.left")
                }
            }
            
            ForEach(files, id: \.path) { file in
                if file.isDirectory {
                    Button(action: { viewModel.navigateTo(file.path) }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(file.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if isSupportedFile(file.name) {
                    Button(action: { selectedFile = file }) {
                        HStack {
                            Image(systemName: fileIcon(for: file.name))
                                .foregroundColor(fileColor(for: file.name))
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .foregroundColor(.primary)
                                Text(formatFileSize(file.size))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .alert("导入书籍", isPresented: .init(
            get: { selectedFile != nil },
            set: { if !$0 { selectedFile = nil } }
        )) {
            Button("取消", role: .cancel) { selectedFile = nil }
            Button("导入") {
                if let file = selectedFile {
                    Task { await viewModel.importFile(file) }
                }
            }
        } message: {
            Text("确定要导入「\(selectedFile?.name ?? "")」吗？")
        }
    }
    
    private func isSupportedFile(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["txt", "epub", "json"].contains(ext)
    }
    
    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "epub": return "book.fill"
        case "txt": return "doc.text.fill"
        case "json": return "doc.badge.gearshape"
        default: return "doc.fill"
        }
    }
    
    private func fileColor(for name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "epub": return .purple
        case "txt": return .blue
        case "json": return .orange
        default: return .gray
        }
    }
    
    private func formatFileSize(_ bytes: Int64?) -> String {
        guard let bytes = bytes else { return "未知大小" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}

@MainActor
class RemoteBookViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var currentFiles: [WebDAVFile]?
    @Published var currentPath = "/"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentClient: WebDAVClient?
    
    func connect(url: String, username: String, password: String) async {
        guard let serverURL = URL(string: url) else {
            errorMessage = "无效的服务器地址"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let credentials = WebDAVCredentials(url: url, username: username, password: password)
        currentClient = WebDAVClient(baseURL: serverURL, credentials: credentials)
        currentPath = "/"
        
        do {
            currentFiles = try await currentClient?.list(path: "/")
            isConnected = true
        } catch {
            errorMessage = "连接失败：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func disconnect() {
        currentClient = nil
        currentFiles = nil
        currentPath = "/"
        isConnected = false
    }
    
    func navigateTo(_ path: String) {
        currentPath = path
        Task {
            isLoading = true
            do {
                currentFiles = try await currentClient?.list(path: path)
            } catch {
                errorMessage = "加载失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    func navigateUp() {
        let components = currentPath.split(separator: "/")
        if components.count > 1 {
            let newPath = "/" + components.dropLast().joined(separator: "/")
            navigateTo(newPath.isEmpty ? "/" : newPath)
        } else {
            currentFiles = nil
            currentPath = "/"
        }
    }
    
    func importFile(_ file: WebDAVFile) async {
        guard let client = currentClient else { return }
        
        isLoading = true
        do {
            let data = try await client.download(path: file.path)
            
            let ext = (file.name as NSString).pathExtension.lowercased()
            if ext == "json" {
                if let jsonString = String(data: data, encoding: .utf8) {
                    URLSchemeHandler.importBookSourceJSON(jsonString) { _ in }
                }
            } else {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
                try data.write(to: tempURL)
                let localBookVM = LocalBookViewModel()
                try await localBookVM.importBook(url: tempURL)
            }
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}