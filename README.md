# Legado iOS

📚 基于 Legado 的 iOS 原生阅读应用

[![iOS CI](https://github.com/chrn11/legado-ios/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/chrn11/legado-ios/actions/workflows/ios-ci.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2016.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## ✨ 特性

- 📖 **书源管理** - 支持自定义书源规则，导入/导出书源
- 🔍 **聚合搜索** - 多书源并发搜索，快速找书
- 📱 **书架管理** - 网格/列表视图，分组管理，进度追踪
- 📖 **阅读器** - 舒适阅读体验，支持多种主题和翻页模式
- 🎯 **规则引擎** - 支持 CSS/XPath/JSONPath/正则/JavaScript
- 💾 **本地书籍** - 支持 TXT/EPUB 格式
- 🔄 **替换净化** - 广告替换，内容净化

## 📋 项目结构

```
Legado-iOS/
├── App/                      # 应用入口
├── Core/                     # 核心模块
│   ├── Persistence/         # CoreData 持久化
│   ├── Network/             # 网络请求
│   └── RuleEngine/          # 规则解析引擎 ⭐
├── Features/                 # 功能模块
│   ├── Bookshelf/           # 书架
│   ├── Reader/              # 阅读器
│   ├── Search/              # 搜索
│   ├── Source/              # 书源管理
│   └── Config/              # 设置
└── UIComponents/            # 通用 UI 组件
```

## 🚀 快速开始

### 环境要求

- Xcode 15.0+
- iOS 16.0+
- Swift 5.10+
- macOS 13+ (编译需要)

### 安装依赖

```bash
cd Legado-iOS
xcodebuild -resolvePackageDependencies -scheme Legado
```

### 运行项目

1. 在 Xcode 中打开 `Legado.xcodeproj`
2. 选择目标设备（真机或模拟器）
3. 点击运行（⌘R）

### GitHub Actions 编译

项目在以下情况会自动编译：
- Push 到 main/develop 分支
- 创建 Pull Request
- 手动触发 workflow

编译产物会上传到 Actions Artifacts，可以在 [Actions](https://github.com/chrn11/legado-ios/actions) 页面下载。

## 📖 书源规则

### 支持的选择器类型

- **CSS 选择器**: `div.book@text`, `a@href`
- **XPath**: `//div[@class='book']`
- **JSONPath**: `$.book.name`, `$.list[0].title`
- **正则**: `regex:\d+`
- **JavaScript**: `{{js result + ' suffix'}}`

### 书源导入格式

```json
{
  "bookSourceUrl": "https://example.com",
  "bookSourceName": "示例书源",
  "bookSourceGroup": "分组",
  "bookSourceType": 0,
  "searchUrl": "https://example.com/search?keyword={{key}}",
  "ruleSearch": {
    "bookList": "div.book-item",
    "name": "h2@text",
    "author": "span.author@text",
    "bookUrl": "a@href"
  },
  "ruleContent": {
    "content": "div.content@html"
  }
}
```

## 🛠 开发计划

### M0 - 基础架构 (已完成 ✅)
- [x] 项目骨架
- [x] CoreData Stack
- [x] 网络层
- [x] 规则引擎 V1

### M1 - 书源与搜索 (已完成 ✅)
- [x] 书源管理界面
- [x] 书源 CRUD
- [x] 搜索功能
- [x] 书籍详情

### M2 - 阅读主链路 (已完成 ✅)
- [x] 目录解析
- [x] 阅读器
- [x] 书架管理

### M3 - 替换规则 (已完成 ✅)
- [x] ReplaceEngine
- [x] ReplaceRule CoreData 实体
- [x] 规则调试工具

### M4 - 本地书籍 (已完成 ✅)
- [x] TXT 解析
- [x] EPUB 支持
- [x] 项目骨架
- [x] CoreData Stack
- [x] 网络层
- [x] 规则引擎 V1

### M1 - 书源与搜索 (进行中 🚧)
- [x] 书源管理界面
- [x] 书源 CRUD
- [ ] 搜索功能
- [ ] 书籍详情

### M2 - 阅读主链路 (计划中 📅)
- [ ] 目录解析
- [ ] 阅读器
- [ ] 书架管理

### M3 - 替换规则 (计划中 📅)
- [ ] ReplaceEngine
- [ ] 规则调试

### M4 - 本地书籍 (计划中 📅)
- [ ] TXT 解析
- [ ] EPUB 支持

## 📸 截图

待更新...

## 🔧 技术栈

- **UI**: SwiftUI + UIKit
- **架构**: MVVM + Clean Architecture
- **数据库**: CoreData
- **网络**: URLSession
- **HTML 解析**: SwiftSoup
- **XPath**: Kanna
- **JS 引擎**: JavaScriptCore

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

本项目遵循 GPL-3.0 协议。

## 🔗 链接

- [原项目 (Android)](https://github.com/gedoor/legado)
- [帮助文档](https://www.legado.top/)
- [书源规则教程](https://mgz0227.github.io/The-tutorial-of-Legado/)

## ⚠️ 免责声明

本应用仅供学习交流使用，请勿用于商业目的。
使用本应用时请遵守相关法律法规，尊重版权。
