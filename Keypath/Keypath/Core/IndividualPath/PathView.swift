//
//  PathView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import SwiftUI

struct PathView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var undoButtonIsFocused: Bool
    
    @State private var previewManager = PreviewManager.shared
    @State private var screenshotManager = ScreenshotManager()
    @State private var commandManager = KeypathCommandManager.shared
    @State private var assignmentCoordinator = KeybindAssignmentCoordinator.shared
    
    @Bindable var path: Keypath
    var isSelected: Bool
    
    var isChangingKeybind: Bool {
        commandManager.isInKeybindUpdateMode && isSelected
    }
    
    var body: some View {
        ZStack {
            
            ConcentricRectangle(corners: .concentric, isUniform: true)
                .fill(.clear)
                .glassEffect(.regular.tint(isSelected && !isChangingKeybind ? .blue.opacity(0.6) : .clear), in: .rect(corners: .concentric, isUniform: true))
            
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
                                                Image(colorScheme == .dark ? .lightHyperkey : .darkHyperkey)
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
                            ConcentricRectangle(corners: .concentric(minimum: 5.0), isUniform: true)
                                .fill(.regularMaterial)
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                VStack {
                    VStack {
                        if let image = previewManager.previews[path.id]?.screenshotImage {
                            if image.width > image.height {
                                Image(decorative: image, scale: 1, orientation: .up)
                                    .resizable()
                                    .clipShape(.rect(corners: .concentric))
                            } else {
                                Image(decorative: image, scale: 1, orientation: .up)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(.rect(corners: .concentric))
                            }
                        } else if let cachedImage = previewManager.previews[path.id]?.cachedImage {
                            if cachedImage.width > cachedImage.height {
                                Image(decorative: cachedImage, scale: 1, orientation: .up)
                                    .resizable()
                                    .clipShape(.rect(corners: .concentric))
                                    .opacity(0.7)
                                    .overlay {
                                        if !path.isWindowOpened {
                                            Image(systemName: "eye.slash")
                                                .resizable()
                                                .frame(width: 35, height: 30)
                                        }
                                    }
                            } else {
                                Image(decorative: cachedImage, scale: 1, orientation: .up)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(.rect(corners: .concentric))
                                    .opacity(0.7)
                                    .overlay {
                                        if !path.isWindowOpened {
                                            Image(systemName: "eye.slash")
                                                .resizable()
                                                .frame(width: 35, height: 30)
                                        }
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
                        ConcentricRectangle(corners: .concentric, isUniform: true)
                            .fill(.clear)
                            .glassEffect(.clear, in: .rect(corners: .concentric, isUniform: true))
                    )
                }
            }
            .padding(10)
            .overlay {
                if isChangingKeybind {
                    ZStack {
                        ConcentricRectangle(corners: .concentric, isUniform: true)
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
            .task(id: path.id) {
                previewManager.registerPath(processID: path.id)
                await runScreenshotLoop()
            }
        }
        .frame(width: 275)
        .frame(height: 190)
        .containerShape(.rect(cornerRadius: 15.0))
        .overlay(alignment: .bottomTrailing) {
            if isCurrentTargetPath && assignmentCoordinator.undoAvailable {
                Button {
                    assignmentCoordinator.undoLastChange()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(assignmentCoordinator.isUndoFocused ? Color.accentColor : .clear, lineWidth: 3)
                }
                .focused($undoButtonIsFocused)
                .accessibilityLabel(assignmentCoordinator.undoDescription ?? "Undo the last keybind change")
                .padding(10)
            }
        }
        .alert(assignmentAlertTitle, isPresented: assignmentAlertBinding) {
            if assignmentCoordinator.pendingConflict != nil {
                Button("Cancel", role: .cancel) {
                    assignmentCoordinator.cancelPendingAssignment()
                }
                Button("Move Keybind", role: .destructive) {
                    assignmentCoordinator.confirmPendingAssignment()
                }
            } else {
                Button("OK", role: .cancel) {
                    assignmentCoordinator.clearError()
                }
            }
        } message: {
            if let errorMessage = assignmentCoordinator.errorMessage,
               let conflict = assignmentCoordinator.pendingConflict {
                Text("\(errorMessage) The key is assigned to \(conflict.ownerNames.joined(separator: ", ")); move it to \(conflict.targetAppName)?")
            } else if let errorMessage = assignmentCoordinator.errorMessage {
                Text(errorMessage)
            } else if let conflict = assignmentCoordinator.pendingConflict {
                let owners = conflict.ownerNames.joined(separator: ", ")
                Text("\(conflict.key) is assigned to \(owners). Moving it to \(conflict.targetAppName) will remove the previous assignment.")
            } else {
                Text("Keypath could not complete the keybind change.")
            }
        }
        .onChange(of: assignmentCoordinator.isUndoFocused) { _, focused in
            undoButtonIsFocused = focused
        }
        .onChange(of: undoButtonIsFocused) { _, focused in
            if focused {
                assignmentCoordinator.setUndoFocused(true)
            }
        }
    }

    private var assignmentAlertTitle: String {
        if assignmentCoordinator.errorMessage != nil { return "Could Not Save Keybind" }
        return assignmentCoordinator.pendingConflict == nil ? "Could Not Save Keybind" : "Move Keybind?"
    }

    private var assignmentAlertBinding: Binding<Bool> {
        Binding(
            get: {
                (isPendingConflictTarget && assignmentCoordinator.pendingConflict != nil)
                    || (isCurrentTargetPath && assignmentCoordinator.errorMessage != nil)
            },
            set: { isPresented in
                if !isPresented && assignmentCoordinator.pendingConflict != nil {
                    assignmentCoordinator.cancelPendingAssignment()
                }
            }
        )
    }

    private var isCurrentTargetPath: Bool {
        guard commandManager.currentPaths.indices.contains(commandManager.currentIndex) else { return false }
        return commandManager.currentPaths[commandManager.currentIndex].id == path.id
    }

    private var isPendingConflictTarget: Bool {
        guard let conflict = assignmentCoordinator.pendingConflict else { return false }
        if let targetBundleID = conflict.targetBundleID {
            return path.application.bundleIdentifier == targetBundleID
        }
        return path.application.bundleIdentifier == nil && path.appName == conflict.targetAppName
    }
    
    func runScreenshotLoop() async {
        while !Task.isCancelled {
            let isVisible = path.hasVisibleWindow
            await MainActor.run {
                path.isWindowOpened = isVisible
            }

            do {
                let image = try await screenshotManager
                    .getApplicationImage(app: path.application)
                
                if let image {
                    await MainActor.run {
                        previewManager.addPreview(image, image, path.id)
                    }
                }
            } catch is CancellationError {
                break
            } catch {
                await MainActor.run {
                    previewManager.resetPreview(processID: path.id)
                    
                    print(previewManager.previews[path.id]?.screenshotImage ?? "no image" + "for path: \(path.appName)")
                }
            }
            
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                break
            }
        }
    }
}

#Preview {
    PathView(path: Keypath(application: NSRunningApplication()), isSelected: false)
}
