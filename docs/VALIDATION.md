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

点击服务后，读取 QuickQR 窗口仍超时；只读进程采样显示旧进程停在状态栏菜单事件循环，尚无法确认完整调用链。没有强制结束进程，以免丢失用户输入；等待正常退出旧进程后重新打开最终构建再验收。

未全局重置 Launch Services，未修改系统隐私权限，未安装到 Applications。

## UI、参考图与剩余验收

- 早期 App 实际启动，观察到输入窗口及扫码窗口；当时用户同时操作，不能把全部结果归因于自动化。
- 当前视觉代码：480×640 原生磨砂窗口、三个等宽导航、圆角输入/列表、系统蓝选中态、纯白二维码、编辑菜单与辅助标签。最终视觉 QA 未完成。
- Esc、关闭再开、剪贴板与收藏 UI 回归、手机扫码、CatPaw Services、Intel/旧 macOS 尚未验收。
- 截图工具反复 `timeoutReached`，一次 Finder 截图返回全白，不可作为演示图。未保存任何用户桌面截图到仓库。
- 参考图通过 Library 解析，但官方传输 helper 与系统 Python 不兼容，未下载成功，未直接看图；没有安装新依赖或绕过传输流程。设计依据为主对话提供的已观察视觉事实。

核心算法与模型测试通过不代表上述 UI/Services 全部验收。仓库不含二进制发布包、开发者凭据或真实收藏数据。
