//
//  env.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
struct AppConfiguration {
    // IMPORTANT: Replace "your-actual-api-key-here" with your Anthropic API key
    // Or set the ANTHROPIC_API_KEY environment variable in your Xcode scheme
    static let anthropicAPIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "your-api-key-here"
    
    static var isAPIKeyValid: Bool {
        !anthropicAPIKey.isEmpty && anthropicAPIKey != "your-actual-api-key-here"
    }
}

  
