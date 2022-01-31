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

class DialDevice {
    private var devicePointer: OpaquePointer?
    private var isConnected: Bool { devicePointer != nil }
    private var serialNumber: String {
        guard let devicePointer = devicePointer else { return "" }

        let buffer = UnsafeMutablePointer<wchar_t>.allocate(capacity: 255)
        hid_get_serial_number_string(devicePointer, buffer, 255)
        return NSString(
            bytes: UnsafePointer(buffer),
            length: wcslen(buffer) * MemoryLayout<wchar_t>.stride,
            encoding: String.Encoding.utf32LittleEndian.rawValue
        )! as String
    }

    var wheelSensitivity: Double = 1

    // Identifiers for the Surface Dial
    private static let vendorId: UInt16 = 0x045E
    private static let productId: UInt16 = 0x091B

    private var isTerminated: Bool = false

    private let buttonHandler: (ButtonState) -> Void
    private let rotationHandler: (RotationState) -> Void
    private let connectionHandler: (_ serialNumber: String) -> Void
    private let disconnectionHandler: () -> Void

    init(
        buttonHandler: @escaping (ButtonState) -> Void,
        rotationHandler: @escaping (RotationState) -> Void,
        connectionHandler: @escaping (_ serialNumber: String) -> Void,
        disconnectionHandler: @escaping () -> Void
    ) {
        self.buttonHandler = buttonHandler
        self.rotationHandler = rotationHandler
        self.connectionHandler = connectionHandler
        self.disconnectionHandler = disconnectionHandler

        if hid_init() < 0 {
            log("hid_init() returned an error")
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            while !self.isTerminated {
                if !self.isConnected {
                    self.connect()
                } else {
                    self.readAndProcess()
                }
            }
        }
    }

    deinit {
        if hid_exit() < 0 {
            log("hid_exit() returned an error")
        }
    }

    func connect() {
        devicePointer = hid_open(DialDevice.vendorId, DialDevice.productId, nil)
        // TODO: this will connect to one of Dial devices. Needs work to be able to handle several.
        if isConnected {
            log("Device connected")
            connectionHandler(serialNumber)
            readAndProcess()
        }
    }

    func disconnect() {
        isTerminated = true
        devicePointer.map(hid_close)
        devicePointer = nil
        disconnectionHandler()
    }

    private func process(bytes: UnsafeMutableBufferPointer<UInt8>) {
        guard bytes[0] == 1 && bytes.count >= 4 else { return }

        let isPressed = bytes[1] & 1 == 1
        let buttonState: ButtonState = isPressed ? .pressed : .released
        buttonHandler(buttonState)

        switch bytes[2] {
            case 1: rotationHandler(.clockwise(1 * wheelSensitivity))
            case 0xff: rotationHandler(.counterClockwise(1 * wheelSensitivity))
            default: break
        }
    }

    private let readBufferSize: Int = 128
    private lazy var readBuffer: UnsafeMutablePointer<UInt8> = .allocate(capacity: readBufferSize)

    func readAndProcess() {
        guard let device = devicePointer else { return }

        let readBytes = hid_read(device, readBuffer, readBufferSize)
        guard readBytes > 0 else {
            log("Device disconnected")
            devicePointer = nil
            disconnectionHandler()
            return
        }

        let array = UnsafeMutableBufferPointer(start: readBuffer, count: Int(readBytes))
        process(bytes: array)
        log("Read data from device: \(array.map { String(format: "%02x", $0) }.joined(separator: " "))")
    }
}
