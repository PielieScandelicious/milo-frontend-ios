//
//  PromoAPIService.swift
//  Scandalicious
//
//  Folder browsing, similar-promo recommendations, and interaction telemetry.
//

import Foundation
import FirebaseAuth

enum PromoInteractionEventType: String, Encodable {
    case dealOpened = "deal_opened"
    case similarPromoClicked = "similar_promo_clicked"
}

actor PromoAPIService {
    static let shared = PromoAPIService()

    private var baseURL: String { AppConfiguration.apiBase }

    enum PromoError: LocalizedError {
        case notFound
        case serviceUnavailable
        case invalidResponse
        case serverError(String)
        case decodingError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Promo not found"
            case .serviceUnavailable:
                return "Deals service is temporarily unavailable"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let message):
                return message
            case .decodingError(let message):
                return "Failed to parse response: \(message)"
            case .networkError(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - Similar Promos

    func getSimilarPromos(promoId: String, limit: Int = 10) async throws -> SimilarPromosResponse {
        guard let url = URL(string: "\(baseURL)/promos/\(promoId)/similar?limit=\(limit)&personalize=true") else {
            throw PromoError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        // Attach bearer if available (optional — endpoint personalizes only if present)
        if let token = try? await getFirebaseToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PromoError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode(SimilarPromosResponse.self, from: data)
                } catch {
                    throw PromoError.decodingError(error.localizedDescription)
                }
            case 404:
                throw PromoError.notFound
            case 503:
                throw PromoError.serviceUnavailable
            default:
                throw PromoError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as PromoError {
            throw error
        } catch {
            throw PromoError.networkError(error)
        }
    }

    // MARK: - Interaction Events (telemetry)

    func logInteractionEvent(
        eventType: PromoInteractionEventType,
        promoItemId: String? = nil,
        sourceItemId: String? = nil,
        storeName: String? = nil,
        metadata: [String: String]? = nil
    ) async {
        guard let url = URL(string: "\(baseURL)/promos/interactions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        // Attach bearer if signed in; if not, event is logged anonymously.
        if let token = try? await getFirebaseToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        struct Body: Encodable {
            let eventType: PromoInteractionEventType
            let promoItemId: String?
            let sourceItemId: String?
            let storeName: String?
            let metadata: [String: String]?

            enum CodingKeys: String, CodingKey {
                case eventType = "event_type"
                case promoItemId = "promo_item_id"
                case sourceItemId = "source_item_id"
                case storeName = "store_name"
                case metadata
            }
        }

        do {
            request.httpBody = try JSONEncoder().encode(Body(
                eventType: eventType,
                promoItemId: promoItemId,
                sourceItemId: sourceItemId,
                storeName: storeName,
                metadata: metadata
            ))
            _ = try? await URLSession.shared.data(for: request)
        } catch {
            // Telemetry is best-effort; never surface errors
            print("[PromoAPI] interaction event failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Promo Folders (public, no auth)

    func getFolders() async throws -> PromoFoldersResponse {
        guard let url = URL(string: "\(baseURL)/promos/folders") else {
            throw PromoError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PromoError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode(PromoFoldersResponse.self, from: data)
                } catch {
                    throw PromoError.decodingError(error.localizedDescription)
                }
            case 503:
                throw PromoError.serviceUnavailable
            default:
                throw PromoError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as PromoError {
            throw error
        } catch {
            throw PromoError.networkError(error)
        }
    }

    // MARK: - Helper

    private func getFirebaseToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken()
    }
}
