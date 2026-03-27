//
//  PathsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/26/26.
//

import SwiftUI

struct PathsView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
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
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15.0) {
                            ForEach(0..<4, id: \.self) { i in
                                PathView()
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    .scrollTargetBehavior(.paging)
                    
                }
                .frame(maxWidth: .infinity, minHeight: 370, maxHeight: 370)
                
                VStack {
                    BottomBarView()
                }
                .frame(maxWidth: .infinity, minHeight: 55, maxHeight: 55)
                .background(
                    Rectangle()
                        .fill(.regularMaterial)
                )
            }
        }
        .background(WindowConfiguration())
    }
}

#Preview {
    PathsView()
        .frame(width: 650, height: 425)
}
