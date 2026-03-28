//
//  UnavaliableAppsView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import SwiftUI

struct UnavaliableAppsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Apps Found",
            systemImage: "macwindow.stack",
            description: Text("Please ensure that you have at least one application running.")
        )
    }
}

#Preview {
    UnavaliableAppsView()
}
