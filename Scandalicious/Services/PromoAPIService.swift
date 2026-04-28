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
    case searchQuerySubmitted = "search_query_submitted"
    case searchResultTapped = "search_result_tapped"
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

    // MARK: - Promo Search (public, optional auth)

    func searchPromos(
        query: String,
        stores: [String] = [],
        limit: Int = 20
    ) async throws -> PromoSearchResponse {
        guard var components = URLComponents(string: "\(baseURL)/promos/search") else {
            throw PromoError.invalidResponse
        }
        var queryItems: [URLQueryItem] = [
            .init(name: "q", value: query),
            .init(name: "limit", value: String(limit)),
        ]
        for store in stores where !store.isEmpty {
            queryItems.append(.init(name: "store", value: store))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw PromoError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

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
                    return try JSONDecoder().decode(PromoSearchResponse.self, from: data)
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

    func getPopularBrands(limit: Int = 10) async throws -> [PopularBrand] {
        guard let url = URL(string: "\(baseURL)/promos/search/popular-brands?limit=\(limit)") else {
            throw PromoError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PromoError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode([PopularBrand].self, from: data)
                } catch {
                    throw PromoError.decodingError(error.localizedDescription)
                }
            default:
                throw PromoError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as PromoError {
            throw error
        } catch {
            throw PromoError.networkError(error)
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

// MARK: - Similar Promos Cache

/// Synchronous-peek cache + inflight dedupe for `/promos/{id}/similar` responses.
/// Mirrors the pattern used by `ImagePrefetcher`: the folder viewer warms the
/// cache while the user browses pages, and `PromoProductDetailSheet` checks
/// the cache synchronously to skip the shimmer when data is already available.
final class SimilarPromosCache {
    static let shared = SimilarPromosCache()

    private let cache: NSCache<NSString, CachedSimilarPromos> = {
        let c = NSCache<NSString, CachedSimilarPromos>()
        c.countLimit = 300
        return c
    }()

    private var inflight: [NSString: Task<SimilarPromosResponse?, Never>] = [:]
    private let queue = DispatchQueue(label: "SimilarPromosCache.inflight")

    private func cacheKey(promoId: String, limit: Int) -> NSString {
        "\(promoId)|\(limit)" as NSString
    }

    /// Synchronous lookup — safe to call from the main thread during SwiftUI init.
    func cached(promoId: String, limit: Int = 10) -> SimilarPromosResponse? {
        cache.object(forKey: cacheKey(promoId: promoId, limit: limit))?.response
    }

    /// Kick off a fetch if not cached or already in-flight; do not wait.
    func prefetch(promoId: String, limit: Int = 10) {
        _ = fetchTask(promoId: promoId, limit: limit)
    }

    /// Await-able access: returns the cached response or the result of a fresh fetch.
    func getOrFetch(promoId: String, limit: Int = 10) async -> SimilarPromosResponse? {
        if let cached = cached(promoId: promoId, limit: limit) { return cached }
        return await fetchTask(promoId: promoId, limit: limit).value
    }

    @discardableResult
    private func fetchTask(promoId: String, limit: Int) -> Task<SimilarPromosResponse?, Never> {
        let key = cacheKey(promoId: promoId, limit: limit)
        if let box = cache.object(forKey: key) {
            let response = box.response
            return Task { response }
        }
        return queue.sync {
            if let existing = inflight[key] { return existing }
            let task = Task<SimilarPromosResponse?, Never> { [weak self] in
                defer {
                    self?.queue.sync { _ = self?.inflight.removeValue(forKey: key) }
                }
                do {
                    let response = try await PromoAPIService.shared.getSimilarPromos(promoId: promoId, limit: limit)
                    self?.cache.setObject(CachedSimilarPromos(response: response), forKey: key)
                    return response
                } catch {
                    return nil
                }
            }
            inflight[key] = task
            return task
        }
    }
}

private final class CachedSimilarPromos {
    let response: SimilarPromosResponse
    init(response: SimilarPromosResponse) { self.response = response }
}

// MARK: - Promo Search Cache

/// Short-TTL cache + inflight dedupe for `/promos/search` responses.
/// 5-minute TTL — promo data is fairly static within a session, but folders
/// rotate weekly so we don't want to over-cache.
final class PromoSearchCache {
    static let shared = PromoSearchCache()

    private let cache: NSCache<NSString, CachedSearch> = {
        let c = NSCache<NSString, CachedSearch>()
        c.countLimit = 100
        return c
    }()

    private static let ttlSeconds: TimeInterval = 300

    private var inflight: [NSString: Task<PromoSearchResponse?, Never>] = [:]
    private let queue = DispatchQueue(label: "PromoSearchCache.inflight")

    private func cacheKey(query: String, stores: [String], limit: Int) -> NSString {
        // Sort to make the key order-independent: {colruyt,delhaize} and
        // {delhaize,colruyt} must hash to the same cache slot.
        let normalized = stores.filter { !$0.isEmpty }.sorted().joined(separator: ",")
        return "\(query.lowercased())|\(normalized)|\(limit)" as NSString
    }

    func cached(query: String, stores: [String], limit: Int) -> PromoSearchResponse? {
        let key = cacheKey(query: query, stores: stores, limit: limit)
        guard let box = cache.object(forKey: key) else { return nil }
        if Date().timeIntervalSince(box.cachedAt) > Self.ttlSeconds {
            cache.removeObject(forKey: key)
            return nil
        }
        return box.response
    }

    func getOrFetch(query: String, stores: [String], limit: Int) async -> PromoSearchResponse? {
        if let hit = cached(query: query, stores: stores, limit: limit) { return hit }
        let key = cacheKey(query: query, stores: stores, limit: limit)
        let task: Task<PromoSearchResponse?, Never> = queue.sync {
            if let existing = inflight[key] { return existing }
            let new = Task<PromoSearchResponse?, Never> { [weak self] in
                defer {
                    self?.queue.sync { _ = self?.inflight.removeValue(forKey: key) }
                }
                do {
                    let response = try await PromoAPIService.shared.searchPromos(
                        query: query, stores: stores, limit: limit
                    )
                    self?.cache.setObject(CachedSearch(response: response), forKey: key)
                    return response
                } catch {
                    return nil
                }
            }
            inflight[key] = new
            return new
        }
        return await task.value
    }
}

private final class CachedSearch {
    let response: PromoSearchResponse
    let cachedAt: Date
    init(response: PromoSearchResponse) {
        self.response = response
        self.cachedAt = Date()
    }
}
