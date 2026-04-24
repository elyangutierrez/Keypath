//
//  BottomBarView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import SwiftUI

struct BottomBarView: View {
    @State private var navigationManager = NavigationManager.shared
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(duration: 0.3)) {
                    navigationManager.toggleRoute()
                }
            }) {
                Image(systemName: "gear")
                    .fontWeight(.medium)
                    .frame(width: 25, height: 25)
                    .background(
                        RoundedRectangle(cornerRadius: 5.0)
                            .fill(.quaternary)
                            .frame(width: 23, height: 23)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 13.0) {
                Text("Commands")
                
                HStack(spacing: 5.0) {
                    
                    let image: NSImage = {
                        let ratio = $0.size.height / $0.size.width
                        $0.size.height = 10
                        $0.size.width = 12 / ratio
                        return $0
                    } (NSImage(resource: .superKeyLight))
                    
                    Image(nsImage: image)
                        .fontWeight(.medium)
                        .frame(width: 25, height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 5.0)
                                .fill(.quaternary)
                                .frame(width: 23, height: 23)
                        )
                    
                    Text("C")
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
        .frame(height: 55)
        .background(
            Rectangle()
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    BottomBarView()
}
