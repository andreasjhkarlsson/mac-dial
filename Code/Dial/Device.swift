//
// Device
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

// Identifiers for the Surface Dial
private let _dialVendorId: UInt16 = 0x045E
private let _dialProductId: UInt16 = 0x091B

private var _connectedSerialNumbers: [String] = []
private var _setDevicePointerHandler: (IOHIDDevice, String) -> Void = { _, _ in }

private var _wheelSensitivity: Double = 1.0
private var _wheelDirection: WheelDirection = .clockwise

private var _buttonHandler: (ButtonState) -> Void = { _ in }
private var _rotationHandler: (RotationState) -> Bool = { _ in false }
private var _connectionHandler: (_ serialNumber: String) -> Void = { _ in }
private var _disconnectionHandler: () -> Void = {}
private var _sendHapticsTapToDialHandler: () -> Void = {}

private var _queue: IOHIDQueue?

private var _hapticsElementManualTrigger: IOHIDElement?

class DialDevice {
    var wheelSensitivity: Double {
        get { _wheelSensitivity }
        set { _wheelSensitivity = newValue }
    }

    var wheelDirection: WheelDirection {
        get { _wheelDirection }
        set { _wheelDirection = newValue }
    }

    var isRotationClickEnabled: Bool = false

    private var dialDevice: IOHIDDevice?
    private var serialNumber: String = "—"

    private var isConnected: Bool { dialDevice != nil }

    init(
        buttonHandler: @escaping (ButtonState) -> Void,
        rotationHandler: @escaping (RotationState) -> Bool,
        connectionHandler: @escaping (_ serialNumber: String) -> Void,
        disconnectionHandler: @escaping () -> Void
    ) {
        _buttonHandler = buttonHandler
        _rotationHandler = rotationHandler
        _connectionHandler = connectionHandler
        _disconnectionHandler = { [self] in
            if let dialDevice {
                IOHIDDeviceUnscheduleFromRunLoop(dialDevice, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
                IOHIDDeviceRegisterRemovalCallback(dialDevice, nil, nil)
                IOHIDDeviceClose(dialDevice, 0)
                log(tag: "Device", "closed")
            }
            if _queue != nil {
                _queue.map {
                    IOHIDQueueStop($0)
                    IOHIDQueueUnscheduleFromRunLoop($0, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
                    log(tag: "Queue", "stopped")
                }
                _queue = nil
            }
            dialDevice = nil
            _connectedSerialNumbers = _connectedSerialNumbers.filter { $0 != serialNumber }
            serialNumber = "—"

            _hapticsElementManualTrigger = nil

            disconnectionHandler()
        }
        _sendHapticsTapToDialHandler = { [self] in
            sendHapticsTapToDial()
        }

        createHidManager()
        setupDeviceMonitoring()
    }

    deinit {
        IOHIDManagerClose(hidManager, UInt32(kIOHIDOptionsTypeNone))
        log(tag: "Manager", "closed")
    }

    private var hidManager: IOHIDManager!

    private func createHidManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, UInt32(kIOHIDOptionsTypeNone))
        let result = IOHIDManagerOpen(manager, 0)
        guard result == kIOReturnSuccess else { fatalError("Can't open HID manager") }

        let matchingDictionary: NSMutableDictionary = .init()
        matchingDictionary[kIOHIDVendorIDKey as NSString] = NSNumber(value: _dialVendorId)
        matchingDictionary[kIOHIDProductIDKey as NSString] = NSNumber(value: _dialProductId)
        IOHIDManagerSetDeviceMatching(manager, matchingDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue);
        log(tag: "Manager", "opened")

        let inputCallback: IOHIDValueCallback = { _, result, _, value in
            guard _queue != nil else { return }

            let bytes = IOHIDValueGetBytePtr(value)
            let length = IOHIDValueGetLength(value)
            var data = Data()
            for index in 0 ..< length {
                data.append(bytes[index])
            }

            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usageId = IOHIDElementGetUsage(element)

//            let reportId = IOHIDElementGetReportID(element)
//            log(tag: "Manager", "value \(hex: usagePage)|\(hex: usageId)|\(hex: reportId): \(data.map { "\(hex: $0)" }.joined(separator: ", "))")

            //    Manager monitoring 0x9|0x1|0x1: 0x0
            //          Buttons. Primary button.
            //          1/0
            //    Manager monitoring 0x1|0x37|0x1: 0x0, 0x0
            //          Dial.
            //          1/-1/0.
            //          A rotary control for generating a variable value, normally in the form of a knob spun by the index finger and thumb.
            //          Report values should increase as controls are spun clockwise.
            //          This usage does not follow the HID orientation conventions.
            //
            //    Not used:
            //
            //    Manager monitoring 0xd|0x48|0x1: 0x3a
            //          Dial. Width
            //    Manager monitoring 0x1|0x30|0x1: 0xa, 0xb
            //          Generic. X.
            //          A linear translation in the X direction.
            //          Report values should increase as the control’s position is moved from left to right.
            //    Manager monitoring 0x1|0x31|0x1: 0xc, 0xd
            //          Generic. Y.
            //          A linear translation in the Y direction.
            //          Report values should increase as the control’s position is moved from far to near.
            //    Manager monitoring 0xd|0x33|0x1: 0x1
            //          Digitizers. Touch.
            //          1/0 (?)
            //          A bit quantity for touch pads analogous to In Range that indicates that a finger is touching the pad.
            //          A system will typically map a Touch usage to a primary button.

            switch (usagePage, usageId) {
                case (0x01, 0x37): // Generic page; Dial
                    let stateValue = IOHIDValueGetIntegerValue(value)
                    let needHaptics: Bool
                    switch stateValue {
                        case 0:
                            needHaptics = _rotationHandler(.stationary)
                        case 1:
                            let direction: RotationState = _wheelDirection == .clockwise
                                ? .clockwise(_wheelSensitivity)
                                : .anticlockwise(_wheelSensitivity)
                            needHaptics = _rotationHandler(direction)
                        case -1:
                            let direction: RotationState = _wheelDirection == .clockwise
                                ? .anticlockwise(_wheelSensitivity)
                                : .clockwise(_wheelSensitivity)
                            needHaptics = _rotationHandler(direction)
                        default:
                            needHaptics = false
                    }
                    if needHaptics {
                        _sendHapticsTapToDialHandler()
                    }
                case (0x09, 0x01): // Generic page; Button
                    let stateValue = IOHIDValueGetIntegerValue(value)
                    _buttonHandler(stateValue == 1 ? .pressed : .released)
                default:
                    break
            }
        }
        IOHIDManagerRegisterInputValueCallback(manager, inputCallback, nil)

        hidManager = manager
    }

    private func setupDeviceMonitoring() {
        _setDevicePointerHandler = { [self] device, serialNumber in
            dialDevice = device
            self.serialNumber = serialNumber
            _connectedSerialNumbers.append(serialNumber)
            _connectionHandler(serialNumber)
            readAndProcess()
        }

        let hidDeviceMatchingCallback: IOHIDDeviceCallback = { context, result, _, device in
            log(tag: "Manager", "Monitor gor a dial...")

            let serialNumberValue = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as NSString) as? NSString
            guard let serialNumber = serialNumberValue as? String else { return }
            guard !_connectedSerialNumbers.contains(serialNumber) else { return }

            log(tag: "Manager", "Found dial serial number \(serialNumber)")
            _setDevicePointerHandler(device, serialNumber)
        }

        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, hidDeviceMatchingCallback, nil)
        log(tag: "Manager", "monitoring started")
    }

    func disconnect() {
        IOHIDManagerRegisterInputValueCallback(hidManager, nil, nil)
        IOHIDManagerRegisterInputReportCallback(hidManager, nil, nil)
        IOHIDManagerClose(hidManager, 0)
    }

    private let reportBufferLength: Int = 128
    private lazy var reportBuffer: UnsafeMutablePointer<UInt8> = .allocate(capacity: reportBufferLength)
    private var context: UnsafeMutableRawPointer!

    func readAndProcess() {
        guard let dialDevice else { return }

        if let queue = IOHIDQueueCreate(nil, dialDevice, 16, 0) {
            _queue = queue

            let queueCallback: IOHIDCallback = { _, result, _ in
                guard let queue = _queue else { return }

                while let value = IOHIDQueueCopyNextValue(queue) {
                    let bytes = IOHIDValueGetBytePtr(value)
                    let length = IOHIDValueGetLength(value)
                    let data = Data(bytes: bytes, count: length)

                    let element = IOHIDValueGetElement(value)
                    let usagePage = IOHIDElementGetUsagePage(element)
                    let usageId = IOHIDElementGetUsage(element)

                    let elementCookie = IOHIDElementGetCookie(element)
                    let elementTypeCode = IOHIDElementGetType(element)
                    let elementType: String
                    switch elementTypeCode {
                        case kIOHIDElementTypeInput_Misc: elementType = "misc"
                        case kIOHIDElementTypeInput_Button: elementType = "button"
                        case kIOHIDElementTypeInput_Axis: elementType = "axis"
                        case kIOHIDElementTypeInput_ScanCodes: elementType = "scanCodes"
                        case kIOHIDElementTypeInput_NULL: elementType = "null"
                        case kIOHIDElementTypeOutput: elementType = "output"
                        case kIOHIDElementTypeFeature: elementType = "feature"
                        case kIOHIDElementTypeCollection: elementType = "collection"
                        default: elementType = "unknown"
                    }

                    let reportId = IOHIDElementGetReportID(element)
                    let reportCount = IOHIDElementGetReportCount(element)

                    log(tag: "Queue", "got value: \(elementType)|\(hex: usagePage)|\(hex: usageId)|\(hex: elementCookie); report \(hex: reportId)|\(hex: reportCount): \(data.map { "\(hex: $0)" }.joined(separator: ", "))")
                }
            }

            let cfElements = IOHIDDeviceCopyMatchingElements(dialDevice, nil, 0)
            if let cfElements, let elements = (cfElements as [AnyObject]) as? [IOHIDElement] {
                elements
                    .filter { element in
                        let usagePage = IOHIDElementGetUsagePage(element)
                        let usageId = IOHIDElementGetUsage(element)

                        let elementTypeCode = IOHIDElementGetType(element)

                        let reportId = IOHIDElementGetReportID(element)

                        switch (usagePage, usageId, reportId, elementTypeCode) {
                            case (0x01, 0x37, 0x01, _): // rotating
                                log(tag: "Device Descriptor", " -> input element: dial")
                                return false
                            case (0x0d, 0x33, 0x01, _): // touch (?)
                                log(tag: "Device Descriptor", " -> input element: touch (?)")
                                return false
                            case (0x09, 0x01, 0x01, _): // button press
                                log(tag: "Device Descriptor", " -> input element: main button press")
                                return false
                            case (0x0e, 0x21, 0x01, kIOHIDElementTypeOutput): // haptics
                                _hapticsElementManualTrigger = element
                                log(tag: "Device Descriptor", " <- output element: haptics manual trigger")
                                return false
                            default:
                                let elementCookie = IOHIDElementGetCookie(element)
                                let elementType: String
                                switch elementTypeCode {
                                    case kIOHIDElementTypeInput_Misc: elementType = "input misc"
                                    case kIOHIDElementTypeInput_Button: elementType = "input button"
                                    case kIOHIDElementTypeInput_Axis: elementType = "input axis"
                                    case kIOHIDElementTypeInput_ScanCodes: elementType = "input scanCodes"
                                    case kIOHIDElementTypeInput_NULL: elementType = "input null"
                                    case kIOHIDElementTypeOutput: elementType = "output"
                                    case kIOHIDElementTypeFeature: elementType = "feature"
                                    case kIOHIDElementTypeCollection: elementType = "collection"
                                    default: elementType = "unknown"
                                }

                                if elementTypeCode == kIOHIDElementTypeCollection {
                                    log(tag: "Device Descriptor", " ## some element: \(elementType)|\(hex: usagePage)|\(hex: usageId)|\(hex: elementCookie); report \(hex: reportId)")
                                } else if elementTypeCode == kIOHIDElementTypeFeature {
                                    log(tag: "Device Descriptor", " .. some element: \(elementType)|\(hex: usagePage)|\(hex: usageId)|\(hex: elementCookie); report \(hex: reportId)")
                                } else if elementTypeCode == kIOHIDElementTypeInput_NULL {
                                    log(tag: "Device Descriptor", " ?? some element: \(elementType)|\(hex: usagePage)|\(hex: usageId)|\(hex: elementCookie); report \(hex: reportId)")
                                } else if elementTypeCode == kIOHIDElementTypeOutput {
                                    log(tag: "Device Descriptor", " <- some element: \(elementType)|\(hex: usagePage)|\(hex: usageId)|\(hex: elementCookie); report \(hex: reportId)")
                                } else {
                                    log(tag: "Device Descriptor", " -> some element: \(elementType)|\(hex: usagePage)|\(hex: usageId)|\(hex: elementCookie); report \(hex: reportId)")
                                }
                                return true
                        }
                    }
                    .forEach { IOHIDQueueAddElement(queue, $0) }
            }

            IOHIDQueueRegisterValueAvailableCallback(queue, queueCallback, nil)

            IOHIDQueueScheduleWithRunLoop(queue, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
            IOHIDQueueStart(queue)
            log(tag: "Queue", "started")
        }

        let result = IOHIDDeviceOpen(dialDevice, 0)
        guard result == kIOReturnSuccess else { return log(tag: "Device", "open error: \(result)") }

        log(tag: "Device", "opened")
        IOHIDDeviceScheduleWithRunLoop(dialDevice, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)

        let removalCallback: IOHIDCallback = { _, result, data in
            _disconnectionHandler()
            log(tag: "Device", "removed")
        }
        IOHIDDeviceRegisterRemovalCallback(dialDevice, removalCallback, nil)
    }

    private let hapticsClick: Int = 0x1003
    private let hapticsBuzz: Int = 0x1004
    private let hapticsRumble: Int = 0x1005

    private func sendHapticsTapToDial() {
        guard isRotationClickEnabled, let dialDevice, let _hapticsElementManualTrigger else { return }

//        log(tag: "Device", "haptics tapping...")

        let valueManualTrigger = IOHIDValueCreateWithIntegerValue(nil, _hapticsElementManualTrigger, 0, hapticsClick)

        let values = [
            _hapticsElementManualTrigger: valueManualTrigger,
        ] as CFDictionary

        let result = IOHIDDeviceSetValueMultiple(dialDevice, values)
        if result != kIOReturnSuccess {
            log(tag: "Device", "haptics tap error: \(result)")
        } else {
//            log(tag: "Device", "haptics tapped")
        }
    }
}

extension DefaultStringInterpolation {
    mutating func appendInterpolation(hex: any FixedWidthInteger) {
        appendInterpolation("0x\(String(hex, radix: 16))")
    }
}
