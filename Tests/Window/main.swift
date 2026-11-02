import AppKit

_ = NSApplication.shared
let host = WindowHost()
let first = host.prepare()
let position = NSPoint(x: 111, y: 222)
first.setFrameOrigin(position)
let expectedFrame = first.frame
let background = first.contentView!
var checks = 0
func require(_ condition: Bool, _ message: String) {
    precondition(condition, message)
    checks += 1
}
for _ in 0..<20 {
    let oldContent = NSView(frame: .zero)
    background.addSubview(oldContent)
    let next = host.prepare()
    require(next === first, "Navigation must reuse the same window")
    require(next.frame == expectedFrame, "Navigation must preserve position and size")
    require(next.contentView === background, "Navigation must preserve the backdrop")
    require(oldContent.superview == nil, "Previous page content must be detached")
    require(next.animationBehavior == .none, "Window transitions must not animate")
}
first.close()
let reopened = host.prepare()
require(reopened === first && reopened.frame == expectedFrame, "Reopen preserves window and placement")
print("PASS: \(checks) window lifecycle checks; no windows were ordered onscreen")
