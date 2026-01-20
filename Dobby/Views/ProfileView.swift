//
//  ProfileView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text("User")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Email")
                    Spacer()
                    Text("user@example.com")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Settings") {
                Toggle("Notifications", isOn: .constant(true))
                Toggle("Dark Mode", isOn: .constant(false))
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
