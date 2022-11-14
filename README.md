# Mac Dial

Small app for the Surface Dial support in macOS. The Surface Dial can be paired with macOS but any input results in invalid mouse inputs. This app reads the raw data from the dial and translates it to correct events for macOS.

## Building

No additional libraries are needed.

You can find universal builds of the app under "releases". Note that these builds can be outdated.

## Usage

The app will continuously try to open any Surface Dial connected to the computer and then process inpout controls. You will need to pair and connect the device as any other bluetooth device.

The app currently supports two modes:
* Scroll mode: Turning the dial will result in scrolling. Pressing the dial is interpreted as a left-button mouse click at the current cursor position.
* Playback mode: Turning the dial controls the system volume of your mac. Pressing the dial plays / pauses any current playback while a double click sends the "next" media event, triple click sends "previous" media event.

To change mode, use the Mac Dial icon in the system menu bar.

If you want the app to run at startup you will need to add it yourself to the "Login items" for your user.

## Future Improvements
  
* Being able to use the dial indefinitely without disconnecting every 5 minutes 
* More input modes (please suggest)
* Change input mode using the dial itself (MS like menu?)
