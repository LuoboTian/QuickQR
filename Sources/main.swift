import AppKit

final class PayloadButton: NSButton {
    var payload: String?
}

final class QRWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { close() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var window: QRWindow?
    private var library: QRLibrary?
    private var displayedText: String?
    private var selectedTab = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 QuickQR", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "qrcode", accessibilityDescription: "QuickQR")
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            library = try QRLibrary(file: folder.appendingPathComponent("QuickQR/favorites.json"))
        } catch {
            showError("收藏文件无法读取，本次运行不写入收藏，以免覆盖已有数据。")
        }
        refreshMenu()
        manualInput()
        // Register only after the menu, library and initial window are ready.
        // A cold-start service can be delivered synchronously at registration.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { manualInput() }
        return true
    }

    private func refreshMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "从剪贴板生成二维码", action: #selector(fromClipboard), keyEquivalent: "")
        menu.addItem(withTitle: "输入文本…", action: #selector(manualInput), keyEquivalent: "")
        let historyItem = NSMenuItem(title: "最近生成（仅本次运行）", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu()
        for text in library?.recent ?? [] {
            let item = NSMenuItem(title: String(text.replacingOccurrences(of: "\n", with: " ").prefix(60)), action: #selector(openStored(_:)), keyEquivalent: "")
            item.representedObject = text
            item.target = self
            historyMenu.addItem(item)
        }
        historyMenu.addItem(.separator())
        let clear = NSMenuItem(title: "清空最近生成", action: #selector(clearRecent), keyEquivalent: "")
        clear.target = self
        historyMenu.addItem(clear)
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)
        let favoritesItem = NSMenuItem(title: "收藏", action: nil, keyEquivalent: "")
        let favoritesMenu = NSMenu()
        for favorite in library?.favorites ?? [] {
            let entry = NSMenuItem(title: favorite.name, action: nil, keyEquivalent: "")
            let actions = NSMenu()
            let open = NSMenuItem(title: "生成二维码", action: #selector(openStored(_:)), keyEquivalent: "")
            open.representedObject = favorite.text
            open.target = self
            actions.addItem(open)
            let delete = NSMenuItem(title: "删除收藏…", action: #selector(deleteFavorite(_:)), keyEquivalent: "")
            delete.representedObject = favorite.id.uuidString
            delete.target = self
            actions.addItem(delete)
            entry.submenu = actions
            favoritesMenu.addItem(entry)
        }
        if favoritesMenu.items.isEmpty { favoritesMenu.addItem(withTitle: "暂无收藏", action: nil, keyEquivalent: "") }
        favoritesItem.submenu = favoritesMenu
        menu.addItem(favoritesItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 QuickQR", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        status.menu = menu
    }

    @objc func openStored(_ sender: NSMenuItem) { show(sender.representedObject as? String) }
    @objc func clearRecent() { library?.clearRecent(); refreshMenu() }
    @objc func deleteFavorite(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw) else { return }
        let alert = NSAlert()
        alert.messageText = "删除这条收藏？"
        alert.informativeText = "此操作无法撤销；最近生成中的内容不会一同删除。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "删除")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try library?.delete(id); refreshMenu() }
        catch { showError("收藏删除失败，请检查本机文件访问权限。") }
    }
    @objc func saveFavorite() {
        guard let text = displayedText, let library else { showError("收藏当前不可用。"); return }
        let alert = NSAlert()
        alert.messageText = "收藏此内容"
        alert.informativeText = "收藏以明文保存在本机。带 token、登录凭据或临时参数的链接不宜收藏。内容不会被改写。请输入收藏名称："
        let name = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        name.stringValue = "我的二维码"
        alert.accessoryView = name
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { showError("收藏名称不能为空。请重新收藏并输入名称。"); return }
        do { try library.save(name: title, text: text); refreshMenu() }
        catch { showError("收藏保存失败，请检查本机文件访问权限。") }
    }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "QuickQR"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc func quit() { NSApp.terminate(nil) }
    @objc func fromClipboard() { show(NSPasteboard.general.string(forType: .string) ?? NSPasteboard.general.string(forType: .URL)) }

    // Only use the pasteboard supplied by Services. Never fall back to general clipboard.
    @objc func generateQRCode(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        show(pasteboard.string(forType: .string) ?? pasteboard.string(forType: .URL))
    }

    private func makeWindow(title: String) -> QRWindow {
        window?.close()
        let result = QRWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        result.title = "QuickQR"
        result.titlebarAppearsTransparent = true
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

    private func stack(in window: NSWindow) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)
        ])
        let navigation = NSStackView()
        navigation.orientation = .horizontal
        navigation.distribution = .fillEqually
        navigation.spacing = 8
        for (index, entry) in [("生成", "qrcode"), ("最近", "clock"), ("收藏", "star")].enumerated() {
            let button = NSButton(title: entry.0, target: self, action: #selector(navigate(_:)))
            button.tag = index
            button.image = NSImage(systemSymbolName: entry.1, accessibilityDescription: entry.0)
            button.imagePosition = .imageAbove
            button.imageScaling = .scaleProportionallyDown
            button.isBordered = false
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.contentTintColor = index == selectedTab ? .systemBlue : .secondaryLabelColor
            button.wantsLayer = true
            button.layer?.cornerRadius = 12
            button.layer?.backgroundColor = index == selectedTab ? NSColor.controlBackgroundColor.cgColor : NSColor.clear.cgColor
            button.setAccessibilityLabel(entry.0)
            button.heightAnchor.constraint(equalToConstant: 64).isActive = true
            navigation.addArrangedSubview(button)
        }
        stack.addArrangedSubview(navigation)
        navigation.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let divider = NSBox()
        divider.boxType = .separator
        stack.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    @objc private func navigate(_ sender: NSButton) {
        selectedTab = sender.tag
        if selectedTab == 0 { manualInput() } else { showList() }
    }
    @objc private func openListEntry(_ sender: PayloadButton) { show(sender.payload) }
    @objc private func deleteListEntry(_ sender: PayloadButton) {
        let item = NSMenuItem()
        item.representedObject = sender.payload
        deleteFavorite(item)
        showList()
    }
    @objc private func clearList() { clearRecent(); showList() }
    private func showList() {
        let w = makeWindow(title: "QuickQR")
        let s = stack(in: w)
        let heading = NSTextField(labelWithString: selectedTab == 1 ? "最近生成" : "我的收藏")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        s.addArrangedSubview(heading)
        let note = NSTextField(wrappingLabelWithString: selectedTab == 1 ? "仅本次运行保留最近 10 条，退出自动清空。" : "只保存在本机。点击条目重新生成二维码。")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 12)
        s.addArrangedSubview(note)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = rows
        rows.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let entries: [(String, String, UUID?)] = selectedTab == 1
            ? (library?.recent ?? []).map { ($0, $0, nil) }
            : (library?.favorites ?? []).map { ($0.name, $0.text, $0.id) }
        for entry in entries {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            row.wantsLayer = true
            row.layer?.cornerRadius = 12
            row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            let open = PayloadButton(title: String(entry.0.replacingOccurrences(of: "\n", with: " ").prefix(48)), target: self, action: #selector(openListEntry(_:)))
            open.payload = entry.1
            open.isBordered = false
            open.alignment = .left
            open.font = .systemFont(ofSize: 13, weight: .medium)
            open.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            open.setAccessibilityLabel(entry.0)
            row.addArrangedSubview(open)
            if let id = entry.2 {
                let delete = PayloadButton(title: "", target: self, action: #selector(deleteListEntry(_:)))
                delete.payload = id.uuidString
                delete.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "删除收藏")
                delete.isBordered = false
                delete.widthAnchor.constraint(equalToConstant: 28).isActive = true
                row.addArrangedSubview(delete)
            }
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            row.heightAnchor.constraint(equalToConstant: 48).isActive = true
        }
        if entries.isEmpty {
            let empty = NSTextField(wrappingLabelWithString: selectedTab == 1 ? "还没有生成记录。先去生成一个二维码吧。" : "还没有收藏。生成二维码后，点击星标保存。")
            empty.textColor = .secondaryLabelColor
            rows.addArrangedSubview(empty)
        }
        s.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 340).isActive = true
        if selectedTab == 1 { s.addArrangedSubview(NSButton(title: "清空最近生成", target: self, action: #selector(clearList))) }
        activate(w)
    }

    private func activate(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func manualInput() {
        selectedTab = 0
        let w = makeWindow(title: "QuickQR · 本地二维码")
        let s = stack(in: w)
        let heading = NSTextField(labelWithString: "让手机，接住这段内容")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        s.addArrangedSubview(heading)
        let label = NSTextField(wrappingLabelWithString: "粘贴网址或输入文本。内容只在本机编码，不访问网址。最近 10 条仅本次运行保留，手动收藏才保存到本机。")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        s.addArrangedSubview(label)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 12
        scroll.layer?.masksToBounds = true
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 388, height: 220))
        editor.isRichText = false
        editor.font = .systemFont(ofSize: 14)
        editor.textContainerInset = NSSize(width: 12, height: 12)
        editor.setAccessibilityLabel("需要生成二维码的原始文本")
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.autoresizingMask = [.width]
        scroll.documentView = editor
        s.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 220).isActive = true
        inputEditor = editor
        let button = NSButton(title: "生成二维码", target: self, action: #selector(generateInput))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.bezelColor = .systemBlue
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        s.addArrangedSubview(button)
        s.addArrangedSubview(NSButton(title: "从剪贴板生成", target: self, action: #selector(fromClipboard)))
        s.addArrangedSubview(NSTextField(wrappingLabelWithString: "也可在支持的应用中选中文字 → 服务 → 用 QuickQR 生成二维码。Esc 关闭窗口。"))
        activate(w)
        w.makeFirstResponder(editor)
    }
    private weak var inputEditor: NSTextView?
    @objc func generateInput() { show(inputEditor?.string) }

    private func show(_ text: String?) {
        do {
            let qr = try QRCode.make(text)
            displayedText = text
            selectedTab = 0
            library?.generated(text!)
            refreshMenu()
            let w = makeWindow(title: "QuickQR · 扫码")
            let s = stack(in: w)
            let image = NSImageView()
            image.image = NSImage(cgImage: qr, size: NSSize(width: qr.width, height: qr.height))
            image.imageScaling = .scaleNone
            image.setAccessibilityLabel("二维码，编码内容见下方原文")
            s.addArrangedSubview(image)
            image.widthAnchor.constraint(equalToConstant: CGFloat(qr.width)).isActive = true
            image.heightAnchor.constraint(equalToConstant: CGFloat(qr.height)).isActive = true
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            let original = NSTextView(frame: NSRect(x: 0, y: 0, width: 392, height: 72))
            original.isEditable = false
            original.isSelectable = true
            original.isRichText = false
            original.string = text!
            original.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            original.autoresizingMask = [.width]
            scroll.documentView = original
            s.addArrangedSubview(scroll)
            scroll.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
            scroll.heightAnchor.constraint(equalToConstant: 72).isActive = true
            s.addArrangedSubview(NSButton(title: "☆ 收藏…", target: self, action: #selector(saveFavorite)))
            s.addArrangedSubview(NSTextField(labelWithString: "本地生成 · Esc 关闭"))
            activate(w)
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "无法生成二维码"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }
}
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
