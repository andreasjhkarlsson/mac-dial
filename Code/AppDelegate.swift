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

let logsEnabled: Bool = true

#if DEBUG
func log(tag: String, _ message: @autoclosure () -> String) {
    guard logsEnabled else { return }

    print("\(Date()) [\(tag)] \(message())")
}
#else
func log(tag: String, _ message: @autoclosure () -> String) {
}
#endif

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet private var controller: AppController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        controller.terminate()
    }
}
