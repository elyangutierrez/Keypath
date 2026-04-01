//
//  BottomBarView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import SwiftUI

struct BottomBarView: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            HStack(spacing: 13.0) {
                Text("Commands")
                
                HStack(spacing: 5.0) {
                    Image(systemName: "control")
                        .fontWeight(.medium)
                        .frame(width: 25, height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 5.0)
                                .fill(.quaternary)
                                .frame(width: 23, height: 23)
                        )
                    
                    Image(systemName: "option")
                        .fontWeight(.medium)
                        .frame(width: 25, height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 5.0)
                                .fill(.quaternary)
                                .frame(width: 23, height: 23)
                        )
                    
                    Text("C")
                        .fontWeight(.medium)
                        .frame(width: 25, height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 5.0)
                                .fill(.quaternary)
                                .frame(width: 23, height: 23)
                        )
                }
            }
        }
        .padding(.horizontal)
        .frame(height: 55)
        .background(
            Rectangle()
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    BottomBarView()
}
