//
// Dial
// MacDial
//
// Created by Alex Babaev on 28 January 2022.
//
// Based on Andreas Karlsson sources
// https://github.com/andreasjhkarlsson/mac-dial
//
// License: MIT
//

import Foundation

class Dial {
    weak var delegate: DialDelegate?

    var wheelSensitivity: Double {
        get { device.wheelSensitivity }
        set { device.wheelSensitivity = newValue }
    }

    var wheelDirection: WheelDirection {
        get { device.wheelDirection }
        set { device.wheelDirection = newValue }
    }

    var isRotationClickEnabled: Bool {
        get { device.isRotationClickEnabled }
        set { device.isRotationClickEnabled = newValue }
    }

    private var device: DialDevice!

    init(
        connectionHandler: @escaping (_ serialNumber: String) -> Void,
        disconnectionHandler: @escaping () -> Void
    ) {
        device = DialDevice(
            buttonHandler: processButton,
            rotationHandler: processRotation,
            connectionHandler: connectionHandler,
            disconnectionHandler: disconnectionHandler
        )
    }

    deinit {
        device.disconnect()
    }

    private var lastButtonState: ButtonState = .released

    private func processButton(state: ButtonState) {
        let lastButtonState = lastButtonState
        self.lastButtonState = state
        guard let delegate = delegate else { return }

        switch (lastButtonState, state) {
            case (.released, .pressed): delegate.buttonPress()
            case (.pressed, .released): delegate.buttonRelease()
            default: break
        }
    }

    private func processRotation(state: RotationState) -> Bool {
        delegate?.rotationChanged(state) ?? false
    }
}
