import AppKit
import CoreGraphics

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    let assets: SpriteAssets
    weak var controller: PetController?
    var spriteRow = 0
    var spriteColumn = 0
    var scale: Double = 1.0
    var bubble: String?
    var isDragging = false
    private var mouseDownAt: NSPoint = .zero
    private var windowDownAt: NSPoint = .zero
    private var moved = false

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    var bubbleHeight: Double { 66 }
    var spriteRect: NSRect {
        NSRect(x: 0, y: bubbleHeight, width: assets.manifest.logicalCellWidth * scale,
               height: assets.manifest.logicalCellHeight * scale)
    }

    init(assets: SpriteAssets) {
        self.assets = assets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func hasOpaquePixel(at point: NSPoint) -> Bool {
        let rect = spriteRect
        return assets.isOpaque(row: spriteRow, column: spriteColumn,
                               x: (point.x - rect.minX) / rect.width * Double(assets.manifest.cellWidth),
                               y: (point.y - rect.minY) / rect.height * Double(assets.manifest.cellHeight))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.current?.imageInterpolation = .high
        assets.image(row: spriteRow, column: spriteColumn)?.draw(in: spriteRect, from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if let bubble {
            let rect = NSRect(x: 7, y: 8, width: bounds.width - 14, height: 45)
            NSColor(calibratedWhite: 1, alpha: 0.96).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 15, yRadius: 15).fill()
            NSColor(calibratedRed: 0.75, green: 0.53, blue: 0.45, alpha: 0.35).setStroke()
            NSBezierPath(roundedRect: rect, xRadius: 15, yRadius: 15).stroke()
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byWordWrapping
            let textRect = rect.insetBy(dx: 7, dy: 8)
            (bubble as NSString).draw(in: textRect, withAttributes: [
                .font: NSFont.systemFont(ofSize: scale < 1 ? 10 : 12, weight: .medium),
                .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.25, blue: 0.24, alpha: 1),
                .paragraphStyle: style
            ])
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        mouseDownAt = NSEvent.mouseLocation
        windowDownAt = window.frame.origin
        moved = false
        isDragging = true
        controller?.beginDragging()
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - mouseDownAt.x
        let dy = current.y - mouseDownAt.y
        if hypot(dx, dy) > 4 { moved = true }
        window?.setFrameOrigin(NSPoint(x: windowDownAt.x + dx, y: windowDownAt.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        controller?.endDragging()
        if !moved { controller?.interact(doubleClick: event.clickCount >= 2) }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = controller?.makeMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
