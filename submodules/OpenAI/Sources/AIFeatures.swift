//
//  AIFeatures.swift
//  OpenAI
//
//  Created by Alexey Voronov on 22.12.2023.
//

import Foundation
import AIStrings
import TelegramPresentationData
import Markdown
import RevenueCat

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
        let userId = Purchases.shared.appUserID
        let configuration = OpenAI.Configuration(token: userId, host: OpenAIConfig.serviceHost, timeoutInterval: 60.0)
        let openAI = OpenAI(configuration: configuration)
        
        return openAI
    }()
    
    public func generateAnswer(
        messages: [MessageEntry],
        resultUpdate: @escaping (String) -> (),
        completion: @escaping (Error?) -> (),
        presentationData: PresentationData
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
            if charCount > 2048 {
                break
            }
            chatMessages.append(chatQuery)
        }
        
        chatMessages = chatMessages.reversed()
        
        chatMessages.append(Chat(role: .system, content: "Using the context of the conversation, respond to messages. Act like a human '\(actorName)'. Respond using Markdown. Answer in user's language as concisely as possible. Keep up the style of conversation. Start your short response with '\(actorName)':"))
                
        let query = ChatQuery(model: .gpt3_5Turbo, messages: chatMessages)
                
        let startStr = "\(actorName)"
        
        self.openAI.chats(query: query) { result in
            switch result {
            case .success(let result):
                if let message = result.choices.first?.message.content {
                    
                    resultUpdate(AIManager.cleanTextFromStart(message, startStr: startStr))
                }
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    
    func replaceSpecialCharacters(in string: String) -> String {
        //var newString = foldMultipleLineBreaks(string)
        let newString = string
        return newString
    }
    
    public func generateSummary(
        messages: [MessageEntry],
        resultUpdate: @escaping (String) -> (),
        completion: @escaping (Error?) -> (),
        presentationData: PresentationData
    ) {
        var charCount = 0
        
        var chatMessages: [Chat] = []
        
        for message in messages.reversed() {
            if message.text.isEmpty {
                continue
            }
            var messageText = replaceSpecialCharacters(in: message.text)
            
            if let name = message.name, !name.isEmpty {
                messageText = "\(replaceSpecialCharacters(in: name)): \(replaceSpecialCharacters(in: messageText))"
            }
            
            
            let chatQuery = Chat(
                role: message.myMessage ? .assistant : .user,
                content : messageText
            )
            
            charCount += messageText.count
            if charCount > 8_192 {
                break
            }
            chatMessages.append(chatQuery)
            
        }
        
        chatMessages = chatMessages.reversed()
        
        let locale = presentationData.strings.baseLanguageCode
        chatMessages.append(Chat(role: .system, content: l("Prompt.Summary", locale)))

        
        let query = ChatQuery(model: .gpt3_5Turbo, messages: chatMessages)
        
        let startStr = l("Prompt.Summary.Start", locale)
                
        self.openAI.chats(query: query) { result in
            switch result {
            case .success(let result):
                if let message = result.choices.first?.message.content {
                    
                    resultUpdate(AIManager.cleanTextFromStart(message, startStr: startStr))
                }
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    static func cleanTextFromStart(_ text: String, startStr: String) -> String {
        // Check if the text is shorter than or equal to 20 characters
        let rangeLimit = min(20, text.count)
        
        // Define the range for the first 20 characters
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: rangeLimit)
        let substring = String(text[range])
        
        let pattern = "[*'\"]*\\**\(startStr)\\**[:]*[*'\" ]*" // regex pattern
        
        // Create a regular expression
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("Invalid pattern 1")
            return text
        }
        
        // Replace matches in the substring
        var modifiedSubstring = regex.stringByReplacingMatches(in: substring, options: [], range: NSRange(location: 0, length: substring.utf16.count), withTemplate: "")
        
        while modifiedSubstring.starts(with: "\n") {
            modifiedSubstring.removeFirst()
        }
        
        // Reassemble the full string with the modified part
        let modifiedText = modifiedSubstring + text[range.upperBound...]
        return modifiedText
    }
}
