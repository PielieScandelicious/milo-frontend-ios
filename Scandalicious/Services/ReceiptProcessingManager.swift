//
//  ReceiptProcessingManager.swift
//  Scandalicious
//
//  Tracks receipts being processed in the background and polls for status updates.
//  Persists active receipts to app group UserDefaults so the share extension's
//  uploads are visible when the main app opens.
//

import Foundation
import UIKit
import SwiftUI
import Combine

@MainActor
class ReceiptProcessingManager: ObservableObject {
    static let shared = ReceiptProcessingManager()

    @Published private(set) var processingReceipts: [ProcessingReceipt] = []

    var hasActiveProcessing: Bool {
        processingReceipts.contains { !$0.isTerminal }
    }

    private var pollingTask: Task<Void, Never>?
    private let uploadService = ReceiptUploadService.shared

    // Polling configuration
    private let initialPollInterval: TimeInterval = 2.0
    private let maxPollInterval: TimeInterval = 10.0
    private let maxPollDuration: TimeInterval = 300 // 5 minutes
    private let completedDisplayDuration: TimeInterval = 5.0

    private let storageKey = "activeProcessingReceipts"
    private let appGroupId = "group.com.deepmaind.scandalicious"

    private init() {
        loadPersistedReceipts()
        startPollingIfNeeded()
    }

    // MARK: - Add Receipt

    func addReceipt(_ accepted: ReceiptUploadAcceptedResponse) {
        guard !processingReceipts.contains(where: { $0.id == accepted.receiptId }) else { return }

        let receipt = ProcessingReceipt(
            id: accepted.receiptId,
            filename: accepted.filename,
            startedAt: Date(),
            status: .pending,
            storeName: nil,
            totalAmount: nil,
            itemsCount: 0,
            errorMessage: nil,
            detectedDate: nil,
            completedAt: nil
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            processingReceipts.insert(receipt, at: 0)
        }

        persistReceipts()
        startPollingIfNeeded()
    }

    // MARK: - Dismiss

    func dismiss(_ receiptId: String) {
        withAnimation(.easeOut(duration: 0.3)) {
            processingReceipts.removeAll { $0.id == receiptId }
        }
        persistReceipts()
    }

    func dismissAll() {
        withAnimation(.easeOut(duration: 0.3)) {
            processingReceipts.removeAll { $0.isTerminal }
        }
        persistReceipts()
    }

    // MARK: - Reload (for share extension pickup)

    func reloadPersistedReceipts() {
        loadPersistedReceipts()
        startPollingIfNeeded()
    }

    // MARK: - Polling

    private func startPollingIfNeeded() {
        guard pollingTask == nil, hasActiveProcessing else { return }

        pollingTask = Task {
            var interval = initialPollInterval

            while !Task.isCancelled && hasActiveProcessing {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }

                await pollAllActive()

                // Exponential backoff: 2s -> 3s -> 4.5s -> 6.75s -> 10s (capped)
                interval = min(interval * 1.5, maxPollInterval)

                pruneStaleReceipts()
            }

            pollingTask = nil
        }
    }

    private func pollAllActive() async {
        let activeReceipts = processingReceipts.filter { !$0.isTerminal }
        guard !activeReceipts.isEmpty else { return }

        // Poll all in parallel
        await withTaskGroup(of: (String, ReceiptStatusResponse?).self) { group in
            for receipt in activeReceipts {
                group.addTask {
                    do {
                        let status = try await self.uploadService.getReceiptStatus(
                            receiptId: receipt.id
                        )
                        return (receipt.id, status)
                    } catch {
                        return (receipt.id, nil)
                    }
                }
            }

            for await (receiptId, statusResponse) in group {
                guard let response = statusResponse,
                      let index = processingReceipts.firstIndex(where: { $0.id == receiptId })
                else { continue }

                let oldStatus = processingReceipts[index].status

                withAnimation(.easeInOut(duration: 0.3)) {
                    processingReceipts[index].status = response.status
                    processingReceipts[index].storeName = response.storeName
                    processingReceipts[index].totalAmount = response.totalAmount
                    processingReceipts[index].itemsCount = response.itemsCount
                    processingReceipts[index].errorMessage = response.errorMessage
                    processingReceipts[index].detectedDate = response.detectedDate

                    if processingReceipts[index].isTerminal && processingReceipts[index].completedAt == nil {
                        processingReceipts[index].completedAt = Date()
                    }
                }

                // Fire notifications on terminal transition
                if !isTerminal(oldStatus) && response.status == .completed {
                    handleReceiptCompleted(processingReceipts[index])
                } else if !isTerminal(oldStatus) && response.status == .failed {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }

        persistReceipts()
    }

    private func handleReceiptCompleted(_ receipt: ProcessingReceipt) {
        NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Auto-dismiss after delay
        Task {
            try? await Task.sleep(for: .seconds(completedDisplayDuration))
            await MainActor.run {
                dismiss(receipt.id)
            }
        }
    }

    private func pruneStaleReceipts() {
        let cutoff = Date().addingTimeInterval(-maxPollDuration)
        for i in processingReceipts.indices {
            if !processingReceipts[i].isTerminal && processingReceipts[i].startedAt < cutoff {
                processingReceipts[i].status = .failed
                processingReceipts[i].errorMessage = "Processing timed out"
                processingReceipts[i].completedAt = Date()
            }
        }
    }

    private func isTerminal(_ status: ReceiptStatus) -> Bool {
        status == .completed || status == .success || status == .failed
    }

    // MARK: - Persistence

    private func persistReceipts() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        let active = processingReceipts.filter { !$0.isTerminal }
        if let data = try? JSONEncoder().encode(active) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func loadPersistedReceipts() {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: storageKey),
              let receipts = try? JSONDecoder().decode([ProcessingReceipt].self, from: data)
        else { return }

        // Merge: add any persisted receipts we don't already have
        for receipt in receipts {
            if !processingReceipts.contains(where: { $0.id == receipt.id }) {
                processingReceipts.append(receipt)
            }
        }
    }
}
