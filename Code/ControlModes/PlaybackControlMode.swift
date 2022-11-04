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
    private var volumeAccumulator: Double = 0
    private var volumeLastSentValue: Double = 0
    private var lastClickTime: TimeInterval = Date.timeIntervalSinceReferenceDate

    func buttonRelease() {
        let currentNumberOfClicks = numberOfClicks + 1
        numberOfClicks = currentNumberOfClicks
        lastClickTime = Date.timeIntervalSinceReferenceDate
        log("Media: Counting clicks: \(numberOfClicks)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard currentNumberOfClicks == numberOfClicks else { return }

            switch numberOfClicks {
                case 1:
                    HIDPostAuxKey(key: NX_KEYTYPE_PLAY, modifiers: [], repeatCount: 1)
                    log("Media: Play/Pause")
                case 2:
                    HIDPostAuxKey(key: NX_KEYTYPE_NEXT, modifiers: [])
                    log("Media: Play Next")
                case 3 ... 1000:
                    HIDPostAuxKey(key: NX_KEYTYPE_PREVIOUS, modifiers: [])
                    log("Media: Play Previous")
                default:
                    break
            }

            numberOfClicks = 0
        }
    }

    func rotationChanged(_ rotation: RotationState) {
        let coefficient = 1.0
        switch rotation {
            case .clockwise(let amount):
                volumeAccumulator += amount * coefficient
                log("Media: Rotated cw; \(amount)")
            case .counterClockwise(let amount):
                volumeAccumulator -= amount * coefficient
                log("Media: Rotated ccw; \(amount)")
        }
        log("Media: volume accumulator: \(volumeAccumulator)")

        if abs(volumeAccumulator - volumeLastSentValue) > 1 {
            let key: Int32 = volumeAccumulator > volumeLastSentValue ? NX_KEYTYPE_SOUND_UP : NX_KEYTYPE_SOUND_DOWN
            let clicks = floor(abs(volumeAccumulator - volumeLastSentValue))
            volumeLastSentValue = volumeAccumulator + (key == NX_KEYTYPE_SOUND_UP ? 1 : -1) * clicks
            log("Media: volume last sent value: \(volumeLastSentValue)")

            DispatchQueue.main.async {
                let modifiers = [ NSEvent.ModifierFlags.shift, NSEvent.ModifierFlags.option ]
                HIDPostAuxKey(key: key, modifiers: modifiers, repeatCount: Int(clicks))
                log("Media: Sound \(key == NX_KEYTYPE_SOUND_UP ? "up" : "down") by \(clicks)")
            }
        }
    }
}
