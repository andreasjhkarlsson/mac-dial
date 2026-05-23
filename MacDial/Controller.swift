
import Foundation

protocol Controller: AnyObject
{
    func onDown()
    
    func onUp()
    
    func onRotate(_ rotation: Dial.Rotation,_ scrollDirection: Int)

    // Called instead of onUp when a long-press cycles the mode mid-press,
    // so a controller can release any state it set up in onDown (e.g. a
    // pending mouse button) without firing its normal "click" action.
    func onCancel()
}

extension Controller {
    func onCancel() { }
}
