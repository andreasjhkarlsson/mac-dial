//
// HID
// MacDial
//
// Created by Alex Babaev on 14 November 2022.
// Copyright © 2022 Alex Babaev. All rights reserved.
//

import AppKit

// https://stackoverflow.com/a/55854051
func HIDPostAuxKey(key: Int32, modifiers: NSEvent.ModifierFlags, repeatCount: Int = 1) {
    func doKey(down: Bool) {
        var rawFlags: UInt = (down ? 0xa00 : 0xb00);
        rawFlags |= modifiers.rawValue
        let flags = NSEvent.ModifierFlags(rawValue: rawFlags)

        let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
        let event = NSEvent.otherEvent(
            with: NSEvent.EventType.systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        let cgEvent = event?.cgEvent
        cgEvent?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    for _ in 0 ..< repeatCount {
        doKey(down: true)
        doKey(down: false)
    }
}

class ModifiersDetector {
    private(set) var currentModifiers: NSEvent.ModifierFlags = []
    private var subscription: Any?

    init() {
        subscription = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.currentModifiers = event.modifierFlags
        }
    }

    deinit {
        subscription.map(NSEvent.removeMonitor)
    }
}
