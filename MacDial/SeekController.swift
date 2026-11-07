
import Foundation
import AppKit

/// Seek controller — scrubs the current media track forward/backward.
///
/// Uses the media keys NX_KEYTYPE_FAST (forward) and NX_KEYTYPE_REWIND
/// (backward), which are the same keys the keyboard's ⏩ / ⏪ media keys
/// send, so they work in every app that honours media keys (Music, Spotify,
/// VLC, YouTube in a browser, Podcasts...).
class SeekController: Controller {

    func onDown() {
    }

    func onUp() {
    }

    func onRotate(_ rotation: Dial.Rotation, _ scrollDirection: Int) {
        switch rotation {
        case .Clockwise(let repeatCount):
            HIDPostAuxKey(key: NX_KEYTYPE_FAST, modifiers: [], _repeat: max(1, repeatCount))
        case .CounterClockwise(let repeatCount):
            HIDPostAuxKey(key: NX_KEYTYPE_REWIND, modifiers: [], _repeat: max(1, repeatCount))
        }
    }
}
