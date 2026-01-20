//
//  ScandaLiciousApp+ShareExtension.swift
//  Scandalicious
//
//  Example integration for Share Extension
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

// MARK: - Example: Main App Entry Point
// Add this to your existing DobbyApp file
// Receipts are uploaded directly to the server via the Share Extension
// No local processing needed in the main app

/*
@main
struct ScandaLiciousApp: App {
    @StateObject private var transactionManager = TransactionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transactionManager)
        }
    }
}
*/

// MARK: - Example: Add Receipt Upload to Your Navigation

/*
struct SettingsView: View {
    var body: some View {
        List {
            Section("Receipts") {
                NavigationLink {
                    ReceiptUploadView()
                } label: {
                    Label("Upload Receipt", systemImage: "doc.text.image")
                }
                
                NavigationLink {
                    ReceiptScanView()
                } label: {
                    Label("Scan New Receipt", systemImage: "camera.viewfinder")
                }
            }
            
            Section("Data") {
                Button {
                    Task {
                        await checkUploadStatus()
                    }
                } label: {
                    Label("Check Upload Status", systemImage: "cloud.fill")
                }
            }
        }
    }
    
    private func checkUploadStatus() async {
        print("☁️ Receipts are uploaded directly to the server")
        print("💾 Check your backend for uploaded receipts")
    }
}
*/

// MARK: - Example: Receipt Upload View (Alternative Implementation)

struct ExampleReceiptUploadView: View {
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isUploading = false
    @State private var uploadResult: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                
                if isUploading {
                    ProgressView("Uploading to server...")
                } else if let result = uploadResult {
                    Text(result)
                        .foregroundColor(result.contains("Success") ? .green : .red)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Button("Choose Different Image") {
                        selectedImage = nil
                        uploadResult = nil
                    }
                    
                    if !isUploading {
                        Button("Upload") {
                            Task {
                                await uploadReceipt()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Receipt Selected",
                    systemImage: "photo.badge.plus",
                    description: Text("Select a receipt image to upload to the server")
                )
                
                Button("Select Image") {
                    showingImagePicker = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Upload Receipt")
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    private func uploadReceipt() async {
        guard let image = selectedImage else { return }
        
        isUploading = true
        uploadResult = nil
        
        do {
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            uploadResult = "Success! S3 Key: \(response.s3_key)"
        } catch {
            uploadResult = "Error: \(error.localizedDescription)"
        }
        
        isUploading = false
    }
}

// MARK: - Simple Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
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

// MARK: - Example: Upload Status

/// Check if receipts have been uploaded by monitoring your backend
/// The Share Extension uploads directly to: https://3edaeenmik.eu-west-1.awsapprunner.com/upload
struct UploadStatusView: View {
    @State private var lastUploadInfo = "No recent uploads"
    
    var body: some View {
        List {
            Section("Upload Configuration") {
                LabeledContent("Endpoint", value: "AWS App Runner")
                LabeledContent("Storage", value: "S3 Bucket")
                LabeledContent("Method", value: "Direct Upload")
            }
            
            Section("How It Works") {
                Text("When you share a receipt image:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Share Extension receives the image/PDF", systemImage: "1.circle.fill")
                    Label("PDFs are uploaded as-is (preserved)", systemImage: "2.circle.fill")
                    Label("Images are converted to JPEG", systemImage: "2.circle.fill")
                    Label("Uploaded to your server via API", systemImage: "3.circle.fill")
                    Label("Server processes and stores in S3", systemImage: "4.circle.fill")
                    Label("Success confirmation shown", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.callout)
            }
            
            Section("Format Support") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.red)
                            Text("PDF Receipts")
                                .font(.headline)
                        }
                        Text("• Uploaded in original PDF format\n• Preserves vector quality\n• Maintains text layer\n• Supports multi-page")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.blue)
                            Text("Image Receipts")
                                .font(.headline)
                        }
                        Text("• Converted to JPEG (90% quality)\n• Supports JPG, PNG, HEIC, etc.\n• Optimized for storage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Testing") {
                NavigationLink {
                    ExampleReceiptUploadView()
                } label: {
                    Label("Test Upload", systemImage: "arrow.up.circle")
                }
            }
        }
        .navigationTitle("Receipt Upload Info")
    }
}

// MARK: - Example: Preview

#Preview("Upload View") {
    NavigationStack {
        ExampleReceiptUploadView()
    }
}

#Preview("Upload Status") {
    NavigationStack {
        UploadStatusView()
    }
}

