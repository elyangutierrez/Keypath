//
//  KeybindsListView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/4/26.
//

import SwiftUI

@Observable
class KeybindDisplayItem: Identifiable {
    var id = UUID()
    var appName: String
    var keybind: Keybind
    var isHovered: Bool = false

    init(appName: String, keybind: Keybind) {
        self.appName = appName
        self.keybind = keybind
    }
}

struct KeybindsListView: View {
    
    @State private var keybindDisplayItems: [KeybindDisplayItem] = []
    @State private var hoveredKeybind: SavedKeybind?
    
    var body: some View {
        VStack {
            VStack {
                ScrollView {
                    VStack(spacing: 15.0) {
                        HStack {
                            Text("Keybinds")
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                        
                        VStack(spacing: 5.0) {
                            ForEach(keybindDisplayItems, id: \.id) { item in
                                VStack {
                                    HStack {
                                        Text(item.appName)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 5.0) {
                                            if case .symbol(_) = item.keybind.key1 {
                                                Image(.hyperKey)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 16, height: 16)
                                                    .background (
                                                        RoundedRectangle(cornerRadius: 5.0)
                                                            .fill(.gray.opacity(0.4))
                                                            .frame(width: 20, height: 20)
                                                    )
                                            }
                                            
                                            if case let .letter(letter) = item.keybind.key2 {
                                                Text(letter)
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
                                        .fill(item.isHovered ? .gray.opacity(0.2) : .clear)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 10.0))
                                .onHover { hovering in
                                    withAnimation(.spring(duration: 0.3)) {
                                        item.isHovered = hovering
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
        .onAppear {
            let keybinds = getAllKeybinds()
            
            for keybind in keybinds.sorted() {
                let item = KeybindDisplayItem(appName: keybind.appName, keybind: keybind.keybind)
                keybindDisplayItems.append(item)
            }
        }
    }
    
    func getAllKeybinds() -> [SavedKeybind] {
        return DataManager.shared.fetchAllSavedKeybinds()
    }
}

#Preview {
    KeybindsListView()
        .frame(width: 315, height: 250)
}
