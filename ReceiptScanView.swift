//
//  ReceiptScanView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import PhotosUI

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var importResult: ReceiptImportResult?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var pastedText: String = ""
    @State private var showTextInput = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Import Receipt")
                        .font(.largeTitle.bold())
                    
                    Text("Scan or paste your receipt to automatically categorize your purchases")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Import Options
                VStack(spacing: 16) {
                    // Camera Button
                    Button {
                        showCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Take Photo")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    
                    // Photo Library Button
                    Button {
                        showImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("Choose from Library")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    
                    // Text Input Button
                    Button {
                        showTextInput = true
                    } label: {
                        HStack {
                            Image(systemName: "text.viewfinder")
                                .font(.title2)
                            Text("Paste Receipt Text")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                
                // Processing Indicator
                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Processing receipt...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Using AI to categorize items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Preview of selected image
                if let image = selectedImage {
                    VStack(spacing: 12) {
                        Text("Selected Receipt")
                            .font(.headline)
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How it works:")
                        .font(.headline)
                    
                    InstructionRow(
                        icon: "1.circle.fill",
                        text: "Take a photo or paste your receipt"
                    )
                    
                    InstructionRow(
                        icon: "2.circle.fill",
                        text: "AI automatically detects the store"
                    )
                    
                    InstructionRow(
                        icon: "3.circle.fill",
                        text: "Items are categorized intelligently"
                    )
                    
                    InstructionRow(
                        icon: "4.circle.fill",
                        text: "Review and save to your transactions"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(white: 0.05))
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showTextInput) {
            TextInputView(text: $pastedText, onSubmit: {
                Task {
                    await processText(pastedText)
                }
            })
        }
        .sheet(item: $importResult) { result in
            ReceiptReviewView(
                result: result,
                onSave: { transactions in
                    transactionManager.addTransactions(transactions)
                    showSuccess = true
                    importResult = nil
                },
                onCancel: {
                    importResult = nil
                }
            )
        }
        .alert("Success!", isPresented: $showSuccess) {
            Button("OK") {
                selectedImage = nil
                pastedText = ""
            }
        } message: {
            Text("Receipt imported successfully!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                Task {
                    await processImage(image)
                }
            }
        }
    }
    
    // MARK: - Process Image
    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            let result = try await ReceiptImportService.shared.importReceipt(from: image)
            await MainActor.run {
                importResult = result
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
            }
        }
    }
    
    // MARK: - Process Text
    private func processText(_ text: String) async {
        guard !text.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            let result = try await ReceiptImportService.shared.importReceipt(from: text)
            await MainActor.run {
                importResult = result
                isProcessing = false
                showTextInput = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Instruction Row
struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue.gradient)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Text Input View
struct TextInputView: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste your receipt text below")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                TextEditor(text: $text)
                    .frame(minHeight: 300)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .padding()
                
                if text.isEmpty {
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Paste receipt text here")
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 200)
                }
                
                Spacer()
            }
            .navigationTitle("Paste Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Process") {
                        onSubmit()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
}
