import Foundation

DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("AppleInterfaceMenuBarHidingChangedNotification"),
    object: nil,
    userInfo: nil,
    options: [.deliverImmediately, .postToAllSessions]
)

print("OK menu bar notification posted")
