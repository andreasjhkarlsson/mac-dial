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
    #if DEBUG
    private let isDebug: Bool = true
    #else
    private let isDebug: Bool = false
    #endif

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
        log(tag: "Media", "counting clicks: \(numberOfClicks)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard currentNumberOfClicks == numberOfClicks else { return }

            switch numberOfClicks {
                case 1:
                    send(key: NX_KEYTYPE_PLAY)
                    log(tag: "Media", "sent Play/Pause")
                case 2:
                    send(key: NX_KEYTYPE_NEXT)
                    log(tag: "Media", "sent Play Next")
                case 3 ... 1000:
                    send(key: NX_KEYTYPE_PREVIOUS)
                    log(tag: "Media", "sent Play Previous")
                default:
                    break
            }

            numberOfClicks = 0
        }
    }

    private func send(key: Int32, repeatCount: Int = 1) {
        guard !isDebug else { return }

        HIDPostAuxKey(key: key, modifiers: [], repeatCount: repeatCount)
    }

    private var lastRotationDirection: RotationState = .stationary

    func rotationChanged(_ rotation: RotationState) -> Bool {
        let step: Double = 1
        let coefficient = 0.2

        var key: Int32 = NX_KEYTYPE_SOUND_UP
        switch rotation {
            case .clockwise:
                key = NX_KEYTYPE_SOUND_UP
                if lastRotationDirection.amount <= 0 {
                    volumeLastSentValue = volumeAccumulator + rotation.amount * coefficient - step
                }
                lastRotationDirection = .clockwise(1)
            case .anticlockwise: key = NX_KEYTYPE_SOUND_DOWN
                if lastRotationDirection.amount >= 0 {
                    volumeLastSentValue = volumeAccumulator + rotation.amount * coefficient + step
                }
                lastRotationDirection = .anticlockwise(1)
            case .stationary:
                lastRotationDirection = .stationary
                return false
        }
        volumeAccumulator += rotation.amount * coefficient

        let volumeDiff = abs(volumeAccumulator - volumeLastSentValue)
        let clicks = floor(volumeDiff / step)

        if volumeDiff >= step {
            let sentValue = volumeLastSentValue + (key == NX_KEYTYPE_SOUND_UP ? 1 : -1) * (clicks * step)
            volumeLastSentValue = sentValue

            if !isDebug {
                let modifiers = [ NSEvent.ModifierFlags.shift, NSEvent.ModifierFlags.option ]
                HIDPostAuxKey(key: key, modifiers: modifiers, repeatCount: Int(clicks))
            }
            log(tag: "Media", "sent Volume \(key == NX_KEYTYPE_SOUND_UP ? "↑" : "↓")")
        } else {
//            log(tag: "Media", "not sent Volume: \(key == NX_KEYTYPE_SOUND_UP ? "↑" : "↓") -> \(volumeAccumulator.formatted(.number.precision(.fractionLength(2)))) / \(volumeLastSentValue.formatted(.number.precision(.fractionLength(2))))")
        }
        return true
    }
}
