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

class DialKeysUpDownControl: DeviceControl {
    #if DEBUG
    private let isDebug: Bool = true
    #else
    private let isDebug: Bool = false
    #endif

    private let modifiers: NSEvent.ModifierFlags
    private let useModifiersWhenExternalDisplayIsMain: Bool
    private let modifiersDetector = ModifiersDetector()

    private let buttonUpKeyCode: Int32
    private let buttonDownKeyCode: Int32

    init(
        buttonUpKeyCode: Int32,
        buttonDownKeyCode: Int32,
        modifiers: NSEvent.ModifierFlags = [],
        useModifiersWhenExternalDisplayIsMain: Bool = false
    ) {
        self.modifiers = modifiers
        self.useModifiersWhenExternalDisplayIsMain = useModifiersWhenExternalDisplayIsMain
        self.buttonUpKeyCode = buttonUpKeyCode
        self.buttonDownKeyCode = buttonDownKeyCode
    }

    func buttonPress() {
    }

    func buttonRelease() {
    }

    private var accumulator: Double = 0
    private var lastSentValue: Double = 0
    private var lastRotationDirection: RotationState = .stationary

    func rotationChanged(_ rotation: RotationState) -> Bool {
        let step: Double = 1
        let coefficient = 0.2

        var key: Int32 = buttonUpKeyCode
        switch rotation {
            case .clockwise:
                key = buttonUpKeyCode
                if lastRotationDirection.amount <= 0 {
                    lastSentValue = accumulator + rotation.amount * coefficient - step
                }
                lastRotationDirection = .clockwise(1)
            case .anticlockwise:
                key = buttonDownKeyCode
                if lastRotationDirection.amount >= 0 {
                    lastSentValue = accumulator + rotation.amount * coefficient + step
                }
                lastRotationDirection = .anticlockwise(1)
            case .stationary:
                lastRotationDirection = .stationary
                return false
        }
        accumulator += rotation.amount * coefficient

        let valueDiff = abs(accumulator - lastSentValue)
        let clicks = floor(valueDiff / step)

        if valueDiff >= step {
            let sentValue = lastSentValue + (isUp(key) ? 1 : -1) * (clicks * step)
            lastSentValue = sentValue

            let modifiers = detectedModifiers
            if !isDebug {
                HIDPostAuxKey(key: key, modifiers: modifiers, repeatCount: Int(clicks))
            }
            log(tag: "Media", "sent \(isUp(key) ? "↑" : "↓")")
        } else {
//            log(tag: "Media", "not sent \(key == buttonUpKeyCode ? "↑" : "↓") -> \(volumeAccumulator.formatted(.number.precision(.fractionLength(2)))) / \(volumeLastSentValue.formatted(.number.precision(.fractionLength(2))))")
        }
        return true
    }

    private var detectedModifiers: NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        if useModifiersWhenExternalDisplayIsMain {
            let description: NSDeviceDescriptionKey = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
            let externalDisplays = NSScreen.screens.filter {
                guard let deviceID = $0.deviceDescription[description] as? NSNumber else { return false }
                return CGDisplayIsBuiltin(deviceID.uint32Value) == 0
            }
            if !externalDisplays.isEmpty {
                modifiers = self.modifiers
            }
        } else {
            modifiers = self.modifiers
        }

        modifiers = modifiers.symmetricDifference(modifiersDetector.currentModifiers)

        return modifiers
    }

    private func isUp(_ key: Int32) -> Bool {
        key == buttonUpKeyCode
    }
}
