#!/usr/bin/swift

import AppKit
import CoreGraphics
import Foundation

let bouncerThreshold: CGFloat = 5.0
let bounceTargetOffset: CGFloat = 8.0
let hideThreshold: CGFloat = 3.0
let showThreshold: CGFloat = 40.0
let pollInterval: TimeInterval = 0.1

func sketchybarTrigger(_ name: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["sketchybar", "--trigger", name]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
}

func isCommandPressed() -> Bool {
    NSEvent.modifierFlags.contains(.command)
}

func checkAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func mainScreenTop() -> CGFloat? {
    guard let screen = NSScreen.main else { return nil }
    return screen.frame.origin.y + screen.frame.size.height
}

func bounceCursor(current: NSPoint, screenTop: CGFloat) {
    guard let screen = NSScreen.main else { return }

    let screenHeight = screen.frame.size.height
    let screenOriginY = screen.frame.origin.y
    let targetCocoaY = screenTop - bounceTargetOffset
    let targetCGY = (screenOriginY + screenHeight) - targetCocoaY

    CGWarpMouseCursorPosition(CGPoint(x: current.x, y: targetCGY))
}

let hasAccessibility = checkAccessibilityPermissions()
if !hasAccessibility {
    fputs("cursor_monitor: Accessibility permission not granted; bouncer disabled.\n", stderr)
}

var barHidden = false

while true {
    guard let top = mainScreenTop() else {
        Thread.sleep(forTimeInterval: pollInterval)
        continue
    }

    let position = NSEvent.mouseLocation
    let distanceFromTop = top - position.y

    if hasAccessibility, distanceFromTop <= bouncerThreshold, !isCommandPressed() {
        bounceCursor(current: position, screenTop: top)
    }

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