
import Foundation
import AppKit

extension NSMenuItem {
    convenience init(title: String) {
        self.init()
        self.title = title
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
        
        menuItems.quit.target = self;
        menuItems.quit.action = #selector(quitApp(sender:))
        
        menu.addMenuItems(menuItems)
        
        statusItem.menu = menu
        
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
        
        dial.onRotation = { [unowned self] rotation in
            currentMode?.onRotate(rotation)
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

    @objc func quitApp(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

}
