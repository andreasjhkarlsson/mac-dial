
import Foundation
import AppKit
import CoreVideo

/// The modes the Surface Dial can drive.
enum DialMode: String, CaseIterable {
    case scroll = "Scroll"
    case zoom = "Zoom"
    case volume = "Volume"
    case seek = "Seek"

    var title: String { rawValue }

    var symbolName: String {
        switch self {
        case .scroll: return "arrow.up.arrow.down"
        case .zoom:   return "plus.magnifyingglass"
        case .volume: return "speaker.wave.2"
        case .seek:   return "forward.end.alt"
        }
    }
}

/// Radial menu view — a dark disc with one segment per mode.
///
/// Mirrors the Windows RadialControl layout: a dark circle, an annulus of
/// segments around a lighter centre circle, the selected segment drawn in a
/// lighter grey with a blue accent arc on the outer rim, an SF Symbol in
/// each segment, and the active mode's name in the middle.
///
/// Each choice owns a fixed 45° arc. The choices therefore occupy only the
/// upper half of the circle rather than filling it completely.
class RadialMenuView: NSView {

    private let modes: [DialMode]
    private var selectedIndex: Int = 0

    /// Eased index so the highlight glides between segments instead of jumping.
    private var animatedIndex: CGFloat = 0
    private var animationTimer: Timer?

    // Geometry
    private let outerRadius: CGFloat = 112
    private let innerRadius: CGFloat = 60
    private let centerRadius: CGFloat = 56
    private let segmentGap: CGFloat = 4      // degrees of gap on each side
    private let accentWidth: CGFloat = 6

    /// Degrees of the circle owned by each choice.
    private let segmentAngle: CGFloat = 45

    // Colours
    private let discColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1.0)
    private let selectedColor = NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.25, alpha: 1.0)
    private let centerColor = NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
    private let accentColor = NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
    private let separatorColor = NSColor(calibratedWhite: 0.0, alpha: 0.35)

    var onPick: ((Int) -> Void)?

    init(modes: [DialMode], selectedIndex: Int) {
        self.modes = modes
        self.selectedIndex = selectedIndex
        self.animatedIndex = CGFloat(selectedIndex)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 260))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopAnimating()
    }

    // MARK: - Selection

    func setSelectedIndex(_ index: Int) {
        guard modes.indices.contains(index) else { return }
        selectedIndex = index
        startAnimating()
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.stepAnimation()
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func stepAnimation() {
        let target = CGFloat(selectedIndex)
        let delta = target - animatedIndex
        if abs(delta) < 0.002 {
            animatedIndex = target
            stopAnimating()
        } else {
            animatedIndex += delta * 0.28
        }
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        // Outer disc
        let disc = NSBezierPath(ovalIn: NSRect(x: center.x - outerRadius,
                                              y: center.y - outerRadius,
                                              width: outerRadius * 2,
                                              height: outerRadius * 2))
        discColor.setFill()
        disc.fill()

        // Selected segment (lighter wedge), interpolated between segments.
        let selectedAngle = self.angle(for: animatedIndex)
        let halfWidth = segmentAngle / 2.0 - segmentGap
        let wedge = NSBezierPath()
        wedge.appendArc(withCenter: center, radius: outerRadius,
                        startAngle: selectedAngle - halfWidth,
                        endAngle: selectedAngle + halfWidth,
                        clockwise: false)
        wedge.appendArc(withCenter: center, radius: innerRadius,
                        startAngle: selectedAngle + halfWidth,
                        endAngle: selectedAngle - halfWidth,
                        clockwise: true)
        wedge.close()
        selectedColor.setFill()
        wedge.fill()

        // Segment separators
        separatorColor.setStroke()
        for i in 0..<modes.count {
            let a = self.angle(for: CGFloat(i))
            let half = segmentAngle / 2.0
            for edge in [-half, half] {
                let rad = (a + edge) * .pi / 180
                let p1 = NSPoint(x: center.x + cos(rad) * innerRadius,
                                 y: center.y + sin(rad) * innerRadius)
                let p2 = NSPoint(x: center.x + cos(rad) * outerRadius,
                                 y: center.y + sin(rad) * outerRadius)
                let line = NSBezierPath()
                line.move(to: p1)
                line.line(to: p2)
                line.lineWidth = 1
                line.stroke()
            }
        }

        // Blue accent arc on the outer rim of the selected segment
        let accent = NSBezierPath()
        accent.appendArc(withCenter: center,
                         radius: outerRadius - accentWidth / 2,
                         startAngle: selectedAngle - halfWidth,
                         endAngle: selectedAngle + halfWidth,
                         clockwise: false)
        accent.lineWidth = accentWidth
        accent.lineCapStyle = .round
        accentColor.setStroke()
        accent.stroke()

        // Icons in each segment
        let iconRadius = (innerRadius + outerRadius) / 2 - 4
        for (i, mode) in modes.enumerated() {
            let a = self.angle(for: CGFloat(i)) * .pi / 180
            let position = NSPoint(x: center.x + cos(a) * iconRadius,
                                   y: center.y + sin(a) * iconRadius)
            drawIcon(mode, at: position, highlighted: i == selectedIndex)
        }

        // Centre circle
        let centreCircle = NSBezierPath(ovalIn: NSRect(x: center.x - centerRadius,
                                                        y: center.y - centerRadius,
                                                        width: centerRadius * 2,
                                                        height: centerRadius * 2))
        centerColor.setFill()
        centreCircle.fill()

        // Mode name in the centre
        drawCenterLabel(mode: modes[selectedIndex], center: center)
    }

    /// Segment 0 sits at the top; the rest go clockwise.
    ///
    /// Each choice owns a fixed `segmentAngle` (45°) slot. The slots are laid
    /// out in the upper half of the circle, centred on the vertical axis, so
    /// the menu forms a fan instead of filling the whole circle.
    private func angle(for index: CGFloat) -> CGFloat {
        let count = CGFloat(modes.count)
        // Total sweep the choices occupy.
        let total = segmentAngle * count
        // Start angle of the first slot: the fan is centred on the top (90°).
        let start = 90.0 + total / 2.0
        return start - (index + 0.5) * segmentAngle
    }

    private func drawIcon(_ mode: DialMode, at point: NSPoint, highlighted: Bool) {
        let size = NSSize(width: 26, height: 26)
        guard let symbol = Self.symbol(for: mode) else { return }

        // Tint the symbol white (selected) or light grey (unselected).
        // SF Symbols are templates, so drawing them with a fill colour
        // applied on top via .sourceAtop gives a solid tinted glyph.
        let tint = highlighted
            ? NSColor.white
            : NSColor(calibratedWhite: 0.72, alpha: 1.0)

        let tinted = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect,
                        from: NSRect(origin: .zero, size: size),
                        operation: .sourceOver,
                        fraction: 1.0)
            tint.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }

        tinted.draw(at: NSPoint(x: point.x - size.width / 2,
                                y: point.y - size.height / 2),
                    from: NSRect(origin: .zero, size: size),
                    operation: .sourceOver,
                    fraction: 1.0)
    }

    private func drawCenterLabel(mode: DialMode, center: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 19, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let text = mode.title as NSString
        let textSize = text.size(withAttributes: attributes)
        let origin = NSPoint(x: center.x - textSize.width / 2,
                             y: center.y - textSize.height / 2)
        text.draw(at: origin, withAttributes: attributes)
    }

    private static func symbol(for mode: DialMode) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: mode.symbolName, accessibilityDescription: nil)
        }
        return nil
    }

    // MARK: - Mouse

    override func mouseUp(with event: NSEvent) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let location = convert(event.locationInWindow, from: nil)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance >= innerRadius, distance <= outerRadius else { return }

        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        // Find the slot whose centre is closest to the click angle.
        var bestIndex = -1
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for i in 0..<modes.count {
            let centre = self.angle(for: CGFloat(i))
            var delta = abs(centre - degrees)
            if delta > 180 { delta = 360 - delta }
            if delta < bestDistance {
                bestDistance = delta
                bestIndex = i
            }
        }

        // Only pick when the click landed inside the slot (allowing for the
        // visual gap between slots).
        guard bestIndex >= 0, bestDistance <= segmentAngle / 2.0 - segmentGap else { return }

        setSelectedIndex(bestIndex)
        onPick?(bestIndex)
    }
}

/// The on-screen mode picker.
///
/// Shown when the dial's button is pressed. The user rotates the dial to
/// move the selection highlight around the radial menu, then presses the
/// button again to confirm.
class ModePickerPanel: NSObject {

    private let panel: NSPanel
    private let menuView: RadialMenuView
    private let hintLabel = NSTextField(labelWithString: "Rotate to choose · click again to confirm")

    private var modes: [DialMode] = DialMode.allCases
    private(set) var selectedIndex: Int = 0

    /// Number of detents that must be turned before the selection moves to
    /// the next mode. Higher values make the picker less sensitive.
    var stepsPerMode: Int = 1

    /// Detents turned since the last selection change.
    private var pendingSteps: Int = 0

    /// Called when the user confirms a mode with a second button press.
    var onConfirm: ((DialMode) -> Void)?
    /// Called when the panel is dismissed without confirming.
    var onCancel: (() -> Void)?

    private var hideTimer: Timer?
    private var confirmed = false

    override init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 284),
                        styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                        backing: .buffered,
                        defer: false)
        let view = RadialMenuView(modes: DialMode.allCases, selectedIndex: 0)
        menuView = view
        super.init()

        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 284))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        view.frame = NSRect(x: 0, y: 24, width: 260, height: 260)
        container.addSubview(view)

        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.textColor = NSColor(calibratedWhite: 0.75, alpha: 1.0)
        hintLabel.alignment = .center
        hintLabel.frame = NSRect(x: 0, y: 0, width: 260, height: 16)
        container.addSubview(hintLabel)

        panel.contentView = container

        view.onPick = { [weak self] index in
            guard let self = self else { return }
            self.selectedIndex = index
            self.confirm()
        }
    }

    // MARK: - Public API

    /// Move the selection by `delta` steps (positive = next mode).
    ///
    /// The dial can be very twitchy, so detents are accumulated and the
    /// selection only moves once `stepsPerMode` detents have been turned.
    func moveSelection(by delta: Int) {
        guard !modes.isEmpty else { return }
        guard delta != 0 else { return }

        pendingSteps += delta

        let threshold = max(1, stepsPerMode)
        // Move once the accumulated detents reach the threshold, then carry
        // the remainder over so the dial stays responsive over long turns.
        while abs(pendingSteps) >= threshold {
            let direction = pendingSteps > 0 ? 1 : -1
            pendingSteps -= direction * threshold

            let count = modes.count
            selectedIndex = ((selectedIndex + direction) % count + count) % count
            menuView.setSelectedIndex(selectedIndex)
            pulse()
        }

        // Keep the menu open while the user is choosing.
        scheduleHide()
    }

    func select(index: Int) {
        guard modes.indices.contains(index) else { return }
        selectedIndex = index
        pendingSteps = 0
        menuView.setSelectedIndex(index)
    }

    var currentMode: DialMode { modes[selectedIndex] }

    /// Show the panel near the mouse cursor.
    func show() {
        confirmed = false

        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2,
                             y: mouse.y - size.height - 24)
        // Keep it on screen
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            let visible = screen.visibleFrame
            if origin.y < visible.minY { origin.y = mouse.y + 24 }
            if origin.y + size.height > visible.maxY { origin.y = visible.maxY - size.height }
            if origin.x < visible.minX { origin.x = visible.minX }
            if origin.x + size.width > visible.maxX { origin.x = visible.maxX - size.width }
        }
        panel.setFrameOrigin(origin)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        scheduleHide()
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    /// Dim the panel briefly while the user is turning the dial.
    private func pulse() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            panel.animator().alphaValue = 0.82
        }
        scheduleHide()
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        // The menu stays open until the user rotates to a mode and clicks
        // again, so it needs a longer idle timeout than a transient popup.
        hideTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.confirmed {
                self.onCancel?()
            }
            self.hide()
        }
    }

    /// Confirm the current selection.
    func confirm() {
        confirmed = true
        hideTimer?.invalidate()
        hideTimer = nil
        let mode = currentMode
        hide()
        onConfirm?(mode)
    }

    deinit {
        hideTimer?.invalidate()
    }
}
