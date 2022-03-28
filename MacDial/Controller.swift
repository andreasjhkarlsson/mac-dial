
import Foundation

protocol Controller: AnyObject
{
    func onDown()
    
    func onUp()
    
    func onRotate(_ rotation: Dial.Rotation,_ scrollDirection: Int)
}
