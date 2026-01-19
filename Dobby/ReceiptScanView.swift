//
//  ReceiptScanView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

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
            Color.black.ignoresSafeArea()
            
            if isProcessing {
                processingView
            } else if selectedImage == nil {
                placeholderView
            }
        }
        .onAppear {
            showCamera = true
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                processReceipt(image: image)
            }
        }
        .sheet(item: $importResult) { result in
            ReceiptReviewView(
                result: result,
                onSave: { transaction in
                    transactionManager.addTransaction(transaction)
                    selectedImage = nil
                    importResult = nil
                },
                onCancel: {
                    selectedImage = nil
                    importResult = nil
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                selectedImage = nil
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Failed to process receipt")
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("Ready to Scan")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap this tab to open camera")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Processing Receipt...")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Extracting transaction details")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func processReceipt(image: UIImage) {
        isProcessing = true
        
        Task {
            do {
                // Simulate OCR processing - replace with actual implementation
                try await Task.sleep(for: .seconds(1.5))
                
                // Create a result with extracted data
                let result = ReceiptImportResult(
                    storeName: "Store Name",
                    category: "General",
                    itemName: "Item",
                    amount: 0.0,
                    date: Date(),
                    quantity: 1,
                    paymentMethod: "Credit Card",
                    image: image
                )
                
                await MainActor.run {
                    isProcessing = false
                    importResult = result
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ReceiptImportResult: Identifiable {
    let id = UUID()
    let storeName: String
    let category: String
    let itemName: String
    let amount: Double
    let date: Date
    let quantity: Int
    let paymentMethod: String
    let image: UIImage?
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.showsCameraControls = true
        picker.delegate = context.coordinator
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

// MARK: - Receipt Review View

struct ReceiptReviewView: View {
    let result: ReceiptImportResult
    let onSave: (Transaction) -> Void
    let onCancel: () -> Void
    
    @State private var storeName: String
    @State private var category: String
    @State private var itemName: String
    @State private var amount: Double
    @State private var date: Date
    @State private var quantity: Int
    @State private var paymentMethod: String
    
    init(result: ReceiptImportResult, onSave: @escaping (Transaction) -> Void, onCancel: @escaping () -> Void) {
        self.result = result
        self.onSave = onSave
        self.onCancel = onCancel
        _storeName = State(initialValue: result.storeName)
        _category = State(initialValue: result.category)
        _itemName = State(initialValue: result.itemName)
        _amount = State(initialValue: result.amount)
        _date = State(initialValue: result.date)
        _quantity = State(initialValue: result.quantity)
        _paymentMethod = State(initialValue: result.paymentMethod)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let image = result.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Section("Transaction Details") {
                    TextField("Store Name", text: $storeName)
                    
                    TextField("Category", text: $category)
                    
                    TextField("Item Name", text: $itemName)
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", value: $amount, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                    
                    Picker("Payment Method", selection: $paymentMethod) {
                        Text("Credit Card").tag("Credit Card")
                        Text("Debit Card").tag("Debit Card")
                        Text("Cash").tag("Cash")
                    }
                }
            }
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let transaction = Transaction(
                            id: UUID(),
                            storeName: storeName,
                            category: category,
                            itemName: itemName,
                            amount: amount,
                            date: date,
                            quantity: quantity,
                            paymentMethod: paymentMethod
                        )
                        onSave(transaction)
                    }
                    .disabled(storeName.isEmpty || category.isEmpty || itemName.isEmpty || amount <= 0)
                }
            }
        }
    }
}

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
}
