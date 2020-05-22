//
//  ContentView.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-04-30.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import SwiftUI

import PartialSheet

struct ContentView: View{
    
    // bluetooth manager
    @ObservedObject var ble = BluetoothManager()
    // current card index
    @State var index: Int = 0
    
    var body: some View {
        var speakers = ble.knownSpeakers.map{$0.value}
        // sort each speaker alphabetically but showing all devices connected over core bluetooth first
        speakers.sort(by: {
            
            if $0.isPresent && !$1.isPresent{
                return false
            }
            
            else if !$0.isPresent && $1.isPresent{
                return true
            }
            else{
                return $0.name ?? "Unknown Name" < $1.name ?? "Unknown Name"
            }
        })
        
        return VStack{
            VStack(spacing: 2){
                HStack {
                   VStack(alignment: .leading) {
                      Text("Speakers")
                         .font(.largeTitle)
                        .fontWeight(.heavy).padding(.top, 40).padding(.horizontal, 20)
                    }
                   Spacer()
                }
                Divider().padding(.horizontal, 10)
            }
            
            // if there are any speakers to display
            if speakers.count > 0{
                // add a paging view with a speaker list card for every known speaker
                PagingView(index: self.$index, maxIndex: speakers.count-1){
                    ForEach(speakers, id: \.self){ speaker in
                        SpeakerListView(device: speaker)
                    }
                }.padding(.bottom, 100)
                    .animation(.easeInOut)
            }
            else{
                Spacer().padding(.bottom, 200)
            }
        }.background(Color("Background")).edgesIgnoringSafeArea(.all)
        // add the partial sheet for the speaker list views to access
        .addPartialSheet()
        // when our view appears start the bluetooth manager
        .onAppear(){
                self.ble.start()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
