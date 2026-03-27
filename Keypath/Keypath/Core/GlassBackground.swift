//
//  GlassBackground.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/26/26
//

import SwiftUI

struct GlassBackground: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(.clear, in: .rect(cornerRadius: 0))
            .ignoresSafeArea()
    }
}

#Preview {
    GlassBackground()
}
