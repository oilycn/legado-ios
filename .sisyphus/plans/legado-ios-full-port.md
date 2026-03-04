# Legado iOS 全量移植计划

> **版本**: v1.0 | **日期**: 2026-03-04 | **作者**: Prometheus  
> **目标**: 将 Android Legado 全部功能 1:1 移植到 iOS 原生（SwiftUI + CoreData）  
> **执行者**: AI Agent (gpt5.2) | **预估总工期**: 130-170 人天  
> **项目路径**: `D:/soft/legado-ios/`

---

## 前置条件（阻断性）

| # | 条件 | 说明 |
|---|---|---|
| 1 | Apple Developer 账号 | Share Extension (T7.1) 需要 App Group entitlement |
| 2 | GitHub Actions CI | `ios-ci.yml` workflow 可用，每 Phase 结束必须触发 |
| 3 | Xcode 15+ | macOS 编译环境（CI 或本地） |
| 4 | CocoaPods/SPM | Readium 集成 (T7.6) 需要包管理器 |

---

## 架构决策（已锁定）

| 决策项 | 选择 | 理由 |
|---|---|---|
| 持久化 | CoreData（非 SwiftData） | 已有 20 个实体定义，iOS 16+ 兼容 |
| 最低版本 | iOS 16.0 | 现有代码基线 |
| UI 框架 | SwiftUI + MVVM | 现有架构 |
| 主键策略 | UUID 内部主键 + bookUrl 唯一约束去重 | 兼容已有代码，同步时以 bookUrl 匹配 |
| EPUB | 集成 Readium Swift Toolkit 3.5.0+ | 生产级，3-5 天集成，比自实现节省 10 天 |
| "1:1 移植" 定义 | 功能等价 + iOS 降级文档化 | iOS 后台限制等不可能完全一致的场景有降级方案 |

---

## 全局防护措施（MUST NOT）

```
MUST NOT: 实现 CarPlay / Widget / Siri 快捷指令 / Apple Watch 适配（v1 排除）
MUST NOT: 在漫画阅读中实现双页/横屏模式（v1 仅竖屏单页）
MUST NOT: 在主题系统中实现自定义字体下载功能
MUST NOT: 在 Web 服务器中实现用户认证/HTTPS/后台运行
MUST NOT: 在规则引擎中添加 Android 没有的新规则类型
MUST NOT: 在任何 Phase 中"顺便优化" Gap 列表外的已有功能
MUST NOT: 把 ReadConfig 从 JSON Data 重构为独立 CoreData entity
MUST NOT: 使用 as any / @ts-ignore 等类型逃逸
MUST NOT: 验收标准使用"用户手动确认"/"目测正常"
MUST NOT: 在 Phase 0 完成并通过 CI 前开始任何其他 Phase
```

---

## iOS 降级方案（与 Android 差异）

| Android 功能 | iOS 限制 | 降级方案 |
|---|---|---|
| WebService 后台 HTTP 服务器 | iOS 无持久后台服务 | 仅前台运行，进入后台时停止并通知用户 |
| DownloadService 持续下载 | iOS ForegroundService 不存在 | URLSession.background，系统调度下载时间 |
| CheckSourceService 后台检查 | iOS BGTask 最多 30s | 改为纯前台操作 + 进度 HUD |
| CacheBookService 后台缓存 | 同上 | BGProcessingTask（有限后台）+ 前台模式 |
| BroadcastReceiver 全局媒体键 | iOS 无全局广播 | MPRemoteCommandCenter（仅音频会话活跃时） |
| ContentProvider 跨 App 数据 | 仅 App Group 内 | Share Extension + App Group 共享容器 |

---

## 代码模式参考（执行者必须遵循）

### CoreData 实体模式
参照 `Core/Persistence/Book+CoreDataClass.swift`:
```
// 文件名: {EntityName}+CoreDataClass.swift
// 位置: Core/Persistence/
// 内容: @objc(EntityName) + fetchRequest() + 计算属性 + create() 工厂方法
```

### View 模式
参照 `Features/Reader/ReaderView.swift`:
```
// @StateObject var viewModel = XxxViewModel()
// @State 管理 UI 状态
// ZStack 层叠布局 + .overlay 弹窗
// .task { await viewModel.load() }
```

### ViewModel 模式
参照 `Features/Reader/ReaderViewModel.swift`:
```
// @MainActor class XxxViewModel: ObservableObject
// @Published 管理状态
// async/await 异步操作
// Task {} 管理生命周期
```

---

## Phase 0: 基础对齐（阻断性）

> **目标**: 修复 CoreData 模型严重缺陷，确保项目可编译运行  
> **预估**: 12-15 人天  
> **Gate**: CI 绿灯 + 20 实体 fetchRequest 测试全通过后才可进入 Phase 1

### T0.1: xcdatamodeld 全实体注册

- **Gap**: CoreData 模型文件 (xcdatamodeld) 当前只有 5 个实体，但项目有 20 个实体的 Swift 文件
- **描述**: 将缺失的 15 个实体注册到 `Legado.xcdatamodeld/Legado.xcdatamodel/contents` XML 文件中
- **依赖**: 无
- **输入**:
  - `Core/Persistence/Legado.xcdatamodeld/Legado.xcdatamodel/contents`（当前 5 实体）
  - 15 个已有 Swift 实体文件: `BookGroup`, `SearchBook`, `SearchKeyword`, `RssSource`, `RssArticle`, `RssReadRecord`, `RssStar`, `CacheEntry`, `Cookie`, `ReadRecord`, `BookProgress`, `HttpTTS`, `DictRule`, `RuleSub`, `TxtTocRule`
  - Android 参考: `app/src/main/java/io/legado/app/data/entities/`
- **输出**: 更新后的 `contents` XML 文件，包含全部 20 个实体定义
- **MUST HAVE**:
  - 全部 20 个实体在 xcdatamodeld 中注册
  - 每个实体的属性类型与对应 Swift 文件一致
  - 实体间关系 (inverse relationships) 正确定义：Book↔BookChapter, Book↔Bookmark, BookSource↔Book
  - Lightweight Migration 支持（添加新实体不需要 mapping model，但需确保 `NSPersistentContainer` 配置了 `NSMigratePersistentStoresAutomaticallyOption`）
- **MUST NOT HAVE**:
  - 修改已有 5 个实体的属性名或类型（避免 migration 问题）
  - 在 Swift 代码中使用强制解包 `NSEntityDescription.entity(forEntityName:)!`
- **BOUNDARY**: 不修改任何 View/ViewModel 文件
- **验收标准**:
  - `grep -c '<entity name=' contents` 输出 == 20
  - XML 格式合法（无未闭合标签、无重复 entity name）
  - CI 编译通过
- **预估**: 3-4 人天
- **QA 场景**:
  - 所有 20 个实体 `NSEntityDescription.entity(forEntityName:, in:)` 返回非 nil
  - CoreDataStack 初始化不崩溃
  - 已有数据（5 实体）不丢失（Lightweight Migration）

### T0.2: 主键策略实施

- **Gap**: iOS Book 用 UUID 主键，Android 用 bookUrl String 主键，导致同步不兼容
- **描述**: 保持 UUID 作为 CoreData 内部主键，增加 bookUrl 唯一约束，实现去重逻辑
- **依赖**: T0.1
- **输入**:
  - `Core/Persistence/Book+CoreDataClass.swift`
  - Android `data/entities/Book.kt` — `@PrimaryKey var bookUrl: String`
- **输出**:
  - 更新 `Book+CoreDataClass.swift`: 添加 `bookUrl` 唯一约束检查
  - 新增 `Core/Persistence/BookDeduplicator.swift`: 基于 bookUrl 的去重工具
- **MUST HAVE**:
  - `bookUrl` 在 xcdatamodeld 中标记为 indexed
  - `BookDeduplicator.deduplicateOnImport(books:context:)` 方法：导入时以 bookUrl 为匹配键，已存在则更新，不存在则创建（UUID 自动生成）
  - WebDAV 同步/备份恢复时使用 bookUrl（而非 UUID）匹配
- **MUST NOT HAVE**:
  - 移除 UUID 字段
  - 修改现有代码中通过 UUID 查询 Book 的逻辑
- **BOUNDARY**: 不修改 WebDAVSyncManager.swift 的同步协议（仅修改匹配逻辑）
- **验收标准**:
  - 导入同一 bookUrl 的书籍两次，CoreData 中只有 1 条记录
  - UUID 不同、bookUrl 相同的记录被正确合并
  - 已有书籍（UUID 主键）不受影响
- **预估**: 2-3 人天
- **QA 场景**:
  - 导入 Android 备份 JSON（bookUrl 主键）→ iOS 正确创建 UUID + bookUrl
  - 再次导入同一备份 → 更新已有记录而非创建重复
  - bookUrl 为 nil/空字符串的边界处理

### T0.3: App Group 预配

- **Gap**: Phase 7 的 Share Extension 需要共享 CoreData 容器，必须 Phase 0 预配
- **描述**: 配置 App Group container，为后续 Share Extension 铺路
- **依赖**: T0.1
- **输入**:
  - `Core/Persistence/CoreDataStack.swift`
  - 项目 `.entitlements` 文件
- **输出**:
  - 更新/新增 `Legado.entitlements`: 添加 `group.com.legado.ios` App Group
  - 更新 `CoreDataStack.swift`: `NSPersistentContainer` 的 store URL 改为 App Group 共享目录
- **MUST HAVE**:
  - App Group ID: `group.com.legado.ios`（需与 Apple Developer Portal 一致）
  - `CoreDataStack` 的 `persistentContainer` store 位置从 App 私有目录改为 `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`
  - 旧数据自动迁移到新位置（首次启动时检测）
- **MUST NOT HAVE**:
  - 破坏现有 CoreData 初始化流程
  - 硬编码 App Group ID（使用常量）
- **BOUNDARY**: 不创建 Extension target（Phase 7 做）
- **验收标准**:
  - `CoreDataStack` 初始化成功，store 文件位于 App Group 共享目录
  - 旧数据迁移测试：模拟旧 store → 新 store 自动迁移
  - CI 编译通过
- **预估**: 2 人天
- **QA 场景**:
  - 全新安装 → 直接在 App Group 目录创建 store
  - 升级安装（已有数据）→ 自动迁移到 App Group 目录
  - App Group 不可用时的降级（fallback 到私有目录）

### T0.4: 项目清理与文档归档

- **Gap**: 项目中有多份矛盾的计划文档，`project.pbxproj` 可能有僵尸文件
- **描述**: 归档旧文档，验证所有 Swift 文件在 Xcode target 中
- **依赖**: 无
- **输入**:
  - `PORTING_PLAN.md`、`IMPLEMENTATION_PLAN.md`、`COREDATA-ISSUES-SUMMARY.txt`、`CoreData-Analysis-Report.md`
  - `legado-ios.xcodeproj/project.pbxproj`
- **输出**:
  - 新建 `docs/archive/` 目录，移入旧文档
  - 验证报告：列出所有在文件系统但不在 pbxproj 中的 Swift 文件
- **MUST HAVE**:
  - `PORTING_PLAN.md` → `docs/archive/PORTING_PLAN.md`
  - `IMPLEMENTATION_PLAN.md` → `docs/archive/IMPLEMENTATION_PLAN.md`
  - `COREDATA-ISSUES-SUMMARY.txt` → `docs/archive/`
  - `CoreData-Analysis-Report.md` → `docs/archive/`
  - 检查 `project.pbxproj` 中是否引用了所有 ~100 个 Swift 文件
  - 缺失的文件添加到 target
- **MUST NOT HAVE**:
  - 删除任何文件（只移动）
  - 修改 `README.md`（用户可能有自定义内容）
- **验收标准**:
  - `docs/archive/` 包含 4 个旧文档
  - 项目根目录不再有 `PORTING_PLAN.md` 等文件
  - 所有 `.swift` 文件在 `project.pbxproj` 的 target 中有引用
- **预估**: 1-2 人天
- **QA 场景**:
  - 归档后 CI 编译不受影响
  - 新文件添加到 target 后无命名冲突

### T0.5: CoreData 运行时验证测试

- **Gap**: 现有 10 个测试文件未覆盖新注册的 15 个实体
- **描述**: 创建全面的 CoreData 实体运行时验证测试
- **依赖**: T0.1, T0.2
- **输入**:
  - `Tests/Unit/CoreDataStackTests.swift`（已有）
  - 全部 20 个实体的 Swift 文件
- **输出**:
  - 更新 `Tests/Unit/CoreDataStackTests.swift`: 添加 20 实体 fetchRequest 测试
  - 新增 `Tests/Unit/BookDeduplicatorTests.swift`: 去重逻辑测试
- **MUST HAVE**:
  - 测试覆盖全部 20 个实体的 `NSEntityDescription.entity(forEntityName:, in:)` 非 nil
  - 测试每个实体的 `fetchRequest()` 可执行
  - 测试 `BookDeduplicator` 的导入去重
  - 测试 Lightweight Migration（从 5 实体 → 20 实体）
- **验收标准**:
  - CI 中 `xcodebuild test` 全部通过
  - 0 个测试失败
- **预估**: 2-3 人天
- **QA 场景**:
  - 每个实体 CRUD 操作正常
  - 关系（Book↔Chapter, Book↔Bookmark）正确建立
  - 并发 context 操作不崩溃

### T0.6: CI 编译验证 Gate

- **Gap**: 必须确认 Phase 0 所有改动编译通过才能继续
- **描述**: 触发 CI，确认编译 + 测试全通过
- **依赖**: T0.1, T0.2, T0.3, T0.4, T0.5
- **输入**: Phase 0 全部改动
- **输出**: CI 绿灯截图/日志
- **MUST HAVE**:
  - `gh run list --workflow=ios-ci.yml --limit 1 --json conclusion` 输出 `success`
  - 0 个编译错误，0 个测试失败
  - 如有 warning，记录但不阻断
- **验收标准**: CI conclusion == "success"
- **预估**: 0.5 人天（等待 + 修复可能的问题）

---

## Phase 1: 阅读器核心增强

> **目标**: 补全阅读器内的缺失交互功能  
> **预估**: 15-20 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯 + 所有新增 View 可正常展示

### T1.1: 换源对话框

- **Gap**: #3 — ChangeBookSourceDialog / ChangeChapterSourceDialog
- **描述**: 阅读中长按可切换书源/章节源，列出可用源并显示当前源标记
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/changesource/ChangeBookSourceDialog.kt`
  - Android `ui/book/changesource/ChangeChapterSourceDialog.kt`
  - iOS `Features/Reader/ReaderView.swift`, `Features/Reader/ReaderViewModel.swift`
  - iOS `Core/Persistence/BookSource+CoreDataClass.swift`
- **输出**:
  - 新增 `Features/Reader/Components/ChangeSourceSheet.swift`: 换源底部 Sheet
  - 新增 `Features/Reader/Components/ChangeSourceViewModel.swift`: 换源逻辑
- **MUST HAVE**:
  - 底部 Sheet 展示所有包含当前书的书源列表
  - 每个源显示: 源名称、最新章节、响应速度标签
  - 当前源高亮标记
  - 点击切换源 → 重新加载当前章节内容
  - 章节源切换: 同一章节从不同源获取内容
  - 加载状态指示器
  - 并发搜索多个源（复用 SearchOptimizer）
- **MUST NOT HAVE**:
  - 源的编辑/删除功能（已有 SourceManageView）
  - 自动切换源（仅手动）
- **BOUNDARY**: 不修改 `SourceManageView.swift`
- **验收标准**:
  - ReaderView 中长按触发换源 Sheet
  - 选择新源后 3s 内加载新内容
  - 网络异常时显示错误提示
- **预估**: 3-4 人天
- **QA 场景**:
  - 仅 1 个源可用 → 显示"无其他可用源"
  - 切换源失败 → 保持当前源不变
  - 切换源后翻页 → 使用新源加载后续章节

### T1.2: 文本选择操作菜单

- **Gap**: #9 — TextActionMenu
- **描述**: 阅读器中选中文本后弹出操作菜单
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/read/TextActionMenu.kt`
  - iOS `Features/Reader/ReaderView.swift`
- **输出**:
  - 新增 `Features/Reader/Components/TextActionMenu.swift`
- **MUST HAVE**:
  - 长按选中文本 → 弹出浮动菜单
  - 菜单项: 复制、添加书签、替换规则、搜索（书内）、搜索（全网）、字典查询
  - 复制: 复制到系统剪贴板
  - 添加书签: 创建 Bookmark 实体，关联当前章节 + 选中位置
  - 替换规则: 快速创建 ReplaceRule（选中文本作为 pattern）
  - 搜索书内: 跳转 SearchContentView（T4.1，如未实现则禁用此项）
  - 搜索全网: 使用 Safari/WKWebView 搜索选中文本
  - 字典: 调用 `UIReferenceLibraryViewController` 查询
- **MUST NOT HAVE**:
  - 翻译功能（v1 排除）
  - 朗读选中文本（已有 TTS 全文朗读）
- **验收标准**:
  - 选中文本后 200ms 内弹出菜单
  - 每个菜单项功能正常
  - 点击菜单外区域关闭菜单
- **预估**: 3 人天
- **QA 场景**:
  - 选中单词 vs 选中段落 → 菜单位置自适应
  - 页面边缘选中 → 菜单不超出屏幕
  - 字典不可用时 → 菜单项灰显

### T1.3: ReadMenu 顶部/底部栏增强

- **Gap**: #6 — ReadMenu overlays
- **描述**: 阅读器点击中央区域弹出的控制覆盖层
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/read/ReadMenu.kt`
  - Android `ui/book/read/config/` 目录
  - iOS `Features/Reader/ReaderView.swift`（已有基础 overlay）
- **输出**:
  - 新增 `Features/Reader/Components/ReadMenuOverlay.swift`: 顶部栏 + 底部栏
  - 新增 `Features/Reader/Components/BrightnessSlider.swift`: 亮度控制
  - 新增 `Features/Reader/Components/ChapterProgressBar.swift`: 章节进度条
- **MUST HAVE**:
  - **顶部栏**: 返回按钮、书名、换源按钮（→T1.1）、更多菜单
  - **底部栏**: 上一章 | 进度滑块 | 下一章 | 目录 | 亮度 | 设置 | 朗读
  - **亮度滑块**: 调节屏幕亮度 (`UIScreen.main.brightness`)
  - **进度滑块**: 拖动跳转到指定进度百分比
  - 点击中央区域 toggle 显示/隐藏（带动画）
  - 自动隐藏: 5s 无操作后自动收起
  - 状态栏跟随 overlay 显示/隐藏
- **MUST NOT HAVE**:
  - 语音速度控制（在 ReadAloudDialog 中，T1.4）
  - 背景色选择（在 ReadStyleDialog 中，T1.4）
- **BOUNDARY**: 不修改 `PagedReaderView.swift` 的翻页逻辑
- **验收标准**:
  - 点击中央区域 overlay 出现/消失，动画流畅
  - 亮度滑块实时调节系统亮度
  - 进度条拖动跳转到正确位置
  - 5s 自动隐藏
- **预估**: 3-4 人天
- **QA 场景**:
  - 进度条拖到 0% → 跳转第一章
  - 进度条拖到 100% → 跳转最后一章
  - 快速连续点击 → 不出现闪烁

### T1.4: 阅读器配置弹窗集合

- **Gap**: #10 — BgTextConfigDialog, TipConfigDialog, MoreConfigDialog, ReadStyleDialog, AutoReadDialog, ReadAloudDialog
- **描述**: 阅读器设置面板中的 6 个配置弹窗
- **依赖**: T1.3
- **输入**:
  - Android `ui/book/read/config/BgTextConfigDialog.kt` — 背景色/文字色
  - Android `ui/book/read/config/TipConfigDialog.kt` — 顶部/底部信息栏配置
  - Android `ui/book/read/config/MoreConfigDialog.kt` — 更多设置
  - Android `ui/book/read/config/ReadStyleDialog.kt` — 阅读样式（字体、间距）
  - Android `ui/book/read/config/AutoReadDialog.kt` — 自动翻页设置
  - Android `ui/book/read/config/ReadAloudDialog.kt` — 语音朗读控制
  - iOS `Features/Reader/ReaderView.swift`
- **输出**:
  - 新增 `Features/Reader/Config/BgTextConfigSheet.swift`
  - 新增 `Features/Reader/Config/TipConfigSheet.swift`
  - 新增 `Features/Reader/Config/MoreConfigSheet.swift`
  - 新增 `Features/Reader/Config/ReadStyleSheet.swift`
  - 新增 `Features/Reader/Config/AutoReadSheet.swift`
  - 新增 `Features/Reader/Config/ReadAloudSheet.swift`
- **MUST HAVE**:
  - **BgTextConfigSheet**: 预设背景色 (白/黄/绿/蓝/黑) + 自定义颜色选择器 + 文字颜色 + 背景图片选择
  - **TipConfigSheet**: 配置顶部/底部信息栏显示项（电量、时间、页码、章节名、进度百分比），开关各项显示
  - **MoreConfigSheet**: 翻页动画选择（已有 5 种）、点击翻页区域配置、页面边距调整、保持屏幕常亮开关
  - **ReadStyleSheet**: 字号调节 (Stepper) + 行间距 + 段间距 + 字间距 + 字体选择（系统字体列表）
  - **AutoReadSheet**: 自动翻页速度调节、滚动模式 vs 翻页模式、开始/暂停控制
  - **ReadAloudSheet**: TTS 播放/暂停/停止、语速调节、音色选择（AVSpeechSynthesisVoice）、定时停止
  - 所有配置实时预览（修改后阅读页面立即更新）
  - 配置持久化到 UserDefaults（使用 `@AppStorage`）
- **MUST NOT HAVE**:
  - 自定义字体下载/导入
  - 自定义 TTS 引擎（仅用系统 AVSpeechSynthesizer + 已有 HttpTTS）
- **验收标准**:
  - 6 个弹窗均可从 ReadMenu 底部栏访问
  - 配置修改实时反映在阅读界面
  - 退出阅读器重新进入 → 配置保持
- **预估**: 5-6 人天
- **QA 场景**:
  - 极小字号 (8pt) / 极大字号 (48pt) → 布局不崩溃
  - 黑色背景 + 白色文字 → 状态栏也变白
  - 自动翻页速度极快 → 不卡顿

### T1.5: 章节内容编辑

- **Gap**: #7 — ContentEditDialog
- **描述**: 阅读中可编辑当前章节文本内容
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/read/ContentEditDialog.kt`
  - iOS `Features/Reader/ReaderViewModel.swift`
- **输出**:
  - 新增 `Features/Reader/Components/ContentEditSheet.swift`
- **MUST HAVE**:
  - 全屏 TextEditor 显示当前章节纯文本内容
  - 编辑后保存到 BookChapter 缓存
  - 保存后刷新阅读页面
  - 取消编辑（不保存）
  - 重置（恢复原始内容，从源重新获取）
- **MUST NOT HAVE**:
  - 富文本编辑
  - 编辑历史/撤销栈
- **验收标准**:
  - 编辑内容保存后立即在阅读界面显示
  - 重置后恢复原始内容
  - 大章节 (>50KB 文本) 编辑不卡顿
- **预估**: 1-2 人天
- **QA 场景**:
  - 编辑后切换章节再切回 → 编辑内容保持
  - 编辑后换源 → 新源内容覆盖编辑内容（提示用户）

### T1.6: 有效替换规则显示

- **Gap**: #8 — EffectiveReplacesDialog
- **描述**: 显示当前生效的所有替换规则列表
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/read/EffectiveReplacesDialog.kt`
  - iOS `Features/Config/ReplaceRuleView.swift`（已有）
  - iOS `Core/RuleEngine/ReplaceEngine.swift`
- **输出**:
  - 新增 `Features/Reader/Components/EffectiveReplacesSheet.swift`
- **MUST HAVE**:
  - 列出当前书籍生效的所有替换规则（全局 + 书源特定）
  - 每条规则显示: 规则名、模式(pattern)、替换值(replacement)、范围(scope)
  - 可临时禁用/启用单条规则（不影响全局设置）
  - 规则排序与执行顺序一致
- **MUST NOT HAVE**:
  - 规则编辑（跳转 ReplaceRuleView）
  - 规则创建
- **验收标准**:
  - 显示的规则列表与实际应用的规则一致
  - 临时禁用规则后刷新页面 → 内容变化
  - 退出阅读器 → 临时禁用状态重置
- **预估**: 1 人天
- **QA 场景**:
  - 无规则生效 → 显示"暂无生效规则"
  - 规则冲突（多条规则匹配同一文本）→ 按排序顺序显示

### Phase 1 验证 Gate

- 触发 CI: `gh workflow run ios-ci.yml`
- 验证: conclusion == "success"
- 手动验证清单:
  - [ ] 换源弹窗可正常切换
  - [ ] 文本选择菜单所有项可点击
  - [ ] ReadMenu 覆盖层显示/隐藏正常
  - [ ] 6 个配置弹窗均可打开且配置生效
  - [ ] 内容编辑保存/重置正常
  - [ ] 替换规则列表显示正确

---

## Phase 2: 音频播放 + 漫画阅读

> **目标**: 实现两种全新阅读模式（音频 type=1、漫画 type=2）  
> **预估**: 18-25 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯 + 音频/漫画各自可播放/阅读

### T2.1: 音频书播放器

- **Gap**: #1 — AudioPlayActivity
- **描述**: 支持 bookSourceType==1 的音频书源，完整的音频播放界面
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/audio/AudioPlayActivity.kt`
  - Android `service/AudioPlayService.kt`
  - iOS `Core/TTS/TTSManager.swift`（参考，但音频播放不同于 TTS）
- **输出**:
  - 新增 `Features/AudioPlayer/AudioPlayerView.swift`: 播放界面
  - 新增 `Features/AudioPlayer/AudioPlayerViewModel.swift`: 播放逻辑
  - 新增 `Core/Audio/AudioPlayManager.swift`: AVPlayer 管理器
- **MUST HAVE**:
  - **播放界面**: 封面图 + 书名 + 章节名 + 进度条 + 播放/暂停按钮 + 上一章/下一章 + 播放速度 (0.5x-3.0x) + 定时停止 (15/30/60/90 分钟 + 本章结束)
  - **后台播放**: `AVAudioSession.Category.playback` + `Info.plist` 添加 `UIBackgroundModes: audio`
  - **锁屏控制**: `MPNowPlayingInfoCenter` 显示书名/作者/封面 + `MPRemoteCommandCenter` 响应播放/暂停/上一曲/下一曲
  - **章节管理**: 自动播放下一章、章节列表快速跳转
  - **播放状态持久化**: 退出后记住上次播放位置（durChapterPos）
  - **音频 URL 获取**: 通过 BookSource 规则获取章节音频 URL → AVPlayer 播放
- **MUST NOT HAVE**:
  - 均衡器/音效
  - 播放列表（跨书籍）
  - 离线下载音频（Phase 6 DownloadManager 处理）
  - CarPlay 适配
- **BOUNDARY**: 不修改 `TTSManager.swift`（TTS 和音频播放是不同功能）
- **验收标准**:
  - type==1 书源的书籍打开时自动进入音频播放界面
  - 音频播放/暂停/切章正常
  - 进入后台继续播放
  - 锁屏控制可用
  - 定时停止到时间自动暂停
- **预估**: 8-10 人天
- **QA 场景**:
  - 音频 URL 404 → 显示错误 + 自动尝试下一章
  - 音频格式不支持 → 提示"不支持的格式"
  - 蓝牙耳机断开 → 自动暂停
  - 来电中断 → 通话结束后恢复播放
  - App 被系统终止后重启 → 恢复上次播放位置

### T2.2: 漫画阅读器

- **Gap**: #2 — ReadMangaActivity
- **描述**: 支持 bookSourceType==2 的漫画/图片源，专用图片阅读器
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/manga/ReadMangaActivity.kt`
  - iOS `Core/Cache/ImageCacheManager.swift`（已有）
- **输出**:
  - 新增 `Features/MangaReader/MangaReaderView.swift`: 漫画阅读界面
  - 新增 `Features/MangaReader/MangaReaderViewModel.swift`: 漫画逻辑
  - 新增 `Features/MangaReader/Components/ZoomableImageView.swift`: 可缩放图片
  - 新增 `Features/MangaReader/Components/MangaPageView.swift`: 单页图片
- **MUST HAVE**:
  - **纵向长条模式**: ScrollView 纵向排列本章所有图片（漫画主流阅读方式）
  - **翻页模式**: 左右翻页浏览单张图片
  - **双指缩放**: `MagnificationGesture` 2x-5x 缩放
  - **图片懒加载**: 仅加载可见区域 ± 2 张图片，使用 `AsyncImage` + `ImageCacheManager`
  - **内存管理**: 图片缓存上限 100MB，超出时 LRU 淘汰
  - **预加载**: 预加载下一章前 3 张图片
  - **加载占位**: 加载中显示灰色占位 + ProgressView
  - **加载失败**: 显示重试按钮
  - **章节管理**: 滑动到底部自动加载下一章
  - **进度保存**: 记录当前阅读到的图片索引
- **MUST NOT HAVE**:
  - 双页模式/横屏模式
  - 图片编辑/标注
  - 图片保存到相册
- **BOUNDARY**: 不修改 `ReaderView.swift`（漫画和文字阅读器是独立的）
- **验收标准**:
  - type==2 书源的书籍打开时自动进入漫画阅读器
  - 图片加载流畅，滚动不卡顿
  - 双指缩放平滑
  - 内存峰值 < 200MB
- **预估**: 6-8 人天
- **QA 场景**:
  - 单页 >10MB 大图 → 不 OOM，显示缩略图后渐进加载
  - 章节 50+ 张图片 → 懒加载正常，无内存泄漏
  - 网络断开 → 已缓存图片可查看，未缓存显示重试
  - 快速连续翻页 → 取消上一页加载请求

### T2.3: 媒体按钮处理

- **Gap**: #24 — MediaButtonReceiver
- **描述**: 耳机/蓝牙设备的媒体按钮响应
- **依赖**: T2.1
- **输入**:
  - Android `receiver/MediaButtonReceiver.kt`
  - iOS `Core/Audio/AudioPlayManager.swift`（T2.1 创建）
  - iOS `Core/TTS/TTSManager.swift`
- **输出**:
  - 新增 `Core/Audio/RemoteCommandHandler.swift`: 统一管理 MPRemoteCommandCenter
- **MUST HAVE**:
  - `MPRemoteCommandCenter` 注册: play/pause/nextTrack/previousTrack/skipForward/skipBackward
  - 统一入口: 音频播放 (T2.1) 和 TTS 朗读共用 RemoteCommandHandler
  - 根据当前活跃场景（音频播放 or TTS）路由命令到对应 Manager
  - 耳机线控: 单击暂停/恢复、双击下一章、三击上一章
- **MUST NOT HAVE**:
  - 自定义按键映射
  - 非音频场景的媒体按钮响应
- **验收标准**:
  - 有线耳机线控正常响应
  - 蓝牙耳机播放/暂停正常
  - TTS 模式和音频模式切换时，媒体按钮指向正确
- **预估**: 2-3 人天
- **QA 场景**:
  - 同时有音频播放和 TTS → 以最后启动的为准
  - 关闭音频播放 → 取消 MPRemoteCommandCenter 注册

### Phase 2 验证 Gate

- CI: conclusion == "success"
- 验证清单:
  - [ ] type==1 源的书自动进入音频播放
  - [ ] type==2 源的书自动进入漫画阅读
  - [ ] 后台音频播放正常
  - [ ] 锁屏控制正常
  - [ ] 漫画缩放流畅
  - [ ] 耳机按钮响应正确

---

## Phase 3: 书架与管理

> **目标**: 补全书架管理和书籍信息编辑功能  
> **预估**: 12-15 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯 + 批量操作正常

### T3.1: 书架批量管理

- **Gap**: #4 — BookshelfManageActivity
- **描述**: 书架长按进入编辑模式，支持批量操作
- **依赖**: Phase 0
- **输入**:
  - Android `ui/main/bookshelf/manage/BookshelfManageActivity.kt`
  - iOS `Features/Bookshelf/BookshelfView.swift`
  - iOS `Features/Bookshelf/BookshelfViewModel.swift`
- **输出**:
  - 更新 `Features/Bookshelf/BookshelfView.swift`: 添加编辑模式
  - 新增 `Features/Bookshelf/Components/BatchOperationBar.swift`: 批量操作工具栏
- **MUST HAVE**:
  - 长按书架中的书 → 进入编辑模式（多选）
  - 编辑模式 UI: 每本书左上角显示勾选框 + 底部操作栏
  - **操作栏**: 全选/取消全选 | 移动到分组 | 删除 | 批量缓存
  - 移动到分组: 弹出分组选择 Sheet (使用 BookGroup 实体)
  - 删除: 确认弹窗 → 批量删除选中书籍及其章节数据
  - 批量缓存: 对选中书籍执行缓存全本
  - 右上角"完成"退出编辑模式
- **MUST NOT HAVE**:
  - 拖拽排序（在编辑模式中）
  - 合并书籍
- **验收标准**:
  - 选中 20 本书批量删除 < 2s
  - 批量移动分组后书架立即更新
  - 空书架长按无反应
- **预估**: 3-4 人天
- **QA 场景**:
  - 操作中返回 → 取消编辑，无变更
  - 批量删除后 undo（可选，优先级低）
  - 书架为空 → 不显示编辑入口

### T3.2: 书籍信息编辑

- **Gap**: #11 — BookInfoEditActivity
- **描述**: 编辑书籍元数据（书名、作者、简介、封面）
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/info/edit/BookInfoEditActivity.kt`
  - iOS `Features/BookDetail/BookDetailView.swift`
- **输出**:
  - 新增 `Features/BookDetail/BookInfoEditView.swift`
- **MUST HAVE**:
  - 可编辑字段: 书名(name)、作者(author)、简介(intro)、自定义封面URL(customCoverUrl)、自定义简介(customIntro)
  - 封面: 支持输入 URL + 从相册选择（PhotosPicker）
  - 保存到 CoreData
  - 取消编辑
- **MUST NOT HAVE**:
  - 编辑书源规则
  - 编辑章节数据
- **验收标准**:
  - 编辑保存后 BookDetailView 立即更新
  - 自定义封面优先于源封面显示
  - 空字段保存不崩溃
- **预估**: 2-3 人天
- **QA 场景**:
  - 超长书名 (>500字) → 正常保存但界面截断显示
  - 无效封面 URL → 显示默认封面

### T3.3: 远程书籍管理

- **Gap**: #12 — RemoteBookActivity
- **描述**: 从 WebDAV/SMB/FTP 等远程存储浏览和导入书籍
- **依赖**: Phase 0, iOS `Core/Sync/WebDAVClient.swift`
- **输入**:
  - Android `ui/book/remote/RemoteBookActivity.kt`
  - iOS `Core/Sync/WebDAVClient.swift`（已有 WebDAV 客户端）
- **输出**:
  - 新增 `Features/Remote/RemoteBookView.swift`
  - 新增 `Features/Remote/RemoteBookViewModel.swift`
- **MUST HAVE**:
  - WebDAV 服务器浏览（目录列表 + 文件列表）
  - 文件过滤: 仅显示 .txt / .epub / .json 文件
  - 文件下载到本地 + 导入到书架
  - 连接配置: 服务器地址 + 用户名 + 密码
  - 已有 WebDAV 配置复用（WebDAVConfigView 中的配置）
- **MUST NOT HAVE**:
  - SMB/FTP 支持（v1 仅 WebDAV）
  - 文件上传
  - 远程文件删除
- **验收标准**:
  - 连接 WebDAV → 显示目录列表
  - 下载 .epub 文件 → 自动导入到书架
  - 网络异常 → 显示错误提示
- **预估**: 3-4 人天
- **QA 场景**:
  - WebDAV 凭证错误 → 显示认证失败
  - 大文件 (>100MB) → 显示下载进度
  - 下载中断 → 清理不完整文件

### T3.4: 书籍导出服务

- **Gap**: #23 — ExportBookService
- **描述**: 将书架中的书导出为 EPUB 或 TXT 文件
- **依赖**: Phase 0
- **输入**:
  - Android `service/ExportBookService.kt`
  - Android `ui/book/ExportBookActivity.kt`
- **输出**:
  - 新增 `Core/Export/BookExporter.swift`: 导出引擎
  - 新增 `Features/BookDetail/ExportBookSheet.swift`: 导出选项 UI
- **MUST HAVE**:
  - **导出格式**: TXT（纯文本拼接所有章节）、EPUB（基础 EPUB 打包）
  - **TXT 导出**: 按"书名_作者.txt"命名，章节标题作为分隔
  - **EPUB 导出**: 包含封面、目录、章节内容，使用 EPUB 3.0 规范
  - **导出位置**: 使用 `UIDocumentPickerViewController` 让用户选择保存位置
  - **进度显示**: 导出大书时显示进度
  - 导出完成后提供分享 (UIActivityViewController)
- **MUST NOT HAVE**:
  - PDF 导出
  - 批量导出
  - 自定义排版/样式
- **验收标准**:
  - TXT 导出文件可正常打开阅读
  - EPUB 导出文件可被 Apple Books 打开
  - 100 章节的书导出 < 10s
- **预估**: 3-4 人天
- **QA 场景**:
  - 章节未缓存 → 提示"请先缓存全本"
  - 导出过程中 App 进入后台 → 继续导出（使用 `beginBackgroundTask`）
  - 磁盘空间不足 → 提示用户

### Phase 3 验证 Gate

- CI: conclusion == "success"
- 验证清单:
  - [ ] 批量选择/删除/移动分组正常
  - [ ] 书籍信息编辑保存正常
  - [ ] WebDAV 远程浏览和下载正常
  - [ ] TXT/EPUB 导出可正常打开

---

## Phase 4: 搜索与发现

> **目标**: 补全书内全文搜索和发现页分页  
> **预估**: 8-10 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯

### T4.1: 书内全文搜索

- **Gap**: #5 — SearchContentActivity
- **描述**: 在当前书的所有已缓存章节中搜索关键词
- **依赖**: Phase 0
- **输入**:
  - Android `ui/book/searchContent/SearchContentActivity.kt`
  - iOS `Features/Reader/ReaderView.swift`
- **输出**:
  - 新增 `Features/Reader/SearchContent/SearchContentView.swift`
  - 新增 `Features/Reader/SearchContent/SearchContentViewModel.swift`
- **MUST HAVE**:
  - 搜索框 + 搜索结果列表
  - 搜索范围: 已缓存章节的文本内容
  - 结果显示: 章节名 + 匹配文本上下文（前后各 30 字符，关键词高亮）
  - 点击结果 → 跳转到对应章节对应位置
  - 搜索为空 → 提示"未找到"
  - 支持正则表达式搜索（可选开关）
  - 搜索历史（最近 10 条）
- **MUST NOT HAVE**:
  - 未缓存章节的搜索（需要网络请求，复杂度过高）
  - 搜索替换
- **验收标准**:
  - 100 章节中搜索关键词 < 3s
  - 点击结果跳转到正确位置
  - 多个结果可翻页浏览
- **预估**: 4-5 人天
- **QA 场景**:
  - 无缓存章节 → 提示"请先缓存章节"
  - 搜索特殊字符 (`.`, `*`, `[`) → 非正则模式下作为普通字符
  - 中文搜索 → 正常工作

### T4.2: 发现页分页

- **Gap**: #13 — ExploreShowActivity pagination
- **描述**: 发现页书源结果支持分页加载
- **依赖**: Phase 0
- **输入**:
  - Android `ui/explore/ExploreShowActivity.kt`
  - iOS `Features/Discovery/DiscoveryView.swift`（已有）
- **输出**:
  - 更新 `Features/Discovery/DiscoveryView.swift`: 添加分页逻辑
- **MUST HAVE**:
  - 滚动到底部自动加载下一页
  - 加载状态指示器（底部 ProgressView）
  - 加载失败重试按钮
  - 已加载数据保持（不重置）
  - 下拉刷新（从第 1 页重新加载）
- **MUST NOT HAVE**:
  - 页码指示器
  - 跳转到指定页
- **验收标准**:
  - 首页加载 < 2s
  - 翻页加载 < 3s
  - 连续加载 10 页不崩溃
- **预估**: 2-3 人天
- **QA 场景**:
  - 书源返回空结果 → 显示"没有更多了"
  - 快速滚动触发多次加载 → 防抖，不重复请求
  - 网络切换 (WiFi→4G) → 不影响加载

### Phase 4 验证 Gate

- CI: conclusion == "success"
- 验证清单:
  - [ ] 书内搜索返回正确结果
  - [ ] 搜索结果跳转到正确位置
  - [ ] 发现页分页加载正常

---

## Phase 5: RSS 增强

> **目标**: 完善 RSS 功能  
> **预估**: 8-10 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯

### T5.1: RSS 源编辑器

- **Gap**: RSS 编辑功能缺失
- **描述**: 编辑 RSS 源的规则配置
- **依赖**: Phase 0
- **输入**:
  - Android `ui/rss/source/edit/RssSourceEditActivity.kt`
  - iOS `Features/RSS/RSSSubscriptionView.swift`（已有列表）
  - iOS `Core/Persistence/RssSource+CoreDataClass.swift`
- **输出**:
  - 新增 `Features/RSS/RssSourceEditView.swift`
- **MUST HAVE**:
  - 编辑字段: sourceName, sourceUrl, sourceIcon, sourceGroup, sortUrl, articleStyle
  - 规则编辑: ruleArticles, ruleNextPage, ruleTitle, ruleDescription, ruleImage, ruleLink, ruleContent
  - JSON 导入/导出单个 RSS 源
  - 保存到 CoreData
  - 新建 RSS 源
- **MUST NOT HAVE**:
  - 规则调试器（已有通用 SourceDebugView）
  - AI 生成规则
- **验收标准**:
  - 编辑保存后 RSS 源列表更新
  - 导出的 JSON 可被 Android Legado 导入
  - 空规则保存不崩溃
- **预估**: 3-4 人天
- **QA 场景**:
  - 无效规则保存 → 保存成功但获取时报错提示
  - 超长 URL → 正常处理

### T5.2: RSS 收藏管理

- **Gap**: RSS 收藏功能
- **描述**: 收藏 RSS 文章，独立管理
- **依赖**: Phase 0
- **输入**:
  - Android `ui/rss/favorites/RssFavoritesActivity.kt`
  - iOS `Core/Persistence/RssStar+CoreDataClass.swift`
- **输出**:
  - 新增 `Features/RSS/RssFavoritesView.swift`
- **MUST HAVE**:
  - 收藏列表: 按时间倒序显示
  - 收藏/取消收藏: 在文章阅读页添加收藏按钮
  - 搜索收藏文章
  - 长按删除
- **验收标准**:
  - 收藏后在列表中立即显示
  - 取消收藏后立即从列表消失
- **预估**: 2-3 人天

### T5.3: RSS WebView 全文阅读

- **Gap**: RSS 文章全文 WebView 阅读
- **描述**: RSS 文章使用 WebView 渲染全文
- **依赖**: Phase 0
- **输入**:
  - Android `ui/rss/read/ReadRssActivity.kt`
  - iOS `Core/Network/FullTextFetcher.swift`（已有全文抓取）
- **输出**:
  - 新增 `Features/RSS/RssReadView.swift`
  - 新增 `Features/RSS/Components/RssWebView.swift`: WKWebView 包装
- **MUST HAVE**:
  - WKWebView 显示文章内容（HTML 渲染）
  - 如有全文规则 → 通过 FullTextFetcher 抓取全文
  - 如无规则 → 直接加载文章 URL
  - 字号调节（JS 注入修改 font-size）
  - 夜间模式（JS 注入暗色 CSS）
  - 收藏按钮
  - 分享按钮（UIActivityViewController）
- **MUST NOT HAVE**:
  - 离线阅读
  - 图片保存
- **验收标准**:
  - 文章 HTML 正确渲染
  - 字号调节实时生效
  - 夜间模式切换正常
- **预估**: 3-4 人天
- **QA 场景**:
  - 文章内容含视频 → WKWebView 可播放
  - 文章 URL 404 → 显示错误页

### Phase 5 验证 Gate

- CI: conclusion == "success"

---

## Phase 6: 后台服务

> **目标**: 实现后台下载、缓存、源检查、Web 服务器  
> **预估**: 15-20 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯

### T6.1: 后台下载管理器

- **Gap**: #20 — DownloadService
- **描述**: 后台下载书籍章节内容
- **依赖**: Phase 0
- **输入**:
  - Android `service/DownloadService.kt`
  - iOS `Core/Network/HTTPClient.swift`
- **输出**:
  - 新增 `Core/Download/DownloadManager.swift`
  - 新增 `Features/Download/DownloadListView.swift`: 下载队列 UI
- **MUST HAVE**:
  - `URLSession` background configuration 后台下载
  - 下载队列管理: 最大并发 3
  - 下载进度显示（每本书/每章节）
  - 断点续传 (URLSessionDownloadTask 自动支持)
  - 暂停/恢复/取消单个下载
  - 存储空间检查: 不足时提示用户
  - `application(_:handleEventsForBackgroundURLSession:)` 处理后台完成回调
  - 下载完成后更新 CoreData（使用 background context）
- **MUST NOT HAVE**:
  - P2P 下载
  - 同时下载 >10 本书
- **验收标准**:
  - 下载 10 章进入后台 → 继续下载
  - 网络断开 → 暂停，恢复后自动继续
  - 存储不足 → 提示
- **预估**: 4-5 人天
- **QA 场景**:
  - 大量章节 (500+) → 进度显示正确
  - 后台下载完成回调时 CoreData context 正确创建
  - 并发修改同一 Book 的 chapter cache → 线程安全

### T6.2: 后台缓存服务

- **Gap**: #22 — CacheBookService
- **描述**: 后台缓存书籍全本内容
- **依赖**: T6.1
- **输入**:
  - Android `service/CacheBookService.kt`
  - iOS `Features/BookDetail/BookDetailView.swift`（已有"缓存全本"按钮）
- **输出**:
  - 新增 `Core/Cache/BackgroundCacheService.swift`
- **MUST HAVE**:
  - 使用 `BGProcessingTask` 注册后台缓存任务
  - 前台模式: 在 BookDetailView 中显示缓存进度
  - 后台模式: 使用 BGProcessingTask（限时 ~几分钟）
  - 缓存范围: 当前章节 → 最新章节
  - 已缓存章节跳过
  - 缓存完成通知 (UNUserNotificationCenter)
- **MUST NOT HAVE**:
  - 后台持续运行（iOS 不允许）
  - 自动缓存所有书架书籍
- **验收标准**:
  - 前台缓存 100 章 < 60s（取决于网络）
  - 进度显示正确
  - 重复缓存 → 跳过已有章节
- **预估**: 3-4 人天

### T6.3: 批量源检查

- **Gap**: #21 — CheckSourceService
- **描述**: 批量检查书源可用性
- **依赖**: Phase 0
- **输入**:
  - Android `service/CheckSourceService.kt`
  - iOS `Features/Source/SourceManageView.swift`
- **输出**:
  - 新增 `Core/Source/SourceChecker.swift`
  - 更新 `Features/Source/SourceManageView.swift`: 添加"检查全部"按钮
- **MUST HAVE**:
  - 前台操作 + 进度 HUD
  - 并发检查（最大 10 并发）
  - 每个源: 发送测试请求 → 判断是否可用
  - 检查结果: 可用/超时/错误 + 响应时间
  - 按结果排序: 不可用源排到最后或标记红色
  - 检查过程可取消
- **MUST NOT HAVE**:
  - 自动删除不可用源
  - 后台定时检查
- **验收标准**:
  - 100 个源检查 < 60s（10 并发 * 5s 超时）
  - 进度百分比正确
  - 取消后立即停止
- **预估**: 3-4 人天
- **QA 场景**:
  - 全部源不可用 → 正常显示结果
  - 检查中修改源 → 不影响正在检查的任务
  - 0 个源 → "暂无书源"提示

### T6.4: Web 服务器

- **Gap**: #19 — WebService
- **描述**: 本地 HTTP 服务器，局域网内浏览器访问
- **依赖**: Phase 0
- **输入**:
  - Android `service/WebService.kt`
  - Android `web/` 目录
- **输出**:
  - 新增 `Core/Web/WebServer.swift`: HTTP 服务器（使用 GCDWebServer 或 Swifter）
  - 新增 `Core/Web/WebServerRoutes.swift`: 路由定义
  - 新增 `Features/Config/WebServerView.swift`: 服务器控制 UI
- **MUST HAVE**:
  - **SPM 依赖**: 使用 `GCDWebServer`（轻量、成熟）
  - **路由**: GET / (书架页面), GET /bookshelf (书籍 JSON), POST /booksource (上传书源), GET /booksource (下载书源)
  - **前端页面**: 简单 HTML（嵌入到 Bundle），显示书架列表 + 上传表单
  - **启动/停止**: 在设置页面控制
  - **IP 显示**: 显示当前设备局域网 IP + 端口（默认 1122）
  - **仅前台**: App 进入后台 → 停止服务器 + 本地通知"Web 服务已停止"
  - **Bonjour**: 注册 `_legado._tcp` 服务以便局域网发现
- **MUST NOT HAVE**:
  - HTTPS
  - 用户认证
  - 后台持续运行
  - 文件管理（删除/重命名）
- **验收标准**:
  - 启动后同局域网浏览器可访问
  - 上传书源 JSON → 自动导入
  - App 进入后台 → 服务停止
- **预估**: 5-6 人天
- **QA 场景**:
  - 端口被占用 → 自动换端口
  - 无 WiFi → 显示"请连接 WiFi"
  - 大文件上传 (10MB+) → 进度显示

### Phase 6 验证 Gate

- CI: conclusion == "success"

---

## Phase 7: 系统集成 + Readium

> **目标**: 实现 iOS 系统集成功能 + EPUB 阅读增强  
> **预估**: 18-22 人天  
> **依赖**: Phase 0 CI Gate 通过  
> **Gate**: CI 绿灯

### T7.1: Share Extension

- **Gap**: #14 — SharedReceiverActivity
- **描述**: 从其他 App 分享内容到 Legado
- **依赖**: T0.3 (App Group)
- **输入**:
  - Android `ui/association/SharedReceiverActivity.kt`
  - iOS App Group 配置（T0.3）
- **输出**:
  - 新增 Xcode target: `LegadoShareExtension`
  - 新增 `ShareExtension/ShareViewController.swift`
  - 新增 `ShareExtension/Info.plist`: 配置支持的类型
- **MUST HAVE**:
  - 接收 URL → 识别为书源 JSON URL → 导入书源
  - 接收 URL → 识别为 `legado://` 协议 → 导入处理
  - 接收文件 (.txt/.epub/.json) → 导入到书架或书源
  - 使用 App Group 共享 CoreData container 写入数据
  - 导入完成提示
  - 点击"在 Legado 中打开"跳转主 App
- **MUST NOT HAVE**:
  - 在 Extension 中显示完整 UI（轻量操作）
  - 在 Extension 中执行网络请求（超时风险）
- **BOUNDARY**: Extension 内存限制 ~120MB，不加载 SwiftSoup/RuleEngine
- **验收标准**:
  - Safari 分享 URL → Legado 出现在分享列表
  - 分享 .json 文件 → 书源导入
  - Extension 不因内存超限被杀死
- **预估**: 4-5 人天
- **QA 场景**:
  - 分享非支持格式 → 提示"不支持的文件类型"
  - 主 App 未运行 → Extension 独立处理 + 下次启动 App 同步
  - App Group 不可用 → 降级到 URL Scheme 打开主 App

### T7.2: 文件关联处理

- **Gap**: #15 — FileAssociationActivity
- **描述**: 系统"用此应用打开"功能
- **依赖**: Phase 0
- **输入**:
  - Android `ui/association/FileAssociationActivity.kt`
- **输出**:
  - 更新 `Info.plist`: 添加 UTType/CFBundleDocumentTypes
  - 更新 `App/LegadoApp.swift`: 处理 `onOpenURL`
- **MUST HAVE**:
  - 注册文件类型: `.txt`, `.epub`, `.json`（书源）
  - 文件管理器中"用 Legado 打开" → 自动导入
  - .txt/.epub → 导入为本地书
  - .json → 识别为书源或备份数据
  - 导入成功后显示确认
- **MUST NOT HAVE**:
  - 自定义文件类型
  - 文件预览
- **验收标准**:
  - 系统文件 App 中用 Legado 打开 .epub → 导入成功
  - .json 书源文件 → 导入成功
- **预估**: 2-3 人天

### T7.3: URL Scheme 导入

- **Gap**: #16 — OnLineImportActivity
- **描述**: 处理 `legado://` 协议链接
- **依赖**: Phase 0
- **输入**:
  - Android `ui/association/OnLineImportActivity.kt`
  - iOS `App/LegadoApp.swift`
- **输出**:
  - 更新 `Info.plist`: 注册 `legado` URL Scheme
  - 更新 `App/LegadoApp.swift`: 处理 `.onOpenURL { url in ... }`
  - 新增 `Core/Import/URLSchemeHandler.swift`: URL 解析和导入逻辑
- **MUST HAVE**:
  - `legado://booksource/importonline?src=<url>` → 下载并导入书源
  - `legado://rsssource/importonline?src=<url>` → 下载并导入 RSS 源
  - `legado://import/booksource?json=<encoded>` → 直接导入 JSON 书源
  - `legado://import/rsssource?json=<encoded>` → 直接导入 JSON RSS 源
  - `legado://replace/importonline?src=<url>` → 导入替换规则
  - 导入确认弹窗（显示源数量 + 确认/取消）
  - URL 格式错误 → 提示"无效的导入链接"
- **MUST NOT HAVE**:
  - 自动导入（必须用户确认）
  - 自定义协议注册
- **验收标准**:
  - Safari 中点击 `legado://booksource/importonline?src=xxx` → 跳转 Legado + 导入确认
  - 导入确认后书源出现在列表中
- **预估**: 3 人天
- **QA 场景**:
  - src URL 不可达 → 超时提示
  - JSON 格式错误 → 解析失败提示
  - 重复导入 → 更新已有源而非创建重复

### T7.4: 验证码 WebView

- **Gap**: #17 — VerificationCodeActivity
- **描述**: 某些书源需要验证码/登录验证
- **依赖**: Phase 0
- **输入**:
  - Android `ui/association/VerificationCodeActivity.kt`
  - Android `ui/login/SourceLoginActivity.kt`
- **输出**:
  - 新增 `Features/Source/VerificationWebView.swift`
  - 新增 `Features/Source/SourceLoginView.swift`
- **MUST HAVE**:
  - WKWebView 加载验证页面 URL
  - 用户手动完成验证/登录后，获取 cookie
  - `WKHTTPCookieStore.getAllCookies()` → 保存到 CoreData `Cookie` 实体
  - 后续请求自动携带已保存的 cookie
  - 支持 JavaScript 执行（某些验证需要 JS）
  - 验证完成检测: 监听 URL 变化/特定 cookie 出现 → 自动关闭
- **MUST NOT HAVE**:
  - 自动填充表单
  - Cookie 过期自动清理
- **验收标准**:
  - 需要验证的书源 → 弹出 WebView
  - 完成验证后 → 后续请求正常
  - Cookie 保存到 CoreData
- **预估**: 3-4 人天
- **QA 场景**:
  - 验证页面需要重定向 → WKWebView 正确跟随
  - Cookie 保存后重启 App → 仍然可用
  - 多个源使用同一域名 → Cookie 共享

### T7.5: URL 打开确认

- **Gap**: #18 — OpenUrlConfirmActivity
- **描述**: 打开外部 URL 前的确认弹窗
- **依赖**: Phase 0
- **输入**:
  - Android `ui/association/OpenUrlConfirmActivity.kt`
- **输出**:
  - 新增 `Core/Util/URLConfirmHelper.swift`
- **MUST HAVE**:
  - 打开外部 URL 前显示 Alert: "确定要打开以下链接？" + URL 预览
  - 确认 → `UIApplication.shared.open(url)`
  - 取消 → 不操作
  - 白名单域名（如 legado GitHub）→ 直接打开不确认
- **MUST NOT HAVE**:
  - 内置浏览器
  - URL 重写
- **验收标准**:
  - 点击外部链接 → 确认弹窗
  - 确认后打开 Safari
- **预估**: 0.5 人天

### T7.6: Readium EPUB 集成

- **Gap**: EPUB 解析极简，需升级为生产级
- **描述**: 集成 Readium Swift Toolkit 替代自实现 EPUBParser
- **依赖**: Phase 0
- **输入**:
  - iOS `Core/Parser/EPUBParser.swift`（当前极简实现）
  - Readium Swift Toolkit 3.5.0+ 文档
- **输出**:
  - 新增 SPM 依赖: `ReadiumShared`, `ReadiumStreamer`, `ReadiumNavigator`
  - 更新 `Core/Parser/EPUBParser.swift`: 底层切换为 Readium
  - 新增 `Features/Reader/EPUBReaderView.swift`: Readium Navigator 包装
- **MUST HAVE**:
  - **SPM 集成**: `https://github.com/nickaroot/readium-swift-toolkit.git` (branch: main)
  - **解析**: Readium Streamer 解析 EPUB → Publication 模型
  - **渲染**: Readium Navigator (EPUBNavigatorViewController) → UIViewControllerRepresentable 包装
  - **功能**: 目录导航、搜索、标注高亮、用户偏好（字号/主题/间距）
  - **旧解析器保留**: `EPUBParser` 作为 fallback（Readium 失败时降级）
  - **本地 EPUB**: 从文件导入 → Readium 打开
  - **网络 EPUB**: 下载到本地 → Readium 打开
- **MUST NOT HAVE**:
  - DRM (LCP) 支持
  - EPUB 编辑
  - 自定义 EPUB 渲染引擎
- **BOUNDARY**: 不修改已有的 `ReaderView.swift`（EPUB 使用独立的 EPUBReaderView）
- **验收标准**:
  - 打开 EPUB 文件 → Readium 渲染页面
  - 目录导航正常
  - 字号/主题调节正常
  - 搜索功能可用
  - 不兼容 EPUB → fallback 到旧解析器
- **预估**: 5-6 人天
- **QA 场景**:
  - 损坏的 EPUB 文件 → Readium 报错 → fallback → 旧解析器报错 → 用户提示
  - EPUB 2.0 vs EPUB 3.0 → 都能打开
  - 大 EPUB (>100MB) → 不 OOM

### Phase 7 验证 Gate

- CI: conclusion == "success"
- 验证清单:
  - [ ] Share Extension 可从 Safari 接收 URL
  - [ ] 文件关联打开正常
  - [ ] URL Scheme 导入正常
  - [ ] 验证码 WebView 正常
  - [ ] Readium EPUB 阅读正常

---

## Phase 8: 主题系统 + 收尾打磨

> **目标**: 完整主题系统 + 缺失的小功能页面 + 最终集成验证  
> **预估**: 15-20 人天  
> **依赖**: Phase 1-7 全部完成  
> **Gate**: CI 绿灯 + 全功能回归测试

### T8.1: 完整主题系统

- **Gap**: #25 — Complete theme system
- **描述**: 可切换的主题系统，自定义背景色/文字色/强调色
- **依赖**: Phase 1-7（需要所有 View 就绪后统一适配）
- **输入**:
  - Android `lib/theme/` 目录
  - iOS 全部 View 文件（~30+ 个）
- **输出**:
  - 新增 `Core/Theme/ThemeManager.swift`: 主题管理器
  - 新增 `Core/Theme/Theme.swift`: 主题模型
  - 新增 `Features/Config/ThemeSettingsView.swift`: 主题设置页
  - 更新所有 View: 使用 ThemeManager 颜色
- **MUST HAVE**:
  - **预设主题**: 默认白、默认黑、护眼绿、米黄、自定义
  - **自定义主题**: 背景色 (ColorPicker) + 文字色 + 强调色
  - **ThemeManager**: `@Observable` 单例，`@AppStorage` 持久化
  - **响应系统外观**: 跟随系统暗色/亮色模式（可选开关）
  - **全局适配**: 所有 View 使用 `ThemeManager.shared.backgroundColor` 等属性
  - **阅读器主题独立**: 阅读器背景/文字色不受全局主题影响（T1.4 已处理）
- **MUST NOT HAVE**:
  - 主题导入/导出
  - 主题商店
  - 自定义图标
- **验收标准**:
  - 切换主题后所有页面颜色统一变化
  - 深色模式/浅色模式切换无闪烁
  - 自定义颜色保存后重启 App 保持
- **预估**: 5-6 人天
- **QA 场景**:
  - 白色背景 + 白色文字 → 防止不可见（自动调整对比度）
  - 系统暗色模式切换 → App 跟随（如开启跟随）

### T8.2: 缺失的功能页面

- **Gap**: 若干小功能页面缺失
- **描述**: 补全剩余小功能页面
- **依赖**: Phase 0-7
- **输入**:
  - Android 对应 Activity
- **输出**:
  - 新增 `Features/Config/AboutView.swift`: 关于页面
  - 新增 `Features/Bookmark/AllBookmarkView.swift`: 全部书签管理
  - 新增 `Features/Config/TxtTocRuleView.swift`: TXT 目录规则管理
  - 新增 `Features/Config/FileManageView.swift`: 文件管理（缓存清理）
  - 新增 `Features/WebView/WebViewScreen.swift`: 通用 WebView 页面
- **MUST HAVE**:
  - **AboutView**: App 版本、开源协议、GitHub 链接、鸣谢
  - **AllBookmarkView**: 所有书的书签列表，按书分组，点击跳转阅读位置
  - **TxtTocRuleView**: TXT 目录规则 CRUD（使用 TxtTocRule 实体）
  - **FileManageView**: 缓存大小显示、清理缓存、图片缓存清理
  - **WebViewScreen**: 通用 WKWebView，接收 URL 参数，标题栏 + 前进/后退/刷新
- **MUST NOT HAVE**:
  - 自动更新检查
  - 用户反馈表单
- **验收标准**:
  - 每个页面可从设置/相关入口导航到达
  - 数据正确显示
- **预估**: 4-5 人天

### T8.3: 集成测试与回归验证

- **Gap**: 缺乏端到端测试
- **描述**: 全功能回归测试
- **依赖**: T8.1, T8.2
- **输入**: 全部已实现功能
- **输出**:
  - 新增 `Tests/Integration/FullFlowTests.swift`
  - 新增 `Tests/Integration/BookSourceCompatTests.swift`
  - 更新 CI: 运行全部测试
- **MUST HAVE**:
  - **核心流程测试**:
    - 导入书源 → 搜索书籍 → 加入书架 → 打开阅读 → 翻页 → 退出 → 恢复位置
    - 导入 EPUB → 阅读 → 书签 → 搜索
    - RSS 订阅 → 抓取 → 阅读 → 收藏
    - WebDAV 备份 → 恢复
  - **书源兼容性测试**: 导入 Android 社区 Top 10 热门书源 JSON，验证解析不报错
  - **性能测试**: 100 个源并发搜索 < 30s、500 章目录加载 < 3s
  - **内存测试**: 漫画阅读器内存峰值 < 200MB
- **MUST NOT HAVE**:
  - UI 自动化测试（需要真机/模拟器，CI 中可选）
  - 压力测试
- **验收标准**:
  - 全部测试通过
  - 0 个 crash
  - 性能指标达标
- **预估**: 5-6 人天
- **QA 场景**:
  - 全量测试在 CI 中 < 10 分钟
  - 测试之间无数据污染

### Phase 8 验证 Gate (最终)

- CI: conclusion == "success"
- 全部测试通过
- 回归验证清单:
  - [ ] Phase 0: CoreData 20 实体正常
  - [ ] Phase 1: 阅读器所有增强功能
  - [ ] Phase 2: 音频播放 + 漫画阅读
  - [ ] Phase 3: 书架管理 + 导出
  - [ ] Phase 4: 搜索 + 发现
  - [ ] Phase 5: RSS
  - [ ] Phase 6: 后台服务
  - [ ] Phase 7: 系统集成 + Readium
  - [ ] Phase 8: 主题 + 完整性

---

## 总览

| Phase | 名称 | 任务数 | 预估 (人天) | 依赖 |
|---|---|---|---|---|
| 0 | 基础对齐 | 6 | 12-15 | 无 |
| 1 | 阅读器核心增强 | 6 | 15-20 | Phase 0 |
| 2 | 音频 + 漫画 | 3 | 18-25 | Phase 0 |
| 3 | 书架与管理 | 4 | 12-15 | Phase 0 |
| 4 | 搜索与发现 | 2 | 8-10 | Phase 0 |
| 5 | RSS 增强 | 3 | 8-10 | Phase 0 |
| 6 | 后台服务 | 4 | 15-20 | Phase 0 |
| 7 | 系统集成 + Readium | 6 | 18-22 | Phase 0, T0.3 |
| 8 | 主题 + 收尾 | 3 | 15-20 | Phase 1-7 |
| **总计** | | **37** | **121-157** | |

> Phase 1-7 可部分并行执行（均仅依赖 Phase 0），Phase 8 必须最后。

---

## 执行指令

```
EXECUTION ORDER:
  Phase 0 (MUST complete first, CI gate)
  → Phase 1, 2, 3, 4, 5, 6, 7 (parallel where possible)
  → Phase 8 (after ALL above complete)

EVERY PHASE:
  1. 实现所有任务
  2. 触发 CI (gh workflow run ios-ci.yml)
  3. CI 绿灯 → 进入下一 Phase
  4. CI 红灯 → 修复后重新触发，直到绿灯

EVERY TASK:
  1. 阅读"输入"中的 Android 参考源码
  2. 阅读"输入"中的 iOS 现有文件
  3. 按"MUST HAVE"实现
  4. 确保"MUST NOT HAVE"的内容不出现
  5. 不修改"BOUNDARY"中列出的文件
  6. 运行"QA 场景"验证
  7. 确保"验收标准"全部满足
```
