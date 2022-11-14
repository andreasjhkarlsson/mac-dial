//
// UserSettings
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

extension SettingsValueKey {
    static let dialMode: SettingsValueKey = "settings.dialMode"
    static let buttonMode: SettingsValueKey = "settings.buttonMode"
    static let sensitivity: SettingsValueKey = "settings.sensitivity"
    static let rotationClick: SettingsValueKey = "settings.isRotationClickEnabled"
    static let wheelDirection: SettingsValueKey = "settings.wheelDirection"
}

class UserSettings {
    enum WheelSensitivity {
        case low
        case medium
        case high
    }

    enum DialOperationMode {
        case scrolling
        case volume
        case brightness
        case keyboard
        case zoom
    }

    enum ButtonOperationMode {
        case leftClick
        case playback
    }

    @FromUserDefaults(key: .dialMode, defaultValue: 2)
    private var dialModeSetting: Int

    @FromUserDefaults(key: .buttonMode, defaultValue: 2)
    private var buttonModeSetting: Int

    @FromUserDefaults(key: .sensitivity, defaultValue: 2)
    private var sensitivitySetting: Int

    @FromUserDefaults(key: .rotationClick, defaultValue: true)
    private var isRotationClickEnabledSetting: Bool

    @FromUserDefaults(key: .wheelDirection, defaultValue: 1)
    private var wheelDirectionSetting: Int

    var dialMode: DialOperationMode {
        get {
            switch dialModeSetting {
                case 1: return .scrolling
                case 2: return .volume
                case 3: return .brightness
                case 4: return .keyboard
                case 5: return .zoom
                default: return .scrolling
            }
        }
        set {
            switch newValue {
                case .scrolling: dialModeSetting = 1
                case .volume: dialModeSetting = 2
                case .brightness: dialModeSetting = 3
                case .keyboard: dialModeSetting = 4
                case .zoom: dialModeSetting = 5
            }
        }
    }

    var buttonMode: ButtonOperationMode {
        get {
            switch dialModeSetting {
                case 1: return .leftClick
                case 2: return .playback
                default: return .playback
            }
        }
        set {
            switch newValue {
                case .leftClick: dialModeSetting = 1
                case .playback: dialModeSetting = 2
            }
        }
    }

    var sensitivity: WheelSensitivity {
        get {
            switch sensitivitySetting {
                case 1: return .low
                case 2: return .medium
                case 3: return .high
                default: return .low
            }
        }
        set {
            switch newValue {
                case .low: sensitivitySetting = 1
                case .medium: sensitivitySetting = 2
                case .high: sensitivitySetting = 3
            }
        }
    }

    var isRotationClickEnabled: Bool {
        get {
            isRotationClickEnabledSetting
        }
        set {
            isRotationClickEnabledSetting = newValue
        }
    }

    var wheelDirection: WheelDirection {
        get {
            wheelDirectionSetting < 0 ? .anticlockwise : .clockwise
        }
        set {
            wheelDirectionSetting = newValue == .clockwise ? 1 : -1
        }
    }
}

struct SettingsValueKey: ExpressibleByStringLiteral {
    var name: String

    init(stringLiteral value: StringLiteralType) {
        name = value
    }
}

@propertyWrapper
struct FromUserDefaults<Value> {
    private let key: String
    private let defaultValue: Value
    private let userDefaults: UserDefaults

    init(key: SettingsValueKey, userDefaults: UserDefaults = UserDefaults.standard, defaultValue: Value) {
        self.key = key.name
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }

    var wrappedValue: Value {
        get {
            userDefaults.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}
