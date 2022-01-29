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
    static let operationMode: SettingsValueKey = "settings.operationMode"
    static let sensitivity: SettingsValueKey = "settings.sensitivity"
}

class UserSettings {
    enum WheelSensitivity {
        case low
        case medium
        case high
    }

    enum OperationMode {
        case scrolling
        case playbackAndVolume
    }

    @FromUserDefaults(key: .operationMode)
    private var operationModeSetting: Int?

    @FromUserDefaults(key: .sensitivity)
    private var sensitivitySetting: Int?

    var operationMode: OperationMode {
        get {
            switch operationModeSetting {
                case 1: return .scrolling
                case 2: return .playbackAndVolume
                default: return .scrolling
            }
        }
        set {
            switch newValue {
                case .scrolling: operationModeSetting = 1
                case .playbackAndVolume: operationModeSetting = 2
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
    private let userDefaults: UserDefaults

    init(key: SettingsValueKey, userDefaults: UserDefaults = UserDefaults.standard) {
        self.key = key.name
        self.userDefaults = userDefaults
    }

    var wrappedValue: Value? {
        get {
            userDefaults.object(forKey: key) as? Value
        }
        set {
            if let newValue = newValue {
                userDefaults.set(newValue, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}
