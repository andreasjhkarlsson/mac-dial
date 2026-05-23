# Mac Dial

macOS support for the Surface Dial. The surface dial can be paired with macOS but any input results in invalid mouse inputs on macOS. This app reads the raw data from the dial and translates them to correct mouse and media inputs for macOS.

## Building

Requirements:
- macOS 13.0 (Ventura) or later
- Xcode 14 or later (Xcode 26 tested)
- `cmake` (install with `brew install cmake`)

Steps:

```sh
git clone --recursive https://github.com/andreasjhkarlsson/mac-dial.git
cd mac-dial
# If you didn't clone with --recursive:
# git submodule update --init --recursive
./build_hidapi.sh
xcodebuild -project MacDial.xcodeproj -scheme MacDial -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
cp -R build/Build/Products/Release/MacDial.app ~/Applications/
```

Note: this depends on a hidapi fork (the upstream `hid_monitor` callback used by `Dial.swift` is custom). The submodule URL points at the fork; do not replace it with upstream hidapi.

You can find universal builds of the app under "releases". Note that these builds can be outdated.

## Usage

The app continuously tries to open any Surface Dial connected to the computer and processes its input. Pair and connect the device as any other bluetooth device.

The app supports four modes:

- **Scroll mode**: turning the dial scrolls; pressing the dial is a mouse click at the cursor position.
- **Playback mode**: turning the dial controls system volume; pressing plays/pauses; double-pressing sends "next track".
- **Brightness mode**: turning the dial adjusts the brightness of the display **under the cursor** (works on both built-in displays and external Apple displays like the Studio Display / Pro Display XDR, via the private `DisplayServices` framework with a graceful fallback to the F1/F2 system event). Pressing does nothing.
- **Mission Control mode**: turning the dial switches between Spaces; pressing opens Mission Control.

You can switch modes either by clicking the Mac Dial icon in the menu bar, or by **long-pressing the dial itself** (hold > 600 ms). Mac Dial gives a haptic blip when the mode cycles.

Wheel sensitivity is remembered **per mode**, so e.g. you can have low sensitivity for brightness but extreme sensitivity for scrolling.

When no Surface Dial is connected the menu bar icon is dimmed so you can tell at a glance whether the app has hardware to talk to.

### Launch at login

There's a "Launch at Login" toggle in the menu (requires macOS 13+). It uses the modern `SMAppService` API and is per-user.

## Improvements

* More input modes
* ~~Change input mode using the dial itself~~
* ~~Smarter device discovery (currently tries to open the dial every 50 ms)~~

