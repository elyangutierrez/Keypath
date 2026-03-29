//
//  PathsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/26/26.
//

import SwiftUI

struct PathsView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @State private var applicationManager = ApplicationManager()
    @State private var commandManager = KeypathCommandManager.shared
    @State private var paths: [Keypath] = []
    
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
                VStack {
                    if !paths.isEmpty {
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 15.0) {
                                    ForEach(Array(paths.enumerated()), id: \.element) { index, path in
                                        PathView(
                                            path: path,
                                            isSelected: commandManager.currentIndex == index && commandManager.isInSelectionMode
                                        )
                                        .id(index)
                                    }
                                }
                            }
                            .scrollIndicators(.never)
                            .contentMargins(.bottom, 30, for: .scrollContent)
                            .padding(.horizontal)
                            .onChange(of: commandManager.currentIndex) { _, newIndex in
                                withAnimation(.spring(response: 0.3)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
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
            paths = applicationManager.getRunningApplications().sorted()
            commandManager.currentNumberOfApps = paths.count
            commandManager.resetIndex()
        }
        .onChange(of: paths.count) { _, newCount in
            commandManager.currentNumberOfApps = newCount
        }
    }
}

#Preview {
    PathsView()
        .frame(width: 650, height: 465)
}
