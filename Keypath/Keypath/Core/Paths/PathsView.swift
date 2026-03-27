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
                    // top section with scrollview and grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15.0) {
                            ForEach(0..<6, id: \.self) { i in
                                VStack {
                                    RoundedRectangle(cornerRadius: 15.0)
                                        .fill(.clear)
                                        .glassEffect(.clear, in: .rect(cornerRadius: 15.0))
                                }
                                .frame(width: 275)
                                .frame(height: 170)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    
                }
                .frame(maxWidth: .infinity, minHeight: 370, maxHeight: 370)
                
                VStack {
                    HStack {
                        VStack {
                            Image(systemName: "gear")
                                .frame(width: 25, height: 25)
                                .background(
                                    RoundedRectangle(cornerRadius: 5.0)
                                        .fill(.quaternary)
                                        .frame(width: 23, height: 23)
                                )
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 13.0) {
                            Text("Commands")
                            
                            HStack(spacing: 5.0) {
                                Image(systemName: "command")
                                    .fontWeight(.medium)
                                    .frame(width: 25, height: 25)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5.0)
                                            .fill(.quaternary)
                                            .frame(width: 23, height: 23)
                                    )
                                
                                Image(systemName: "command")
                                    .fontWeight(.medium)
                                    .frame(width: 25, height: 25)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5.0)
                                            .fill(.quaternary)
                                            .frame(width: 23, height: 23)
                                    )
                                
                                Image(systemName: "command")
                                    .fontWeight(.medium)
                                    .frame(width: 25, height: 25)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5.0)
                                            .fill(.quaternary)
                                            .frame(width: 23, height: 23)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
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
