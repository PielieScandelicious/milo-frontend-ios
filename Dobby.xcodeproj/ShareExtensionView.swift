//
//  ShareExtensionView.swift
//  Dobby Share Extension
//
//  Share extension UI for receiving receipts from other apps
//

import SwiftUI
import UniformTypeIdentifiers
import Vision

struct ShareExtensionView: View {
    @Environment(\.extensionContext) private var extensionContext
    @StateObject private var viewModel = ShareExtensionViewModel()
    
    let sharedItems: [Any]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                switch viewModel.state {
                case .processing:
                    ProcessingView(message: viewModel.statusMessage)
                    
                case .reviewing(let receiptData):
                    ReviewReceiptView(
                        receiptData: receiptData,
                        onSave: { store, date in
                            Task {
                                await viewModel.saveReceipt(store: store, date: date)
                                completeExtension()
                            }
                        },
                        onCancel: {
                            cancelExtension()
                        }
                    )
                    
                case .error(let errorMessage):
                    ErrorView(
                        message: errorMessage,
                        onRetry: {
                            Task {
                                await viewModel.processSharedItems(sharedItems)
                            }
                        },
                        onCancel: {
                            cancelExtension()
                        }
                    )
                    
                case .success:
                    SuccessView()
                }
            }
            .navigationTitle("Add to Dobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .reviewing = viewModel.state {
                    // Show cancel button only in review state
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            cancelExtension()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.processSharedItems(sharedItems)
        }
    }
    
    private func completeExtension() {
        extensionContext?.completeRequest(returningItems: nil)
    }
    
    private func cancelExtension() {
        extensionContext?.cancelRequest(withError: ShareExtensionError.userCancelled)
    }
}

// MARK: - View Model

@MainActor
class ShareExtensionViewModel: ObservableObject {
    @Published var state: ShareExtensionState = .processing
    @Published var statusMessage = "Processing receipt..."
    
    private var currentReceiptData: ReceiptData?
    
    enum ShareExtensionState {
        case processing
        case reviewing(ReceiptData)
        case error(String)
        case success
    }
    
    func processSharedItems(_ items: [Any]) async {
        state = .processing
        statusMessage = "Extracting receipt..."
        
        do {
            // Extract data from shared items
            guard let extensionItem = items.first as? NSExtensionItem,
                  let attachments = extensionItem.attachments else {
                throw ShareExtensionError.noValidData
            }
            
            var imageData: Data?
            var extractedText: String?
            
            // Try to get image first
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    statusMessage = "Loading image..."
                    imageData = try await loadImage(from: attachment)
                    print("📸 Image loaded: \(imageData?.count ?? 0) bytes")
                    break
                }
            }
            
            // If we have an image, extract text from it
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                statusMessage = "Reading receipt text..."
                print("🔍 Starting OCR...")
                extractedText = try await extractTextFromImage(uiImage)
                print("📝 Extracted text (\(extractedText?.count ?? 0) chars):")
                print(extractedText ?? "[no text]")
            } else {
                // Try to get text directly
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        statusMessage = "Loading text..."
                        extractedText = try await loadText(from: attachment)
                        print("📝 Text loaded: \(extractedText ?? "[empty]")")
                        break
                    }
                }
            }
            
            guard extractedText != nil || imageData != nil else {
                throw ShareExtensionError.noValidData
            }
            
            statusMessage = "Detecting store..."
            
            // Detect store from text
            let detectedStore = detectStore(from: extractedText ?? "")
            print("🏪 Detected store: \(detectedStore.rawValue)")
            
            let detectedDate = extractDate(from: extractedText ?? "") ?? Date()
            print("📅 Detected date: \(detectedDate)")
            
            // Create receipt data for review
            let receiptData = ReceiptData(
                imageData: imageData,
                extractedText: extractedText,
                detectedStore: detectedStore,
                date: detectedDate
            )
            
            currentReceiptData = receiptData
            state = .reviewing(receiptData)
            
        } catch {
            print("❌ Error processing: \(error)")
            state = .error(error.localizedDescription)
        }
    }
    
    func saveReceipt(store: SupportedStore, date: Date) async {
        guard var receiptData = currentReceiptData else { return }
        
        // Update with user-selected values
        receiptData.detectedStore = store
        receiptData.date = date
        
        state = .processing
        statusMessage = "Saving receipt..."
        
        do {
            try await saveToSharedContainer(receiptData)
            print("✅ Receipt saved successfully!")
            state = .success
            
            // Auto-close after success
            try await Task.sleep(for: .milliseconds(800))
        } catch {
            print("❌ Failed to save: \(error)")
            state = .error("Failed to save: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractTextFromImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ShareExtensionError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func detectStore(from text: String) -> SupportedStore {
        let lowercasedText = text.lowercased()
        
        for store in SupportedStore.allCases where store != .unknown {
            for keyword in store.keywords {
                if lowercasedText.contains(keyword.lowercased()) {
                    return store
                }
            }
        }
        
        return .unknown
    }
    
    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        return matches?.first?.date
    }
    
    private func saveToSharedContainer(_ data: ReceiptData) async throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.yourname.dobby"
        ) else {
            throw ShareExtensionError.noSharedContainer
        }
        
        let receiptsFolder = containerURL.appendingPathComponent("SharedReceipts")
        
        if !FileManager.default.fileExists(atPath: receiptsFolder.path) {
            try FileManager.default.createDirectory(
                at: receiptsFolder,
                withIntermediateDirectories: true
            )
        }
        
        let shareData = ReceiptShareData(
            imageData: data.imageData,
            text: data.extractedText,
            storeName: data.detectedStore.rawValue,
            date: data.date
        )
        
        let filename = "receipt_\(UUID().uuidString).json"
        let fileURL = receiptsFolder.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(shareData)
        
        try jsonData.write(to: fileURL)
    }
    
    private func loadImage(from attachment: NSItemProvider) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let url = data as? URL {
                    do {
                        let imageData = try Data(contentsOf: url)
                        continuation.resume(returning: imageData)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else if let imageData = data as? Data {
                    continuation.resume(returning: imageData)
                } else if let image = data as? UIImage {
                    continuation.resume(returning: image.jpegData(compressionQuality: 0.9))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadText(from attachment: NSItemProvider) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let text = data as? String {
                    continuation.resume(returning: text)
                } else if let data = data as? Data,
                          let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ProcessingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SuccessView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Receipt Added!")
                .font(.title2.bold())
            
            Text("Open Dobby to review")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Unable to Import")
                .font(.title2.bold())
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct ReviewReceiptView: View {
    let receiptData: ReceiptData
    let onSave: (SupportedStore, Date) -> Void
    let onCancel: () -> Void
    
    @State private var selectedStore: SupportedStore
    @State private var selectedDate: Date
    @State private var showingStorePicker = false
    
    init(receiptData: ReceiptData, onSave: @escaping (SupportedStore, Date) -> Void, onCancel: @escaping () -> Void) {
        self.receiptData = receiptData
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedStore = State(initialValue: receiptData.detectedStore)
        _selectedDate = State(initialValue: receiptData.date)
        
        // Debug: Print what was detected
        print("🔍 ReviewReceiptView initialized with:")
        print("   Store: \(receiptData.detectedStore.rawValue)")
        print("   Date: \(receiptData.date)")
        print("   Has image: \(receiptData.imageData != nil)")
        print("   Text length: \(receiptData.extractedText?.count ?? 0)")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Receipt Preview
                if let imageData = receiptData.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        .padding(.horizontal)
                }
                
                // Store Selection Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Store")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                showingStorePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "storefront.fill")
                                        .foregroundStyle(selectedStore == .unknown ? .orange : .blue)
                                    
                                    Text(selectedStore.displayName)
                                        .font(.title3.bold())
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Auto-detection status
                    HStack(spacing: 8) {
                        Image(systemName: receiptData.detectedStore == .unknown ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(receiptData.detectedStore == .unknown ? .orange : .green)
                        
                        Text(receiptData.detectedStore == .unknown ? "Store not detected - please select" : "Auto-detected: \(receiptData.detectedStore.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Date Picker
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.blue)
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal)
                
                // Receipt Text Preview (if available)
                if let text = receiptData.extractedText, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Receipt Text")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            Text(text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 150)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                
                // Save Button
                Button {
                    onSave(selectedStore, selectedDate)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add Receipt")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingStorePicker) {
            StorePickerView(selectedStore: $selectedStore)
        }
    }
}

struct StorePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStore: SupportedStore
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(SupportedStore.allCases, id: \.self) { store in
                    Button {
                        selectedStore = store
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "storefront.fill")
                                .foregroundStyle(store == .unknown ? .orange : .blue)
                            
                            Text(store.displayName)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if selectedStore == store {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ReceiptData {
    let imageData: Data?
    let extractedText: String?
    var detectedStore: SupportedStore
    var date: Date
}

struct ReceiptShareData: Codable {
    let imageData: Data?
    let text: String?
    let storeName: String
    let date: Date
}

// Store Detection (copied from main app)
enum SupportedStore: String, CaseIterable, Codable {
    case aldi = "ALDI"
    case colruyt = "COLRUYT"
    case delhaize = "DELHAIZE"
    case carrefour = "CARREFOUR"
    case lidl = "LIDL"
    case unknown = "Unknown Store"
    
    var displayName: String {
        return self.rawValue
    }
    
    var keywords: [String] {
        switch self {
        case .aldi:
            return ["aldi", "aldi nord", "aldi süd"]
        case .colruyt:
            return ["colruyt", "okay", "bio-planet"]
        case .delhaize:
            return ["delhaize", "ad delhaize", "proxy delhaize"]
        case .carrefour:
            return ["carrefour", "carrefour express", "carrefour market"]
        case .lidl:
            return ["lidl"]
        case .unknown:
            return []
        }
    }
}

enum ShareExtensionError: LocalizedError {
    case noExtensionItem
    case noAttachments
    case noValidData
    case noSharedContainer
    case userCancelled
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .noExtensionItem:
            return "No shared data found"
        case .noAttachments:
            return "No attachments found"
        case .noValidData:
            return "Unable to extract receipt data. Please share an image or text."
        case .noSharedContainer:
            return "Unable to access shared storage. Please check App Groups configuration."
        case .userCancelled:
            return "Import cancelled"
        case .invalidImage:
            return "Invalid image format"
        }
    }
}

// MARK: - Environment Key for Extension Context

private struct ExtensionContextKey: EnvironmentKey {
    static let defaultValue: NSExtensionContext? = nil
}

extension EnvironmentValues {
    var extensionContext: NSExtensionContext? {
        get { self[ExtensionContextKey.self] }
        set { self[ExtensionContextKey.self] = newValue }
    }
}
