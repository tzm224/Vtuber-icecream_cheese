import AppKit
import CoreGraphics
import CheeseCore

final class PetController: NSObject {
    private let assets: SpriteAssets
    private let defaults = UserDefaults.standard
    private let window: PetPanel
    private let petView: PetView
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var currentState = "idle"
    private var stateStarted = ProcessInfo.processInfo.systemUptime
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var interactionUntil = 0.0
    private var bubbleUntil = 0.0
    private var nextWalk = ProcessInfo.processInfo.systemUptime + 12
    private var walkTarget: Double?
    private var paused = false
    private var hidden = false
    private var lastMouse = NSEvent.mouseLocation
    private var mouseMovedAt = 0.0
    private var isMenuOpen = false

    private var roaming: Bool {
        get { defaults.bool(forKey: "roaming") }
        set { defaults.set(newValue, forKey: "roaming") }
    }
    private var followsMouse: Bool {
        get { defaults.bool(forKey: "followsMouse") }
        set { defaults.set(newValue, forKey: "followsMouse") }
    }

    init(assets: SpriteAssets) {
        self.assets = assets
        petView = PetView(assets: assets)
        window = PetPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        super.init()
        defaults.register(defaults: ["roaming": true, "followsMouse": true, "scale": 1.0])
        petView.controller = self
        let savedScale = defaults.double(forKey: "scale")
        petView.scale = [0.75, 1.0, 1.25].contains(savedScale) ? savedScale : 1.0
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = petView
        window.setContentSize(petSize)
        restorePosition()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "雪糕cheese 桌宠")
        statusItem.button?.toolTip = "雪糕cheese · 点我打开菜单"
        refreshMenu()
        window.orderFrontRegardless()
        say("雪糕来陪你啦 ♡", seconds: 3)
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    private var petSize: NSSize {
        NSSize(width: assets.manifest.logicalCellWidth * petView.scale,
               height: assets.manifest.logicalCellHeight * petView.scale + petView.bubbleHeight)
    }

    private var activeScreen: NSScreen? {
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func restorePosition() {
        if defaults.object(forKey: "positionX") != nil {
            let saved = NSPoint(x: defaults.double(forKey: "positionX"), y: defaults.double(forKey: "positionY"))
            let center = NSPoint(x: saved.x + petSize.width / 2, y: saved.y + petSize.height / 2)
            if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
                window.setFrameOrigin(PetGeometry.clampedOrigin(saved, size: petSize, inside: screen.visibleFrame))
                return
            }
        }
        resetPosition()
    }

    private func savePosition() {
        defaults.set(window.frame.minX, forKey: "positionX")
        defaults.set(window.frame.minY, forKey: "positionY")
    }

    @objc private func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let desired = NSPoint(x: frame.maxX - petSize.width - 48, y: frame.minY + 12)
        window.setFrameOrigin(PetGeometry.clampedOrigin(desired, size: petSize, inside: frame))
        walkTarget = nil
        nextWalk = ProcessInfo.processInfo.systemUptime + 10
        savePosition()
    }

    @objc private func screenChanged() {
        guard let screen = activeScreen else { return }
        window.setFrameOrigin(PetGeometry.clampedOrigin(window.frame.origin, size: petSize, inside: screen.visibleFrame))
        walkTarget = nil
        savePosition()
    }

    @objc private func didWake() {
        lastTick = ProcessInfo.processInfo.systemUptime
        nextWalk = lastTick + 10
        screenChanged()
    }

    func beginDragging() { walkTarget = nil }

    func endDragging() {
        screenChanged()
        nextWalk = ProcessInfo.processInfo.systemUptime + 10
    }

    func interact(doubleClick: Bool) {
        play(doubleClick ? "jumping" : "waving",
             message: doubleClick ? "好耶！元气补充完毕 ✨" : ["今天也要开心呀 ♡", "摸摸头，充个电～", "我会一直陪着你～"].randomElement()!)
    }

    private func play(_ state: String, message: String) {
        walkTarget = nil
        let now = ProcessInfo.processInfo.systemUptime
        interactionUntil = now + max(2.2, (assets.manifest.animations[state]?.duration ?? 1) * 2)
        nextWalk = interactionUntil + Double.random(in: 6...12)
        setState(state, now: now, restart: true)
        say(message, seconds: 3)
    }

    private func say(_ message: String, seconds: Double) {
        petView.bubble = message
        bubbleUntil = ProcessInfo.processInfo.systemUptime + seconds
        petView.needsDisplay = true
    }

    private func setState(_ state: String, now: Double, restart: Bool = false) {
        if currentState != state || restart {
            currentState = state
            stateStarted = now
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick
        lastTick = now
        guard !hidden else { return }
        // Update click-through after this tick's movement/frame change, including early exits.
        defer {
            if !petView.isDragging && !isMenuOpen {
                let point = petView.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
                window.ignoresMouseEvents = !petView.hasOpaquePixel(at: point)
            }
        }
        if petView.bubble != nil && now >= bubbleUntil { petView.bubble = nil; petView.needsDisplay = true }
        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) > 2 {
            mouseMovedAt = now
            lastMouse = mouse
        }
        guard !petView.isDragging && !isMenuOpen else { return }

        if now >= interactionUntil {
            if !paused && roaming, let screen = activeScreen {
                if walkTarget == nil && now >= nextWalk {
                    let minX = Double(screen.visibleFrame.minX)
                    let maxX = Double(max(screen.visibleFrame.minX, screen.visibleFrame.maxX - petSize.width))
                    walkTarget = Double.random(in: minX...maxX)
                }
                if let target = walkTarget {
                    let x = Double(window.frame.minX)
                    let next = PetGeometry.walkingStep(x: x, target: target, speed: 34, dt: dt)
                    window.setFrameOrigin(NSPoint(x: next, y: window.frame.minY))
                    setState(target >= x ? "running-right" : "running-left", now: now)
                    if abs(target - next) < 0.5 {
                        walkTarget = nil
                        nextWalk = now + Double.random(in: 8...18)
                        savePosition()
                        setState("idle", now: now)
                    }
                } else { setState("idle", now: now) }
            } else { walkTarget = nil; setState("idle", now: now) }
        }

        let animation = assets.manifest.animations[currentState] ?? assets.manifest.animations["idle"]!
        var row = animation.row
        var column = animation.frame(at: paused && now >= interactionUntil ? 0 : now - stateStarted)
        if followsMouse && !paused && currentState == "idle" && now - mouseMovedAt < 1.2 && now >= interactionUntil {
            let center = NSPoint(x: window.frame.midX, y: window.frame.minY + assets.manifest.logicalCellHeight * petView.scale * 0.68)
            let dx = Double(mouse.x - center.x)
            let dy = Double(mouse.y - center.y)
            if hypot(dx, dy) > 55 && hypot(dx, dy) < 1_200 {
                let index = PetGeometry.lookIndex(dx: dx, dy: dy)
                let direction = assets.manifest.lookDirections[index]
                row = direction.row
                column = direction.column
            }
        }
        if row != petView.spriteRow || column != petView.spriteColumn {
            petView.spriteRow = row
            petView.spriteColumn = column
            petView.needsDisplay = true
        }
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "雪糕cheese")
        menu.delegate = self
        let title = NSMenuItem(title: "雪糕cheese · 桌面小伙伴", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        addItem("打个招呼 ♡", action: #selector(wave), to: menu)
        addItem("蹦蹦跳跳", action: #selector(jump), to: menu)
        addItem("陪我工作", action: #selector(work), to: menu)
        addItem("歪头等你", action: #selector(waitForYou), to: menu)
        addItem("认真看看", action: #selector(review), to: menu)
        addItem("需要安慰", action: #selector(comfort), to: menu)
        menu.addItem(.separator())
        addItem("自动散步", action: #selector(toggleRoaming), to: menu, checked: roaming)
        addItem("视线跟随鼠标", action: #selector(toggleGaze), to: menu, checked: followsMouse)
        addItem(paused ? "继续活动" : "暂停活动", action: #selector(togglePause), to: menu)
        let sizeMenu = NSMenu(title: "大小")
        for (label, value) in [("小巧 · 75%", 0.75), ("标准 · 100%", 1.0), ("大只 · 125%", 1.25)] {
            let item = addItem(label, action: #selector(resize(_:)), to: sizeMenu, checked: petView.scale == value)
            item.representedObject = value
        }
        let sizeItem = NSMenuItem(title: "桌宠大小", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        addItem("回到当前屏幕右下角", action: #selector(resetPosition), to: menu)
        addItem(hidden ? "显示桌宠" : "暂时隐藏", action: #selector(toggleHidden), to: menu)
        menu.addItem(.separator())
        addItem("关于与使用说明", action: #selector(about), to: menu)
        addItem("退出桌宠", action: #selector(quit), to: menu, key: "q")
        return menu
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, to menu: NSMenu,
                         checked: Bool = false, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.state = checked ? .on : .off
        menu.addItem(item)
        return item
    }

    private func refreshMenu() { statusItem?.menu = makeMenu() }
    @objc private func wave() { play("waving", message: "嗨，今天也辛苦啦 ♡") }
    @objc private func jump() { play("jumping", message: "起跳！烦恼都飞走～") }
    @objc private func work() { play("running", message: "好，陪你认真一会儿！") }
    @objc private func waitForYou() { play("waiting", message: "不着急，我等你呀～") }
    @objc private func review() { play("review", message: "让我认真看看……") }
    @objc private func comfort() { play("failed", message: "抱抱，慢慢来也没关系 ♡") }
    @objc private func toggleRoaming() { roaming.toggle(); walkTarget = nil; nextWalk = ProcessInfo.processInfo.systemUptime + 3; refreshMenu() }
    @objc private func toggleGaze() { followsMouse.toggle(); refreshMenu() }
    @objc private func togglePause() { paused.toggle(); walkTarget = nil; refreshMenu() }
    @objc private func resize(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        petView.scale = scale
        defaults.set(scale, forKey: "scale")
        window.setContentSize(petSize)
        screenChanged()
        petView.needsDisplay = true
        refreshMenu()
    }
    @objc private func toggleHidden() {
        hidden.toggle()
        if hidden { window.orderOut(nil) } else { window.orderFrontRegardless(); nextWalk = ProcessInfo.processInfo.systemUptime + 5 }
        refreshMenu()
    }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "雪糕cheese 桌宠"
        alert.informativeText = "单击打招呼 · 双击跳跃 · 拖动移动\n右键或菜单栏 ✨ 打开菜单\n透明区域可点击穿透，不抢键盘焦点。\n\n这是非官方同人作品，与角色权利人无隶属或代言关系。\n完全本地运行，无账号、联网、录音或数据上传。\n\n项目：github.com/tzm224/Vtuber-icecream_cheese"
        alert.addButton(withTitle: "知道啦")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    func stop() {
        timer?.invalidate()
        timer = nil
        savePosition()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

extension PetController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true; window.ignoresMouseEvents = false }
    func menuDidClose(_ menu: NSMenu) { isMenuOpen = false; lastTick = ProcessInfo.processInfo.systemUptime }
}
