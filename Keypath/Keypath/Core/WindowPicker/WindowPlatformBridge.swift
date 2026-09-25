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

    private static func resolve<T>(_ name: String, from handle: UnsafeMutableRawPointer?) -> T? {
        guard let handle,
              let symbol = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}
