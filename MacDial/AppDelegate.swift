
import Cocoa
import ServiceManagement
import SwiftUI
import IOKit.hidsystem

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController?
    let dial = Dial()

    func requestPermissions() {
        // More information on this behaviour: https://stackoverflow.com/questions/29006379/accessibility-permissions-reset-after-application-update
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "App permissions"
            alert.alertStyle = NSAlert.Style.informational
            alert.informativeText = "Mac Dial needs Accessibility permissions to work. In the next dialog you will be asked to open the Settings app to enable the permissions.\nIMPORTANT! Due to an issue in macOS, if you're upgrading from an earlier version of Mac Dial you might have to remove Mac Dial from the accessibility permissions and then restart the app to re-add the permissions."
            alert.runModal()
        }

        let options : NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]

        AXIsProcessTrustedWithOptions(options)

        requestInputMonitoring()
    }

    /// macOS gates raw HID access behind Input Monitoring. Without it,
    /// the dial never delivers reports to the app. Requesting access here
    /// makes the system show the "allow input monitoring" prompt.
    private func requestInputMonitoring() {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if access != kIOHIDAccessTypeGranted {
            print("Input Monitoring not granted — requesting (macOS will prompt).")
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        } else {
            print("Input Monitoring already granted.")
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        requestPermissions()
        dial.start();
        statusBarController = StatusBarController.init(dial)

        // Debug hook: MACDIAL_SHOW_PICKER=1 opens the radial menu on launch so
        // the layout can be verified without physically pressing the dial.
        if ProcessInfo.processInfo.environment["MACDIAL_SHOW_PICKER"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.statusBarController?.debugShowPicker()
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        dial.stop();
    }
}

