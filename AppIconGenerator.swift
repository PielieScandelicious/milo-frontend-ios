//
//  AppIconGenerator.swift
//  Dobby
//
//  App icon generator for Dobby - Financial tracking with AI
//

import SwiftUI

/// The official Dobby app icon
/// Features a minimal geometric design with sparkles representing the AI assistant
/// Perfect balance of modern iOS design and professional appearance
struct AppIconView: View {
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

// MARK: - Icon Export View with Instructions
struct AppIconExportView: View {
    @State private var selectedSize: IconSize = .original
    
    enum IconSize: String, CaseIterable {
        case original = "1024×1024 (App Store)"
        case large = "180×180 (iPhone Pro)"
        case standard = "120×120 (iPhone)"
        case ipad = "152×152 (iPad Pro)"
        case small = "76×76 (iPad)"
        
        var dimension: CGFloat {
            switch self {
            case .original: return 1024
            case .large: return 180
            case .standard: return 120
            case .ipad: return 152
            case .small: return 76
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Icon Preview
                VStack(spacing: 16) {
                    Text("Dobby App Icon")
                        .font(.largeTitle.bold())
                    
                    AppIconView()
                        .frame(width: selectedSize.dimension, height: selectedSize.dimension)
                        .clipShape(RoundedRectangle(cornerRadius: selectedSize.dimension * 0.2237))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    Picker("Size", selection: $selectedSize) {
                        ForEach(IconSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("📱 How to Export Your Icon")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            number: "1",
                            text: "Run this preview in Xcode Canvas"
                        )
                        InstructionRow(
                            number: "2",
                            text: "Select '1024×1024 (App Store)' above"
                        )
                        InstructionRow(
                            number: "3",
                            text: "Right-click the icon and save as image"
                        )
                        InstructionRow(
                            number: "4",
                            text: "Visit appicon.co and upload the 1024×1024 image"
                        )
                        InstructionRow(
                            number: "5",
                            text: "Download the generated AppIcon.appiconset"
                        )
                        InstructionRow(
                            number: "6",
                            text: "Drag it into your Assets.xcassets folder"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // Alternative: Manual Screenshot Method
                VStack(alignment: .leading, spacing: 16) {
                    Text("📸 Alternative: Screenshot Method")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            number: "1",
                            text: "Select '1024×1024 (App Store)' above"
                        )
                        InstructionRow(
                            number: "2",
                            text: "Take a screenshot (Cmd+Shift+4 on Mac)"
                        )
                        InstructionRow(
                            number: "3",
                            text: "Crop to exactly the icon (use Preview or similar)"
                        )
                        InstructionRow(
                            number: "4",
                            text: "Use appicon.co to generate all sizes"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // Quick Copy JSON
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚡️ Or Copy This Contents.json")
                        .font(.headline)
                    
                    Text("Create Assets.xcassets/AppIcon.appiconset/Contents.json")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(contentsJSON)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical, 30)
        }
    }
    
    private var contentsJSON: String {
        """
        {
          "images" : [
            {
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(.body, design: .rounded).bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
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
                )
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Previews
#Preview("App Icon") {
    AppIconView()
        .frame(width: 1024, height: 1024)
}

#Preview("Export & Instructions") {
    AppIconExportView()
}

