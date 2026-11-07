# Mac Dial

macOS support for the Surface Dial. The surface dial can be paired with macOS but any input results in invalid mouse inputs on macOS. This app reads the raw data from the dial and translates them to correct mouse and media inputs for macOS.

## Building

Clone the repository and build with XCode. No C library or submodule is needed — the dial is read through the native IOKit HID APIs.

You can find universal builds of the app under "releases". Note that these builds can be outdated.

## Usage

The app will continously try to open any Surface Dial connected to the computer and then process input controls. You will need to pair and connect the device as any other bluetooth device.

The app currently supports four modes:
* Scroll mode: Turning the dial will result in scrolling. Pressing the dial is interpreteded as a mouse click at the current cursor position.
* Playback mode: Turning the dial controls the system volume of your mac. Pressing the dial plays / pauses any current playback while a double click sends the "next" media action.
* Zoom mode: Turning the dial zooms in and out.
* Seek mode: Turning the dial seeks forward and backward in the current media.

To change mode, click the Mac Dial icon in the system menu bar, or press the dial to open the radial mode picker and rotate to the mode you want, then press again to confirm.

If you want to app to run at startup you will need to add it yourself to the "login items" for your user.

## Permissions

The app needs Accessibility access (to send clicks and key events) and Input Monitoring (to read the raw HID reports from the dial). Both are requested on first launch.

## Improvements

* ~~Change input mode using the dial itself~~ — a radial mode picker is available by pressing the dial
* ~~Smarter device discovery (currently tries to open the dial every 50 ms)~~
