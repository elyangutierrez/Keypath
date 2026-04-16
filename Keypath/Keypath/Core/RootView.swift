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
    
    var paths: [Keypath] {
        let currentPaths = ApplicationManager.getPaths()
        
        for path in currentPaths {
            if path.hasVisibleWindow {
                path.isWindowOpened = true
            }
        }
        
        let existingKeybinds = DataManager.shared.fetchAllSavedKeybinds()
        
        if !existingKeybinds.isEmpty {
            for keybind in existingKeybinds {
                for path in currentPaths {
                    if path.application.localizedName ?? "" == keybind.appName {
                        path.keybind = keybind.keybind
                    }
                }
            }
        }
        
        return currentPaths
    }
    
    @State private var scrollID: Int? = 0
    
    let columns: [GridItem] = [
        GridItem(.fixed(300)),
        GridItem(.fixed(300))
    ]
    
    var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    var body: some View {
        ZStack {
            GlassBackground()
            
            VStack(spacing: 0.0) {
                switch navigationManager.route {
                case .settings:
                    ExclusionListView()
                case .paths:
                    PathsView(paths: paths)
                }
                
                VStack {
                    BottomBarView()
                }
                .frame(maxWidth: .infinity, minHeight: 55, maxHeight: 55)
            }
        }
        .onAppear {
            commandManager.resetIndex()
            commandManager.setPaths(paths)
            scrollID = 0
        }
        .onChange(of: navigationManager.route) { _, _ in
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
