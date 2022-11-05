//
// ScrollControllMode
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

class ScrollControlMode: DialDelegate, ControlMode {
    let image: NSImage = #imageLiteral(resourceName: "icon-scroll")

    enum Direction {
        case up
        case down
    }

    func buttonPress() {
        sendMouse(eventType: .leftMouseDown)
    }

    func buttonRelease() {
        sendMouse(eventType: .leftMouseUp)
    }

    private func sendMouse(eventType: CGEventType) {
        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let translatedMousePos = NSPoint(x: mousePos.x, y: screenHeight - mousePos.y)
        let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: translatedMousePos, mouseButton: .left)
        event?.post(tap: .cghidEventTap)

        log("Mouse event: \(eventType.rawValue == CGEventType.leftMouseDown.rawValue ? "left down" : "left up")")
    }

    var lastRotate: TimeInterval = Date().timeIntervalSince1970

    func rotationChanged(_ rotation: RotationState) {
        let diff = (Date().timeIntervalSince1970 - lastRotate) * 1000
        let multiplier = Double(1.0 + ((150.0 - min(diff, 150.0)) / 40.0))
        let steps: Int32 = Int32(floor(rotation.amount * multiplier))

        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: steps, wheel2: 0, wheel3: 0)
        event?.post(tap: .cghidEventTap)
        log("Scroll event: \(steps)")

        lastRotate = Date().timeIntervalSince1970
    }
}
