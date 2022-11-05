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

    private var lastActionWasUp: Bool?

    func rotationChanged(_ rotation: RotationState) {
        let step: Double = 1
        let coefficient = 0.2

        var key: Int32 = NX_KEYTYPE_SOUND_UP
        switch rotation {
            case .clockwise:
                key = NX_KEYTYPE_SOUND_UP
                if lastActionWasUp != true {
                    volumeLastSentValue = volumeAccumulator + rotation.amount * coefficient - step
                }
                lastActionWasUp = true
            case .counterClockwise: key = NX_KEYTYPE_SOUND_DOWN
                if lastActionWasUp != false {
                    volumeLastSentValue = volumeAccumulator + rotation.amount * coefficient + step
                }
                lastActionWasUp = false
            case .stationary:
                lastActionWasUp = nil
                return
        }
        volumeAccumulator += rotation.amount * coefficient

        let volumeDiff = abs(volumeAccumulator - volumeLastSentValue)
        let clicks = floor(volumeDiff / step)

        if volumeDiff >= step {
            let sentValue = volumeLastSentValue + (key == NX_KEYTYPE_SOUND_UP ? 1 : -1) * (clicks * step)
            log("Volume: \(key == NX_KEYTYPE_SOUND_UP ? "↑" : "↓") -> \(volumeAccumulator.formatted(.number.precision(.fractionLength(2)))) / \(volumeLastSentValue.formatted(.number.precision(.fractionLength(2)))) -> \(sentValue.formatted(.number.precision(.fractionLength(2))))")
            volumeLastSentValue = sentValue

            DispatchQueue.main.async {
                let modifiers = [ NSEvent.ModifierFlags.shift, NSEvent.ModifierFlags.option ]
                HIDPostAuxKey(key: key, modifiers: modifiers, repeatCount: Int(clicks))
                log("\(key == NX_KEYTYPE_SOUND_UP ? "↑" : "↓")")
//                log("Media: \(key == NX_KEYTYPE_SOUND_UP ? "↑" : "↓") • \(clicks)")
            }
        } else {
            log("Volume: \(key == NX_KEYTYPE_SOUND_UP ? "↑" : "↓") -> \(volumeAccumulator.formatted(.number.precision(.fractionLength(2)))) / \(volumeLastSentValue.formatted(.number.precision(.fractionLength(2))))")
        }
    }
}
