//
//  CommandsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import SwiftUI

struct CommandsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredShortcut: ShortcutAction?

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 15.0) {
                    HStack {
                        Text("Commands")
                            .fontWeight(.medium)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Commands.activationChordHelpText)
                        Text(Commands.contextualShortcutHelpText)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 5.0) {
                        ForEach(Commands.shortcuts) { shortcut in
                            HStack(alignment: .top, spacing: 6.0) {
                                Image(systemName: shortcut.icon)
                                    .imageScale(.medium)

                                Text(shortcut.title)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutPriority(1)

                                Spacer(minLength: 8)

                                HStack(spacing: 5.0) {
                                    if shortcut.usesActivationChord {
                                        Image(colorScheme == .dark ? .lightHyperkey : .darkHyperkey)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .background {
                                                ConcentricRectangle(corners: .concentric(minimum: 5.0))
                                                    .fill(.gray.opacity(0.4))
                                                    .frame(width: 20, height: 20)
                                            }
                                    }

                                    Text(shortcut.keyLabel)
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 20, minHeight: 20)
                                        .background {
                                            ConcentricRectangle(corners: .concentric(minimum: 5.0))
                                                .fill(.gray.opacity(0.4))
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 35, alignment: .topLeading)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                            .background {
                                ConcentricRectangle(corners: .concentric(minimum: 10.0))
                                    .fill(hoveredShortcut == shortcut.action ? .gray.opacity(0.2) : .clear)
                            }
                            .contentShape(.rect(cornerRadius: 10.0))
                            .onHover { hovering in
                                withAnimation(.spring(duration: 0.3)) {
                                    hoveredShortcut = hovering ? shortcut.action : nil
                                }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .safeAreaPadding()
    }
}

#Preview {
    CommandsView()
        .frame(width: 315, height: 250)
}
