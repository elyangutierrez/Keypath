//
//  WindowPlatformBridge.swift
//  Keypath
//

import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import AppKit

/// Runtime-checked access to macOS window APIs that have no supported public
/// equivalent. All calls are isolated here so the rest of the picker can fail
/// closed when a symbol is unavailable.
@MainActor
enum WindowPlatformBridge {
    private typealias AXGetWindowIDFunction = @convention(c) (
        AXUIElement,
        UnsafeMutablePointer<CGWindowID>
    ) -> Int32

    private typealias GetProcessForPIDFunction = @convention(c) (
        pid_t,
        UnsafeMutablePointer<ProcessSerialNumber>
    ) -> Int32

    private typealias SetFrontProcessFunction = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        CGWindowID,
        UInt32
    ) -> Int32

    private typealias PostEventRecordFunction = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        UnsafeMutablePointer<UInt8>
    ) -> Int32

    private typealias MainConnectionIDFunction = @convention(c) () -> Int32

    private typealias WindowIsOrderedInFunction = @convention(c) (
        Int32,
        CGWindowID,
        UnsafeMutablePointer<UInt8>
    ) -> Int32

    private typealias CopySpacesForWindowsFunction = @convention(c) (
        Int32,
        Int32,
        CFArray
    ) -> Unmanaged<CFArray>?

    private typealias CopyManagedDisplaySpacesFunction = @convention(c) (
        Int32
    ) -> Unmanaged<CFArray>?

    private typealias SpaceGetTypeFunction = @convention(c) (Int32, UInt64) -> Int32

    private typealias WindowQueryWindowsFunction = @convention(c) (
        Int32,
        CFArray,
        Int32
    ) -> Unmanaged<CFTypeRef>?

    private typealias WindowQueryResultCopyWindowsFunction = @convention(c) (
        CFTypeRef
    ) -> Unmanaged<CFTypeRef>?

    private typealias WindowIteratorGetCountFunction = @convention(c) (CFTypeRef) -> Int32

    private typealias WindowIteratorAdvanceFunction = @convention(c) (CFTypeRef) -> Bool

    private typealias WindowIteratorGetParentIDFunction = @convention(c) (CFTypeRef) -> CGWindowID

    private typealias WindowIteratorGetWindowIDFunction = @convention(c) (CFTypeRef) -> CGWindowID

    private static let hiServicesHandle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices",
        RTLD_LAZY
    )

    private static let hitoolboxHandle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox",
        RTLD_LAZY
    )

    private static let skyLightHandle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        RTLD_LAZY
    )

    private static let axGetWindowID = resolve(
        "_AXUIElementGetWindow",
        from: hiServicesHandle
    ) as AXGetWindowIDFunction?

    private static let getProcessForPID = resolve(
        "GetProcessForPID",
        from: hitoolboxHandle
    ) as GetProcessForPIDFunction?

    private static let setFrontProcess = resolve(
        "_SLPSSetFrontProcessWithOptions",
        from: skyLightHandle
    ) as SetFrontProcessFunction?

    private static let postEventRecord = resolve(
        "SLPSPostEventRecordTo",
        from: skyLightHandle
    ) as PostEventRecordFunction?

    private static let mainConnectionID = resolve(
        "SLSMainConnectionID",
        from: skyLightHandle
    ) as MainConnectionIDFunction?

    private static let windowIsOrderedIn = resolve(
        "SLSWindowIsOrderedIn",
        from: skyLightHandle
    ) as WindowIsOrderedInFunction?

    private static let copySpacesForWindows = resolve(
        "SLSCopySpacesForWindows",
        from: skyLightHandle
    ) as CopySpacesForWindowsFunction?

    private static let copyManagedDisplaySpaces = resolve(
        "SLSCopyManagedDisplaySpaces",
        from: skyLightHandle
    ) as CopyManagedDisplaySpacesFunction?

    private static let spaceGetType = resolve(
        "SLSSpaceGetType",
        from: skyLightHandle
    ) as SpaceGetTypeFunction?

    private static let windowQueryWindows = resolve(
        "SLSWindowQueryWindows",
        from: skyLightHandle
    ) as WindowQueryWindowsFunction?

    private static let windowQueryResultCopyWindows = resolve(
        "SLSWindowQueryResultCopyWindows",
        from: skyLightHandle
    ) as WindowQueryResultCopyWindowsFunction?

    private static let windowIteratorGetCount = resolve(
        "SLSWindowIteratorGetCount",
        from: skyLightHandle
    ) as WindowIteratorGetCountFunction?

    private static let windowIteratorAdvance = resolve(
        "SLSWindowIteratorAdvance",
        from: skyLightHandle
    ) as WindowIteratorAdvanceFunction?

    private static let windowIteratorGetParentID = resolve(
        "SLSWindowIteratorGetParentID",
        from: skyLightHandle
    ) as WindowIteratorGetParentIDFunction?

    private static let windowIteratorGetWindowID = resolve(
        "SLSWindowIteratorGetWindowID",
        from: skyLightHandle
    ) as WindowIteratorGetWindowIDFunction?

    static func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let axGetWindowID else { return nil }
        var windowID: CGWindowID = 0
        guard axGetWindowID(element, &windowID) == 0, windowID != 0 else { return nil }
        return windowID
    }

    static func activateWindow(processIdentifier: pid_t, windowID: CGWindowID) -> Bool {
        guard windowID != 0,
              let getProcessForPID,
              let setFrontProcess,
              let postEventRecord else {
            return false
        }

        var processSerialNumber = ProcessSerialNumber()
        guard getProcessForPID(processIdentifier, &processSerialNumber) == 0,
              setFrontProcess(&processSerialNumber, windowID, 0x200) == 0 else {
            return false
        }

        // This event-record layout is used by Amethyst's AX window focus path.
        // It asks SkyLight to key the exact CG window ID, rather than whichever
        // window the app happened to have focused previously.
        for eventKind: UInt8 in [0x01, 0x02] {
            var bytes = [UInt8](repeating: 0, count: 0xF8)
            bytes[0x04] = 0xF8
            bytes[0x08] = eventKind
            bytes[0x3A] = 0x10
            withUnsafeBytes(of: windowID) { source in
                bytes.withUnsafeMutableBytes { destination in
                    destination.baseAddress!.advanced(by: 0x3C)
                        .copyMemory(from: source.baseAddress!, byteCount: MemoryLayout<CGWindowID>.size)
                }
            }
            for index in 0x20..<0x30 { bytes[index] = 0xFF }

            let status = bytes.withUnsafeMutableBufferPointer { buffer in
                postEventRecord(&processSerialNumber, buffer.baseAddress!)
            }
            guard status == 0 else { return false }
        }

        return true
    }

    /// Returns only confirmed user or full-screen Spaces for a window.
    /// Missing private symbols, failed calls, and malformed results all fail closed.
    static func managedSpaces(for windowID: CGWindowID) -> Set<UInt64>? {
        guard windowID != 0,
              let mainConnectionID,
              let copySpacesForWindows,
              let copyManagedDisplaySpaces,
              let spaceGetType else {
            return nil
        }

        let connection = mainConnectionID()
        let windowList = [NSNumber(value: windowID)] as CFArray
        guard let copiedSpaces = copySpacesForWindows(connection, 0x7, windowList) else {
            return nil
        }
        let spaces = copiedSpaces.takeRetainedValue()
        guard let spaceIDs = numericIDs(in: spaces), !spaceIDs.isEmpty,
              let copiedManagedSpaces = copyManagedDisplaySpaces(connection) else {
            return nil
        }

        let managedSpaceList = copiedManagedSpaces.takeRetainedValue()
        guard let managedIDs = managedSpaceIDs(in: managedSpaceList),
              !managedIDs.isEmpty else {
            return nil
        }

        let candidateIDs = spaceIDs.intersection(managedIDs)
        let confirmedIDs = candidateIDs.filter { spaceID in
            let spaceType = spaceGetType(connection, spaceID)
            return spaceType == 0 || spaceType == 4
        }
        return confirmedIDs.isEmpty ? nil : confirmedIDs
    }

    /// Confirms that a Core Graphics-only candidate is a root window that
    /// WindowServer currently considers ordered in on a managed Space.
    static func isOrderedRootWindow(_ windowID: CGWindowID) -> Bool {
        guard windowID != 0,
              let mainConnectionID,
              let windowIsOrderedIn,
              let windowQueryWindows,
              let windowQueryResultCopyWindows,
              let windowIteratorGetCount,
              let windowIteratorAdvance,
              let windowIteratorGetParentID,
              let windowIteratorGetWindowID else {
            return false
        }

        let connection = mainConnectionID()
        var orderedIn: UInt8 = 0
        guard windowIsOrderedIn(connection, windowID, &orderedIn) == 0,
              orderedIn != 0 else {
            return false
        }

        let windowList = [NSNumber(value: windowID)] as CFArray
        guard let query = windowQueryWindows(connection, windowList, 1)?.takeRetainedValue(),
              let iterator = windowQueryResultCopyWindows(query)?.takeRetainedValue(),
              windowIteratorGetCount(iterator) == 1,
              windowIteratorAdvance(iterator) else {
            return false
        }

        return windowIteratorGetWindowID(iterator) == windowID
            && windowIteratorGetParentID(iterator) == 0
    }

    private static func numericIDs(in array: CFArray) -> Set<UInt64>? {
        guard CFGetTypeID(array) == CFArrayGetTypeID(),
              let values = array as? [NSNumber] else {
            return nil
        }

        var result = Set<UInt64>()
        for value in values {
            guard CFGetTypeID(value as CFTypeRef) == CFNumberGetTypeID() else {
                return nil
            }
            let identifier = value.uint64Value
            guard identifier != 0 else { return nil }
            result.insert(identifier)
        }
        return result
    }

    private static func managedSpaceIDs(in displaySpaces: CFArray) -> Set<UInt64>? {
        guard CFGetTypeID(displaySpaces) == CFArrayGetTypeID(),
              let displays = displaySpaces as? [NSDictionary],
              !displays.isEmpty else {
            return nil
        }

        var result = Set<UInt64>()
        for display in displays {
            guard CFGetTypeID(display as CFTypeRef) == CFDictionaryGetTypeID(),
                  let spaces = display["Spaces"] as? NSArray,
                  CFGetTypeID(spaces as CFTypeRef) == CFArrayGetTypeID() else {
                return nil
            }

            for value in spaces {
                guard CFGetTypeID(value as CFTypeRef) == CFDictionaryGetTypeID(),
                      let space = value as? NSDictionary,
                      let identifier = spaceIdentifier(in: space) else {
                    return nil
                }
                result.insert(identifier)
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func spaceIdentifier(in space: NSDictionary) -> UInt64? {
        let rawValue = space["id64"] ?? space["ManagedSpaceID"]
        guard let number = rawValue as? NSNumber,
              CFGetTypeID(number as CFTypeRef) == CFNumberGetTypeID() else {
            return nil
        }
        let identifier = number.uint64Value
        return identifier == 0 ? nil : identifier
    }

    private static func resolve<T>(_ name: String, from handle: UnsafeMutableRawPointer?) -> T? {
        guard let handle,
              let symbol = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}
