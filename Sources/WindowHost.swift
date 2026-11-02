import AppKit

final class QRWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { close() }
}

/// Navigation replaces content, never the window. Keeping its identity also
/// preserves the user's position and avoids macOS close/open animations.
final class WindowHost {
    private(set) var window: QRWindow?

    func prepare() -> QRWindow {
        if let window {
            window.makeFirstResponder(nil)
            window.contentView?.subviews.forEach { $0.removeFromSuperview() }
            return window
        }
        let result = QRWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        result.title = "QuickQR"
        result.titlebarAppearsTransparent = true
        result.animationBehavior = .none
        let backdrop = NSVisualEffectView()
        backdrop.material = .windowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        result.contentView = backdrop
        result.isReleasedWhenClosed = false
        result.center()
        window = result
        return result
    }
}
