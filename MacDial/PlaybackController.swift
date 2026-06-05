

import Foundation
import AppKit

// https://stackoverflow.com/a/55854051
func HIDPostAuxKey(key: Int32, modifiers: [NSEvent.ModifierFlags], _repeat: Int = 1) {
    func doKey(down: Bool) {

        var rawFlags: UInt = (down ? 0xa00 : 0xb00);

        for modifier in modifiers {
            rawFlags |= modifier.rawValue
        }

        let flags = NSEvent.ModifierFlags(rawValue: rawFlags)

        let data1 = Int((key<<16) | (down ? 0xa00 : 0xb00))

        let ev = NSEvent.otherEvent(with: NSEvent.EventType.systemDefined,
                                    location: NSPoint(x:0,y:0),
                                    modifierFlags: flags,
                                    timestamp: 0,
                                    windowNumber: 0,
                                    context: nil,
                                    subtype: 8,
                                    data1: data1,
                                    data2: -1
                                    )
        let cev = ev?.cgEvent
        cev?.post(tap: CGEventTapLocation.cghidEventTap)
    }
    for _ in 0..<_repeat {
        doKey(down: true)
        doKey(down: false)
    }

}


class PlaybackController : Controller {

    var onLongPress: (() -> Void)?

    private let longPressDelay: TimeInterval = 1.0
    private var pendingLongPress: DispatchWorkItem?
    private var didLongPress = false
    var lastClick = Date().timeIntervalSince1970

    func onDown() {
        didLongPress = false

        let longPress = DispatchWorkItem { [weak self] in
            self?.pendingLongPress = nil
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
            return
        }

        let now = Date().timeIntervalSince1970
        let clickDelay = now - lastClick

        // Next song on double click
        if (clickDelay < 0.5) {
            // Undo pause sent on first click
            HIDPostAuxKey(key: NX_KEYTYPE_PLAY, modifiers: [], _repeat: 1)

            HIDPostAuxKey(key: NX_KEYTYPE_NEXT, modifiers: [])
        }
        else { // Play / Pause on single click

            HIDPostAuxKey(key: NX_KEYTYPE_PLAY, modifiers: [], _repeat: 1)
        }

        lastClick = Date().timeIntervalSince1970
    }



    func onRotate(_ rotation: Dial.Rotation,_ scrollDirection: Int) {

        let modifiers = [NSEvent.ModifierFlags.shift, NSEvent.ModifierFlags.option]

        switch (rotation) {
        case .Clockwise(let _repeat):
            HIDPostAuxKey(key: NX_KEYTYPE_SOUND_UP, modifiers: modifiers, _repeat: _repeat)
            break
        case .CounterClockwise(let _repeat):
            HIDPostAuxKey(key: NX_KEYTYPE_SOUND_DOWN, modifiers: modifiers, _repeat: _repeat)

            break
        }
    }


}
