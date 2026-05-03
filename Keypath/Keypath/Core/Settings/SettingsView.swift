//
//  SettingsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/16/26.
//

import SwiftUI

struct SettingsView: View {
    
    @FocusState private var isFocused
    
    @State private var excludedApps: [String] = Config.shared.getExcludedApps()
    @State private var newAppPath: String = ""
    @State private var navigationManager = NavigationManager.shared
    @State private var isShowingExclusionList: Bool = true
    @State private var applicationList: [ListApplication] = []
    @State private var applicationNames: [String] = []
    @State private var dataManager = DataManager.shared
    
    @State private var selectedApp: ListApplication?
    
    let applicationManager = ApplicationManager()
    
    var filteredAppList: [ListApplication] {
        let query = newAppPath.trimmingCharacters(in: .whitespaces).lowercased()
        
        guard !query.isEmpty else {
            return []
        }
        
        return applicationList.filter { $0.appName.lowercased().contains(query) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    
                    ConcentricRectangle(corners: .concentric, isUniform: true)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(corners: .concentric, isUniform: true))
                    
                    VStack(spacing: 20.0) {
                        HStack {
                            Text("Excluded Applications")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Enter App Name", text: $newAppPath)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(
                                        ConcentricRectangle(corners: .concentric(minimum: 8.0), isUniform: true)
                                            .fill(.gray.opacity(0.2))
                                    )
                                    .focused($isFocused)
                                
                                Button(action: {
                                    withAnimation(.spring(duration: 0.3)) {
                                        addApp()
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !newAppPath.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 10.0) {
                                        ForEach(filteredAppList, id: \.id) { app in
                                            HStack(spacing: 10.0) {
                                                if let icon = app.icon {
                                                    Image(nsImage: icon)
                                                }
                                                
                                                Text(app.appName)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(5)
                                            .background(
                                                ConcentricRectangle(corners: .concentric(minimum: 7.0), isUniform: true)
                                                    .fill(getFillStyle(for: app))
                                            )
                                            .contentShape(RoundedRectangle(cornerRadius: 8.0))
                                            .onTapGesture {
                                                withAnimation(.spring(duration: 0.3)) {
                                                    if app.isSelected {
                                                        app.isSelected = false
                                                        app.fillState = .hovering
                                                        newAppPath = ""
                                                        selectedApp = nil
                                                    } else {
                                                        // Reset previous selection
                                                        selectedApp?.isSelected = false
                                                        selectedApp?.fillState = .none
                                                        
                                                        // Set new selection
                                                        app.isSelected = true
                                                        app.fillState = .selected
                                                        selectedApp = app
                                                        newAppPath = app.appName
                                                    }
                                                }
                                            }
                                            .onHover { hovering in
                                                guard !app.isSelected else { return }
                                                withAnimation(.spring(duration: 0.3)) {
                                                    app.fillState = hovering ? .hovering : .none
                                                }
                                            }
                                        }
                                    }
                                }
                                .scrollIndicators(.never)
                                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .leading)
                                .safeAreaPadding()
                                .background(
                                    ConcentricRectangle(corners: .concentric(minimum: 8.0), isUniform: true)
                                        .fill(.gray.opacity(0.2))
                                )
                            }
                        }
                        
                        VStack(spacing: 8) {
                            if isShowingExclusionList {
                                ForEach(excludedApps.sorted(), id: \.self) { app in
                                    HStack {
                                        Text(app)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.spring(duration: 0.3)) {
                                                removeApp(app)
                                            }
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10)
                                    .background(
                                        ConcentricRectangle(corners: .concentric(minimum: 8.0), isUniform: true)
                                            .fill(.gray.opacity(0.2))
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
                .containerShape(.rect(cornerRadius: 15.0))
                
                ZStack {
                    
                    ConcentricRectangle(corners: .concentric, isUniform: true)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(corners: .concentric, isUniform: true))
                    
                    VStack(spacing: 20.0) {
                        HStack {
                            Text("Reset Keybinds")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 20.0) {
                            Text("Resetting your keybinds will remove all custom keybinds you have set up. This cannot be undone.")
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Button(role: .destructive, action: {
                                dataManager.removeAllSavedKeybinds()
                            }) {
                                Text("Reset")
                                    .frame(height: 25)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
                .containerShape(.rect(cornerRadius: 15.0))
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, EdgeInsets(top: 0.0, leading: 0.0, bottom: 30.0, trailing: 0.0), for: .scrollContent)
        .onAppear {
            fetchApplications()
        }
        .onTapGesture {
            isFocused = false
        }
    }
    
    func getFillStyle(for app: ListApplication) -> AnyShapeStyle {
        if app.isSelected {
            return AnyShapeStyle(Color.blue)
        }
        
        switch app.fillState {
        case .hovering:
            return AnyShapeStyle(.gray.opacity(0.2))
        case .selected:
            return AnyShapeStyle(Color.blue)
        default:
            return AnyShapeStyle(Color.clear)
        }
    }
    
    func fetchApplications() {
        applicationList = applicationManager.getApplications().sorted()
        applicationNames = applicationList.map { $0.appName }.sorted()
    }
    
    func addApp() {
        
        guard selectedApp != nil else { return }
        
        let trimmed = newAppPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Config.shared.addExcludedApp(trimmed)
        excludedApps = Config.shared.getExcludedApps()
        newAppPath = ""
        
        selectedApp?.isSelected = false
        selectedApp?.fillState = .none
        selectedApp = nil
    }
    
    func removeApp(_ app: String) {
        Config.shared.removeExcludedApp(app)
        excludedApps = Config.shared.getExcludedApps()
    }
}

#Preview {
    SettingsView()
        .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410)
}
