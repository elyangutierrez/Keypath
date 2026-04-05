//
//  CommandsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import SwiftUI

struct CommandsView: View {
    
    @State private var commands = Commands().cmds
    
    var body: some View {
        VStack {
            VStack {
                ScrollView {
                    VStack(spacing: 15.0) {
                        HStack {
                            Text("Commands")
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                        
                        VStack(spacing: 5.0) {
                            ForEach(commands, id: \.id) { cmd in
                                VStack {
                                    HStack {
                                        HStack {
                                            Image(systemName: cmd.icon)
                                            
                                            Text(cmd.name)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 5.0) {
                                            if case let .symbol(sym) = cmd.keybind.key1 {
                                                Image(systemName: sym)
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 5.0)
                                                            .fill(.gray.opacity(0.4))
                                                    )
                                            }
                                            
                                            if case let .symbol(sym) = cmd.keybind.key2 {
                                                Image(systemName: sym)
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 5.0)
                                                            .fill(.gray.opacity(0.4))
                                                    )
                                            }
                                            
                                            if case let .letter(letter) = cmd.keybind.key3 {
                                                Text(letter)
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 5.0)
                                                            .fill(.gray.opacity(0.4))
                                                    )
                                            } else if case let .symbol(sym) = cmd.keybind.key3 {
                                                Image(systemName: sym)
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 5.0)
                                                            .fill(.gray.opacity(0.4))
                                                    )
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 35, maxHeight: 35)
                                .padding(.horizontal, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 10.0)
                                        .fill(cmd.isHovered ? .gray.opacity(0.2) : .clear)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 10.0))
                                .onHover { hovering in
                                    withAnimation(.spring(duration: 0.3)) {
                                        cmd.isHovered = hovering
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .safeAreaPadding()
    }
}

#Preview {
    CommandsView()
        .frame(width: 315, height: 250)
}
