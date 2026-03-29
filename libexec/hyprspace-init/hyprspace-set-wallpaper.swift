import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: hyprspace-set-wallpaper <image-path>\n", stderr)
    exit(2)
}

let wallpaperPath = CommandLine.arguments[1]
let wallpaperURL = URL(fileURLWithPath: wallpaperPath)
let screens = NSScreen.screens

guard FileManager.default.fileExists(atPath: wallpaperPath) else {
    fputs("ERROR missing wallpaper file: \(wallpaperPath)\n", stderr)
    exit(3)
}

guard !screens.isEmpty else {
    fputs("ERROR no screens available\n", stderr)
    exit(1)
}

let workspace = NSWorkspace.shared
for screen in screens {
    let options = workspace.desktopImageOptions(for: screen) ?? [:]
    try workspace.setDesktopImageURL(wallpaperURL, for: screen, options: options)
}

print("OK wallpaper applied to \(screens.count) screen(s)")
