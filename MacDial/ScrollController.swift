
import Foundation
import AppKit

class ScrollController: Controller
{
    enum MouseButton {
        case left
        case right
    }

    var onLongPress: (() -> Void)?

    private let doublePressDelay: TimeInterval = 0.35
    private let longPressDelay: TimeInterval = 1.0
    private var pendingSinglePress: DispatchWorkItem?
    private var pendingLongPress: DispatchWorkItem?
    private var isDoublePressCandidate = false
    private var didLongPress = false
    private let scrollEventSource = CGEventSource(stateID: .hidSystemState)

    private var mousePosition: CGPoint {
        if let event = CGEvent(source: nil) {
            return event.location
        }

        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        return CGPoint(x: mousePos.x, y: screenHeight - mousePos.y)
    }

    private func click(_ button: MouseButton) {
        let position = mousePosition
        let mouseButton: CGMouseButton = button == .left ? .left : .right

        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp

        CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: position, mouseButton: mouseButton)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: position, mouseButton: mouseButton)?.post(tap: .cghidEventTap)
    }

    func onDown() {
        if let pendingSinglePress = pendingSinglePress {
            pendingSinglePress.cancel()
            self.pendingSinglePress = nil
            isDoublePressCandidate = true
        }

        didLongPress = false

        let longPress = DispatchWorkItem { [weak self] in
            self?.pendingSinglePress?.cancel()
            self?.pendingSinglePress = nil
            self?.pendingLongPress = nil
            self?.isDoublePressCandidate = false
            self?.didLongPress = true
            self?.onLongPress?()
        }
        pendingLongPress = longPress
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDelay, execute: longPress)
    }

    func onUp() {
        pendingLongPress?.cancel()
        pendingLongPress = nil

        if didLongPress {
            didLongPress = false
            isDoublePressCandidate = false
            return
        }

        if isDoublePressCandidate {
            isDoublePressCandidate = false
            click(.right)
            return
        }

        let singlePress = DispatchWorkItem { [weak self] in
            self?.click(.left)
            self?.pendingSinglePress = nil
            self?.isDoublePressCandidate = false
        }
        pendingSinglePress = singlePress
        DispatchQueue.main.asyncAfter(deadline: .now() + doublePressDelay, execute: singlePress)
    }

    var lastRotate: TimeInterval = Date().timeIntervalSince1970

    func onRotate(_ rotation: Dial.Rotation,_ scrollDirection: Int) {
        var steps = 0
        switch rotation {
        case .Clockwise(let d):
            steps = d
        case .CounterClockwise(let d):
            steps = -d
        }

        steps *= scrollDirection;

        let diff = (Date().timeIntervalSince1970 - lastRotate) * 1000
        let multiplifer = Int(1 + ((150 - min(diff, 150)) / 40))


        let lineDelta = Int32(steps * multiplifer)
        let pixelDelta = lineDelta * 24
        let event = CGEvent(scrollWheelEvent2Source: scrollEventSource, units: .pixel, wheelCount: 1, wheel1: pixelDelta, wheel2: 0, wheel3: 0)
        event?.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(lineDelta))
        event?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(pixelDelta))
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        event?.post(tap: .cghidEventTap)

        lastRotate = Date().timeIntervalSince1970
    }
}
