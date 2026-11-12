// Print the window number of the Atari800 emulator window, for screencapture -l.
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in windows {
    if let owner = w[kCGWindowOwnerName as String] as? String,
       owner.lowercased().contains("atari800"),
       let number = w[kCGWindowNumber as String] as? Int {
        print(number)
        break
    }
}
