//
//  PathView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import SwiftUI

struct PathView: View {
    
    @State private var screenshotManager = ScreenshotManager()
    
    @State private var screenshotImage: CGImage?
    
    var path: Keypath
    var isSelected: Bool
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Image(nsImage: path.application.icon ?? NSImage())
                    
                    Text(path.application.localizedName ?? "Unknown")
                    
                    Spacer()
                    
                    VStack {
                        HStack(spacing: -10.0) {
                            Image(systemName: "control")
                                .fontWeight(.medium)
                                .frame(width: 25, height: 25)
                            
                            Image(systemName: "option")
                                .fontWeight(.medium)
                                .frame(width: 25, height: 25)
                            
                            Text("C")
                                .fontWeight(.medium)
                                .frame(width: 25, height: 25)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 5.0)
                            .fill(.regularMaterial)
                    )
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            VStack {
                if let image = screenshotImage {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .clipShape(.rect(cornerRadius: 15.0))
                        .opacity(path.application.isActive ? 1.0 : 0.5)
                        .overlay {
                            if !path.application.isActive {
                                Image(systemName: "eye.slash")
                                    .resizable()
                                    .frame(width: 35, height: 30)
                            }
                        }
                } else {
                    Image(nsImage: path.application.icon ?? NSImage())
                        .resizable()
                        .frame(width: 80, height: 80)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15.0)
                    .fill(.clear)
                    .glassEffect(.clear, in: .rect(cornerRadius: 15.0))
            )
        }
        .padding(10)
        .frame(width: 275)
        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 15.0)
                .fill(isSelected ? .blue.opacity(0.6) : .clear)
                .glassEffect(.clear, in: .rect(cornerRadius: 15.0))
        )
        .task {
            if screenshotImage == nil {
                screenshotImage = await screenshotManager.getApplicationImage(app: path.application)
            }
        }
    }
}

#Preview {
    PathView(path: Keypath(application: NSRunningApplication()), isSelected: false)
}
