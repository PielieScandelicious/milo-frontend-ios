//
//  env.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation

enum AppConfiguration {
    // Railway Backend API Configuration
    static let backendBaseURL = "https://scandalicious-api-production.up.railway.app"

    // API Endpoints (computed properties to avoid actor isolation issues)
    static var uploadEndpoint: String { "\(backendBaseURL)/upload" }
    static var chatEndpoint: String { "\(backendBaseURL)/api/v1/chat/" }
    static var chatStreamEndpoint: String { "\(backendBaseURL)/api/v1/chat/stream" }
    static var processReceiptEndpoint: String { "\(backendBaseURL)/process-receipt" }
}

  
