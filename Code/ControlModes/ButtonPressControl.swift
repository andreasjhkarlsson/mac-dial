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

class ButtonPressControl: DeviceControl {
    private let eventDownType: CGEventType
    private let eventUpType: CGEventType
    private var lastButtonState: ButtonState?

    init(eventDownType: CGEventType, eventUpType: CGEventType) {
        self.eventDownType = eventDownType
        self.eventUpType = eventUpType
    }

    func buttonPress() {
        if lastButtonState != .pressed {
            lastButtonState = .pressed
            sendMouse(eventType: eventDownType)
        }
    }

    func buttonRelease() {
        if lastButtonState != .released {
            lastButtonState = .released
            sendMouse(eventType: eventUpType)
        }
    }

    private func sendMouse(eventType: CGEventType) {
        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let translatedMousePos = NSPoint(x: mousePos.x, y: screenHeight - mousePos.y)
        let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: translatedMousePos, mouseButton: .left)
        event?.post(tap: .cghidEventTap)

        log(tag: "Scroll", "sent mouse event: \(eventType.rawValue)")
    }

    func rotationChanged(_ rotation: RotationState) -> Bool {
        return false
    }
}
