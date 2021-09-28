//
//  DialController.swift
//  MacDial
//
//  Created by Andreas Karlsson on 27/09/2021.
//

import Foundation
import AppKit

class DialController: DialDelegate
{
    private let dial: Dial
    
    init(dial: Dial) {
        self.dial = dial
        dial.delegate = self
    }
    
    func buttonChanged(buttonState: Dial.ButtonState) {
        print("Button: \(buttonState)")

        print(NSEvent.mouseLocation)
        
        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        
        let translatedMousePos = NSPoint(x: mousePos.x, y: screenHeight - mousePos.y)
        
        let event = CGEvent(mouseEventSource: nil, mouseType: buttonState == .pressed ? .leftMouseDown : .leftMouseUp, mouseCursorPosition: translatedMousePos, mouseButton: .left)
        
        event?.post(tap: .cghidEventTap)
    }
    
    func rotated(rotation: Dial.Rotation) {
        
        print("Rotate: \(rotation)")
        
        var steps = 0
        switch rotation {
        case .Clockwise(_):
            steps = 1
        case .CounterClockwise(_):
            steps = -1
        }
        
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: Int32(steps), wheel2: 0, wheel3: 0)
        
        event?.post(tap: .cghidEventTap)
        
    }
}
