//
//  env.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation

enum AppConfiguration {
    // Railway Backend API Configuration
    static let backendBaseURL = "https://3edaeenmik.eu-west-1.awsapprunner.com"

    // API Endpoints (computed properties to avoid actor isolation issues)
    static var uploadEndpoint: String { "\(backendBaseURL)/upload" }
    static var chatEndpoint: String { "\(backendBaseURL)/chat" }
    static var processReceiptEndpoint: String { "\(backendBaseURL)/process-receipt" }
}

  
