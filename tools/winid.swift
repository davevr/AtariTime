// Print the window number of the Atari800 emulator window, for screencapture -l.
// Looks at every window, not only those on the current desktop, so it still
// works when the emulator opens on another Space.
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in windows {
    if let owner = w[kCGWindowOwnerName as String] as? String,
       owner.lowercased().contains("atari800"),
       let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
       let bounds = w[kCGWindowBounds as String] as? [String: Any],
       let height = bounds["Height"] as? Double, height > 100,
       let number = w[kCGWindowNumber as String] as? Int {
        print(number)
        break
    }
}
