
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
    private var statusBarButton: NSStatusBarButton?
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let dial: Dial
    
    
    
    struct MenuItems {
        let title = NSMenuItem.init(title: "Mac Dial")
        let connectionStatus = NSMenuItem.init()
        let separator = NSMenuItem.separator()
        let scrollMode = NSMenuItem.init(title: "Scroll mode")
        let playbackMode = NSMenuItem.init(title: "Playback mode")
        let separator2 = NSMenuItem.separator()
        let quit = NSMenuItem.init(title: "Quit")
    }
    
    private let menuItems = MenuItems()
    
    var currentMode: ControlMode? {
        get {
            if (menuItems.playbackMode.state == .on) {
                return menuItems.playbackMode.representedObject as! ControlMode
            }
            if (menuItems.scrollMode.state == .on) {
                return menuItems.scrollMode.representedObject as! ControlMode
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
        menuItems.scrollMode.state = .off;
        menuItems.scrollMode.representedObject = ScrollControlMode()
        
        
        menuItems.playbackMode.target = self
        menuItems.playbackMode.action = #selector(setMode(sender:))
        menuItems.playbackMode.state = .on;
        menuItems.playbackMode.representedObject = PlaybackControlMode()
        
        menuItems.quit.target = self;
        menuItems.quit.action = #selector(quitApp(sender:))
        
        
        
        menu.addMenuItems(menuItems)
        
        statusItem.menu = menu
        
        statusBarButton = statusItem.button
        if let button = statusBarButton {
            updateIcon()
            button.target = self
            button.imagePosition = .imageLeft
            
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
        if (menuItems.scrollMode.state == .on) {
            statusBarButton?.image = #imageLiteral(resourceName: "icon-scroll")
        }
        else if (menuItems.playbackMode.state == .on) {
            statusBarButton?.image = #imageLiteral(resourceName: "icon-playback")
        }
        statusBarButton?.image?.size = NSSize(width: 18.0, height: 18.0)
        statusBarButton?.image?.isTemplate = true
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
