
import Foundation
import AppKit
import CoreGraphics

// Thin wrapper around Apple's private DisplayServices framework so we can
// get/set brightness on any connected display (built-in or external) by
// CGDirectDisplayID, rather than relying on the system-routed brightness
// media keys (which on a laptop + external display almost always end up
// adjusting the wrong screen).
private enum DisplayServices {
    private static let handle: UnsafeMutableRawPointer? = {
        return dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    }()

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let getBrightnessFn: GetBrightnessFn? = {
        guard let h = handle, let sym = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFn.self)
    }()

    private static let setBrightnessFn: SetBrightnessFn? = {
        guard let h = handle, let sym = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFn.self)
    }()

    static var isAvailable: Bool { getBrightnessFn != nil && setBrightnessFn != nil }

    static func brightness(for display: CGDirectDisplayID) -> Float? {
        guard let fn = getBrightnessFn else { return nil }
        var value: Float = 0
        return fn(display, &value) == 0 ? value : nil
    }

    @discardableResult
    static func setBrightness(_ value: Float, for display: CGDirectDisplayID) -> Bool {
        guard let fn = setBrightnessFn else { return false }
        return fn(display, max(0, min(1, value))) == 0
    }
}

class BrightnessController: Controller {

    // 1/64 ≈ 1.5% per dial click. With the default Medium sensitivity (36
    // clicks per revolution) one full turn moves ~56% of the brightness
    // range, which feels close to a regular brightness slider.
    private static let stepPerClick: Float = 1.0 / 64.0

    func onDown() { }

    func onUp() { }

    func onRotate(_ rotation: Dial.Rotation, _ scrollDirection: Int) {
        let signedSteps: Int
        switch rotation {
        case .Clockwise(let r): signedSteps = r
        case .CounterClockwise(let r): signedSteps = -r
        }

        // Try the per-display path first so dual-display setups (e.g. a
        // MacBook + Studio Display XDR) adjust the screen the user is
        // looking at rather than whatever macOS thinks is "the" display.
        if DisplayServices.isAvailable,
           let display = displayUnderCursor(),
           let current = DisplayServices.brightness(for: display) {
            let target = current + Float(signedSteps) * Self.stepPerClick
            DisplayServices.setBrightness(target, for: display)
            return
        }

        // Fallback: post the same media key as F1/F2. macOS picks which
        // display to apply it to, which is rarely what you want with an
        // external display attached but is better than doing nothing.
        let key: Int32 = signedSteps > 0 ? Int32(NX_KEYTYPE_BRIGHTNESS_UP) : Int32(NX_KEYTYPE_BRIGHTNESS_DOWN)
        HIDPostAuxKey(key: key, modifiers: [], _repeat: abs(signedSteps))
    }

    private func displayUnderCursor() -> CGDirectDisplayID? {
        let mouse = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if NSMouseInRect(mouse, screen.frame, false),
               let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return CGDirectDisplayID(number.uint32Value)
            }
        }
        return CGMainDisplayID()
    }
}
