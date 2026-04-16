//
//  ExclusionListView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/16/26.
//

import SwiftUI

struct ExclusionListView: View {
    @State private var excludedApps: [String] = Config.shared.getExcludedApps()
    @State private var newAppPath: String = ""
    @State private var navigationManager = NavigationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            
            HStack {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            HStack {
                Text("Excluded Applications")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Add application by name (e.g., 'Finder')")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    TextField("App Name", text: $newAppPath)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                        .onSubmit {
                            addApp()
                        }
                    
                    Button(action: addApp) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(excludedApps, id: \.self) { app in
                        HStack {
                            Text(app)
                                .fontWeight(.medium)
                            Spacer()
                            Button(action: {
                                removeApp(app)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.1)))
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410)
    }
    
    private func addApp() {
        let trimmed = newAppPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Config.shared.addExcludedApp(trimmed)
        excludedApps = Config.shared.getExcludedApps()
        newAppPath = ""
    }
    
    private func removeApp(_ app: String) {
        Config.shared.removeExcludedApp(app)
        excludedApps = Config.shared.getExcludedApps()
    }
}

#Preview {
    ExclusionListView()
        .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410)
}
