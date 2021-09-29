

import Foundation
import AppKit

// https://stackoverflow.com/a/55854051
func HIDPostAuxKey(key: Int32) {
    func doKey(down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: (down ? 0xa00 : 0xb00))
        let data1 = Int((key<<16) | (down ? 0xa00 : 0xb00))

        let ev = NSEvent.otherEvent(with: NSEvent.EventType.systemDefined,
                                    location: NSPoint(x:0,y:0),
                                    modifierFlags: flags,
                                    timestamp: 0,
                                    windowNumber: 0,
                                    context: nil,
                                    subtype: 8,
                                    data1: data1,
                                    data2: -1
                                    )
        let cev = ev?.cgEvent
        cev?.post(tap: CGEventTapLocation.cghidEventTap)
    }
    doKey(down: true)
    doKey(down: false)
}


class PlaybackControlMode : ControlMode {
    
    var lastClick = Date().timeIntervalSince1970
    
    func onDown() {
        
    }
    
    func onUp() {
        
        let clickDelay = Date().timeIntervalSince1970 - lastClick
        
        // Next song on double click
        if (clickDelay < 0.5) {
            HIDPostAuxKey(key: NX_KEYTYPE_NEXT)
        }
        else { // Play / Pause on single click
            
            HIDPostAuxKey(key: NX_KEYTYPE_PLAY)
        }
        
        lastClick = Date().timeIntervalSince1970
    }
    
    func onRotate(_ rotation: Dial.Rotation) {
        switch (rotation) {
        case .Clockwise(_):
            HIDPostAuxKey(key: NX_KEYTYPE_SOUND_UP)
            break
        case .CounterClockwise(_):
            HIDPostAuxKey(key: NX_KEYTYPE_SOUND_DOWN)
            break
        }
    }
    
    
}
