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

private var _buttonWasState: ButtonState = .released
private var _wheelSensitivity: Double = 1.0
private var _buttonHandler: (ButtonState) -> Void = { _ in }
private var _rotationHandler: (RotationState) -> Void = { _ in }
private var _connectionHandler: (_ serialNumber: String) -> Void = { _ in }
private var _disconnectionHandler: () -> Void = {}

class DialDevice {
    var wheelSensitivity: Double {
        get { _wheelSensitivity }
        set { _wheelSensitivity = newValue }
    }

    private var dialDevice: IOHIDDevice?
    private var serialNumber: String = "—"

    private var isConnected: Bool { dialDevice != nil }

    private let hidMainQueue: DispatchQueue = DispatchQueue(label: "MacDial.hid.main", target: DispatchQueue.main)
    private let hidBackgroundQueue: DispatchQueue = DispatchQueue(label: "MacDial.hid.background", target: DispatchQueue.global(qos: .background))

    init(
        buttonHandler: @escaping (ButtonState) -> Void,
        rotationHandler: @escaping (RotationState) -> Void,
        connectionHandler: @escaping (_ serialNumber: String) -> Void,
        disconnectionHandler: @escaping () -> Void
    ) {
        _buttonHandler = buttonHandler
        _rotationHandler = rotationHandler
        _connectionHandler = connectionHandler
        _disconnectionHandler = { [self] in
            guard let dialDevice else { return }

            _ = IOHIDDeviceClose(dialDevice, 0)
            reportBuffer = .allocate(capacity: reportBufferLength)

            _connectedSerialNumbers = _connectedSerialNumbers.filter { $0 != serialNumber }
            self.dialDevice = nil
            serialNumber = "—"
            disconnectionHandler()
        }
        setupDeviceMonitoring()
    }

    deinit {
        IOHIDManagerClose(hidManager, UInt32(kIOHIDOptionsTypeNone))
        log("HID manager closed")
    }

    private let hidManager: IOHIDManager = {
        let result = IOHIDManagerCreate(kCFAllocatorDefault, UInt32(kIOHIDOptionsTypeNone))
        IOHIDManagerOpen(result, 0)
        IOHIDManagerSetDeviceMatching(result, nil)
        IOHIDManagerScheduleWithRunLoop(result, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue);
        log("HID manager opened")
        return result
    }()

    private func setupDeviceMonitoring() {
        _setDevicePointerHandler = { [self] device, serialNumber in
            dialDevice = device
            self.serialNumber = serialNumber
            _connectedSerialNumbers.append(serialNumber)
            _connectionHandler(serialNumber)
            readAndProcess()
        }

        let hidDeviceMatchingCallback: IOHIDDeviceCallback = { context, result, _, device in
            let vendorIdValue = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as NSString) as? Int32
            let productIdValue = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as NSString) as? Int32
            let serialNumberValue = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as NSString) as? NSString
            guard let vendorId = vendorIdValue, let productId = productIdValue, let serialNumber = serialNumberValue as? String else { return }
            guard vendorId == _dialVendorId, productId == _dialProductId else { return }
            guard !_connectedSerialNumbers.contains(serialNumber) else { return }

            log("Found Dial device: \(serialNumber)")
            _setDevicePointerHandler(device, serialNumber)
        }

        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, hidDeviceMatchingCallback, nil)
        log("Monitoring started")
    }

    func disconnect() {
        IOHIDManagerClose(hidManager, 0)
    }

    private let reportBufferLength: Int = 128
    private lazy var reportBuffer: UnsafeMutablePointer<UInt8> = .allocate(capacity: reportBufferLength)

    func readAndProcess() {
        guard let dialDevice else { return }

        let result = IOHIDDeviceOpen(dialDevice, 0)
        guard result == kIOReturnSuccess else { return log("Device open error: \(result)") }

        IOHIDDeviceScheduleWithRunLoop(dialDevice, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)

        let inputReportCallback: IOHIDReportCallback = { _, result, _, type, reportId, data, dataLength in
            guard dataLength >= 3 && data[0] == 1 else { return }

            log("Got data: \(data[1]):\(data[2])")

            let buttonState: ButtonState = data[1] & 1 == 1 ? .pressed : .released
            if buttonState != _buttonWasState {
                _buttonWasState = buttonState
                _buttonHandler(buttonState)
            }

            switch data[2] {
                case 1:
                    _rotationHandler(.clockwise(_wheelSensitivity))
                case 0xff:
                    _rotationHandler(.counterClockwise(_wheelSensitivity))
                default:
                    break
            }
        }
        IOHIDDeviceRegisterInputReportCallback(dialDevice, reportBuffer, reportBufferLength, inputReportCallback, nil)

        let removalCallback: IOHIDCallback = { _, result, data in
            _disconnectionHandler()
            log("Device disconnected")
        }
        IOHIDDeviceRegisterRemovalCallback(dialDevice, removalCallback, nil)
    }
}
