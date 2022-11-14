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

class ButtonPlaybackControl: DeviceControl {
    #if DEBUG
    private let isDebug: Bool = true
    #else
    private let isDebug: Bool = false
    #endif

    func buttonPress() {
    }

    private var numberOfClicks: Int = 0
    private var accumulator: Double = 0
    private var lastSentValue: Double = 0
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

    func rotationChanged(_ rotation: RotationState) -> Bool {
        false
    }
}
