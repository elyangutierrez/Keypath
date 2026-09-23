# Keypath project notes

## What this project is

Keypath is a native macOS menu bar utility for quickly finding and switching among running applications with a keyboard. Its main interface is a floating heads-up display (HUD) that lists eligible running apps, shows their icons and window previews, and supports custom letter shortcuts. The project README describes the goal as making app switching across virtual desktop workflows easier. The implementation activates or minimizes app windows through macOS; it does not directly move windows between Spaces.

The app is an accessory-style menu bar app (`LSUIElement = YES`), not a conventional app with a persistent main window. The menu bar menu can toggle auto-launch, show or hide the HUD, and quit Keypath. The HUD is an `NSPanel` configured to float above normal windows and appear across Spaces and fullscreen apps.

## Main user flows and behavior

- At launch, `AppDelegate` synchronizes the saved auto-launch preference, creates the HUD panel with `RootView`, and starts the global keyboard event listener.
- The listener requires macOS Accessibility permission. It watches modifier changes and key-down events with a Core Graphics event tap.
- Global shortcut handling is suspended while the Settings route is active.
- The current activation chord is a **double tap of left Option**, followed by a command within about 1.5 seconds. The code recognizes these commands:
  - `K`: show or hide the app HUD.
  - `C`: show or hide the command reference while the HUD is open.
  - `/`: show or hide the saved app-keybind list.
  - `S`: enter or leave selection mode; left/right arrows move the selection.
  - `U`: assign a keybind to the selected app; press Escape to cancel.
  - In the HUD, a configured letter activates its app. If that app is already active and its window is open, the implementation minimizes its windows; otherwise it activates the app.
- The README currently says the activation chord is double Control. Treat `Keymaps.swift` and `CommandListener.swift` as the implementation source of truth if documenting or changing the chord, and update the README when appropriate.
- The HUD lists running regular-policy apps except those excluded in Settings. The default excluded names are Finder and Preview. Apps are sorted by localized name.
- Settings lets the user add installed apps to the exclusion list, remove exclusions, and reset all custom keybinds. The installed-app picker scans `/Applications` and `/System/Applications`.
- A saved app keybind stores the app's display name, optional bundle identifier, and a Codable keybind. The HUD currently restores saved keybinds by matching the app's localized name.
- App launch state is observed through `NSWorkspace` notifications so the HUD list can refresh when apps launch, terminate, hide, or unhide.
- Each app card checks window visibility with Accessibility APIs and falls back to Core Graphics window information. It requests a ScreenCaptureKit screenshot of an on-screen app window on a five-second loop while its card is visible in the HUD. Previews are held in memory by process ID.

## Technology and platform

- Swift 6 app target using SwiftUI and AppKit, with SwiftData for saved keybinds.
- macOS deployment target: 26.2.
- System APIs in use include Core Graphics, ApplicationServices/Accessibility, ScreenCaptureKit, `NSWorkspace`, and ServiceManagement (`SMAppService`) for login launch.
- The app target has App Sandbox disabled. Accessibility permission is needed for the event tap and window operations; screen capture behavior is subject to macOS privacy controls.
- No Swift Package manifest or third-party dependency manager is present. Xcode project source membership uses synchronized filesystem groups.

## Source map

- `Keypath/Keypath/App/`: SwiftUI app entry point, launch delegate, and AppKit window configuration.
- `Keypath/Keypath/Core/RootView.swift`: root HUD view, route selection, construction of the running-app paths, and workspace notification refreshes.
- `Keypath/Keypath/Core/Paths/`: app grid, bottom navigation bar, and empty-state view.
- `Keypath/Keypath/Core/IndividualPath/`: one app card, window activation/minimizing and visibility checks, and screenshot preview state.
- `Keypath/Keypath/Core/Commands/`: command reference, saved-keybind list, keybind types, command state, and SwiftData persistence.
- `Keypath/Keypath/Core/Settings/`: excluded-app settings, app picker model, and `UserDefaults`/login-item configuration.
- `Keypath/Keypath/Core/Navigation/`: shared route state for the HUD and Settings.
- `Keypath/Keypath/Util/Keyboard/`: physical macOS key-code maps and the global keyboard event listener.
- `Keypath/Keypath/Util/Managers/`: app discovery/launch, screenshots, and floating HUD panel setup.
- `Keypath/Keypath/Resources/Assets.xcassets/`: app icon, accent color, and light/dark Hyper Key images.
- `Keypath/KeypathTests/`: unit tests for key maps, command-manager selection state, and SwiftData keybind persistence.
- `README.md` and root `Assets/`: user-facing project description and repository preview images.

## State and persistence

- `KeypathCommandManager.shared` owns HUD presentation flags, selected app index, and the current app paths.
- `NavigationManager.shared` switches between the paths HUD and Settings.
- `DataManager.shared` owns a SwiftData container containing `SavedKeybind` records. Preserve existing saved-data compatibility when changing the model; use `DataManager(isStoredInMemoryOnly: true)` for isolated persistence tests.
- `Config.shared` stores auto-launch and excluded app names in the `UserDefaults` dictionary under `CONFIGDICT`. Auto-launch registration is synchronized through `SMAppService.mainApp`.
- `PreviewManager.shared` stores current and cached `CGImage` previews in memory, keyed by process ID. It removes entries when an app terminates.
- Observable managers are shared across the menu bar app, HUD views, and event listener. Keep UI-facing state updates on the main actor, especially when handling event-tap callbacks or asynchronous screenshot work.

## Working guidance

- Keep changes consistent with a macOS-only SwiftUI/AppKit app and the existing source layout. Do not add iOS assumptions.
- Key codes in `Keymaps.swift` are physical macOS virtual key codes, not characters from the current keyboard layout. Keep the forward map, reverse map, and valid assignment map consistent when changing supported keys.
- Keep global hotkey handling, keybind display, command documentation, and the README in sync. The command reference in `Commands.swift` is a separate displayed list from the event handling in `CommandListener.swift`.
- Treat Accessibility and ScreenCaptureKit calls as permission-sensitive and failure-prone. Preserve graceful behavior when a process has no accessible window, a screenshot is unavailable, or system permission is absent.
- Preserve existing SwiftData records or provide an explicit migration if the saved-keybind schema changes. Avoid relying on app display names as globally unique identifiers without considering the existing stored format.
- The shared Xcode scheme is `Keypath`. Build with `xcodebuild -project Keypath/Keypath.xcodeproj -scheme Keypath -configuration Debug build`; run unit tests with `xcodebuild test -project Keypath/Keypath.xcodeproj -scheme Keypath -destination 'platform=macOS'`.
- The Xcode project declares a `KeypathUITests` target, but there are currently no UI test source files in the repository. The checked-in tests are the three unit-test files under `Keypath/KeypathTests/`.
