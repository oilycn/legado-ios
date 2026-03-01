//
//  QRCodeScanView.swift
//  Legado-iOS
//
//  二维码扫描导入书源
//  支持扫描包含书源 JSON 数据的二维码或 URL
//

import SwiftUI
import AVFoundation
import CoreData

// MARK: - 二维码扫描视图
struct QRCodeScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QRCodeScanViewModel()
    @State private var showingManualInput = false
    @State private var manualUrl = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // 摄像头预览
                QRCameraPreview(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
                
                // 扫描框
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 250, height: 250)
                        .overlay(
                            // 四角标记
                            ZStack {
                                CornerMark().position(x: 15, y: 15)
                                CornerMark().rotationEffect(.degrees(90)).position(x: 235, y: 15)
                                CornerMark().rotationEffect(.degrees(180)).position(x: 235, y: 235)
                                CornerMark().rotationEffect(.degrees(270)).position(x: 15, y: 235)
                            }
                        )
                    
                    Text("将二维码放入框内扫描")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // 底部操作
                    HStack(spacing: 40) {
                        Button(action: { showingManualInput = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "keyboard")
                                    .font(.title2)
                                Text("手动输入")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        }
                        
                        Button(action: { viewModel.toggleFlash() }) {
                            VStack(spacing: 6) {
                                Image(systemName: viewModel.isFlashOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.title2)
                                Text("闪光灯")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 40)
                }
                
                // 导入结果
                if viewModel.isImporting {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("正在导入书源...")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("扫码导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("导入结果", isPresented: $viewModel.showResult) {
                Button("确定") { dismiss() }
            } message: {
                Text(viewModel.resultMessage)
            }
            .alert("手动输入", isPresented: $showingManualInput) {
                TextField("书源 URL 或 JSON", text: $manualUrl)
                    .textInputAutocapitalization(.never)
                Button("取消", role: .cancel) { }
                Button("导入") {
                    if !manualUrl.isEmpty {
                        Task { await viewModel.importFromUrl(manualUrl) }
                    }
                }
            }
        }
    }
}

// MARK: - 四角标记
private struct CornerMark: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.green, lineWidth: 3)
        .frame(width: 20, height: 20)
    }
}

// MARK: - QR 扫描 ViewModel
@MainActor
class QRCodeScanViewModel: NSObject, ObservableObject {
    @Published var isFlashOn = false
    @Published var isImporting = false
    @Published var showResult = false
    @Published var resultMessage = ""
    
    var captureSession: AVCaptureSession?
    private var hasProcessed = false
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        
        captureSession = session
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        isFlashOn.toggle()
        device.torchMode = isFlashOn ? .on : .off
        device.unlockForConfiguration()
    }
    
    func processQRCode(_ code: String) {
        guard !hasProcessed else { return }
        hasProcessed = true
        stopScanning()
        
        Task {
            await importFromUrl(code)
        }
    }
    
    func importFromUrl(_ urlOrJson: String) async {
        isImporting = true
        
        do {
            var jsonData: Data
            
            // 判断是 JSON 还是 URL
            let trimmed = urlOrJson.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
                // 直接是 JSON
                jsonData = trimmed.data(using: .utf8) ?? Data()
            } else if trimmed.hasPrefix("http") {
                // 从 URL 下载
                guard let url = URL(string: trimmed) else {
                    throw ImportError.invalidUrl
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                jsonData = data
            } else {
                throw ImportError.invalidFormat
            }
            
            // 解析书源
            let count = try await importBookSources(from: jsonData)
            resultMessage = "成功导入 \(count) 个书源"
        } catch {
            resultMessage = "导入失败：\(error.localizedDescription)"
        }
        
        isImporting = false
        showResult = true
    }
    
    private func importBookSources(from data: Data) async throws -> Int {
        // 尝试解析为书源 JSON 数组
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // 尝试单个书源
            if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                try await importSingleSource(jsonDict)
                return 1
            }
            throw ImportError.invalidFormat
        }
        
        var count = 0
        let context = CoreDataStack.shared.viewContext
        
        for sourceDict in jsonArray {
            do {
                try await importSingleSource(sourceDict)
                count += 1
            } catch {
                print("导入书源失败：\(error)")
            }
        }
        
        try CoreDataStack.shared.save()
        return count
    }
    
    private func importSingleSource(_ dict: [String: Any]) async throws {
        let context = CoreDataStack.shared.viewContext
        
        guard let bookSourceUrl = dict["bookSourceUrl"] as? String,
              let bookSourceName = dict["bookSourceName"] as? String else {
            throw ImportError.missingFields
        }
        
        // 检查重复
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "bookSourceUrl == %@", bookSourceUrl)
        
        let existing = try? context.fetch(request)
        let source: BookSource
        
        if let existingSource = existing?.first {
            source = existingSource
        } else {
            source = BookSource.create(in: context)
        }
        
        // 填充基本信息
        source.bookSourceUrl = bookSourceUrl
        source.bookSourceName = bookSourceName
        source.bookSourceGroup = dict["bookSourceGroup"] as? String
        source.bookSourceType = (dict["bookSourceType"] as? NSNumber)?.int32Value ?? 0
        source.bookSourceComment = dict["bookSourceComment"] as? String
        source.enabled = (dict["enabled"] as? Bool) ?? true
        source.searchUrl = dict["searchUrl"] as? String
        source.exploreUrl = dict["exploreUrl"] as? String
        source.header = dict["header"] as? String
        source.loginUrl = dict["loginUrl"] as? String
        
        // 转换规则 JSON
        if let ruleSearch = dict["ruleSearch"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: ruleSearch) {
            source.ruleSearchData = data
        }
        if let ruleExplore = dict["ruleExplore"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: ruleExplore) {
            source.ruleExploreData = data
        }
        if let ruleBookInfo = dict["ruleBookInfo"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: ruleBookInfo) {
            source.ruleBookInfoData = data
        }
        if let ruleToc = dict["ruleToc"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: ruleToc) {
            source.ruleTocData = data
        }
        if let ruleContent = dict["ruleContent"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: ruleContent) {
            source.ruleContentData = data
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QRCodeScanViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let code = object.stringValue else { return }
        
        Task { @MainActor in
            processQRCode(code)
        }
    }
}

// MARK: - 相机预览
struct QRCameraPreview: UIViewRepresentable {
    @ObservedObject var viewModel: QRCodeScanViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        guard let session = viewModel.captureSession else { return view }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        viewModel.startScanning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - 错误类型
enum ImportError: LocalizedError {
    case invalidUrl
    case invalidFormat
    case missingFields
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "无效的 URL"
        case .invalidFormat: return "无效的书源格式"
        case .missingFields: return "书源数据缺少必要字段"
        case .saveFailed: return "保存失败"
        }
    }
}
