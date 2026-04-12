//
//  PathsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/26/26.
//

import SwiftData
import SwiftUI

struct PathsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @State private var applicationManager = ApplicationManager()
    @State private var commandManager = KeypathCommandManager.shared
    @State private var paths: [Keypath] = []
    @State private var scrollID: Int? = 0
    
    let columns: [GridItem] = [
        GridItem(.fixed(300)),
        GridItem(.fixed(300))
    ]
    
    var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    var sortedPaths: [Keypath] {
        return paths.sorted()
    }
    
    var body: some View {
        ZStack {
            GlassBackground()
            
            VStack(spacing: 0.0) {
                VStack {
                    if !paths.isEmpty {
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 15.0) {
                                ForEach(Array(sortedPaths.enumerated()), id: \.element) { index, path in
                                    PathView(
                                        path: path,
                                        isSelected: commandManager.currentIndex == index && commandManager.isInSelectionMode
                                    )
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.never)
                        .contentMargins(.bottom, 30, for: .scrollContent)
                        .padding(.horizontal)
                        .scrollPosition(id: $scrollID)
                        .scrollTargetBehavior(.viewAligned)
                        .onChange(of: commandManager.currentIndex) { _, newIndex in
                            withAnimation(.spring(response: 0.3)) {
                                scrollID = newIndex
                            }
                        }
                        .overlay {
                            if commandManager.isShowingCommands {
                                VStack {
                                    VStack {
                                        CommandsView()
                                    }
                                    .frame(width: 315, height: 250)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15.0)
                                            .fill(.clear)
                                            .glassEffect(.regular, in: .rect(cornerRadius: 15.0))
                                    )
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .padding()
                            } else if commandManager.isShowingKeybinds {
                                VStack {
                                    VStack {
                                        KeybindsListView()
                                    }
                                    .frame(width: 315, height: 250)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15.0)
                                            .fill(.clear)
                                            .glassEffect(.regular, in: .rect(cornerRadius: 15.0))
                                    )
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                .padding()
                            }
                        }
                    } else {
                        UnavaliableAppsView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410)
                
                VStack {
                    BottomBarView()
                }
                .frame(maxWidth: .infinity, minHeight: 55, maxHeight: 55)
            }
        }
        .onAppear {
            
            paths = applicationManager.getPaths()
            
            for path in paths {
                if path.hasVisibleWindow {
                    path.isWindowOpened = true
                }
            }
            
            let existingKeybinds = DataManager.shared.fetchAllSavedKeybinds()
            
            if !existingKeybinds.isEmpty {
                for keybind in existingKeybinds {
                    for path in paths {
                        if path.application.localizedName ?? "" == keybind.appName {
                            path.keybind = keybind.keybind
                        }
                    }
                }
            }
            
            commandManager.currentNumberOfApps = paths.count
            commandManager.resetIndex()
            commandManager.setPaths(paths)
            scrollID = 0
        }
        .onChange(of: paths.count) { _, newCount in
            commandManager.currentNumberOfApps = newCount
            commandManager.setPaths(paths)
        }
    }
}

#Preview {
    PathsView()
        .frame(width: 650, height: 465)
}
