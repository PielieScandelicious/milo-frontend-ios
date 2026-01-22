//
//  ReceiptUploadViewModel.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ReceiptUploadViewModel: ObservableObject {
    @Published var uploadState: ReceiptUploadState = .idle
    @Published var uploadedReceipt: ReceiptUploadResponse?
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    var isUploading: Bool {
        if case .uploading = uploadState {
            return true
        }
        return false
    }
    
    var isProcessing: Bool {
        if case .processing = uploadState {
            return true
        }
        return false
    }
    
    var isBusy: Bool {
        isUploading || isProcessing
    }
    
    // MARK: - Upload Receipt
    
    func uploadReceipt(image: UIImage) async {
        guard uploadState == .idle else {
            print("Upload already in progress")
            return
        }
        
        uploadState = .uploading
        
        do {
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            
            switch response.status {
            case .success, .completed:
                uploadState = .success(response)
                uploadedReceipt = response
                
                // Trigger success haptic
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
            case .pending, .processing:
                uploadState = .processing
                errorMessage = "Receipt is still being processed. Please check back later."
                showError = true
                
                // You could implement polling here if needed
                await pollForProcessingCompletion(receiptId: response.receiptId)
                
            case .failed:
                uploadState = .failed("Receipt processing failed")
                errorMessage = "The receipt could not be processed. Please try again with a clearer image."
                showError = true
                
                // Trigger error haptic
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch let error as ReceiptUploadError {
            uploadState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            showError = true
            
            // Trigger error haptic
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            uploadState = .failed(error.localizedDescription)
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showError = true
            
            // Trigger error haptic
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    // MARK: - Reset State
    
    func reset() {
        uploadState = .idle
        uploadedReceipt = nil
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private Methods
    
    private func pollForProcessingCompletion(receiptId: String) async {
        // This is a placeholder for polling logic
        // You would implement this if your API supports checking receipt status
        // For now, we'll just reset after a delay
        try? await Task.sleep(for: .seconds(3))
        uploadState = .idle
    }
}

