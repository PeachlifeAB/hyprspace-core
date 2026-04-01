#!/usr/bin/swift

import AppKit
import Foundation

let hideThreshold: CGFloat = 8.0
let showThreshold: CGFloat = 24.0
let pollInterval: TimeInterval = 0.03

func sketchybarTrigger(_ name: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["sketchybar", "--trigger", name]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
}

func screenContainingMouse(_ position: NSPoint) -> NSScreen? {
    for screen in NSScreen.screens {
        if screen.frame.contains(position) {
            return screen
        }
    }
    return NSScreen.main ?? NSScreen.screens.first
}

func screenTop(for position: NSPoint) -> CGFloat? {
    guard let screen = screenContainingMouse(position) else { return nil }
    return screen.frame.origin.y + screen.frame.size.height
}

var barHidden = false

while true {
    let position = NSEvent.mouseLocation

    guard let top = screenTop(for: position) else {
        Thread.sleep(forTimeInterval: pollInterval)
        continue
    }

    let distanceFromTop = top - position.y

    if !barHidden {
        if distanceFromTop <= hideThreshold {
            sketchybarTrigger("cursor_at_top")
            barHidden = true
        }
    } else if distanceFromTop > showThreshold {
        sketchybarTrigger("cursor_away_from_top")
        barHidden = false
    }

    Thread.sleep(forTimeInterval: pollInterval)
}
