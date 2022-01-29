//
// AppDelegate
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

let logsEnabled: Bool = false
func log(_ message: @autoclosure () -> String) {
    guard logsEnabled else { return }

    print(message())
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet private var controller: AppController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        controller.terminate()
    }
}
