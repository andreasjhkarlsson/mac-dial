# Mac Dial

macOS support for the Surface Dial. The surface dial can be paired with macOS but any input results in invalid mouse inputs on macOS. This app reads the raw data from the dial and translates them to correct mouse and media inputs for macOS.

## Building

Make sure to clone the hidapi submodule and build the library using the build_hidapi.sh script. App should then build with XCode.

You can find universal builds of the app under "releases". Note that these builds can be outdated.

## Usage

The app will continously try to open any Surface Dial connected to the computer and then process inpout controls. You will need to pair and connect the device  as any other bluetooth device.

The app currently supports two modes:
* Scroll mode: Turning the dial will result in scrolling. Pressing the dial is interpreteded as a mouse click at the current cursor position.
* Playback mode: Turning the dial controls the system volume of your mac. Pressing the dial plays / pauses any current playback while a double click sends the "next" media action.

To change mode, click the Mac Dial icon in the system menu bar.

If you want to app to run at startup you will need to add it yourself to the "login items" for your user.

## Improvements

* More input modes
* Change input mode using the dial itself
* Smarter device discovery (currently tries to open the dial every 50 ms)
