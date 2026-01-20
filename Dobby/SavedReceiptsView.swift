//
//  SavedReceiptsView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

struct SavedReceiptsView: View {
    @State private var receipts: [URL] = []
    @State private var selectedReceipt: URL?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false  // Changed to false since we're not loading anything
    
    var body: some View {
        ZStack {
            Color(white: 0.05)
                .ignoresSafeArea()
            
            deprecatedFeatureMessage
        }
        .navigationTitle("Saved Receipts")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Deprecated Feature Message
    private var deprecatedFeatureMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("All Receipts Are Cloud-Based")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Receipts are now automatically uploaded to the cloud when you scan them. Local storage has been disabled.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Automatic cloud backup")
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Access from any device")
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Automatic processing")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SavedReceiptsView()
    }
}

