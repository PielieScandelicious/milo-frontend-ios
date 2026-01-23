//
//  UserProfile.swift
//  Scandalicious
//
//  Created by Claude on 23/01/2026.
//

import Foundation

struct UserProfile: Codable {
    let userId: String
    var firstName: String?
    var lastName: String?
    var gender: String?
    var profileCompleted: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case gender
        case profileCompleted = "profile_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserProfileUpdate: Codable {
    var firstName: String?
    var lastName: String?
    var gender: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case gender
    }
}

enum ProfileGender: String, CaseIterable {
    case male = "male"
    case female = "female"
    case preferNotToSay = "prefer_not_to_say"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}
