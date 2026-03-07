import SwiftUI

struct WebDAVConfigView: View {
    @StateObject private var viewModel: WebDAVConfigViewModel

    init() {
        _viewModel = StateObject(wrappedValue: WebDAVConfigViewModel())
    }

    var body: some View {
        Form {
            Section("服务器设置") {
                TextField("服务器地址", text: $viewModel.serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("用户名", text: $viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("密码", text: $viewModel.password)
                    .textContentType(.password)

                TextField("备份路径", text: $viewModel.backupPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button("测试连接") {
                    Task { await viewModel.testConnection() }
                }
                .disabled(viewModel.isTesting || viewModel.isWorking)

                if viewModel.isConnected {
                    Button("立即备份") {
                        Task { await viewModel.backup() }
                    }
                    .disabled(viewModel.isWorking)

                    Button("从云端恢复") {
                        Task { await viewModel.restore() }
                    }
                    .disabled(viewModel.isWorking)
                }
            }

            if viewModel.isWorking || viewModel.syncProgress > 0 {
                Section("同步进度") {
                    ProgressView(value: viewModel.syncProgress)
                    Text("\(Int(viewModel.syncProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("WebDAV 同步")
        .alert("提示", isPresented: $viewModel.showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .onDisappear {
            viewModel.persistSettings()
        }
    }
}

@MainActor
final class WebDAVConfigViewModel: ObservableObject {
    @Published var serverURL: String
    @Published var username: String
    @Published var password: String
    @Published var backupPath: String

    @Published var isTesting = false
    @Published var isConnected = false
    @Published var isWorking = false
    @Published var syncProgress: Double = 0
    @Published var showingAlert = false
    @Published var alertMessage: String?

    private var syncManager: WebDAVSyncManager?

    init() {
        let defaults = UserDefaults.standard
        serverURL = defaults.string(forKey: WebDAVSettingsStore.serverURLKey) ?? ""
        username = defaults.string(forKey: WebDAVSettingsStore.usernameKey) ?? ""
        password = defaults.string(forKey: WebDAVSettingsStore.passwordKey) ?? ""
        backupPath = defaults.string(forKey: WebDAVSettingsStore.backupPathKey) ?? WebDAVSettingsStore.defaultBackupPath
    }

    func testConnection() async {
        guard validateInput() else {
            return
        }

        persistSettings()
        isTesting = true
        defer { isTesting = false }

        do {
            let manager = try makeSyncManager()
            let result = try await manager.testConnection()
            isConnected = result
            syncProgress = manager.syncProgress
            showAlert(result ? "连接成功" : "连接失败")
        } catch {
            isConnected = false
            showAlert("连接失败：\(error.localizedDescription)")
        }
    }

    func backup() async {
        guard validateInput() else {
            return
        }

        persistSettings()
        isWorking = true
        defer { isWorking = false }

        do {
            let manager = try makeSyncManager()
            try await manager.backup()
            syncProgress = manager.syncProgress
            isConnected = true
            showAlert("备份成功")
        } catch {
            showAlert("备份失败：\(error.localizedDescription)")
        }
    }

    func restore() async {
        guard validateInput() else {
            return
        }

        persistSettings()
        isWorking = true
        defer { isWorking = false }

        do {
            let manager = try makeSyncManager()
            try await manager.restore()
            syncProgress = manager.syncProgress
            isConnected = true
            showAlert("恢复成功")
        } catch {
            showAlert("恢复失败：\(error.localizedDescription)")
        }
    }

    func persistSettings() {
        let defaults = UserDefaults.standard
        defaults.set(serverURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: WebDAVSettingsStore.serverURLKey)
        defaults.set(username.trimmingCharacters(in: .whitespacesAndNewlines), forKey: WebDAVSettingsStore.usernameKey)
        defaults.set(password, forKey: WebDAVSettingsStore.passwordKey)
        defaults.set(WebDAVSettingsStore.normalizePath(backupPath), forKey: WebDAVSettingsStore.backupPathKey)
    }

    private func makeSyncManager() throws -> WebDAVSyncManager {
        if let manager = syncManager {
            return manager
        }

        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw URLError(.badURL)
        }

let credentials = WebDAVCredentials(
            url: trimmed,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        let client = WebDAVClient(baseURL: url, credentials: credentials)
        let manager = WebDAVSyncManager(client: client)
        syncManager = manager
        return manager
    }

    private func validateInput() -> Bool {
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath = WebDAVSettingsStore.normalizePath(backupPath)

        guard !trimmedURL.isEmpty, URL(string: trimmedURL) != nil else {
            showAlert("请输入有效的服务器地址")
            return false
        }

        guard !trimmedUser.isEmpty else {
            showAlert("请输入用户名")
            return false
        }

        guard !password.isEmpty else {
            showAlert("请输入密码")
            return false
        }

        guard !normalizedPath.isEmpty else {
            showAlert("请输入备份路径")
            return false
        }

        backupPath = normalizedPath
        syncManager = nil
        return true
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}
