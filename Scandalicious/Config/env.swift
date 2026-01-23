//
//  env.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation

enum AppConfiguration {
    // Railway Backend API Configuration
    #if PRODUCTION
    static let backendBaseURL = "https://scandalicious-api-production.up.railway.app"
    static let environment = "PRODUCTION"
    #else
    static let backendBaseURL = "https://scandalicious-api-non-prod.up.railway.app"
    static let environment = "DEBUG/NON-PROD"
    #endif

    // API Endpoints (computed properties to avoid actor isolation issues)
    static var uploadEndpoint: String { "\(backendBaseURL)/upload" }
    static var chatEndpoint: String { "\(backendBaseURL)/api/v1/chat/" }
    static var chatStreamEndpoint: String { "\(backendBaseURL)/api/v1/chat/stream" }

    // Receipt API endpoint
    static var receiptUploadEndpoint: String { "\(backendBaseURL)/api/v3/receipts/upload" }
    
    // Helper to log current configuration
    static func logConfiguration() {
        print("🔧 App Environment: \(environment)")
        print("🌐 Backend URL: \(backendBaseURL)")
    }
}

  
