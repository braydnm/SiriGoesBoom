//
//  LoadingCircle.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-07.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import SwiftUI

// Animated loading circle when powering on
struct LoadingIndicator: View{
    
    @State var animateStrokeStart = true
    @State var animateStrokeEnd = false
    @State var isRotating = false
    var color: Color
    var lineWidth: Float
    
    init(_ color: Color, _ lineWidth: Float = 3){
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View{
        Circle()
            .trim(from: animateStrokeStart ? 1/3 : 1/9, to: animateStrokeEnd ? 2/5 : 1)
            .stroke(lineWidth: CGFloat(self.lineWidth))
            .foregroundColor(self.color)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear() {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
                {
                    self.isRotating.toggle()
                }
                
                withAnimation(Animation.linear(duration: 1).delay(0.5).repeatForever(autoreverses: true))
                {
                    self.animateStrokeStart.toggle()
                }
                
                withAnimation(Animation.linear(duration: 1).delay(1).repeatForever(autoreverses: true))
               {
                   self.animateStrokeEnd.toggle()
               }
        }
    }
    
}

//struct LoadingCircle_Previews: PreviewProvider {
//    static var previews: some View {
//        LoadingIndicator()
//    }
//}
