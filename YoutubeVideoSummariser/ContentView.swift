//
//  ContentView.swift
//  YoutubeVideoSummariser
//
//  Created by Mazen Kourouche on 15/6/2023.
//

import SwiftUI

struct ContentView: View {
    @State private var videoUrl = ""
    @ObservedObject private var youtubeSummariser = YouTubeSummariser()
    
    var body: some View {
        if let state = youtubeSummariser.state {
            VStack {
                switch state {
                case .transcribing:
                    Text("Transcribing")
                case .summarising(let string):
                    Text("Summaring: \(string)")
                case .failed:
                    Text("Failed")
                default: Text("Uninitialised")
                }
                Button("New Summary") {
                    youtubeSummariser.state = nil
                }
                
            }
            .padding()
        } else {
            VStack {
                TextField("Enter YouTube URL", text: $videoUrl)
                    .padding()
                    .border(Color.gray, width: 0.5)
                
                Button(action: {
                    Task {
                        await youtubeSummariser.summariseYouTubeVideo(url: videoUrl)
                    }
                }) {
                    Text("Summarise")
                }.padding()
            }.padding()
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
