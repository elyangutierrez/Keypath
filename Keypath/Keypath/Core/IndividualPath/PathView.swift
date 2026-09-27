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
    var cardSize: CGSize

    private var isNarrow: Bool { cardSize.width < 160 }
    private var isCompact: Bool { cardSize.width < 220 }
    
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
                    HStack(spacing: isNarrow ? 4 : 8) {
                        Image(nsImage: path.application.icon ?? NSImage())
                            .resizable()
                            .scaledToFit()
                            .frame(width: isNarrow ? 19 : 26, height: isNarrow ? 19 : 26)
                        
                        Text(path.application.localizedName ?? "Unknown")
                            .font(isNarrow ? .caption2 : .body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        
                        Spacer(minLength: 0)
                        
                        VStack {
                            HStack(spacing: -5.0) {
                                if let keybind = path.keybind {
                                    if !isNarrow, case .symbol(_) = keybind.key1 {
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
                                            .font(isNarrow ? .caption : .body)
                                            .frame(width: isNarrow ? 21 : 25, height: isNarrow ? 21 : 25)
                                    }
                                } else {
                                    Image(systemName: "nosign")
                                        .fontWeight(.medium)
                                        .frame(width: isNarrow ? 21 : 25, height: isNarrow ? 21 : 25)
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
                                                .frame(width: isCompact ? 24 : 35, height: isCompact ? 21 : 30)
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
                                                .frame(width: isCompact ? 24 : 35, height: isCompact ? 21 : 30)
                                        }
                                    }
                            }
                        } else {
                            Image(nsImage: path.application.icon ?? NSImage())
                                .resizable()
                                .frame(width: isNarrow ? 40 : (isCompact ? 60 : 80),
                                       height: isNarrow ? 40 : (isCompact ? 60 : 80))
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
            .padding(isNarrow ? 7 : 10)
            .overlay {
                if isChangingKeybind {
                    ZStack {
                        ConcentricRectangle(corners: .concentric, isUniform: true)
                            .fill(.ultraThickMaterial)
                            .opacity(0.9)
                        
                        VStack(spacing: isNarrow ? 5 : 15) {
                            Image(systemName: "keyboard")
                                .resizable()
                                .frame(width: isNarrow ? 25 : 35, height: isNarrow ? 18 : 25)
                            
                            Text(isNarrow ? "Press a key" : "Enter your new keybind")
                                .font(isNarrow ? .caption : .headline)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .task(id: path.id) {
                previewManager.registerPath(processID: path.id)
                await runScreenshotLoop()
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .containerShape(.rect(cornerRadius: 15.0))
        .overlay(alignment: .bottomTrailing) {
            if assignmentCoordinator.isUndoTarget(
                path,
                among: commandManager.currentPaths,
                isSelected: isCurrentTargetPath
            ) {
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
    PathView(path: Keypath(application: NSRunningApplication()),
             isSelected: false, cardSize: CGSize(width: 275, height: 190))
}
