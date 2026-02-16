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
    var nickname: String?
    var gender: String?
    var age: Int?
    var language: String?
    var profileCompleted: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case nickname
        case gender
        case age
        case language
        case profileCompleted = "profile_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserProfileUpdate: Codable {
    var nickname: String?
    var gender: String?
    var age: Int?
    var language: String?
}

enum ProfileGender: String, CaseIterable {
    case male = "male"
    case female = "female"
    case preferNotToSay = "prefer_not_to_say"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .preferNotToSay: return "X"
        }
    }
}

enum ProfileLanguage: String, CaseIterable {
    case english = "en"
    case dutch = "nl"
    case french = "fr"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .dutch: return "Nederlands"
        case .french: return "Fran\u{00E7}ais"
        }
    }

    var flag: String {
        switch self {
        case .english: return "\u{1F1EC}\u{1F1E7}"
        case .dutch: return "\u{1F1F3}\u{1F1F1}"
        case .french: return "\u{1F1EB}\u{1F1F7}"
        }
    }

    static func from(apiValue: String?) -> ProfileLanguage? {
        guard let apiValue = apiValue else { return nil }
        return ProfileLanguage(rawValue: apiValue)
    }
}
