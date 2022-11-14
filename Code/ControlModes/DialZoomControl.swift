//
// ScrollControlMode
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
import Carbon

class DialZoomControl: DeviceControl {
    func buttonPress() {
    }

    func buttonRelease() {
    }

    private var lastRotate: TimeInterval = Date().timeIntervalSince1970

    func rotationChanged(_ rotation: RotationState) -> Bool {
        guard rotation != .stationary else { return false }

        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let mousePosition = NSPoint(x: mousePos.x, y: screenHeight - mousePos.y)
        let rect = NSScreen.main!.frame
        let highlightRect = CGRect(x: mousePosition.x - 50, y: mousePosition.y - 50, width: 100, height: 100)

        // TODO: This thing does not work for now
        withUnsafePointer(to: rect) { rect in
            withUnsafePointer(to: highlightRect) { highlightRect in
                let status = UAZoomChangeFocus(rect, highlightRect, UInt32(kUAZoomFocusTypeInsertionPoint))
                print("----------> \(mousePosition.x);\(mousePosition.y) \(status == noErr ? "OK" : "Error code") \(status)")
            }
        }

        lastRotate = Date().timeIntervalSince1970
        return true
    }
}
