//
//  QRCodeScanView.swift
//  Legado-iOS
//
//  二维码扫描导入书源
//  支持扫描包含书源 JSON 数据的二维码或 URL
//

import SwiftUI
import AVFoundation

// MARK: - 二维码扫描视图
struct QRCodeScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QRCodeScanViewModel()
    @State private var showingManualInput = false
    @State private var manualUrl = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.cameraReady {
                    // 摄像头预览
                    QRCameraPreview(viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    // 等待权限或无权限提示
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 16) {
                        if !viewModel.cameraAuthorized {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                            Text("请在设置中允许相机权限")
                                .foregroundColor(.white)
                        } else {
                            ProgressView()
                                .tint(.white)
                            Text("初始化相机...")
                                .foregroundColor(.white)
                        }
                    }
                }
                
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
            .onAppear {
                viewModel.checkAndSetupCamera()
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
    @Published var cameraAuthorized = false
    @Published var cameraReady = false
    
    var captureSession: AVCaptureSession?
    private var hasProcessed = false

    private let sourceImporter = SourceViewModel()
    
    override init() {
        super.init()
        // 不在 init 中访问相机，等权限授权后再初始化
    }
    
    func checkAndSetupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraAuthorized = granted
                    if granted { self?.setupCamera() }
                }
            }
        default:
            cameraAuthorized = false
        }
    }
    
    private func setupCamera() {
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
        cameraReady = true
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

        sourceImporter.errorMessage = nil

        let trimmed = urlOrJson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resultMessage = "导入失败：内容为空"
            isImporting = false
            showResult = true
            return
        }

        let count: Int
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            count = sourceImporter.importFromText(trimmed)
        } else {
            count = await sourceImporter.importFromURL(trimmed)
        }

        if count > 0 {
            resultMessage = "成功导入 \(count) 个书源"
        } else {
            resultMessage = "导入失败：\(sourceImporter.errorMessage ?? "无效的书源格式")"
        }
        
        isImporting = false
        showResult = true
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
