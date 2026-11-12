// Print the window number of an Atari800 emulator window, for screencapture -l.
//
//     winid [pid]
//
// With a process id, only that emulator's window is considered, so a test
// run never picks up a copy of the emulator that somebody is playing in.
// Looks at every window, not only those on the current desktop, so it still
// works when the emulator opens on another Space.
import CoreGraphics
import Foundation

let wantedPid: Int? = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) : nil
let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in windows {
    if let owner = w[kCGWindowOwnerName as String] as? String,
       owner.lowercased().contains("atari800"),
       let pid = w[kCGWindowOwnerPID as String] as? Int,
       wantedPid == nil || wantedPid == pid,
       let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
       let bounds = w[kCGWindowBounds as String] as? [String: Any],
       let height = bounds["Height"] as? Double, height > 100,
       let number = w[kCGWindowNumber as String] as? Int {
        print(number)
        break
    }
}
