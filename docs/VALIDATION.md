# 验证记录 · 2026-11-02

环境：Apple Silicon，macOS 26.6.2，Swift 6.2.1，Xcode 26.1。

## 已通过

- 在最终仓库运行 `bash scripts/build.sh` 编译成功；本地 ad-hoc 签名检查、Info.plist 格式检查通过。
- `bash scripts/test.sh`：23 项检查，包含 5 组 Vision 精确解码，以及 Services 声明的回归检查。
- QR 输入：nil、空串、纯空白、超限 ASCII/中文拒绝；URL 查询/片段、百分号编码、加号、首尾空格/换行、中文/emoji、2000 字节 ASCII 精确回读。
- 最近生成：10 条上限、重复前移、只存内存、清空不删除收藏。
- 收藏：在随机临时目录验证原文持久化、重新加载、删除持久化、损坏 JSON 拒绝覆盖；未操作用户真实收藏。
- Swift 模块缓存已按仓库绝对路径隔离，修复移动构建目录导致的 PCH 路径不匹配。

## Services 诊断与修复

起初 TextEdit 服务菜单没有 QuickQR。只读检查确认 Launch Services 注册存在、回调 selector 为 `generateQRCode:userData:error:`，但 `NSRequiredContext` 缺失。

已按 [Apple Services Properties](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html) 补空字典，并在应用完成初始化后才注册 provider，避免冷启动时输入窗口覆盖服务结果。构建号更新、刷新本 App 注册后，系统缓存中已出现修正的 context，TextEdit 选中 `https://example.com/quickqr?source=services` 后，服务菜单实际出现「用 QuickQR 生成二维码」。

用户确认旧进程退出后，已检查进程消失并正常打开最新构建。TextEdit 中测试网址仍保持选中，菜单可发现入口；但自动化菜单点击没有可靠触发生成，键盘菜单导航也丢失选区，无法将完整服务链路记为通过。当前最小剩余验证是用户在 TextEdit 中手动选中公开网址，实际点击服务入口，核对弹窗原文；不能以“入口可见”替代该结果。

未全局重置 Launch Services，未修改系统隐私权限，未安装到 Applications。

## UI 实测与截图

- 最新构建成功启动，手动输入 `https://example.com/quickqr` 后实际显示二维码和精确原文。
- 空输入点击生成弹出清楚错误；显式剪贴板生成显示 `https://example.com/clipboard-demo`。
- 最近列表显示生成结果、一键清空后显示空状态；10 条限制/去重/退出生命周期由自动测试覆盖。
- 主动命名 `QuickQR Demo 1102` 收藏成功，列表可见，重新生成得到 `https://example.com/quickqr-demo`；删除确认弹窗可见并选择取消，未删除已有收藏。持久化删除由隔离临时文件测试覆盖。
- Esc 关闭后通过正常应用入口重新打开输入窗口成功；正常 Cmd-Q 退出后进程确实消失，可再启动。
- 首次真实截图发现列表底部对齐，已用 flipped document stack 修正；复拍确认内容从顶部开始。
- 已保存三个实际 App 窗口截图至 `docs/images/`，README 相对引用。截图内容为公开测试网址和普通收藏名称，不含用户桌面或私密链接。
- 屏幕捕捉曾返回 `SCStreamError -3811`，后续恢复；部分 AX 索引点击无效果，实际功能验证使用当前截图坐标并读取操作后的 AX 状态。

## 未完成项

- TextEdit Services 完整调用、CatPaw Services、手机扫码、Intel/旧 macOS 尚未验收。没有给任意应用兼容承诺。
- 未执行完整 11 条最近记录的 UI 压力流程；上限与顺序已有自动模型测试。
- 参考图通过 Library 解析，但官方传输 helper 与系统 Python 不兼容，未下载成功，未直接看图；未安装新依赖或绕过传输流程。设计依据为主对话提供的已观察视觉事实，已检查当前实际截图。

仓库不含二进制发布包、开发者凭据、系统采样日志或真实收藏文件。
