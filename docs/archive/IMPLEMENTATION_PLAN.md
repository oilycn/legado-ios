# Legado iOS 完整移植计划

> 由 Plan Agent (Metis) 生成的详细实施计划

## 总览

| 指标 | 数值 |
|------|------|
| 总任务数 | 23 个 |
| P0（必须） | 8 个，32-40 人天 |
| P1（核心） | 9 个，28-36 人天 |
| P2（增值） | 6 个，18-24 人天 |
| **总估算** | **78-100 人天** |
| 最大并行度 | 3-4 条并行线路 |

---

## P0 任务列表（必须优先完成）

### P0-T1：规则分割器
- **交付物**: `RuleSplitter.swift` — 处理 `@前缀:`、`&&`、`||`、`%%`、`##`
- **工时**: 4 人天
- **依赖**: 无

### P0-T2：变量与模板引擎
- **交付物**: `TemplateEngine.swift` — `{{key}}` 模板替换、`@put/@get`
- **工时**: 3 人天
- **依赖**: P0-T1

### P0-T3：JavaScript 桥增强
- **交付物**: `JSBridge.swift` — java.ajax/getString/put/get/cookie/source
- **工时**: 5 人天
- **依赖**: P0-T2

### P0-T4：JSONPath 增强与正则分组
- **交付物**: 完整 JSONPath 支持（递归/切片/过滤）、正则分组提取
- **工时**: 3 人天
- **依赖**: P0-T1

### P0-T5：翻页动画（覆盖/滑动）
- **交付物**: `PageSplitter.swift` + `PagedReaderView.swift`
- **工时**: 6 人天
- **依赖**: 无

### P0-T6：仿真翻页
- **交付物**: `CurlPageViewController.swift` — UIPageViewController wrapper
- **工时**: 3 人天
- **依赖**: P0-T5

### P0-T7：书源编辑器
- **交付物**: `SourceEditView.swift` + `RuleFieldEditor.swift`
- **工时**: 5 人天
- **依赖**: 无

### P0-T8：书源调试器
- **交付物**: `SourceDebugView.swift` + `RuleDebugger.swift`
- **工时**: 5 人天
- **依赖**: P0-T1

---

## P1 任务列表（核心体验）

| ID | 任务 | 工时 | 依赖 |
|----|------|------|------|
| P1-T1 | TTS 语音朗读 | 4d | P0-T5 |
| P1-T2 | 自动翻页 | 2d | P0-T5 |
| P1-T3 | WebDAV 同步 | 5d | 无 |
| P1-T4 | RSS 全文抓取 | 4d | P0-T1 |
| P1-T5 | 自定义主题 | 3d | P0-T5 |
| P1-T6 | 书籍分组 | 3d | 无 |
| P1-T7 | 阅读增强 | 2d | P0-T5 |
| P1-T8 | 搜索优化 | 2d | 无 |
| P1-T9 | 替换规则增强 | 3d | 无 |

---

## P2 任务列表（增值功能）

| ID | 任务 | 工时 | 依赖 |
|----|------|------|------|
| P2-T1 | 阅读统计 | 4d | P0-T5 |
| P2-T2 | iCloud 同步完善 | 3d | 无 |
| P2-T3 | EPUB 完整支持 | 5d | P0-T5 |
| P2-T4 | 发现页 | 3d | P0-T1 |
| P2-T5 | 书源订阅 | 2d | 无 |
| P2-T6 | 数据迁移兼容 | 3d | P0 |

---

## 依赖关系图

```
P0-T1 ─┬─→ P0-T2 → P0-T3
        ├─→ P0-T4
        ├─→ P0-T8
        └─→ P1-T4
        
P0-T5 ──→ P0-T6
          ├─→ P1-T1, P1-T2, P1-T5, P1-T7
          └─→ P2-T1, P2-T3

独立任务: P0-T7, P1-T3, P1-T6, P1-T8, P1-T9, P2-T2, P2-T5
```

---

## 并行执行策略

### 阶段 1（第 1-2 周）
- **线路 A**: P0-T1 → P0-T2 → P0-T3（规则引擎链）
- **线路 B**: P0-T5 → P0-T6（翻页动画）
- **线路 C**: P0-T7（书源编辑器）
- **线路 D**: P1-T3 + P1-T6（WebDAV + 分组）

### 阶段 2（第 3-4 周）
- **线路 A**: P0-T4 + P0-T8 + P1-T4
- **线路 B**: P1-T1 + P1-T2 + P1-T7
- **线路 C**: P1-T5 + P1-T8 + P1-T9

### 阶段 3（第 5-6 周）
- P2 任务并行执行

---

## 关键技术决策

### MUST
- 规则引擎修改必须通过 `RuleExecutor` 协议扩展
- 翻页动画遵循 `PagedReaderView` 统一接口
- 所有新 CoreData 实体支持 Lightweight Migration
- JS 桥同步 HTTP 必须有 10 秒超时保护

### MUST NOT
- 修改 `BookSource+CoreDataClass.swift` 的现有 JSON Codable 结构
- 在 RuleEngine 中使用 `as! Any` 强转
- TTS 在前台模式下请求后台音频权限

### 参考
- `Core/RuleEngine/RuleEngine.swift:86-97` — 执行器注册模式
- `Features/Reader/ReaderSettingsFullView.swift:35-43` — PageAnimation 枚举

---

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| JS 桥同步 HTTP 阻塞主线程 | DispatchQueue.global + Semaphore，10s 超时 |
| UIPageViewController 与 SwiftUI 状态不同步 | Coordinator + @Binding 双向绑定 |
| CloudKit schema 不可逆 | 先在 Development 环境测试 |
| Readium 包体积过大 | 评估后可自实现简化版 |
| Android 书源 JSON 未文档化字段 | 使用 `decodeIfPresent`，忽略未知字段 |