
import Foundation

protocol ControlMode: AnyObject
{
    func onDown()
    
    func onUp()
    
    func onRotate(_ rotation: Dial.Rotation,_ scrollDirection: Int)
}
