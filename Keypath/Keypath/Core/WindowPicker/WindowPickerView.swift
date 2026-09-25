//
//  WindowPickerView.swift
//  Keypath
//

import AppKit
import SwiftUI

struct WindowPickerView: View {
    @Bindable private var manager: WindowPickerManager

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(manager: WindowPickerManager = .shared) {
        self.manager = manager
    }

    var body: some View {
        VStack(spacing: 10) {
            if manager.visibleWindows.isEmpty {
                ContentUnavailableView {
                    Label("No Windows Available", systemImage: "macwindow.on.rectangle")
                } description: {
                    Text("The app no longer has accessible windows. Press Escape to close this picker.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                windowGrid
            }

            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            footer
        }
        .padding(14)
        .frame(width: manager.panelContentSize.width, height: manager.panelContentSize.height)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .glassEffect(.clear, in: .rect(cornerRadius: 18))
        }
        .containerShape(.rect(cornerRadius: 18))
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Window picker")
    }

    private var windowGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                ForEach(Array(manager.visibleWindows.enumerated()), id: \.element.id) { index, window in
                    WindowPickerCardView(
                        applicationName: manager.application?.localizedName ?? "App",
                        applicationIcon: manager.application?.icon ?? NSImage(),
                        keyNumber: index + 1,
                        windowTitle: window.title,
                        isMinimized: window.isMinimized,
                        keybind: manager.keybind,
                        preview: manager.windowPreviews[window.number],
                        isSelected: manager.selectedWindowIndex
                            == manager.pageIndex * WindowPickerManager.windowsPerPage + index
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Accessible app windows")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(Commands.windowPickerHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            if manager.pageCount > 1 {
                Text("Page \(manager.pageIndex + 1) of \(manager.pageCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WindowPickerView()
}
