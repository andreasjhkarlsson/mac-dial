
import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController?
    let dial = Dial()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        dial.start();
        statusBarController = StatusBarController.init(dial)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        dial.stop();
    }
}

