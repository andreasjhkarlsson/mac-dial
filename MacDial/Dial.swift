
import Foundation
import AppKit

extension NSString {
    convenience init(wcharArray: UnsafeMutablePointer<wchar_t>) {
        self.init(bytes: UnsafePointer(wcharArray),
                        length: wcslen(wcharArray) * MemoryLayout<wchar_t>.stride,
                        encoding: String.Encoding.utf32LittleEndian.rawValue)!
    }
}

class Dial
{
    enum ButtonState {
        case pressed
        case released
    }
    
    enum Rotation {
        case Clockwise (Int)
        case CounterClockwise (Int)
    }
    
    enum InputReport
    {
        case dial(ButtonState, Rotation?)
        case unknown
    }
    
    class Device
    {
        private struct ReadBuffer {
            let pointer: UnsafeMutablePointer<UInt8>
            let size: Int
            init(size: Int) {
                self.size = size
                pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            }

        }
        
        // Identifiers for the Surface Dial
        private static let VendorId: UInt16 = 0x045E
        private static let ProductId: UInt16 = 0x091B
        private var dev: OpaquePointer?
        private let readBuffer = ReadBuffer(size: 1024)
        
        init() {
            
        }
        
        var isConnected: Bool {
            get {
                return dev != nil
            }
        }
        
        var manufacturer: String {
            get {
                if let dev = self.dev {
                    let buffer = UnsafeMutablePointer<wchar_t>.allocate(capacity: 255)
                    
                    hid_get_manufacturer_string(dev, buffer, 255)
                    
                    return NSString(wcharArray: buffer) as String
                }
                
                return ""
            }
        }
        
        var serialNumber: String {
            get {
                if let dev = self.dev {
                    let buffer = UnsafeMutablePointer<wchar_t>.allocate(capacity: 255)
                    hid_get_serial_number_string(dev, buffer, 255)
                    
                    return NSString(wcharArray: buffer) as String
                }
                return ""
            }
        }
        
        @discardableResult
        func connect() -> Bool {
            dev = hid_open(Dial.Device.VendorId, Dial.Device.ProductId, nil)
            
            return isConnected
        }
        
        func disconnect() {
            if let dev = self.dev {
                hid_close(dev)
            }
            dev = nil
        }
        
        private func parse(bytes: UnsafeMutableBufferPointer<UInt8>) -> InputReport? {
            switch bytes[0] {
            case 1 where bytes.count >= 4:
                
                let buttonState = bytes[1]&1 == 1 ? ButtonState.pressed : .released
                
                let rotation = { () -> Rotation? in
                    switch bytes[2] {
                        case 1:
                            return .Clockwise(1)
                        case 0xff:
                            return .CounterClockwise(1)
                        default:
                            return nil
                }}()
                
                return .dial(buttonState, rotation)
            case 32:
                return .unknown
            default:
                return nil;
            }
        }
        
        func read() -> InputReport?
        {
            if let dev = self.dev {
                let readBytes = hid_read(dev, readBuffer.pointer, readBuffer.size)
                
                if readBytes <= 0 {
                    print("Device disconnected")
                    self.dev = nil;
                    return nil;
                }
                
                let array = UnsafeMutableBufferPointer(start: readBuffer.pointer, count: Int(readBytes))
                
                let dataStr = array.map({ String(format:"%02X", $0)}).joined(separator: " ")
                print("Read data from device: \(dataStr)")
                
                return parse(bytes: array)
            }
            
            return nil
        }
    }
    
    private var thread: Thread?
    var run: Bool = false
    let device = Device()
    private let quit = DispatchSemaphore(value: 0)
    private var lastButtonState = ButtonState.released
    
    var onButtonStateChanged: ((ButtonState) -> Void)?
    var onRotation: ((Rotation) -> Void)?
    
    init() {
        hid_init()
    }
    
    deinit {
        stop()
        hid_exit()
    }
    
    func start() {
        self.thread = Thread(target: self, selector: #selector(threadProc(arg:)), object: nil);
        
        run = true;
        thread!.start()
    }
    
    func stop() {
        run = false;
        if let thread = self.thread {
            quit.signal()
            device.disconnect()
            while !thread.isFinished { }
            self.thread = nil;
        }
        
    }
    
    private func connect() -> Bool
    {
        return false
    }
    
    @objc
    private func threadProc(arg: NSObject) {
        
        while run {
            
            if !device.isConnected {
                print("Trying to connect to device")
                if device.connect() {
                    print("Device \(device.serialNumber) connected.")
                }
            }
            
            if device.isConnected {
                switch device.read() {
                case .dial(let buttonState, let rotation):
                    
                    switch buttonState {
                    case .pressed where lastButtonState == .released:
                        onButtonStateChanged?(.pressed)
                    case .released where lastButtonState == .pressed:
                        onButtonStateChanged?(.released)
                    default: break
                    }
                    
                    if rotation != nil {
                        onRotation?(rotation!)
                    }
                    
                    self.lastButtonState = buttonState
                
                default:
                    print("Unknown input report")
                } 
            }
            
            let _ = quit.wait(timeout: .now().advanced(by: .milliseconds(50)))
        }
    }
}
