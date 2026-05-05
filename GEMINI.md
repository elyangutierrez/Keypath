# Keypath Project Instructions

## Project Overview
Keypath is a personal macOS application built with SwiftUI and AppKit that enables effortless application switching via custom keybinds. It operates primarily from the menu bar (`MenuBarExtra`) and utilizes a double-control (⌃⌃) hyper key pattern for rapid navigation.

## Architecture & Best Practices

### 1. Frameworks (SwiftUI & AppKit)
- The UI is driven by modern **SwiftUI**.
- System-level interactions, application fetching, and window management rely heavily on **AppKit** (e.g., `NSWorkspace`, `NSApplication`).

### 2. State Management
- Use modern Swift **`@Observable`** macros for all state management classes (e.g., `ApplicationManager`, `KeypathCommandManager`). Avoid legacy `ObservableObject` and `@Published`.

### 3. Data Persistence (SwiftData)
- **SwiftData** is used for local data persistence (e.g., saving keybinds via `DataManager`).
- Ensure all SwiftData model interactions are properly isolated, typically utilizing `@MainActor` for context safety.

### 4. Concurrency (async/await)
- Prioritize **modern Swift Concurrency (`async`/`await`, `Task`, `actor`)** over legacy completion handlers or GCD (`DispatchQueue`) when handling asynchronous operations.

### 5. Coding Style & Conventions
- Prefer explicit abstractions, type safety, and direct usage of native macOS APIs.
- Keep the codebase idiomatic to Swift 5.9+.
