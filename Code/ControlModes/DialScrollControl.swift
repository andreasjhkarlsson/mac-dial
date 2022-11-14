//
// ScrollControlMode
// MacDial
//
// Created by Alex Babaev on 28 January 2022.
//
// Based on Andreas Karlsson sources
// https://github.com/andreasjhkarlsson/mac-dial
//
// License: MIT
//

import AppKit

class DialScrollControl: DeviceControl {
    private let modifiers: NSEvent.ModifierFlags

    init(modifiers: NSEvent.ModifierFlags = []) {
        self.modifiers = modifiers
    }

    func buttonPress() {
    }

    func buttonRelease() {
    }

    private func sendMouse(eventType: CGEventType) {
        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let translatedMousePos = NSPoint(x: mousePos.x, y: screenHeight - mousePos.y)
        let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: translatedMousePos, mouseButton: .left)
        event?.post(tap: .cghidEventTap)

        log(tag: "Scroll", "sent mouse event: \(eventType.rawValue == CGEventType.leftMouseDown.rawValue ? "left down" : "left up")")
    }

    private var lastRotate: TimeInterval = Date().timeIntervalSince1970

    func rotationChanged(_ rotation: RotationState) -> Bool {
        guard rotation != .stationary else { return false }

        let diff = (Date().timeIntervalSince1970 - lastRotate) * 1000
        let multiplier = Double(1.0 + ((150.0 - min(diff, 150.0)) / 40.0))
        let steps: Int32 = Int32(floor(rotation.amount * multiplier))

        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: steps, wheel2: 0, wheel3: 0)
        event?.post(tap: .cghidEventTap)
        log(tag: "Scroll", "sent scroll event: \(steps) steps")

        lastRotate = Date().timeIntervalSince1970
        return true
    }
}
