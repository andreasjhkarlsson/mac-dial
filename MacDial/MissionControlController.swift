
import Foundation
import AppKit
import Carbon.HIToolbox

class MissionControlController: Controller {

    private static let leftArrow: CGKeyCode = CGKeyCode(kVK_LeftArrow)
    private static let rightArrow: CGKeyCode = CGKeyCode(kVK_RightArrow)

    private func postKey(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
    }

    func onDown() { }

    func onUp() {
        // Open Mission Control on a click. Uses LaunchServices rather than a
        // keystroke so it still works when the user has remapped the
        // Mission Control shortcut.
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    func onRotate(_ rotation: Dial.Rotation, _ scrollDirection: Int) {
        // Use the system "move between spaces" shortcut (ctrl + arrow).
        let direction: CGKeyCode
        switch rotation {
        case .Clockwise:
            direction = scrollDirection >= 0 ? Self.rightArrow : Self.leftArrow
        case .CounterClockwise:
            direction = scrollDirection >= 0 ? Self.leftArrow : Self.rightArrow
        }
        postKey(direction, flags: .maskControl)
    }
}
