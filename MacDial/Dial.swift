
import Foundation
import AppKit
import Cocoa
import SwiftUI
import IOKit.hid
import IOKit.hidsystem

/// Reads the Surface Dial through native IOKit.
///
/// hidapi's input-report callback is broken on macOS 26.4.1+: the kernel
/// processes reports but they never reach user space. `IOHIDManager` delivers
/// them correctly, so the dial is read through IOKit directly.
class Dial
{
    enum ButtonState {
        case pressed
        case released
    }

    enum Rotation {
        case Clockwise (Int)
        case CounterClockwise (Int)
    }

    enum InputReport
    {
        case dial(ButtonState, Rotation?)
        case unknown
    }

    /// A complete press → rotate → release gesture, delivered as one unit.
    ///
    /// Use `onInteraction` instead of `onButtonStateChanged` / `onRotation`
    /// when the whole gesture should be handled in one place. The separate
    /// callbacks remain available for callers that want the raw events.
    enum Interaction {
        /// The dial button went down.
        case pressed
        /// The dial was rotated while the button was held.
        case rotated(Rotation, Int)
        /// The dial button came back up.
        case released
    }

    class Device
    {
        // Identifiers for the Surface Dial
        static let VendorId: UInt16 = 0x045E
        static let ProductId: UInt16 = 0x091B

        private var manager: IOHIDManager?
        private var device: IOHIDDevice?

        /// Serial number, once the device has been opened.
        private(set) var serialNumberValue: String = ""
        private(set) var manufacturerValue: String = ""

        var wheelSensivitity = 36

        var scrollDirection = 1

        var haptics = false

        var isConnected: Bool {
            device != nil
        }

        var serialNumber: String { serialNumberValue }

        var manufacturer: String { manufacturerValue }

        /// Called on every decoded input report, on the main queue.
        var onReport: ((InputReport) -> Void)?

        init() {
        }

        deinit {
            disconnect()
        }

        @discardableResult
        func connect() -> Bool {
            // Reuse the manager across reconnects so we neither leak it nor
            // register the input-report callback more than once.
            let mgr: IOHIDManager
            if let existing = manager {
                mgr = existing
            } else {
                mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

                let matching: [String: Any] = [
                    kIOHIDVendorIDKey as String: Int32(Device.VendorId),
                    kIOHIDProductIDKey as String: Int32(Device.ProductId),
                ]
                IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)

                IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(),
                                                CFRunLoopMode.commonModes.rawValue)
                IOHIDManagerRegisterInputReportCallback(mgr, { context, _, _, _, _, report, length in
                    guard let context else { return }
                    let handler = Unmanaged<Device>.fromOpaque(context).takeUnretainedValue()
                    handler.handle(report: report, length: length)
                }, Unmanaged.passUnretained(self).toOpaque())

                self.manager = mgr
            }

            // Seize the device so macOS' own HID event driver does not keep
            // the reports to itself.
            let openResult = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            guard openResult == kIOReturnSuccess else {
                print("IOHIDManagerOpen failed: \(openResult)")
                return false
            }

            // The manager now owns the device; grab the reference so we can
            // read its properties and write reports back to it.
            if let devices = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>,
               let found = devices.first {
                self.device = found
            }

            return device != nil
        }

        func disconnect() {
            if let mgr = manager {
                IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetCurrent(),
                                                 CFRunLoopMode.commonModes.rawValue)
                IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            }
            manager = nil
            device = nil
            serialNumberValue = ""
            manufacturerValue = ""
        }

        /// Called from the IOKit callback; must stay cheap and thread-safe.
        private func handle(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
            guard length >= 3 else { return }
            let bytes = UnsafeBufferPointer(start: report, count: length)

            // Only Report ID 1 carries the dial state. The others are the
            // system control / vendor reports, which are not interesting.
            guard bytes[0] == 1 else { return }

            let flags = bytes[1]

            // Report ID 1 layout:
            //   byte 1  bit 0 = button pressed
            //            bit 1 = rotation present
            //   byte 2  direction (0x01 clockwise, 0xFF counter-clockwise)
            //   byte 3  magnitude
            // Observed values: 00 idle, 01 pressed, 02 rotating, 03 both.
            let buttonPressed = (flags & 0x01) != 0
            let hasRotation = (flags & 0x02) != 0
            let buttonState: ButtonState = buttonPressed ? .pressed : .released

            var rotation: Rotation? = nil
            if hasRotation {
                // Bytes 2 and 3 hold the rotation as a 16-bit signed
                // little-endian value: 0x0001 = one step clockwise,
                // 0xFFFF = one step counter-clockwise. The sign gives the
                // direction, the absolute value the number of steps.
                let raw = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
                let value = Int(Int16(bitPattern: raw))
                if value > 0 {
                    rotation = .Clockwise(value)
                } else if value < 0 {
                    rotation = .CounterClockwise(-value)
                }
            }

            let decoded: InputReport = .dial(buttonState, rotation)
            DispatchQueue.main.async { [weak self] in
                self?.onReport?(decoded)
            }
        }

        /// Reads the serial number. Must be called after the device is open.
        func refreshIdentifiers() {
            guard let device else { return }
            serialNumberValue = Self.stringProperty(device, key: kIOHIDSerialNumberKey) ?? ""
            manufacturerValue = Self.stringProperty(device, key: kIOHIDManufacturerKey) ?? ""
        }

        private static func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
            guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return nil }
            guard CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
            return (value as! CFString) as String
        }

        /// Sets the number of rotation steps the dial reports per detent.
        ///
        /// Report ID 1 carries the rotation as a feature report; writing the
        /// step count changes how many steps one full turn produces.
        func updateSensitivity() {
            guard let device else { return }

            let steps = UInt16(wheelSensivitity)
            var buf: [UInt8] = [0x01, UInt8(steps & 0xff), UInt8((steps >> 8) & 0xff),
                                0x00, haptics ? 0x03 : 0x02, 0x00, 0x00, 0x00]
            let length = buf.count
            buf.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return }
                IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x01, base.assumingMemoryBound(to: UInt8.self),
                                     CFIndex(length))
            }
        }

        /// Fires a haptic pulse.
        func impact(repeatCount: UInt8 = 0) {
            guard let device else { return }
            var buf: [UInt8] = [0x01, repeatCount, 0x03, 0x00, 0x00]
            let length = buf.count
            buf.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return }
                IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x01, base.assumingMemoryBound(to: UInt8.self),
                                     CFIndex(length))
            }
        }
    }

    private var thread: Thread?
    private var run: Bool = false
    let device = Device()

    var onButtonStateChanged: ((ButtonState) -> Void)?
    var onRotation: ((Rotation, Int) -> Void)?

    /// The whole press → rotate → release gesture in one callback.
    ///
    /// Fires alongside the separate callbacks, so either style can be used.
    var onInteraction: ((Interaction) -> Void)?

    var wheelSensitivity: Int {
        get {
            return device.wheelSensivitity
        }

        set (value) {
            device.wheelSensivitity = value
            device.updateSensitivity()
        }
    }

    var scrollDirection: Int {
        get {
            return device.scrollDirection
        }

        set (value) {
            device.scrollDirection = value
        }
    }

    var haptics: Bool {
        get {
            return device.haptics
        }

        set (value) {
            device.haptics = value
            device.updateSensitivity()
        }
    }

    private var lastButtonState = ButtonState.released

    init() {
    }

    func start() {
        guard !run else { return }
        run = true

        device.onReport = { [weak self] report in
            guard let self else { return }
            switch report {
            case .dial(let buttonState, let rotation):
                switch buttonState {
                case .pressed where lastButtonState == .released:
                    onButtonStateChanged?(.pressed)
                    onInteraction?(.pressed)
                case .released where lastButtonState == .pressed:
                    onButtonStateChanged?(.released)
                    onInteraction?(.released)
                default: break
                }

                if let rotation = rotation {
                    onRotation?(rotation, scrollDirection)
                    onInteraction?(.rotated(rotation, scrollDirection))
                }

                lastButtonState = buttonState

            case .unknown:
                print("Unknown input report.")
            }
        }

        openDevice()
    }

    /// Opens the dial, retrying until it succeeds.
    ///
    /// The Surface Dial drops its Bluetooth link when it goes idle, so the
    /// device may not be present at startup. The manager is left open with a
    /// device-arrival callback, and this is called again whenever the dial
    /// shows up.
    private func openDevice() {
        guard run else { return }

        if device.connect() {
            print("Device \(device.serialNumber) opened.")
            device.refreshIdentifiers()
            device.updateSensitivity()
        } else {
            print("Device couldn't be opened, waiting for it to connect...")
            // Retry shortly; the dial usually reconnects within seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.openDevice()
            }
        }
    }

    func stop() {
        run = false
        device.onReport = nil
        device.disconnect()
    }
}
