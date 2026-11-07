
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
    case zoom = "zoom"
    case seek = "seek"

    /// Maps a persisted mode string onto the app's DialMode.
    var dialMode: DialMode {
        switch self {
        case .scrolling: return .scroll
        case .playback: return .volume
        case .zoom:     return .zoom
        case .seek:     return .seek
        }
    }

    init?(dialMode: DialMode) {
        switch dialMode {
        case .scroll: self = .scrolling
        case .volume: self = .playback
        case .zoom:   self = .zoom
        case .seek:   self = .seek
        }
    }
}
enum HapticsMode: String {
    case enabled = "enabled"
    case disabled = "disabled"
}

/// How many detents the dial must be turned before the on-screen mode
/// picker moves to the next mode.
enum PickerSensitivity: String {
    /// Every detent moves the selection.
    case high = "high"
    /// Three detents per mode change.
    case medium = "medium"
    /// Five detents per mode change.
    case low = "low"

    /// Number of detents required to move one step in the picker.
    var stepsPerMode: Int {
        switch self {
        case .high: return 1
        case .medium: return 3
        case .low: return 5
        }
    }
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
        self.addItem(items.zoomMode)
        self.addItem(items.seekMode)
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

        items.pickerSensitivity.submenu = NSMenu.init()
        for pickerSensitivityOption in items.pickerSensitivityOptions {
            items.pickerSensitivity.submenu?.addItem(pickerSensitivityOption)
        }
        self.addItem(items.pickerSensitivity)

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

    /// The on-screen mode picker shown when the dial's button is pressed.
    private let picker = ModePickerPanel()

    /// True while the on-screen picker is open — in that state the dial
    /// navigates the menu instead of driving the active controller.
    private var isPickerOpen = false
    
    struct MenuItems {
        let title = NSMenuItem.init(title: "Mac Dial")
        let connectionStatus = NSMenuItem.init()
        let separator = NSMenuItem.separator()
        let scrollMode = ControllerOptionItem.init(title: "Scroll mode", mode: .scrolling, controller: ScrollController())
        let playbackMode = ControllerOptionItem.init(title: "Playback mode", mode: .playback, controller: PlaybackController())
        let zoomMode = ControllerOptionItem.init(title: "Zoom mode", mode: .zoom, controller: ZoomController())
        let seekMode = ControllerOptionItem.init(title: "Seek mode", mode: .seek, controller: SeekController())
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
        let pickerSensitivity = NSMenuItem.init(title: "Menu Sensitivity")
        let pickerSensitivityOptions = [
            MenuOptionItem<PickerSensitivity>.init(title: "High (1 step)", option: .high),
            MenuOptionItem<PickerSensitivity>.init(title: "Medium (3 steps)", option: .medium),
            MenuOptionItem<PickerSensitivity>.init(title: "Low (5 steps)", option: .low)
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
            case .some("zoom"):
                return .zoom
            case .some("seek"):
                return .seek
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
            case .zoom:
                UserDefaults.standard.setValue("zoom", forKey: "mode")
            case .seek:
                UserDefaults.standard.setValue("seek", forKey: "mode")
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
            case .zoom:
                return menuItems.zoomMode.controller
            case .seek:
                return menuItems.seekMode.controller
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

    /// How many detents the dial must be turned before the on-screen picker
    /// moves to the next mode.
    var pickerSensitivity: PickerSensitivity? {
        get {
            let raw = UserDefaults.standard.string(forKey: "pickersensitivity") ?? PickerSensitivity.medium.rawValue
            return PickerSensitivity(rawValue: raw)
        }
        set (sensitivity) {
            for option in menuItems.pickerSensitivityOptions {
                option.state = (option.representedObject as! PickerSensitivity) == sensitivity ? .on : .off
            }

            // Show the active setting in the parent item's title.
            if let sensitivity = sensitivity {
                menuItems.pickerSensitivity.title = "Menu Sensitivity (\(sensitivity.rawValue.capitalized))"
            } else {
                menuItems.pickerSensitivity.title = "Menu Sensitivity"
            }

            UserDefaults.standard.setValue(sensitivity?.rawValue, forKey: "pickersensitivity")
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

        menuItems.zoomMode.target = self
        menuItems.zoomMode.action = #selector(setMode(sender:))
        menuItems.zoomMode.selected = currentMode == .zoom;

        menuItems.seekMode.target = self
        menuItems.seekMode.action = #selector(setMode(sender:))
        menuItems.seekMode.selected = currentMode == .seek;

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

        for option in menuItems.pickerSensitivityOptions {
            option.target = self
            option.action = #selector(setPickerSensitivity(sender:))
            option.selected = option.option == pickerSensitivity
        }
        pickerSensitivity = pickerSensitivity // trigger set which updates the menu state
        
        
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
        
        // The combined press → rotate → release handler owns the interaction.
        // The separate callbacks stay wired up so either style can be used,
        // but only one of them drives the UI at a time.
        dial.onInteraction = { [unowned self] interaction in
            self.handleInteraction(interaction)
        }

        dial.onButtonStateChanged = { [unowned self] state in
            guard !self.usesCombinedGesture else { return }
            switch state {
            case .pressed:
                self.handleButtonPressed()
                break
            case .released:
                self.handleButtonReleased()
                break
            }
        }

        dial.onRotation = { [unowned self] rotation, scrollDirection in
            guard !self.usesCombinedGesture else { return }
            self.handleRotation(rotation, scrollDirection)
        }
    }

    /// When true, the single combined gesture handler drives the UI and the
    /// separate press/rotate/release handlers are ignored.
    var usesCombinedGesture = true

    /// True while the dial button is held down.
    private var isDialHeld = false

    /// True when the dial was turned during this press, meaning the gesture
    /// was "press and rotate" rather than a plain tap.
    private var didRotateWhileHeld = false

    /// True when the next release of the dial button should confirm the
    /// highlighted mode.
    ///
    /// Set when the dial is clicked while the menu is already open, and when
    /// the dial is rotated while the button is held. A plain first tap leaves
    /// it false, so the menu stays open.
    private var pendingConfirm = false

    // MARK: - Button handling

    /// Handles the whole press → rotate → release gesture in one place.
    ///
    /// This is the combined counterpart to `handleButtonPressed`,
    /// `handleButtonReleased` and the rotation handler. All three remain
    /// available separately for callers that want the individual events.
    private func handleInteraction(_ interaction: Dial.Interaction) {
        switch interaction {
        case .pressed:
            isDialHeld = true
            didRotateWhileHeld = false

            if isPickerOpen {
                // The menu is already open: this click confirms the
                // highlighted mode when the button comes back up.
                pendingConfirm = true
                print("[Dial] press → confirm pending")
            } else {
                // First click: open the menu and leave it open.
                openPicker()
                print("[Dial] press → menu opened")
            }

        case .rotated(let rotation, let scrollDirection):
            if isDialHeld {
                // "Press and rotate" confirms on release.
                didRotateWhileHeld = true
                pendingConfirm = true
            }
            handleRotation(rotation, scrollDirection)

        case .released:
            let shouldConfirm = pendingConfirm
            isDialHeld = false
            didRotateWhileHeld = false
            pendingConfirm = false

            // A plain tap leaves the menu open, waiting for the user to
            // rotate to a mode and click again to confirm. A press-and-rotate
            // gesture confirms on release, as before.
            if shouldConfirm && isPickerOpen {
                print("[Dial] release → confirm")
                confirmPicker()
            } else {
                print("[Dial] release → menu stays open")
            }
        }
    }

    /// Rotation while the picker is open moves the selection; otherwise it
    /// drives the active mode.
    private func handleRotation(_ rotation: Dial.Rotation, _ scrollDirection: Int) {
        if isPickerOpen {
            var steps = 0
            switch rotation {
            case .Clockwise(let d): steps = d
            case .CounterClockwise(let d): steps = -d
            }
            picker.moveSelection(by: steps)
        } else {
            currentController.onRotate(rotation, scrollDirection)
        }
    }

    /// Opens the picker with the current mode highlighted.
    private func openPicker() {
        isPickerOpen = true
        // Apply the configured sensitivity so the picker needs several
        // detents before the selection moves.
        picker.stepsPerMode = pickerSensitivity?.stepsPerMode ?? 1
        // Start the highlight on the currently active mode.
        picker.select(index: DialMode.allCases.firstIndex(of: currentMode.dialMode) ?? 0)
        picker.onConfirm = { [weak self] mode in
            guard let self = self else { return }
            self.apply(mode: mode)
        }
        picker.onCancel = { [weak self] in
            self?.isPickerOpen = false
        }
        picker.show()
    }

    /// Confirms the highlighted mode and closes the picker.
    private func confirmPicker() {
        isPickerOpen = false
        picker.confirm()
    }

    /// First press opens the on-screen picker, second press confirms.
    ///
    /// This is the separate-callback path, used when `usesCombinedGesture`
    /// is false. It mirrors the combined handler: the first click only opens
    /// the menu, and a later click confirms it.
    private func handleButtonPressed() {
        if isPickerOpen {
            // The menu is already open: this click confirms the highlighted
            // mode.
            confirmPicker()
        } else {
            openPicker()
        }
    }

    private func handleButtonReleased() {
        // Nothing to do — confirmation happens on press, not release.
    }

    /// Debug helper: open the picker without pressing the dial.
    func debugShowPicker() {
        isPickerOpen = true
        picker.select(index: 0)
        picker.onConfirm = { [weak self] mode in
            self?.apply(mode: mode)
        }
        picker.onCancel = { [weak self] in
            self?.isPickerOpen = false
        }
        picker.show()
    }

    /// Switch the active mode and refresh the menu bar state.
    private func apply(mode: DialMode) {
        isPickerOpen = false

        menuItems.scrollMode.state = (mode == .scroll) ? .on : .off
        menuItems.playbackMode.state = (mode == .volume) ? .on : .off
        menuItems.zoomMode.state = (mode == .zoom) ? .on : .off
        menuItems.seekMode.state = (mode == .seek) ? .on : .off

        if let appMode = Mode(dialMode: mode) {
            currentMode = appMode
        }

        updateIcon()
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
            else if (menuItems.zoomMode.state == .on) {
                button.image = makeSymbolImage(named: "plus.magnifyingglass", fallback: "icon-scroll")
            }
            else if (menuItems.seekMode.state == .on) {
                button.image = makeSymbolImage(named: "forward.end.alt", fallback: "icon-playback")
            }

            button.image?.size = NSSize(width: 18, height: 18)

            button.imagePosition = .imageLeft
        }
    }

    /// SF Symbols need macOS 11; this app deploys to 10.15, so fall back to a
    /// bundled asset when the symbol is unavailable.
    private func makeSymbolImage(named: String, fallback: String) -> NSImage? {
        if #available(macOS 11.0, *) {
            if let image = NSImage(systemSymbolName: named, accessibilityDescription: nil) {
                return image
            }
        }
        return NSImage(named: fallback)
    }
    
    @objc func showAbout(sender: AnyObject) {
        
    }
    
    @objc func setMode(sender: AnyObject) {

        let item = sender as! ControllerOptionItem

        menuItems.playbackMode.state = item == menuItems.playbackMode ? .on : .off
        menuItems.scrollMode.state = item == menuItems.scrollMode ? .on : .off
        menuItems.zoomMode.state = item == menuItems.zoomMode ? .on : .off
        menuItems.seekMode.state = item == menuItems.seekMode ? .on : .off

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

    @objc func setPickerSensitivity(sender: AnyObject) {
        let item = sender as! NSMenuItem
        pickerSensitivity = (item.representedObject as! PickerSensitivity)
    }

    @objc func quitApp(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

}
