//
//  IconGeneratorView.swift
//  Dobby
//
//  Temporary view to generate and export app icon
//

import SwiftUI

struct IconGeneratorView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Dobby App Icon")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                // The actual icon at 1024x1024
                AppIconDesign()
                    .frame(width: 340, height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 76))
                    .shadow(color: .white.opacity(0.3), radius: 30, x: 0, y: 15)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("📸 To Export:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("1. Run this view on simulator\n2. Take a screenshot (Cmd+Shift+4)\n3. Crop just the icon (square)\n4. Go to appicon.co\n5. Upload and generate all sizes\n6. Add to Assets.xcassets")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
}

/// The actual app icon design
struct AppIconDesign: View {
    var body: some View {
        ZStack {
            // Solid color background - deep indigo
            Color(red: 0.25, green: 0.25, blue: 0.45)
            
            // Clean circular design
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.6, blue: 1.0),
                            Color(red: 0.6, green: 0.4, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 650, height: 650)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            
            // Sparkles icon centered
            Image(systemName: "sparkles")
                .font(.system(size: 420, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
        }
    }
}

#Preview {
    IconGeneratorView()
}
