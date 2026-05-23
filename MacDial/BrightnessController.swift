
import Foundation
import AppKit

class BrightnessController: Controller {
    func onDown() { }

    func onUp() { }

    func onRotate(_ rotation: Dial.Rotation, _ scrollDirection: Int) {
        switch rotation {
        case .Clockwise(let repeatCount):
            HIDPostAuxKey(key: NX_KEYTYPE_BRIGHTNESS_UP, modifiers: [], _repeat: repeatCount)
        case .CounterClockwise(let repeatCount):
            HIDPostAuxKey(key: NX_KEYTYPE_BRIGHTNESS_DOWN, modifiers: [], _repeat: repeatCount)
        }
    }
}
