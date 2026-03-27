//
//  KeypathApp.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/24/26.
//

import SwiftUI

@main
struct KeypathApp: App {
    var body: some Scene {
        WindowGroup {
            PathsView()
                .frame(width: 650, height: 425)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
