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
import Carbon

class DialScrollControl: DeviceControl {
    private let withControl: Bool

    init(withControl: Bool = false) {
        self.withControl = withControl
    }

    func buttonPress() {
    }

    func buttonRelease() {
    }

    private var lastRotate: TimeInterval = Date().timeIntervalSince1970

    func rotationChanged(_ rotation: RotationState) -> Bool {
        guard rotation != .stationary else { return false }

        let diff = (Date().timeIntervalSince1970 - lastRotate) * 1000
        let multiplier = Double(1.0 + ((150.0 - min(diff, 150.0)) / 40.0))
        let steps: Int32 = Int32(floor(rotation.amount * multiplier))

        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: withControl ? .pixel : .line,
            wheelCount: 1,
            wheel1: steps,
            wheel2: 0,
            wheel3: 0
        )
        if withControl {
            scrollEvent?.flags = .maskControl
        }
        scrollEvent?.post(tap: .cghidEventTap)
        log(tag: "Scroll", "sent scroll event: \(steps) steps\(withControl ? " with Control" : "")")

        lastRotate = Date().timeIntervalSince1970
        return true
    }
}
