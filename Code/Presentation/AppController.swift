//
// AppController
// MacDial
//
// Created by Alex Babaev on 28 January 2022.
//
// Based on Andreas Karlsson sources
// https://github.com/andreasjhkarlsson/mac-dial
//
// License: MIT
//

import AppKit

class AppController: NSObject {
    @IBOutlet private var statusMenu: NSMenu!

    @IBOutlet private var menuState: NSMenuItem!

    @IBOutlet private var menuControlModeScroll: NSMenuItem!
    @IBOutlet private var menuControlModePlayback: NSMenuItem!

    @IBOutlet private var menuSensitivityLow: NSMenuItem!
    @IBOutlet private var menuSensitivityMedium: NSMenuItem!
    @IBOutlet private var menuSensitivityHigh: NSMenuItem!

    private let statusItem: NSStatusItem

    private let settings: UserSettings = .init()

    private var dial: Dial?
    private var currentControlMode: DialDelegate & ControlMode = ScrollControlMode()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        dial = Dial(connectionHandler: connected, disconnectionHandler: disconnected)
    }

    override func awakeFromNib() {
        statusItem.menu = statusMenu

        switch settings.operationMode {
            case .scrolling:
                modeSelect(item: menuControlModeScroll)
            case .playbackAndVolume:
                modeSelect(item: menuControlModePlayback)
        }
        switch settings.sensitivity {
            case .low:
                sensitivitySelect(item: menuSensitivityLow)
            case .medium:
                sensitivitySelect(item: menuSensitivityMedium)
            case .high:
                sensitivitySelect(item: menuSensitivityHigh)
        }
    }

    func terminate() {
        dial = nil
    }

    private func connected(_ serialNumber: String) {
        menuState.title = "Connected to MS Dial (serial: \(serialNumber))"
    }

    private func disconnected() {
        menuState.title = "Not Connected to MS Dial"
    }

    @IBAction
    private func modeSelect(item: NSMenuItem) {
        menuControlModeScroll.state = .off
        menuControlModePlayback.state = .off
        switch item.identifier {
            case menuControlModeScroll.identifier:
                currentControlMode = ScrollControlMode()
                menuControlModeScroll.state = .on
                settings.operationMode = .scrolling
            case menuControlModePlayback.identifier:
                currentControlMode = PlaybackControlMode()
                menuControlModePlayback.state = .on
                settings.operationMode = .playbackAndVolume
            default:
                break
        }
        dial?.delegate = currentControlMode
        statusItem.button?.image = currentControlMode.image
        statusItem.button?.image?.size = .init(width: 18, height: 18)
        statusItem.button?.imagePosition = .imageLeft
    }

    @IBAction
    private func sensitivitySelect(item: NSMenuItem) {
        menuSensitivityLow.state = .off
        menuSensitivityMedium.state = .off
        menuSensitivityHigh.state = .off
        switch item.identifier {
            case menuSensitivityLow.identifier:
                menuSensitivityLow.state = .on
                dial?.wheelSensitivity = 1
                settings.sensitivity = .low
            case menuSensitivityMedium.identifier:
                menuSensitivityMedium.state = .on
                dial?.wheelSensitivity = 2
                settings.sensitivity = .medium
            case menuSensitivityHigh.identifier:
                menuSensitivityHigh.state = .on
                dial?.wheelSensitivity = 3
                settings.sensitivity = .high
            default:
                break
        }
    }

    @IBAction
    private func quitTap(_ item: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
}
