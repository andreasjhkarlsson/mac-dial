
import Foundation
import AppKit

enum WheelSensitivity {
    case low
    case medium
    case high
}

enum ScrollDirection {
    case standard
    case natural
}

extension NSMenuItem {
    convenience init(title: String) {
        self.init()
        self.title = title
    }
    
    convenience init(title: String, sensitivity: WheelSensitivity) {
        self.init()
        self.title = title
        self.representedObject = sensitivity
    }
    
    convenience init(title: String, direction: ScrollDirection) {
        self.init()
        self.title = title
        self.representedObject = direction
    }
}

extension NSMenu {
    func addMenuItems(_ items: StatusBarController.MenuItems) {
        self.addItem(items.title)
        self.addItem(items.connectionStatus)
        self.addItem(items.separator)
        self.addItem(items.scrollMode)
        self.addItem(items.playbackMode)
        self.addItem(items.separator2)
        items.wheelSensitivity.submenu = NSMenu.init()
        for sensitivityOption in items.wheelSensitivityOptions {
            items.wheelSensitivity.submenu?.addItem(sensitivityOption)
        }
        self.addItem(items.wheelSensitivity)
        items.scrollDirection.submenu = NSMenu.init()
        for scrollDirectionOption in items.scrollDirectionOptions {
            items.scrollDirection.submenu?.addItem(scrollDirectionOption)
        }
        self.addItem(items.scrollDirection)
        self.addItem(items.separator3)
        self.addItem(items.quit)
    }
}

class StatusBarController
{
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let dial: Dial
    private let menuItems = MenuItems()
    
    struct MenuItems {
        let title = NSMenuItem.init(title: "Mac Dial")
        let connectionStatus = NSMenuItem.init()
        let separator = NSMenuItem.separator()
        let scrollMode = NSMenuItem.init(title: "Scroll mode")
        let playbackMode = NSMenuItem.init(title: "Playback mode")
        let separator2 = NSMenuItem.separator()
        let wheelSensitivity = NSMenuItem.init(title: "Wheel sensitivity")
        let wheelSensitivityOptions = [
            NSMenuItem.init(title: "Low", sensitivity: .low),
            NSMenuItem.init(title: "Medium", sensitivity: .medium),
            NSMenuItem.init(title: "High", sensitivity: .high)
        ]
        let scrollDirection = NSMenuItem.init(title: "Scroll Direction")
        let scrollDirectionOptions = [
            NSMenuItem.init(title: "Standard", direction: .standard),
            NSMenuItem.init(title: "Natural", direction: .natural)
        ]
        let separator3 = NSMenuItem.separator()
        let quit = NSMenuItem.init(title: "Quit")
    }
    
    var currentMode: ControlMode? {
        get {
            if (menuItems.playbackMode.state == .on) {
                return (menuItems.playbackMode.representedObject as! ControlMode)
            }
            if (menuItems.scrollMode.state == .on) {
                return (menuItems.scrollMode.representedObject as! ControlMode)
            }
            
            return nil
        }
    }
    
    var wheelSensitivity: WheelSensitivity? {
        get {
            for option in menuItems.wheelSensitivityOptions {
                if option.state == .on {
                    return (option.representedObject as! WheelSensitivity)
                }
            }
            return nil
        }
        set (sensitivity) {
            switch sensitivity {
            case .low:
                dial.wheelSensitivity = 1
                break
            case .medium: dial.wheelSensitivity = 2
                break
            case .high:
                dial.wheelSensitivity = 4
                break
            case .none:
                break
            }
            for option in menuItems.wheelSensitivityOptions {
                option.state = (option.representedObject as! WheelSensitivity) == sensitivity ? .on : .off
            }
        }
    }
    
    var scrollDirection: ScrollDirection? {
        get {
            for option in menuItems.scrollDirectionOptions {
                if option.state == .on {
                    return (option.representedObject as! ScrollDirection)
                }
            }
            return nil
        }
        set (scrollingDirection) {
            switch scrollingDirection {
            case .standard:
                dial.scrollDirection = 1
                break
            case .natural:
                dial.scrollDirection = -1
                break
            case .none:
                break
            }
            for option in menuItems.scrollDirectionOptions {
                option.state = (option.representedObject as! ScrollDirection) == scrollingDirection ? .on : .off
            }
        }
    }
    
    init( _ dial: Dial) {
        self.dial = dial
        self.menu = NSMenu.init()
        
        statusBar = NSStatusBar.init()
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        menu.minimumWidth = 260
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 0)
        ]
        
        menuItems.title.attributedTitle = NSAttributedString(string: menuItems.title.title, attributes: attributes)
        menuItems.title.target = self
        menuItems.title.action = #selector(showAbout(sender:))
        
        menuItems.connectionStatus.target = self
        menuItems.connectionStatus.isEnabled = false
        
        menuItems.scrollMode.target = self
        menuItems.scrollMode.action = #selector(setMode(sender:))
        menuItems.scrollMode.state = .on;
        menuItems.scrollMode.representedObject = ScrollControlMode()
        
        menuItems.playbackMode.target = self
        menuItems.playbackMode.action = #selector(setMode(sender:))
        menuItems.playbackMode.state = .off;
        menuItems.playbackMode.representedObject = PlaybackControlMode()
        
        for option in menuItems.wheelSensitivityOptions {
            option.target = self
            option.action = #selector(setSensitivity(sender:))
        }
        
        for option in menuItems.scrollDirectionOptions {
            option.target = self
            option.action = #selector(setScrollDirection(sender:))
        }
        
        menuItems.quit.target = self;
        menuItems.quit.action = #selector(quitApp(sender:))
        
        menu.addMenuItems(menuItems)
        
        statusItem.menu = menu
        
        wheelSensitivity = .medium
        
        scrollDirection = .natural  // set to standard or natural here to change default scroll direction
        
        if let button = statusItem.button {
            button.target = self
            updateIcon()
        }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self]_ in
            self?.updateConnectionStatus()
        }
        
        dial.onButtonStateChanged = { [unowned self] state in
            switch state {
            case .pressed:
                currentMode?.onDown()
                break
            case .released:
                currentMode?.onUp()
                break
            }
        }
        
        dial.onRotation = { [unowned self] rotation, scrollDirection in
            currentMode?.onRotate(rotation, scrollDirection)
        }
    }
    
    private func updateConnectionStatus() {
        if dial.device.isConnected {
            let serialNumber = dial.device.serialNumber
            menuItems.connectionStatus.title = "Surface Dial '\(serialNumber)' connected"
        }
        else {
            menuItems.connectionStatus.title = "No Surface Dial connected"
        }
    }
    
    private func updateIcon() {
        
        if let button = statusItem.button {
            if (menuItems.scrollMode.state == .on) {
                button.image = #imageLiteral(resourceName: "icon-scroll")
            }
            else if (menuItems.playbackMode.state == .on) {
                button.image = #imageLiteral(resourceName: "icon-playback")
            }
            
            button.image?.size = NSSize(width: 18, height: 18)
            
            button.imagePosition = .imageLeft
        }
    }
    
    @objc func showAbout(sender: AnyObject) {
        
    }
    
    @objc func setMode(sender: AnyObject) {
        
        let item = sender as! NSMenuItem
        
        menuItems.playbackMode.state = item == menuItems.playbackMode ? .on : .off
        menuItems.scrollMode.state = item == menuItems.scrollMode ? .on : .off
        
        updateIcon()
    }
    
    @objc func setSensitivity(sender: AnyObject) {
        let item = sender as! NSMenuItem
        wheelSensitivity = (item.representedObject as! WheelSensitivity)
    }
    
    @objc func setScrollDirection(sender: AnyObject) {
        let item = sender as! NSMenuItem
        scrollDirection = (item.representedObject as! ScrollDirection)
    }

    @objc func quitApp(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

}
