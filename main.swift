import Foundation
import IOKit
import IOKit.hid
import CoreGraphics

// Shokz Loop120 dongle (OpenComm2 UC) — HID button → Fn bridge for Aqua Voice
//
// Button event map (measured 2026-11-15, hiddump):
//   Multifunction, standby     → Consumer 0xCD (Play/Pause)  → Fn×2 = hands-free START
//   Multifunction, hands-free  → Telephony 0x2F, val=0 single event → Fn = hands-free STOP
//   Mute, standby              → no event (local only)
//   Mute, hands-free           → Telephony 0x2F, val=1→val=0 pair → IGNORED
//
// 0x2F pair vs single is the only signal separating mute from multifunction.
// If a multifunction press ever arrives as a pair, its stop is ignored — press again.
//
// Play/Pause never reaches macOS: blocked by hidutil UserKeyMapping
// (LaunchAgent com.shokz.playpause-block, added 2026-11-15).

let vendorID = 0x3511   // Shokz (Loop110/120 common)
let productID = 0x2F06  // Loop120
let kVK_Function: CGKeyCode = 0x3F

func simulateFnPress() {
    let src = CGEventSource(stateID: .hidSystemState)
    if let down = CGEvent(keyboardEventSource: src, virtualKey: kVK_Function, keyDown: true),
       let up = CGEvent(keyboardEventSource: src, virtualKey: kVK_Function, keyDown: false) {
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

func simulateFnDoubleTap() {
    simulateFnPress()
    usleep(50000)
    simulateFnPress()
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matchDict: [String: Any] = [kIOHIDVendorIDKey as String: vendorID,
                              kIOHIDProductIDKey as String: productID]
IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
if openResult != 0 {
    print("ERROR: Cannot open HID manager (code: \(openResult))")
    print("Turn OFF Karabiner Modify Events for Loop120.")
    print("Grant Input Monitoring permission to Terminal.")
    exit(1)
}

let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
print("Shokz Loop120 devices: \(devices.count)")
if devices.isEmpty {
    print("ERROR: Loop120 not found.")
    exit(1)
}

var phonePressPending = false
var phonePressTime = Date.distantPast

let callback: IOHIDValueCallback = { context, result, sender, value in
    let element = IOHIDValueGetElement(value)
    let usagePage = Int(IOHIDElementGetUsagePage(element))
    let usage = Int(IOHIDElementGetUsage(element))
    let intValue = IOHIDValueGetIntegerValue(value)

    switch (usagePage, usage) {
    case (12, 205) where intValue == 1:
        print("[START] Play/Pause → Fn×2 (Hands Free ON)")
        simulateFnDoubleTap()
    case (11, 47):
        if intValue == 1 {
            phonePressPending = true
            phonePressTime = Date()
        } else {
            if phonePressPending && Date().timeIntervalSince(phonePressTime) < 1.0 {
                print("[SKIP] Mute button (0x2F pair) — ignored")
                phonePressPending = false
            } else {
                phonePressPending = false
                print("[STOP] Phone Key → Fn (Hands Free OFF)")
                simulateFnPress()
            }
        }
    default:
        break
    }
}

IOHIDManagerRegisterInputValueCallback(manager, callback, nil)
print("""
shokz-aquavoice daemon running.
  Standby   → button     → Fn×2 (Hands Free ON)
  Mic active → button    → Fn   (Hands Free OFF)
  Mic active → mute btn  → ignored (local mute only)
Press Ctrl+C to stop.
""")
CFRunLoopRun()
