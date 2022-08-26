
import Foundation
import AppKit

enum WheelSensitivity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case extreme = "extreme"
}

enum ScrollDirection: String {
    case standard = "standard"
    case natural = "natural"
}

enum Mode: String {
    case scrolling = "scrolling"
    case playback = "playback"
}

enum HapticsMode: String {
    case enabled = "enabled"
    case disabled = "disabled"
}

extension NSMenuItem {
    convenience init(title: String) {
        self.init()
        self.title = title
    }
}

class MenuOptionItem<Type>: NSMenuItem {
    init(title: String, option: Type) {
        super.init(title: title, action: nil, keyEquivalent: "")
        self.representedObject = option
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var selected : Bool
    {
        get { return self.state == .on }
        set (on) { self.state = on ? .on : .off }
    }
    
    var option : Type
    {
        get
        {
            return self.representedObject as! Type
        }
    }
}

class ControllerOptionItem: MenuOptionItem<Mode>
{
    let controller: Controller
    
    init(title: String, mode: Mode, controller: Controller) {
        self.controller = controller
        super.init(title: title, option: mode)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        items.hapticsMode.submenu = NSMenu.init()
        for hapticsModeOption in items.hapticsModeOptions {
            items.hapticsMode.submenu?.addItem(hapticsModeOption)
        }
        self.addItem(items.hapticsMode)
        
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
        let scrollMode = ControllerOptionItem.init(title: "Scroll mode", mode: .scrolling, controller: ScrollController())
        let playbackMode = ControllerOptionItem.init(title: "Playback mode", mode: .playback, controller: PlaybackController())
        let separator2 = NSMenuItem.separator()
        let wheelSensitivity = NSMenuItem.init(title: "Wheel Sensitivity")
        let wheelSensitivityOptions = [
            MenuOptionItem<WheelSensitivity>.init(title: "Low", option: .low),
            MenuOptionItem<WheelSensitivity>.init(title: "Medium", option: .medium),
            MenuOptionItem<WheelSensitivity>.init(title: "High", option: .high),
            MenuOptionItem<WheelSensitivity>.init(title: "Extreme", option: .extreme)
        ]
        let scrollDirection = NSMenuItem.init(title: "Scroll Direction")
        let scrollDirectionOptions = [
            MenuOptionItem<ScrollDirection>.init(title: "Standard", option: .standard),
            MenuOptionItem<ScrollDirection>.init(title: "Natural", option: .natural)
        ]
        let hapticsMode = NSMenuItem.init(title: "Haptics")
        let hapticsModeOptions = [
            MenuOptionItem<HapticsMode>.init(title: "Disabled", option: .disabled),
            MenuOptionItem<HapticsMode>.init(title: "Enabled", option: .enabled)
        ]
        let separator3 = NSMenuItem.separator()
        let quit = NSMenuItem.init(title: "Quit")
    }
    
    var currentMode: Mode
    {
        get {
            switch UserDefaults.standard.string(forKey: "mode")
            {
            case .some("scroll"):
                return .scrolling
            case .some("playback"):
                return .playback
            default:
                return .scrolling
            }
        }
        
        set (value) {
            switch (value)
            {
            case .playback:
                UserDefaults.standard.setValue("playback", forKey: "mode")
            case .scrolling:
                UserDefaults.standard.setValue("scroll", forKey: "mode")
            }
        }
    }
    
    var currentController: Controller
    {
        get {
            switch (currentMode)
            {
            case .playback:
                return menuItems.playbackMode.controller
            case .scrolling:
                return menuItems.scrollMode.controller
            }
        }
    }
    
    var wheelSensitivity: WheelSensitivity? {
        get {
            let raw = UserDefaults.standard.string(forKey: "sensitivity") ?? WheelSensitivity.medium.rawValue
            return WheelSensitivity(rawValue: raw)
        }
        set (sensitivity) {
            switch sensitivity {
            case .low:
                dial.wheelSensitivity = 18
                break
            case .medium:
                dial.wheelSensitivity = 36
                break
            case .high:
                dial.wheelSensitivity = 72
                break
            case .extreme:
                dial.wheelSensitivity = 360
            case .none:
                break
            }
            for option in menuItems.wheelSensitivityOptions {
                option.state = (option.representedObject as! WheelSensitivity) == sensitivity ? .on : .off
            }
            
            UserDefaults.standard.setValue(sensitivity?.rawValue, forKey: "sensitivity")
        }
    }
    
    var scrollDirection: ScrollDirection? {
        get {
            let raw = UserDefaults.standard.string(forKey: "direction") ?? ScrollDirection.natural.rawValue
            return ScrollDirection(rawValue: raw)
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
            
            UserDefaults.standard.setValue(scrollingDirection?.rawValue, forKey: "direction")
        }
    }
    
    var hapticsMode: HapticsMode? {
        get {
            let raw = UserDefaults.standard.string(forKey: "hapticsmode") ?? HapticsMode.disabled.rawValue
            return HapticsMode(rawValue: raw)
        }
        set (hapticsModeSet) {
            switch hapticsModeSet {
            case .disabled:
                dial.haptics = false
                break
            case .enabled:
                dial.haptics = true
                break
            case .none:
                break
            }
            for option in menuItems.hapticsModeOptions {
                option.state = (option.representedObject as! HapticsMode) == hapticsModeSet ? .on : .off
            }
            
            UserDefaults.standard.setValue(String(hapticsModeSet!.rawValue), forKey: "hapticsmode")
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
        menuItems.scrollMode.selected = currentMode == .scrolling;
        
        menuItems.playbackMode.target = self
        menuItems.playbackMode.action = #selector(setMode(sender:))
        menuItems.playbackMode.selected = currentMode == .playback;
        
        for option in menuItems.wheelSensitivityOptions {
            option.target = self
            option.action = #selector(setSensitivity(sender:))
            option.selected = option.option == wheelSensitivity
        }
        wheelSensitivity = wheelSensitivity // trigger set which updates dial
        
        for option in menuItems.scrollDirectionOptions {
            option.target = self
            option.action = #selector(setScrollDirection(sender:))
            option.selected = option.option == scrollDirection
        }
        
        for option in menuItems.hapticsModeOptions {
            option.target = self
            option.action = #selector(setHaptics(sender:))
            option.selected = option.option == hapticsMode
        }
        hapticsMode = hapticsMode // trigger set which updates dial
        
        
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
                currentController.onDown()
                break
            case .released:
                currentController.onUp()
                break
            }
        }
        
        dial.onRotation = { [unowned self] rotation, scrollDirection in
            currentController.onRotate(rotation, scrollDirection)
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
        
        let item = sender as! ControllerOptionItem
        
        menuItems.playbackMode.state = item == menuItems.playbackMode ? .on : .off
        menuItems.scrollMode.state = item == menuItems.scrollMode ? .on : .off
        
        currentMode = item.option
        
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
    
    @objc func setHaptics(sender: AnyObject) {
        let item = sender as! NSMenuItem
        hapticsMode = (item.representedObject as! HapticsMode)
    }

    @objc func quitApp(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

}
