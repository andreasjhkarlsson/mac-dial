
import Foundation
import AppKit

enum WheelSensitivity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case extreme = "extreme"

    var dialValue: Int {
        switch self {
        case .low: return 18
        case .medium: return 36
        case .high: return 72
        case .extreme: return 360
        }
    }
}

enum ScrollDirection: String {
    case standard = "standard"
    case natural = "natural"
}

enum Mode: String, CaseIterable {
    case scrolling = "scrolling"
    case playback = "playback"
    case brightness = "brightness"
    case missionControl = "missionControl"

    var displayName: String {
        switch self {
        case .scrolling: return "Scroll mode"
        case .playback: return "Playback mode"
        case .brightness: return "Brightness mode"
        case .missionControl: return "Mission Control mode"
        }
    }

    var symbolName: String {
        switch self {
        case .scrolling: return "arrow.up.arrow.down"
        case .playback: return "play.circle"
        case .brightness: return "sun.max"
        case .missionControl: return "square.grid.2x2"
        }
    }

    var legacyAssetName: String? {
        switch self {
        case .scrolling: return "icon-scroll"
        case .playback: return "icon-playback"
        default: return nil
        }
    }

    func next() -> Mode {
        let all = Mode.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
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
        for modeItem in items.modeItems {
            self.addItem(modeItem)
        }
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
        self.addItem(items.launchAtLogin)
        self.addItem(items.separator4)
        self.addItem(items.about)
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

    private static let longPressThreshold: TimeInterval = 0.6
    private var pressStartTime: TimeInterval?
    private var longPressTimer: DispatchSourceTimer?
    private var longPressActive: Bool = false

    struct MenuItems {
        let title = NSMenuItem.init(title: "Mac Dial")
        let connectionStatus = NSMenuItem.init()
        let separator = NSMenuItem.separator()
        let modeItems: [ControllerOptionItem] = [
            ControllerOptionItem(title: Mode.scrolling.displayName, mode: .scrolling, controller: ScrollController()),
            ControllerOptionItem(title: Mode.playback.displayName, mode: .playback, controller: PlaybackController()),
            ControllerOptionItem(title: Mode.brightness.displayName, mode: .brightness, controller: BrightnessController()),
            ControllerOptionItem(title: Mode.missionControl.displayName, mode: .missionControl, controller: MissionControlController()),
        ]
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
        let launchAtLogin = NSMenuItem.init(title: "Launch at Login")
        let separator4 = NSMenuItem.separator()
        let about = NSMenuItem.init(title: "About Mac Dial")
        let quit = NSMenuItem.init(title: "Quit")
    }
    
    var currentMode: Mode
    {
        get {
            if let raw = UserDefaults.standard.string(forKey: "mode"),
               let mode = Mode(rawValue: raw) {
                return mode
            }
            // Back-compat with the 1.4 storage that used "scroll"/"playback".
            switch UserDefaults.standard.string(forKey: "mode") {
            case .some("scroll"): return .scrolling
            case .some("playback"): return .playback
            default: return .scrolling
            }
        }
        
        set (value) {
            UserDefaults.standard.setValue(value.rawValue, forKey: "mode")
        }
    }
    
    var currentController: Controller
    {
        get {
            return controllerItem(for: currentMode).controller
        }
    }

    private func controllerItem(for mode: Mode) -> ControllerOptionItem {
        return menuItems.modeItems.first { $0.option == mode } ?? menuItems.modeItems[0]
    }

    private func sensitivityKey(for mode: Mode) -> String {
        return "sensitivity.\(mode.rawValue)"
    }

    private func sensitivity(for mode: Mode) -> WheelSensitivity {
        // Fall back to the legacy global "sensitivity" key, then to medium.
        if let raw = UserDefaults.standard.string(forKey: sensitivityKey(for: mode)),
           let value = WheelSensitivity(rawValue: raw) {
            return value
        }
        if let raw = UserDefaults.standard.string(forKey: "sensitivity"),
           let value = WheelSensitivity(rawValue: raw) {
            return value
        }
        return .medium
    }

    private func setSensitivity(_ sensitivity: WheelSensitivity, for mode: Mode) {
        UserDefaults.standard.setValue(sensitivity.rawValue, forKey: sensitivityKey(for: mode))
        if mode == currentMode {
            applySensitivityToDial()
        }
        refreshSensitivityCheckmarks()
    }

    private func applySensitivityToDial() {
        dial.wheelSensitivity = sensitivity(for: currentMode).dialValue
    }

    private func refreshSensitivityCheckmarks() {
        let current = sensitivity(for: currentMode)
        for option in menuItems.wheelSensitivityOptions {
            option.selected = option.option == current
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
            case .natural:
                dial.scrollDirection = -1
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
            case .enabled:
                dial.haptics = true
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

        // IMPORTANT: must use NSStatusBar.system; a freshly-init'd NSStatusBar
        // is not connected to the actual menu bar, so the status item would
        // be created but never render. This was the cause of the missing
        // menu bar icon in 1.4 on recent macOS releases.
        statusBar = NSStatusBar.system
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

        for modeItem in menuItems.modeItems {
            modeItem.target = self
            modeItem.action = #selector(setMode(sender:))
            modeItem.selected = modeItem.option == currentMode
        }
        
        for option in menuItems.wheelSensitivityOptions {
            option.target = self
            option.action = #selector(setSensitivity(sender:))
        }
        refreshSensitivityCheckmarks()
        applySensitivityToDial()
        
        for option in menuItems.scrollDirectionOptions {
            option.target = self
            option.action = #selector(setScrollDirection(sender:))
            option.selected = option.option == scrollDirection
        }
        scrollDirection = scrollDirection // trigger set which updates dial
        
        for option in menuItems.hapticsModeOptions {
            option.target = self
            option.action = #selector(setHaptics(sender:))
            option.selected = option.option == hapticsMode
        }
        hapticsMode = hapticsMode // trigger set which updates dial

        menuItems.launchAtLogin.target = self
        menuItems.launchAtLogin.action = #selector(toggleLaunchAtLogin(sender:))
        menuItems.launchAtLogin.isEnabled = LoginItem.isAvailable
        menuItems.launchAtLogin.state = LoginItem.isEnabled ? .on : .off

        menuItems.about.target = self
        menuItems.about.action = #selector(showAbout(sender:))
        
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
        updateConnectionStatus()

        dial.onButtonStateChanged = { [unowned self] state in
            switch state {
            case .pressed:
                handleButtonPressed()
            case .released:
                handleButtonReleased()
            }
        }
        
        dial.onRotation = { [unowned self] rotation, scrollDirection in
            currentController.onRotate(rotation, scrollDirection)
        }
    }

    private func handleButtonPressed() {
        pressStartTime = Date().timeIntervalSince1970
        longPressActive = false
        currentController.onDown()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.longPressThreshold)
        timer.setEventHandler { [weak self] in
            self?.fireLongPress()
        }
        longPressTimer?.cancel()
        longPressTimer = timer
        timer.resume()
    }

    private func handleButtonReleased() {
        longPressTimer?.cancel()
        longPressTimer = nil
        pressStartTime = nil

        if longPressActive {
            longPressActive = false
            // onCancel for the new (post-cycle) controller is a no-op; the
            // old controller was already cancelled in fireLongPress.
            return
        }

        currentController.onUp()
    }

    private func fireLongPress() {
        longPressTimer = nil
        longPressActive = true

        // Release any state the current mode set up in onDown (e.g. a
        // pending mouse-down in scroll mode) before swapping controllers.
        currentController.onCancel()

        // Cycle to the next mode and give a haptic blip as feedback.
        let next = currentMode.next()
        applyMode(next)
        dial.device.impact()
    }

    private func applyMode(_ mode: Mode) {
        currentMode = mode
        for item in menuItems.modeItems {
            item.selected = item.option == mode
        }
        applySensitivityToDial()
        refreshSensitivityCheckmarks()
        updateIcon()
    }
    
    private func updateConnectionStatus() {
        let connected = dial.device.isConnected
        if connected {
            let serialNumber = dial.device.serialNumber
            menuItems.connectionStatus.title = "Surface Dial '\(serialNumber)' connected"
        } else {
            menuItems.connectionStatus.title = "No Surface Dial connected"
        }
        // Dim the menu bar icon when no Dial is connected so it's obvious
        // at a glance whether the app has hardware to talk to.
        statusItem.button?.appearsDisabled = !connected
    }
    
    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName = currentMode.symbolName
        var image: NSImage? = NSImage(systemSymbolName: symbolName, accessibilityDescription: currentMode.displayName)

        if image == nil, let asset = currentMode.legacyAssetName {
            image = NSImage(named: asset)
        }

        if let img = image {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        }

        button.imagePosition = .imageLeft
    }
    
    @objc func showAbout(sender: AnyObject) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "Mac Dial"
        alert.informativeText = """
        Version \(version)

        Surface Dial support for macOS.
        Click the menu bar icon to switch modes, or long-press the dial to cycle modes from the dial itself.

        https://github.com/andreasjhkarlsson/mac-dial
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open on GitHub")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn,
           let url = URL(string: "https://github.com/andreasjhkarlsson/mac-dial") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func setMode(sender: AnyObject) {
        guard let item = sender as? ControllerOptionItem else { return }
        applyMode(item.option)
    }
    
    @objc func setSensitivity(sender: AnyObject) {
        guard let item = sender as? MenuOptionItem<WheelSensitivity> else { return }
        setSensitivity(item.option, for: currentMode)
    }
    
    @objc func setScrollDirection(sender: AnyObject) {
        let item = sender as! NSMenuItem
        scrollDirection = (item.representedObject as! ScrollDirection)
    }
    
    @objc func setHaptics(sender: AnyObject) {
        let item = sender as! NSMenuItem
        hapticsMode = (item.representedObject as! HapticsMode)
    }

    @objc func toggleLaunchAtLogin(sender: AnyObject) {
        let newValue = !LoginItem.isEnabled
        LoginItem.setEnabled(newValue)
        menuItems.launchAtLogin.state = LoginItem.isEnabled ? .on : .off
    }

    @objc func quitApp(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

}

