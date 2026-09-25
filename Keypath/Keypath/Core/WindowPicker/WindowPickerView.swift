//
//  WindowPickerView.swift
//  Keypath
//

import AppKit
import SwiftUI

struct WindowPickerView: View {
    @Bindable private var manager: WindowPickerManager

    init(manager: WindowPickerManager = .shared) {
        self.manager = manager
    }

    var body: some View {
        ZStack {
            ConcentricRectangle(corners: .concentric, isUniform: true)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(corners: .concentric))

            VStack(alignment: .leading, spacing: 12) {
                header

                if let errorMessage = manager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                if manager.visibleWindows.isEmpty {
                    ContentUnavailableView {
                        Label("No Windows Available", systemImage: "macwindow.on.rectangle")
                    } description: {
                        Text("The app no longer has accessible windows. Press Escape to close this picker.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    windowList
                }

                Text(Commands.windowPickerHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        }
        .frame(width: PathsWindowManager.pathsContentSize.width - 30,
               height: PathsWindowManager.pathsContentSize.height - 30)
        .containerShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Window picker")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: manager.application?.icon ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Choose a Window")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if manager.pageCount > 1 {
                Text("Page \(manager.pageIndex + 1) of \(manager.pageCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headerSubtitle: String {
        let appName = manager.application?.localizedName ?? "App"
        guard let range = manager.visibleWindowRange else {
            return "\(appName) · No accessible windows"
        }
        if manager.pageCount == 1 {
            return "\(appName) · \(manager.windows.count) windows"
        }
        return "\(appName) · Windows \(range.lowerBound)–\(range.upperBound) of \(manager.windows.count)"
    }

    private var windowList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(manager.visibleWindows.enumerated()), id: \.element.id) { index, window in
                    windowRow(window, keyNumber: index + 1)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.never)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Accessible app windows")
    }

    private func windowRow(_ window: AccessibleWindow, keyNumber: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(keyNumber)")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(width: 30, height: 30)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            Text(window.title)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            if window.isMinimized {
                Label("Minimized", systemImage: "minus.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(corners: .concentric(minimum: 12)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Window \(window.number): \(window.title)")
        .accessibilityValue(window.isMinimized ? "Minimized" : "Available")
        .accessibilityHint("Press \(keyNumber) to activate this window.")
    }
}

#Preview {
    WindowPickerView()
}
