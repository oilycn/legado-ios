# Legado iOS 一比一移植计划

## 项目状态概览

### ✅ 已完成 (Core Infrastructure)
- [x] 项目架构 (SwiftUI + CoreData)
- [x] CoreData 模型 (Book, BookSource, BookChapter, Bookmark, ReplaceRule)
- [x] 书源管理 (导入/导出/legado://协议/二维码)
- [x] 阅读器核心 (分页/进度跟踪/章节缓存)
- [x] 搜索流程 (搜索→加入书架→详情→阅读)
- [x] 备份恢复 (JSON导出/导入)

### 🚧 进行中 (High Priority)
- [ ] TTS 语音朗读
- [ ] 本地书籍导入 (TXT/EPUB)
- [ ] 自动翻页
- [ ] WebDAV 同步

### 📋 待实现 (Medium Priority)
- [ ] 替换规则引擎完整实现
- [ ] 阅读统计
- [ ] 书架分组
- [ ] 主题系统完善

### 🔮 未来功能 (Low Priority)
- [ ] iCloud 同步
- [ ] 小组件
- [ ] Siri 快捷指令
- [ ] VoiceOver 无障碍支持

---

## 阶段一：TTS 语音朗读系统

### 功能需求 (对标 Android Legado)
1. **基础朗读**：使用 AVSpeechSynthesizer 朗读章节内容
2. **语速控制**：0.5x - 2.0x 调速
3. **音色选择**：系统语音 / 在线 TTS (如果支持)
4. **朗读范围**：当前页/当前章/全文
5. **后台播放**：支持锁屏继续朗读
6. **音频控制**：播放/暂停/快进/后退
7. **定时停止**：设定时间后自动停止

### 实现文件
- `Core/TTS/TTSManager.swift` - 核心管理器
- `Features/Reader/TTSControlsView.swift` - 控制面板
- `Features/Reader/TTSService.swift` - 后台服务

---

## 阶段二：本地书籍导入

### 功能需求
1. **文件选择**：支持 .txt, .epub 文件
2. **TXT 解析**：
   - 自动章节识别 (正则匹配 "第X章" 等)
   - 编码检测 (UTF-8/GBK/GB2312)
   - 分章节存储到 CoreData
3. **EPUB 解析**：
   - 解压 EPUB (ZIP格式)
   - 解析 OPF 文件获取元数据
   - 提取章节内容 (HTML→纯文本)
4. **封面提取**：从 EPUB 或自动生成

### 实现文件
- `Core/Parser/TXTParser.swift` - TXT解析器
- `Core/Parser/EPUBParser.swift` - EPUB解析器
- `Core/Parser/EncodingDetector.swift` - 编码检测
- `Features/Bookshelf/LocalBookImportView.swift` - 导入界面

---

## 阶段三：自动翻页

### 功能需求
1. **时间设置**：5秒 - 60秒可调
2. **智能模式**：根据字数计算时间
3. **章节连续**：自动进入下一章
4. **手势暂停**：点击屏幕暂停

### 实现文件
- `Features/Reader/AutoPageTurnManager.swift` - 计时管理
- `Features/Reader/AutoPageTurnControlsView.swift` - 控制面板

---

## 阶段四：WebDAV 同步

### 功能需求
1. **配置**：服务器地址/账号/密码
2. **上传**：备份到 WebDAV
3. **下载**：从 WebDAV 恢复
4. **自动同步**：设置同步频率
5. **冲突处理**：本地/云端版本比较

### 实现文件
- `Core/Sync/WebDAVManager.swift` - WebDAV 客户端
- `Core/Sync/WebDAVConfigView.swift` - 配置界面
- `Core/Sync/SyncService.swift` - 同步服务

---

## 技术栈

### 核心框架
- **UI**: SwiftUI (iOS 16+)
- **数据**: CoreData (本地存储)
- **网络**: URLSession + 自定义解析
- **语音**: AVFoundation (AVSpeechSynthesizer)
- **文件**: FileManager + ZIPFoundation (EPUB)

### 第三方依赖 (建议)
```swift
// Package.swift 或 SPM
- ZIPFoundation  // EPUB解压
- SwiftSoup      // HTML解析 (已使用)
- GRDB           // 高性能 SQLite (可选)
```

---

## 下一步行动

现在开始 **阶段一：TTS 语音朗读系统**
