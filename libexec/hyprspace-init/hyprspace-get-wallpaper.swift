import AppKit
import Foundation

let screens = NSScreen.screens

guard !screens.isEmpty else {
    fputs("ERROR no screens available\n", stderr)
    exit(1)
}

let workspace = NSWorkspace.shared
var paths: [String] = []

for screen in screens {
    if let url = workspace.desktopImageURL(for: screen) {
        paths.append(url.path)
    }
}

guard !paths.isEmpty else {
    fputs("ERROR unable to read wallpaper from any screen\n", stderr)
    exit(1)
}

// Print one path per line (usually all screens share the same wallpaper)
for path in paths {
    print(path)
}
