//
//  PathView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import SwiftUI

struct PathView: View {
    
    @State private var screenshotManager = ScreenshotManager()
    @State private var commandManager = KeypathCommandManager.shared
    
    @State private var screenshotImage: CGImage?
    
    @Bindable var path: Keypath
    var isSelected: Bool
    
    var isChangingKeybind: Bool {
        commandManager.isInKeybindUpdateMode && isSelected
    }
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Image(nsImage: path.application.icon ?? NSImage())
                    
                    Text(path.application.localizedName ?? "Unknown")
                    
                    Spacer()
                    
                    VStack {
                        HStack(spacing: -5.0) {
                            if let keybind = path.keybind {
                                if case .symbol(_) = keybind.key1 {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 25, height: 25)
                                        .overlay {
                                            Image(.hyperKey)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 15, height: 15)
                                        }
                                }
                                
                                if case let .letter(letter) = keybind.key2 {
                                    Text(letter)
                                        .frame(width: 25, height: 25)
                                }
                            } else {
                                Image(systemName: "nosign")
                                    .fontWeight(.medium)
                                    .frame(width: 25, height: 25)
                            }
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
                VStack {
                    if let image = screenshotImage {
                        Image(decorative: image, scale: 1, orientation: .up)
                            .resizable()
                            .clipShape(.rect(cornerRadius: 15.0))
                            .opacity(path.application.isHidden ? 0.5 : 1.0)
                            .overlay {
                                if path.application.isHidden {
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
        }
        .padding(10)
        .frame(width: 275)
        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 15.0)
                .fill(.clear)
                .glassEffect(.regular.tint(isSelected && !isChangingKeybind ? .blue.opacity(0.6) : .clear), in: .rect(cornerRadius: 15.0))
        )
        .contentShape(.rect(cornerRadius: 15.0))
        .overlay {
            if isChangingKeybind {
                ZStack {
                    RoundedRectangle(cornerRadius: 15.0)
                        .fill(.ultraThickMaterial)
                        .opacity(0.9)
                    
                    VStack(spacing: 15.0) {
                        Image(systemName: "keyboard")
                            .resizable()
                            .frame(width: 35, height: 25)
                        
                        Text("Enter your new keybind")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .task {
            await runScreenshotLoop()
        }
    }
    
    func runScreenshotLoop() async {
        do {
            while !Task.isCancelled {
                let image = try await screenshotManager
                    .getApplicationImage(app: path.application)
                
                if let image {
                    await MainActor.run {
                        self.screenshotImage = image
                    }
                }
                
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        } catch is CancellationError {
            // Clean exit — no logging needed
        } catch let error as ScreenshotError {
            print("[\(error.title)] \(error.localizedDescription)")
        } catch {
            print("Error: \(error)")
        }
    }
}

#Preview {
    PathView(path: Keypath(application: NSRunningApplication()), isSelected: false)
}
