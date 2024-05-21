//
//  APIManager.swift
//  YoutubeVideoSummariser
//
//  Created by Mazen Kourouche on 15/6/2023.
//

import Foundation
import OpenAI
import Alamofire

struct TranscriptionResponse: Decodable {
    let data: TranscriptionData
}

struct TranscriptionData: Decodable {
    let transcript: String
}

class YouTubeSummariser: ObservableObject {
    let openAI = OpenAI(apiToken: "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")
    @Published var state: SummariserState?
    private var observation: NSKeyValueObservation?
    
    func summariseYouTubeVideo(url: String) async {
        do {
            
            // Step 1: Extract Video ID
            let videoId = try retrieveVideoId(url)
            
            // Step 2: Transcribe the audio file
            let transcription = try await transcribeAudio(videoId: videoId)
            
            // Step 3: Summarise the transcription
            await summariseCaption(caption: transcription)
            
        } catch {
            print("An error occurred: \(error)")
            DispatchQueue.main.async {
                self.state = .failed
            }
            
        }
    }
    
    
    func transcribeAudio(videoId: String) async throws -> String {
        await MainActor.run {
            state = .transcribing
        }
        let url = "https://youtube-transcripts-api.vercel.app/api/transcription"
        
        do {
            let response = try await AF.request(url, method: .post, parameters: ["videoId": videoId]).serializingDecodable(TranscriptionResponse.self).value
           
            return response.data.transcript
        } catch {
            throw error
        }
    }


    func summariseCaption(caption: String) async {
        await MainActor.run {
            state = .summarising("")
        }
        let chatQuery = ChatQuery(model: .gpt3_5Turbo, messages: [.init(role: .user, content: "Summarise this transcript from a video: \(caption) then translate the summarize to bahasa indonesia")])

        do {
            for try await result in openAI.chatsStream(query: chatQuery) {
                if case let .summarising(content) = state, let resultContent = result.choices.first?.delta.content {
                    await MainActor.run {
                        state = .summarising(content + resultContent)
                    }
                }
            }
        } catch {
            print(error)
            await MainActor.run {
                state = .failed
            }
        }
    }
    
    func retrieveVideoId(_ url: String) throws -> String {
       
        let RE_YOUTUBE = try! NSRegularExpression(pattern: "(?:youtube\\.com\\/(?:[^\\/]+\\/.+\\/(?:v|e(?:mbed)?)\\/|.*[?&]v=)|youtu\\.be\\/)([^\"&?\\/\\s]{11})", options: .caseInsensitive)
        
        let range = NSRange(location: 0, length: url.utf16.count)
        if let match = RE_YOUTUBE.firstMatch(in: url, options: [], range: range) {
            if let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        throw SummariserError.runtimeError("Failed to retrieve video ID")
    }
}

enum SummariserState: Equatable {
    case idle
    case transcribing
    case summarising(String)
    case failed
}

enum SummariserError: Error {
    case runtimeError(String)
}
