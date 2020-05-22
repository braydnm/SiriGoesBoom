//
//  SpeakerListView.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-05.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import SwiftUI
import PartialSheet
import ActivityIndicatorView

struct SpeakerListView : View{
    @ObservedObject var device: Speaker
    @State var renameInput: String = ""
        
    // values used for the editing of a variables name
    @EnvironmentObject var partialSheetManager: PartialSheetManager
    
    func mod(_ a: Int, _ n: Int) -> Int {
        precondition(n > 0, "modulus must be positive")
        let r = a % n
        return r >= 0 ? r : r + n
    }
    
    // usage of the djb2 hash to hash the name of the speaker and grab the for the speaker
    func getColor(x: String) -> Color {
      var hash = 5381
      for char in x {
        hash = ((hash << 5) &+ hash) &+ char.hashValue
      }
        
      return Color("SpeakerBackgroundColor\(mod(Int(hash), 8) + 1)")
    }
    
    var body: some View {
        let color = getColor(x: self.device.name ?? "Unknown Speaker")
        return VStack {
                HStack{
                    // Speaker Name, model, serial
                    VStack(alignment: .leading){
                        HStack {
                            // Device name, on a double tap show a partialsheet with a box to rename the device
                            Text((device.name ?? "Unknown Speaker").replacingOccurrences(of: " ", with: "\n"))
                             .font(.title)
                             .fontWeight(.bold)
                             .foregroundColor(.white)
                                .padding(20)
                                .onTapGesture(count: 2){
                                    
                                    if !self.device.connected{
                                        return
                                    }
                                    
                                    self.partialSheetManager.showPartialSheet({
                                        print("Partial sheet dismissed")
                                    }) {
                                        VStack{
                                            Text("Rename Your Speaker: ").font(.headline).bold()
                                            BoomTextView(title: self.device.name ?? "Unkown Speaker", text: self.$renameInput, color: color, thickness: 4.0).padding(.horizontal, 10)
                                            HStack{
                                                Spacer()
                                                Button(action: {
                                                    
                                                    // if the user input is different send the command to rename the device
                                                    // this should update on its own when the speaker sends back the acknowledge response and the device object changes as it is an observerd object
                                                    if self.renameInput != self.device.name && self.renameInput.count > 0{
                                                        self.device.rename(name: self.renameInput)
                                                    }
                                                    
                                                    // dismiss the sheet
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
                                                    self.partialSheetManager.closePartialSheet()
                                                }){
                                                    Image(systemName: "checkmark.circle.fill").resizable().font(Font.title.bold()).frame(width: 35, height: 35)
                                                        .foregroundColor(color)
                                                }.buttonStyle(PlainButtonStyle())
                                                Spacer()
                                            }
                                        }
                                    }
                            }
                        }
                        
                        Text(device.model ?? "Unknown Model" )
                            .font(.body)
                            .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                        
                        Text(device.serial ?? "SerialUnkown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.leading, 20)
                        
                        Spacer()
                    }
                    Spacer()
                    // Battery indicator, only if the device is available over BLE or Core Bluetooth
                    if self.device.isPresent{
                        VStack{
                            BatteryIndicator(UInt8(device.battery ?? 0)).frame(width: 55, height: 55, alignment: .trailing)
                            .padding(.top, 30).padding(.horizontal, 20)
                            Spacer()
                        }
                    }
                }
                Spacer()
                // if the device is available over BLE or Core Bluetooth allow the user to toggle the power of the device
                if self.device.isPresent{
                    HStack{
                        Spacer()
                        Button(action: {
                            if !self.device.isChangingConnection{
                                print("Toggling power")
                                self.device.togglePower()
                            }
                        }){
                            ZStack{
                                Circle().frame(width: 50, height: 50).foregroundColor(.white)
                                if !self.device.isChangingConnection{
                                    Image(systemName: "power").resizable().font(Font.title.weight(.bold)).frame(width: 30, height: 30).foregroundColor(self.device.connected ? Color("PowerOn") : color)
                                }
                                ActivityIndicatorView(isVisible: self.$device.isChangingConnection, type: .arcs).frame(width: 30, height: 30).foregroundColor(self.device.connected ? Color("PowerOn") : color)
                            }
                            }.padding(.bottom, 30).buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                }
        // monitor the device boolean for a failure to toggle the power and show an alert if it is true
        }.alert(isPresented: self.$device.failed_to_change_connection, content: {
            Alert(title: Text("Failed to \(self.device.connected ? "Disconnect" : "Connect")"), message: Text("Try moving your device in range or performing the action manually"), dismissButton: .default(Text("OK")))
        }).background(self.device.isPresent ? color : Color("SpeakerBackgroundColorDisabled"))
            .cornerRadius(30)
            .frame(width: 270, height: 350)
             .shadow(color: Color("Shadow"), radius: 10)
    }
}

//struct SpeakerListView_Previews: PreviewProvider {
//
//    @State var test: String = "SpeakerName"
//
//    static var previews: some View {
//        SpeakerListView()
//    }
//}
