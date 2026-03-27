//
//  PathView.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import SwiftUI

struct PathView: View {
    var body: some View {
        VStack {
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 5.0)
                        .fill(.white)
                        .frame(width: 25, height: 25)
                    
                    Text("Holder")
                    
                    Spacer()
                    
                    VStack {
                        HStack(spacing: -10.0) {
                            Image(systemName: "control")
                                .fontWeight(.medium)
                                .frame(width: 25, height: 25)
                            
                            Image(systemName: "option")
                                .fontWeight(.medium)
                                .frame(width: 25, height: 25)
                            
                            Text("C")
                                .fontWeight(.medium)
                                .frame(width: 25, height: 25)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 5.0)
                            .fill(.clear)
                            .glassEffect(.clear, in: .rect(cornerRadius: 5.0))
                    )
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            VStack {
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15.0)
                    .fill(.clear)
                    .glassEffect(.clear, in: .rect(cornerRadius: 15.0))
            )
        }
        .padding(10)
        .frame(width: 275)
        .frame(height: 170)
        .background(
            RoundedRectangle(cornerRadius: 15.0)
                .fill(.clear)
                .glassEffect(.clear, in: .rect(cornerRadius: 15.0))
        )
    }
}

#Preview {
    PathView()
}
