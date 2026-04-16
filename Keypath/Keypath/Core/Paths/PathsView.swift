//
//  PathsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/26/26.
//

import SwiftData
import SwiftUI

struct PathsView: View {
    @State private var applicationManager = ApplicationManager()
    @State private var commandManager = KeypathCommandManager.shared
    @State private var scrollID: Int? = 0
    
    let columns: [GridItem] = [
        GridItem(.fixed(300)),
        GridItem(.fixed(300))
    ]
    
    var paths: [Keypath]
    
    var body: some View {
        VStack {
            if !paths.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15.0) {
                        ForEach(Array(paths.enumerated()), id: \.element) { index, path in
                            PathView(
                                path: path,
                                isSelected: getSelection(index)
                            )
                            .id(index)
                            .onHover { hovering in
                                if hovering && commandManager.isInSelectionMode {
                                    withAnimation(.spring(duration: 0.3)) {
                                        commandManager.currentIndex = index
                                    }
                                }
                            }
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
    }
    
    func getSelection(_ pathIndex: Int) -> Bool {
        guard commandManager.isInSelectionMode else { return false }
        return commandManager.currentIndex == pathIndex
    }
}

#Preview {
    PathsView(paths: [])
        .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410)
}
