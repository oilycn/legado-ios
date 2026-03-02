//
//  ReaderSettingsFullView.swift
//  Legado-iOS
//
//  完整阅读设置界面
//

import SwiftUI

struct ReaderSettingsFullView: View {
    @Environment(\.dismiss) var dismiss
    
    // 阅读配置
    @State private var fontSize: Double = 18
    @State private var lineSpacing: Double = 8
    @State private var paragraphSpacing: Double = 12
    @State private var pageMargin: Double = 16
    @State private var brightness: Double = 1.0
    @State private var theme: ReaderThemeType = .light
    @State private var pageAnimation: PageAnimation = .cover
    @State private var fontFamily: String = "System"
    @State private var showStatusBar = false
    @State private var clickToFlip = true
    
    enum ReaderThemeType: String, CaseIterable, Identifiable {
        case light = "亮色"
        case dark = "暗色"
        case sepia = "羊皮纸"
        case eyeProtection = "护眼"
        case custom = "自定义"
        
        var id: String { self.rawValue }
    }
    
    enum PageAnimation: String, CaseIterable, Identifiable {
        case cover = "覆盖"
        case simulation = "仿真"
        case slide = "滑动"
        case scroll = "滚动"
        case none = "无动画"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        Form {
                Section(header: Text("主题")) {
                    Picker("主题", selection: $theme) {
                        ForEach(ReaderThemeType.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if theme == .custom {
                        ColorPicker("背景颜色", selection: .constant(.white))
                        ColorPicker("文字颜色", selection: .constant(.black))
                    }
                }
                
                Section(header: Text("字体")) {
                    Stepper("字号：\(Int(fontSize))", value: $fontSize, in: 12...32, step: 1)
                    
                    Stepper("行距：\(Int(lineSpacing))", value: $lineSpacing, in: 4...20, step: 1)
                    
                    Stepper("段距：\(Int(paragraphSpacing))", value: $paragraphSpacing, in: 0...30, step: 2)
                    
                    Picker("字体", selection: $fontFamily) {
                        Text("系统").tag("System")
                        Text("宋体").tag("Songti")
                        Text("黑体").tag("Heiti")
                        Text("楷体").tag("Kaiti")
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("翻页")) {
                    Picker("翻页动画", selection: $pageAnimation) {
                        ForEach(PageAnimation.allCases) { anim in
                            Text(anim.rawValue).tag(anim)
                        }
                    }
                    
                    Toggle("点击翻页", isOn: $clickToFlip)
                }
                
                Section(header: Text("显示")) {
                    Stepper("页边距：\(Int(pageMargin))", value: $pageMargin, in: 0...40, step: 4)
                    
                    Slider(value: $brightness, in: 0.5...1.5, step: 0.1) {
                        Text("亮度")
                    }
                    
                    Toggle("显示状态栏", isOn: $showStatusBar)
                }
                
                Section(header: Text("预览")) {
                    ReaderPreviewView(
                        fontSize: fontSize,
                        lineSpacing: lineSpacing,
                        theme: theme
                    )
                    .frame(height: 200)
                }
                
                Section {
                    Button("恢复默认设置") {
                        resetToDefault()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
    }
    
    private func resetToDefault() {
        fontSize = 18
        lineSpacing = 8
        paragraphSpacing = 12
        pageMargin = 16
        brightness = 1.0
        theme = .light
        pageAnimation = .cover
        fontFamily = "System"
    }
    
    private func saveSettings() {
        // TODO: 保存到 UserDefaults 或数据库
        print("保存设置")
    }
}

// MARK: - 预览视图
struct ReaderPreviewView: View {
    let fontSize: Double
    let lineSpacing: Double
    let theme: ReaderSettingsFullView.ReaderThemeType
    
    var backgroundColor: Color {
        switch theme {
        case .light: return .white
        case .dark: return .black
        case .sepia: return Color(red: 0.96, green: 0.91, blue: 0.83)
        case .eyeProtection: return Color(red: 0.75, green: 0.84, blue: 0.71)
        case .custom: return .white
        }
    }
    
    var textColor: Color {
        switch theme {
        case .light: return .black
        case .dark: return .white
        case .sepia: return Color(red: 0.33, green: 0.28, blue: 0.22)
        case .eyeProtection: return .black
        case .custom: return .black
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            Text("预览文本")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            Text("""
            这是阅读效果预览。您可以根据个人喜好调整字体大小、行距、段距等参数，以获得最佳的阅读体验。
            
            点击屏幕左侧可返回上一章，点击右侧可进入下一章。点击屏幕中央可显示或隐藏菜单。
            """)
            .font(.system(size: fontSize))
            .foregroundColor(textColor)
            .lineSpacing(lineSpacing)
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        ReaderSettingsFullView()
    }
}
