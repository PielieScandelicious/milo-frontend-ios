//
//  env.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation

struct AppConfiguration {
    // Railway Backend API Configuration
    static let backendBaseURL = "https://3edaeenmik.eu-west-1.awsapprunner.com"
    
    // API Endpoints
    static let uploadEndpoint = "\(backendBaseURL)/upload"
    static let chatEndpoint = "\(backendBaseURL)/chat"
    static let processReceiptEndpoint = "\(backendBaseURL)/process-receipt"
}

  
