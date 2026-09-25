//
//  AccessibleWindow.swift
//  Keypath
//

import AppKit
import ApplicationServices

struct AccessibleWindow: Identifiable {
    let number: Int
    let title: String
    let isMinimized: Bool
    let element: AXUIElement

    var id: Int { number }
}

@MainActor
enum ApplicationWindowAccessibility {
    static func windows(for application: NSRunningApplication) -> [AccessibleWindow] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        ) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return []
        }

        let standardWindows = windows.filter(isStandardWindow)
        var orderedWindows = standardWindows

        var focusedWindowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        ) == .success,
           let focusedWindowValue,
           CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID() {
            let focusedWindow = unsafeDowncast(focusedWindowValue, to: AXUIElement.self)
            if let focusedIndex = orderedWindows.firstIndex(where: {
                CFEqual($0 as CFTypeRef, focusedWindow as CFTypeRef)
            }) {
                let focused = orderedWindows.remove(at: focusedIndex)
                orderedWindows.insert(focused, at: 0)
            }
        }

        return orderedWindows.enumerated().map { index, element in
            var titleValue: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(
                element,
                kAXTitleAttribute as CFString,
                &titleValue
            )
            let title = titleResult == .success
                ? (titleValue as? String).flatMap { $0.isEmpty ? nil : $0 }
                : nil

            var minimizedValue: CFTypeRef?
            let minimizedResult = AXUIElementCopyAttributeValue(
                element,
                kAXMinimizedAttribute as CFString,
                &minimizedValue
            )

            return AccessibleWindow(
                number: index + 1,
                title: title ?? "Window \(index + 1)",
                isMinimized: minimizedResult == .success && (minimizedValue as? Bool == true),
                element: element
            )
        }
    }

    static func activate(_ window: AccessibleWindow, in application: NSRunningApplication) -> Bool {
        application.activate(options: [])

        if window.isMinimized {
            let restoreResult = AXUIElementSetAttributeValue(
                window.element,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            guard restoreResult == .success else { return false }
        }

        let raiseResult = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(
            window.element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        return raiseResult == .success || focusResult == .success
    }

    private static func isStandardWindow(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        ) == .success,
              let role = roleValue as? String,
              role == (kAXWindowRole as String) else {
            return false
        }

        var subroleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &subroleValue
        ) == .success,
              let subrole = subroleValue as? String else {
            return true
        }

        return subrole == (kAXStandardWindowSubrole as String)
    }
}
