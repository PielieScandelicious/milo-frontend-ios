//
//  BankSelectionView.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI
import AuthenticationServices

struct BankSelectionView: View {
    @ObservedObject var viewModel: BankingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var webAuthSession: ASWebAuthenticationSession?
    @State private var showingSafariSheet = false
    @State private var authURL: URL?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Country Header
                countryHeader

                // Search Bar
                searchBar

                // Bank List
                ScrollView {
                    if viewModel.banksState.isLoading {
                        loadingView
                    } else if let error = viewModel.banksState.errorMessage {
                        errorView(message: error)
                    } else if viewModel.filteredBanks.isEmpty {
                        emptyView
                    } else {
                        bankGrid
                    }
                }
            }
            .background(Color(white: 0.08))
            .navigationTitle("Select Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.closeBankSelection()
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
            .overlay {
                if viewModel.isConnecting {
                    connectingOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Country Header

    private var countryHeader: some View {
        Button {
            viewModel.closeBankSelection()
            viewModel.openCountryPicker()
        } label: {
            HStack {
                Text(viewModel.selectedCountry.flag)
                    .font(.system(size: 24))

                Text(viewModel.selectedCountry.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
            .padding()
            .background(Color(white: 0.12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.4))

            TextField("Search banks...", text: $viewModel.bankSearchQuery)
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !viewModel.bankSearchQuery.isEmpty {
                Button {
                    viewModel.bankSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding()
        .background(Color(white: 0.15))
    }

    // MARK: - Bank Grid

    private var bankGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.filteredBanks) { bank in
                BankCard(bank: bank) {
                    startBankConnection(bank)
                }
            }
        }
        .padding()
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text("Loading banks...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))

            Text("Failed to load banks")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.refreshBanks()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                    .cornerRadius(8)
            }
        }
        .padding()
        .padding(.top, 40)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.4))

            Text("No banks found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            if !viewModel.bankSearchQuery.isEmpty {
                Text("Try a different search term")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Connecting Overlay

    private var connectingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Connecting to bank...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text("You'll be redirected to your bank's login page")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(Color(white: 0.15))
            .cornerRadius(16)
        }
    }

    // MARK: - Bank Connection

    private func startBankConnection(_ bank: BankInfo) {
        Task {
            guard let url = await viewModel.startBankConnection(bank: bank) else {
                return
            }

            // Open in Safari for OAuth
            await MainActor.run {
                startWebAuthentication(url: url)
            }
        }
    }

    private func startWebAuthentication(url: URL) {
        // Use ASWebAuthenticationSession for secure OAuth flow
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "milo"
        ) { callbackURL, error in
            if let error = error {
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    // User cancelled
                    let result = BankingCallbackResult(
                        connectionId: nil,
                        status: .cancelled,
                        accountCount: 0,
                        errorMessage: nil
                    )
                    viewModel.handleConnectionCallback(result)
                } else {
                    let result = BankingCallbackResult(
                        connectionId: nil,
                        status: .error,
                        accountCount: 0,
                        errorMessage: error.localizedDescription
                    )
                    viewModel.handleConnectionCallback(result)
                }
                return
            }

            // Handle the callback URL - the deep link handler will process it
            if let callbackURL = callbackURL {
                // The URL will be handled by the app's onOpenURL handler
                // which will post a notification that the viewModel is listening to
                UIApplication.shared.open(callbackURL)
            }
        }

        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = WebAuthPresentationContext.shared

        self.webAuthSession = session
        session.start()
    }
}

// MARK: - Web Auth Presentation Context

class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

#Preview {
    BankSelectionView(viewModel: BankingViewModel())
}
