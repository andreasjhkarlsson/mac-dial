//
// DialDelegate
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

enum ButtonState: Equatable {
    case pressed
    case released
}

enum RotationState: Equatable {
    case clockwise(Double)
    case counterClockwise(Double)
    
    var amount: Double {
        switch self {
            case .clockwise(let amount), .counterClockwise(let amount): return amount
        }
    }
}

protocol DialDelegate: AnyObject {
    func buttonPress()
    func buttonRelease()
    func rotationChanged(_ rotation: RotationState)
}
