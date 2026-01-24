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

    // API Version - change this to update all endpoints
    private static let apiVersion = "v2"
    static var apiBase: String { "\(backendBaseURL)/api/\(apiVersion)" }

    // API Endpoints
    static var uploadEndpoint: String { "\(backendBaseURL)/upload" }
    static var chatEndpoint: String { "\(apiBase)/chat/" }
    static var chatStreamEndpoint: String { "\(apiBase)/chat/stream" }
    static var receiptUploadEndpoint: String { "\(apiBase)/receipts/upload" }
    static var rateLimitEndpoint: String { "\(apiBase)/rate-limit" }
    static var analyticsEndpoint: String { apiBase }
    static var profileEndpoint: String { "\(apiBase)/profile" }
    static var transactionsEndpoint: String { "\(apiBase)/transactions" }
    static var receiptsEndpoint: String { "\(apiBase)/receipts" }
    
    // Helper to log current configuration
    static func logConfiguration() {
        print("🔧 App Environment: \(environment)")
        print("🌐 Backend URL: \(backendBaseURL)")
    }
}

  
