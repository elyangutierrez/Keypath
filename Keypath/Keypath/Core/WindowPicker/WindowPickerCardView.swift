//
//  WindowPickerCardView.swift
//  Keypath
//

import AppKit
import SwiftUI

struct WindowPickerCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let applicationName: String
    let applicationIcon: NSImage
    let keyNumber: Int
    let windowTitle: String
    let isMinimized: Bool
    let keybind: Keybind?
    let preview: CGImage?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(nsImage: applicationIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)

                Text(applicationName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                Text("\(keyNumber)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                
                Spacer(minLength: 0)

                keybindBadge
            }
            .frame(height: 30)

            previewArea
                .frame(height: 124)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: 184)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .containerShape(.rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Window \(keyNumber): \(windowTitle)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Press \(keyNumber) to activate this window.")
        .help(windowTitle)
    }

    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(.gray.opacity(0.24))

            if let preview {
                GeometryReader { geometry in
                    Image(decorative: preview, scale: 1, orientation: .up)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
        }
        .clipShape(.rect(cornerRadius: 11))
        .accessibilityHidden(true)
    }

    private var keybindBadge: some View {
        HStack(spacing: 1) {
            if let keybind {
                if case .symbol = keybind.key1 {
                    Image(colorScheme == .dark ? .lightHyperkey : .darkHyperkey)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                }

                Text(keybindLabel(for: keybind.key2))
                    .font(.body)
                    .frame(minWidth: 25, minHeight: 25)
            } else {
                Image(systemName: "nosign")
                    .font(.caption.weight(.medium))
                    .frame(width: 19, height: 20)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }

    private var accessibilityValue: String {
        if isMinimized {
            return preview == nil ? "Minimized. Preview unavailable." : "Minimized. Preview available."
        }
        return preview == nil ? "Preview unavailable." : "Preview available."
    }

    private func keybindLabel(for command: CommandType) -> String {
        switch command {
        case let .letter(letter):
            return letter.uppercased()
        case let .symbol(symbol):
            return symbol
        }
    }
}
