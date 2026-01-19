//
//  ReceiptScanView.swift (TEMPORARY FIX VERSION)
//  Dobby
//
//  This version has a button to open camera instead of auto-opening
//  Use this while we debug the permission issue
//

import SwiftUI
import PhotosUI

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var importResult: ReceiptImportResult?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Clean background
            Color(white: 0.05)
                .ignoresSafeArea()
            
            // Processing state
            if isProcessing {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    
                    Text("Processing Receipt...")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Extracting text and categorizing items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Placeholder state with manual button
                VStack(spacing: 24) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 70))
                        .foregroundStyle(.white)
                    
                    Text("Ready to Scan")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    Text("Take a photo of your receipt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // MANUAL CAMERA BUTTON
                    Button {
                        showCamera = true
                    } label: {
                        Label("Open Camera", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(.blue.gradient)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }
        .sheet(item: $importResult) { result in
            ReceiptReviewView(
                result: result,
                onSave: { transactions in
                    transactionManager.addTransactions(transactions)
                    importResult = nil
                },
                onCancel: {
                    importResult = nil
                }
            )
        }
        .alert("Error Processing Receipt", isPresented: $showError) {
            Button("OK") {
                selectedImage = nil
            }
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
        // REMOVED AUTO-OPEN FOR DEBUGGING
        // .onAppear {
        //     showCamera = true
        // }
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
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        
        // Clean camera UI
        picker.showsCameraControls = true
        picker.allowsEditing = false
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
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

#Preview("Scan View") {
    NavigationStack {
        ReceiptScanView()
            .environmentObject(TransactionManager())
    }
}
