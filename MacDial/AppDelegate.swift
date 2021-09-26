//
//  AppDelegate.swift
//  MacDial
//
//  Created by Andreas Karlsson on 14/09/2021.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController?
    let popover = NSPopover.init()


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
        popover.contentSize = CGSize(width: 360, height: 360)
        popover.contentViewController = NSHostingController(rootView: contentView)
        statusBarController = StatusBarController.init(popover)
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

