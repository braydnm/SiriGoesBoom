//
//  BatteryIndicator.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-05.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import SwiftUI

// Circular percentage battery indicator used in the SpeakerListView
struct BatteryIndicator: View{
    var progress: UInt8
    
    init(_ progress: UInt8) {
        self.progress = progress
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 7.0)
                .opacity(0.3)
                .foregroundColor(Color.white)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(Float(self.progress) / 100, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 7.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.white)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear)

            Text(String(format: "%d%%", min(self.progress, 100)))
                .font(.body)
                .bold()
                .foregroundColor(.white)
        }
    }
}
