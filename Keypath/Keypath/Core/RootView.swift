//
//  RootView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/26/26.
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @State private var applicationManager = ApplicationManager()
    @State private var commandManager = KeypathCommandManager.shared
    @State private var navigationManager = NavigationManager.shared
    @State private var recentAppManager = RecentAppManager.shared
    @State private var windowPickerManager = WindowPickerManager.shared
    
    var paths: [Keypath] {
        
        print("Getting paths...")
        
        let currentPaths = ApplicationManager.getPaths()
        let savedKeybinds = KeybindAssignmentCoordinator.shared.savedKeybinds(for: currentPaths)
        
        for path in currentPaths {
            path.keybind = savedKeybinds[path.id]

            if path.hasVisibleWindow {
                path.isWindowOpened = true
            }
        }

        return currentPaths
    }
    
    @State private var scrollID: Int? = 0
    
    var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    var body: some View {
        Group {
            if navigationManager.route == .paths && windowPickerManager.isVisible {
                WindowPickerView(manager: windowPickerManager)
                    .frame(width: PathsWindowManager.pathsContentSize.width,
                           height: PathsWindowManager.pathsContentSize.height)
            } else if navigationManager.route == .paths && recentAppManager.isVisible {
                RecentAppPickerView(manager: recentAppManager)
                    .frame(width: PathsWindowManager.recentAppsContentSize.width,
                           height: PathsWindowManager.recentAppsContentSize.height)
            } else {
                ZStack {
                    GlassBackground()

                    VStack(spacing: 0.0) {
                        switch navigationManager.route {
                        case .settings:
                            SettingsView()
                        case .paths:
                            PathsView(paths: commandManager.currentPaths)
                        }

                        BottomBarView()
                            .frame(maxWidth: .infinity, minHeight: 55, maxHeight: 55)
                    }
                }
                .frame(width: PathsWindowManager.pathsContentSize.width,
                       height: PathsWindowManager.pathsContentSize.height)
                .containerShape(.rect(cornerRadius: 15.0))
                .clipShape(.rect(cornerRadius: 15.0))
            }
        }
        .onAppear {
            commandManager.resetIndex()
            commandManager.setPaths(paths)
            PathsWindowManager.shared.setRecentAppsMode(recentAppManager.isVisible)
            scrollID = 0
        }
        .onChange(of: recentAppManager.isVisible) { _, isVisible in
            PathsWindowManager.shared.setRecentAppsMode(isVisible)
        }
        .onChange(of: navigationManager.route) { _, _ in
            if navigationManager.route == .settings {
                recentAppManager.cancelPicker()
                windowPickerManager.finish()
            }
            commandManager.setPaths(paths)
        }
        .onReceive(NotificationCenter.default.publisher(for: .excludedAppsDidChange)) { _ in
            commandManager.setPaths(paths)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            commandManager.setPaths(paths)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                PreviewManager.shared.removePath(processID: app.processIdentifier)
            }
            commandManager.setPaths(paths)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didHideApplicationNotification)) { _ in
            commandManager.setPaths(paths)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnhideApplicationNotification)) { _ in
            commandManager.setPaths(paths)
        }
    }
    
    func getSelection(_ pathIndex: Int) -> Bool {
        guard commandManager.isInSelectionMode else { return false }
        return commandManager.currentIndex == pathIndex
    }
}

#Preview {
    RootView()
        .frame(width: 650, height: 465)
}
