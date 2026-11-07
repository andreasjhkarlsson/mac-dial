
import Foundation
import AppKit

/// Zoom controller.
///
/// macOS has no public API for synthesizing a true `NSEventTypeMagnify`
/// event — AppKit exposes `NSEvent.magnification` for *reading* such events,
/// and CoreGraphics has no gesture event type at all. The public, supported
/// way to trigger a system zoom is the ⌘-modifier + scroll gesture, which
/// every zoomable view (Safari, Preview, Xcode, Pages, Maps...) honours.
///
/// So: post a scroll-wheel event carrying the ⌘ modifier flag. The scroll
/// delta is derived from the dial's wheel sensitivity so one notch maps to a
/// sensible zoom step, and the same acceleration model as ScrollController is
/// applied so fast spins zoom faster.
class ZoomController: Controller {

    private func sendZoom(steps: Int) {
        guard steps != 0 else { return }

        // Magnification is positive when zooming IN. Clockwise on a dial is
        // "up" in the same sense as scrolling up, so clockwise == zoom in.
        let event = CGEvent(scrollWheelEvent2Source: nil,
                            units: .line,
                            wheelCount: 1,
                            wheel1: Int32(steps),
                            wheel2: 0,
                            wheel3: 0)

        // ⌘ + scroll is the system zoom gesture.
        event?.flags = .maskCommand
        event?.post(tap: .cghidEventTap)
    }

    func onDown() {
    }

    func onUp() {
    }

    var lastRotate: TimeInterval = Date().timeIntervalSince1970

    func onRotate(_ rotation: Dial.Rotation, _ scrollDirection: Int) {
        var steps = 0
        switch rotation {
        case .Clockwise(let d):
            steps = d
        case .CounterClockwise(let d):
            steps = -d
        }

        // scrollDirection is -1 for "natural". For zoom we want clockwise to
        // always mean zoom-in regardless of the scroll preference, so we take
        // the absolute value of the dial's direction sign out of the equation
        // by using our own mapping and ignoring scrollDirection.
        steps = abs(steps)

        // Same acceleration model as ScrollController: quick flicks move more.
        let diff = (Date().timeIntervalSince1970 - lastRotate) * 1000
        let multiplier = Int(1 + ((150 - min(diff, 150)) / 40))

        sendZoom(steps: steps * multiplier)

        lastRotate = Date().timeIntervalSince1970
    }
}
