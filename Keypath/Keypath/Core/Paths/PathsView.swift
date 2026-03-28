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
    
    let columns: [GridItem] = [
        GridItem(.fixed(300)),
        GridItem(.fixed(300))
    ]
    
    var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    var sortedApps: [NSRunningApplication] {
        let apps = applicationManager.getRunningApplications().sorted(by: { $0.localizedName ?? "" < $1.localizedName ?? "" })
        
        return apps
    }
    
    var body: some View {
        ZStack {
            GlassBackground()
            
            VStack(spacing: 0.0) {
                VStack {
                    if !sortedApps.isEmpty {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 15.0) {
                                ForEach(sortedApps, id: \.self) { application in
                                    PathView(application: application)
                                        
                                }
                            }
                        }
                        .scrollIndicators(.never)
                        .contentMargins(.bottom, 30, for: .scrollContent)
                        .padding(.horizontal)
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
    }
}

#Preview {
    PathsView()
        .frame(width: 650, height: 465)
}
