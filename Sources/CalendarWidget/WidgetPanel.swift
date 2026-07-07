import AppKit
import SwiftUI

/// 最前面・クリック透過のウィジェットパネルを管理する。
final class WidgetController {
    let panel: NSPanel
    private var hoverTimer: Timer?
    private var isHovering = false

    static let defaultSize = NSSize(width: 260, height: 540)

    init(service: CalendarService) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.alphaValue = Settings.shared.baseOpacity

        let hosting = NSHostingView(rootView: WidgetView(service: service))
        panel.contentView = hosting

        positionInitially()
        panel.setFrameAutosaveName("CalendarWidgetPanel")

        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.updateHoverState()
        }

        if Settings.shared.widgetVisible {
            panel.orderFrontRegardless()
        }
    }

    private func positionInitially() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - Self.defaultSize.width - 16,
            y: visible.maxY - Self.defaultSize.height - 16
        )
        panel.setFrameOrigin(origin)
    }

    private func updateHoverState() {
        guard panel.isVisible else { return }
        let inside = panel.frame.contains(NSEvent.mouseLocation)
        guard inside != isHovering else { return }
        isHovering = inside
        panel.ignoresMouseEvents = !inside
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = inside ? 0.95 : Settings.shared.baseOpacity
        }
    }

    // MARK: メニューから呼ばれる操作

    var isShown: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
        Settings.shared.widgetVisible = true
    }

    func hide() {
        panel.orderOut(nil)
        Settings.shared.widgetVisible = false
    }

    func applyBaseOpacity() {
        if !isHovering {
            panel.alphaValue = Settings.shared.baseOpacity
        }
    }

    func resetPosition() {
        positionInitially()
        panel.orderFrontRegardless()
    }
}
