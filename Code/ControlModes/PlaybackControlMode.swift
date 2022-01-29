//
// PlaybackControlMode
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

// https://stackoverflow.com/a/55854051
func HIDPostAuxKey(key: Int32, modifiers: [NSEvent.ModifierFlags], repeatCount: Int = 1) {
    func doKey(down: Bool) {
        var rawFlags: UInt = (down ? 0xa00 : 0xb00);

        for modifier in modifiers {
            rawFlags |= modifier.rawValue
        }

        let flags = NSEvent.ModifierFlags(rawValue: rawFlags)

        let data1 = Int((key<<16) | (down ? 0xa00 : 0xb00))

        let ev = NSEvent.otherEvent(
            with: NSEvent.EventType.systemDefined,
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

    for _ in 0 ..< repeatCount {
        doKey(down: true)
        doKey(down: false)
    }
}

class PlaybackControlMode: DialDelegate, ControlMode {
    let image: NSImage = #imageLiteral(resourceName: "icon-playback")

    func buttonPress() {
    }

    private var numberOfClicks: Int = 0
    private var lastClickTime: TimeInterval = Date.timeIntervalSinceReferenceDate

    func buttonRelease() {
        let currentNumberOfClicks = numberOfClicks + 1
        numberOfClicks = currentNumberOfClicks
        lastClickTime = Date.timeIntervalSinceReferenceDate
        log("Counting clicks: \(numberOfClicks)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard currentNumberOfClicks == numberOfClicks else { return }
            
            switch self.numberOfClicks {
                case 1:
                    HIDPostAuxKey(key: NX_KEYTYPE_PLAY, modifiers: [], repeatCount: 1)
                    log("Play/Pause")
                case 2:
                    HIDPostAuxKey(key: NX_KEYTYPE_NEXT, modifiers: [])
                    log("Play Next")
                case 3 ... 1000:
                    HIDPostAuxKey(key: NX_KEYTYPE_PREVIOUS, modifiers: [])
                    log("Play Previous")
                default:
                    break
            }

            self.numberOfClicks = 0
        }
    }

    func rotationChanged(_ rotation: RotationState) {
        let modifiers = [NSEvent.ModifierFlags.shift, NSEvent.ModifierFlags.option]
        let clicks = Int(round(rotation.amount))

        switch (rotation) {
            case .clockwise:
                HIDPostAuxKey(key: NX_KEYTYPE_SOUND_UP, modifiers: modifiers, repeatCount: clicks)
                log("Sound up by \(clicks)")
            case .counterClockwise:
                HIDPostAuxKey(key: NX_KEYTYPE_SOUND_DOWN, modifiers: modifiers, repeatCount: clicks)
                log("Sound down by \(clicks)")
        }
    }
}
