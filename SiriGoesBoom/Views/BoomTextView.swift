//
//  BoomTextView.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-07.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import SwiftUI

// Text edit view
struct BoomTextView : View{
    
    @Binding var text: String
    var title: String
    var activeColor: Color
    var thickness: Float
    var maxLength: Int
    
    // State variables to update the view
    @State var currentColor: Color = .gray
    @State var input: String = ""
    @State var editing: Bool = false
    
    
    init(title: String, text: Binding<String>, color: Color, thickness: Float = 2.0, maxLength: Int = 30){
        self._text = text
        self.title = title
        self.activeColor = color
        self.thickness = thickness
        self.maxLength = maxLength
    }
    var body: some View{
        
        VStack{
            TextField("", text: self.$input,
              onEditingChanged: { edit in
                  self.editing = edit
              }
            ).onReceive(self.input.publisher.collect(), perform: {
                self.input = String($0.prefix(self.maxLength))
                self.text = self.input
            }).onAppear(perform: {
                self.input = self.title
            })
            HorizontalLine(color: editing ? self.activeColor : .gray)
        }.padding(.bottom, CGFloat(self.thickness))
        
    }
    
}

struct HorizontalLineShape: Shape {

    func path(in rect: CGRect) -> Path {

        let fill = CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height)
        var path = Path()
        path.addRoundedRect(in: fill, cornerSize: CGSize(width: 2, height: 2))

        return path
    }
}

struct HorizontalLine: View {
    private var color: Color? = nil
    private var height: CGFloat = 1.0

    init(color: Color, height: CGFloat = 1.0) {
        self.color = color
        self.height = height
    }

    var body: some View {
        HorizontalLineShape().fill(self.color!).frame(minWidth: 0, maxWidth: .infinity, minHeight: height, maxHeight: height)
    }
}
