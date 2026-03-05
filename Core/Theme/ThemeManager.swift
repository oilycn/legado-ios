//
//  ThemeManager.swift
//  Legado-iOS
//
//  主题管理器 - Phase 8
//

import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .default
    @Published var followSystem: Bool = true
    @Published var customColors: CustomColors?
    
    struct AppTheme {
        let name: String
        let backgroundColor: Color
        let textColor: Color
        let accentColor: Color
        let secondaryBackground: Color
        
        static let `default` = AppTheme(name: "默认白", backgroundColor: .white, textColor: .black, accentColor: .blue, secondaryBackground: Color(.systemGray6))
        static let dark = AppTheme(name: "夜间黑", backgroundColor: Color(hex: "#1a1a1a") ?? .black, textColor: .white, accentColor: .blue, secondaryBackground: Color(hex: "#2a2a2a") ?? .gray)
        static let sepia = AppTheme(name: "护眼黄", backgroundColor: Color(hex: "#F5F0E6") ?? .white, textColor: Color(hex: "#3D3D3D") ?? .black, accentColor: .brown, secondaryBackground: Color(hex: "#EBE6DC") ?? .gray)
        static let green = AppTheme(name: "护眼绿", backgroundColor: Color(hex: "#D9F2D9") ?? .white, textColor: Color(hex: "#2D4A2D") ?? .black, accentColor: .green, secondaryBackground: Color(hex: "#C9E2C9") ?? .gray)
    }
    
    struct CustomColors {
        var backgroundColor: Color = .white
        var textColor: Color = .black
        var accentColor: Color = .blue
    }
    
    private init() {
        loadTheme()
        observeSystemTheme()
    }
    
    private func loadTheme() {
        if let themeName = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme.preset(named: themeName) {
            currentTheme = theme
        }
        followSystem = UserDefaults.standard.bool(forKey: "followSystemTheme")
    }
    
    private func observeSystemTheme() {
        // 监听系统主题变化
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.name, forKey: "selectedTheme")
    }
    
    func setCustomColors(_ colors: CustomColors) {
        customColors = colors
        currentTheme = AppTheme(name: "自定义", backgroundColor: colors.backgroundColor, textColor: colors.textColor, accentColor: colors.accentColor, secondaryBackground: colors.backgroundColor)
    }
    
    func toggleFollowSystem() {
        followSystem.toggle()
        UserDefaults.standard.set(followSystem, forKey: "followSystemTheme")
    }
}

extension ThemeManager.AppTheme {
    static func preset(named: String) -> ThemeManager.AppTheme? {
        switch named {
        case "默认白": return .default
        case "夜间黑": return .dark
        case "护眼黄": return .sepia
        case "护眼绿": return .green
        default: return nil
        }
    }
}