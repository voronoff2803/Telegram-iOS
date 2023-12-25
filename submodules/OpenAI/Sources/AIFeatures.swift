//
//  AIFeatures.swift
//  OpenAI
//
//  Created by Alexey Voronov on 22.12.2023.
//

import Foundation

final public class AIManager {
    public struct MessageEntry {
        public init(myMessage: Bool, name: String?, text: String) {
            self.myMessage = myMessage
            self.name = name
            self.text = text
        }
        
        let myMessage: Bool
        let name: String?
        let text: String
    }
    
    public init() {}
    
    lazy var openAI: OpenAI = {
        let configuration = OpenAI.Configuration(token: "", host: "35.233.105.235", timeoutInterval: 60.0)
        let openAI = OpenAI(configuration: configuration)
        
        return openAI
    }()
    
    public func generateAnswer(
        messages: [MessageEntry],
        resultUpdate: @escaping (String) -> (),
        completion: @escaping (Error?) -> ()
    ) {
        var charCount = 0
        var actorName: String = "John"
        
        var chatMessages: [Chat] = []
        
        for message in messages.reversed() {
            if message.text.isEmpty {
                continue
            }
            var messageText = message.text
            
            if let name = message.name, !name.isEmpty {
                if message.myMessage {
                    actorName = name
                }
                
                messageText = "'\(name)': \(messageText)"
            }
            
            let chatQuery = Chat(role: message.myMessage ? .assistant : .user, content : messageText)
            
            charCount += messageText.count
            if charCount > 1024 {
                break
            }
            chatMessages.append(chatQuery)
        }
        
        chatMessages = chatMessages.reversed()
        
        chatMessages.append(Chat(role: .system, content: "Using the context of the conversation, respond to messages. Act like a human '\(actorName)'. Respond using Markdown. Answer in user's language as concisely as possible. Keep up the style of conversation. Start your short response with '\(actorName)':"))
        
        let query = ChatQuery(model: .gpt3_5Turbo, messages: chatMessages)
        
        var message = ""
        
        var isRemovedName = false
        
        self.openAI.chatsStream(query: query) { partialResult in
            switch partialResult {
            case .success(let result):
                if let delta = result.choices.first?.delta.content {
                    message += delta
                    
                    if !isRemovedName {
                        if message.contains("\(actorName)") {
                            isRemovedName = true
                            message = message.replacingOccurrences(of: "\(actorName)", with: "")
                        }
                    }
                    
                    if message.count < 20 {
                        let symbolsToRemove = ["'", " ", ":"]
                        
                        for symbol in symbolsToRemove {
                            if message.hasPrefix(symbol) {
                                message = String(message.dropFirst(symbol.count))
                            }
                        }
                    }
                    
                    if message.count > 20 && !isRemovedName {
                        isRemovedName = true
                    }
                    
                    if isRemovedName {
                        resultUpdate(message)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        } completion: { error in
            completion(error)
        }
    }
    
    
    public func generateSummary(
        messages: [MessageEntry],
        resultUpdate: @escaping (String) -> (),
        completion: @escaping (Error?) -> ()
    ) {
        var charCount = 0
        
        var chatMessages: [Chat] = []
        
        for message in messages.reversed() {
            if message.text.isEmpty {
                continue
            }
            var messageText = message.text
            
            if let name = message.name, !name.isEmpty {
                messageText = "'\(name)': \(messageText)"
            }
            
            let chatQuery = Chat(role: message.myMessage ? .assistant : .user, content : messageText)
            
            charCount += messageText.count
            if charCount > 1024 {
                break
            }
            chatMessages.append(chatQuery)
        }
        
        chatMessages = chatMessages.reversed()
        
        chatMessages.append(Chat(role: .system, content: "Using the context of the conversation, write a short summary of the dialog. Respond using Markdown. The summary should be in the same language as most of the dialog messages. Respond using the same language as most of the dialog messages content!"))
        

        let query = ChatQuery(model: .gpt3_5Turbo, messages: chatMessages)
        
        var message = ""
                
        self.openAI.chatsStream(query: query) { partialResult in
            switch partialResult {
            case .success(let result):
                if let delta = result.choices.first?.delta.content {
                    message += delta
                    
                    resultUpdate(message)
                }
            case .failure(let error):
                completion(error)
            }
        } completion: { error in
            completion(error)
        }
    }
}
