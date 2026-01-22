//
//  ReceiptErrorView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI

// MARK: - Receipt Status

enum ReceiptStatusType {
    case uploading(subtitle: String)
    case processing(subtitle: String)
    case success(message: String)
    case failed(message: String, canRetry: Bool)
}

/// A unified view for displaying all receipt upload states in a consistent box
struct ReceiptStatusView: View {
    let status: ReceiptStatusType
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon/Indicator
            statusIcon
            
            // Title
            Text(statusTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            // Subtitle/Message (only show if not empty)
            if let subtitle = statusSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            // Action Buttons (only for failed state)
            if case .failed(_, let canRetry) = status {
                VStack(spacing: 12) {
                    if canRetry, let onRetry = onRetry {
                        Button {
                            onRetry()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Try Again")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Text(canRetry ? "Cancel" : "Dismiss")
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 32)
        .frame(minWidth: 280, maxWidth: 400)
        .frame(minHeight: processingOrSuccessMinHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .uploading, .processing:
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .frame(height: 60)
            
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
                .frame(height: 60)
            
        case .failed:
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.3, blue: 0.3),
                                Color(red: 0.9, green: 0.2, blue: 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.5), radius: 15, y: 6)
                
                Image(systemName: "xmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(height: 60)
        }
    }
    
    private var statusTitle: String {
        switch status {
        case .uploading:
            return "Uploading Receipt..."
        case .processing:
            return "Processing..."
        case .success:
            return "Success!"
        case .failed:
            return "Upload Failed"
        }
    }
    
    private var statusSubtitle: String? {
        switch status {
        case .uploading(let subtitle):
            return subtitle
        case .processing(let subtitle):
            return subtitle
        case .success(let message):
            return message
        case .failed(let message, _):
            return message
        }
    }

    /// Minimum height for processing/success states to ensure smooth transitions
    private var processingOrSuccessMinHeight: CGFloat? {
        switch status {
        case .uploading, .processing, .success:
            // Consistent min height for states without buttons
            return 172
        case .failed:
            // No min height for failed state (has buttons)
            return nil
        }
    }
}

// MARK: - Legacy Error View (for compatibility)

/// Legacy error view - kept for backward compatibility
/// Use ReceiptStatusView with .failed status instead
struct ReceiptErrorView: View {
    let title: String
    let message: String
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    init(
        title: String = "Processing Failed!",
        message: String,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ReceiptStatusView(
            status: .failed(message: message, canRetry: onRetry != nil),
            onRetry: onRetry,
            onDismiss: onDismiss
        )
    }
}

/// A button style that provides a subtle bounce effect on press
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Overlay Modifier for Easy Use

extension View {
    /// Shows a unified receipt status overlay
    func receiptStatusOverlay(
        status: Binding<ReceiptStatusType?>,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            
            if let currentStatus = status.wrappedValue {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ReceiptStatusView(
                    status: currentStatus,
                    onRetry: onRetry,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            status.wrappedValue = nil
                        }
                        onDismiss()
                    }
                )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: status.wrappedValue != nil)
    }
    
    /// Legacy error overlay - kept for backward compatibility
    func receiptErrorOverlay(
        isPresented: Binding<Bool>,
        title: String = "Processing Failed!",
        message: String,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ReceiptErrorView(
                    title: title,
                    message: message,
                    onRetry: onRetry,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isPresented.wrappedValue = false
                        }
                    }
                )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented.wrappedValue)
    }
}

// MARK: - UIKit Version for Share Extension

/// UIKit version of the unified status view for use in Share Extension
class ReceiptStatusViewController: UIViewController {
    private var currentStatus: ReceiptStatusType
    private let onRetry: (() -> Void)?
    private let onDismiss: () -> Void
    
    // Constraints that need to be updated based on content visibility
    private var containerBottomConstraint: NSLayoutConstraint?
    private var containerMinHeightConstraint: NSLayoutConstraint?
    private var messageLabelHeightConstraint: NSLayoutConstraint?
    
    // UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.shadowRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()
    
    private let iconContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dismiss", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    init(
        status: ReceiptStatusType,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.currentStatus = status
        self.onRetry = onRetry
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        updateUI(for: currentStatus)
    }
    
    func updateStatus(_ newStatus: ReceiptStatusType) {
        currentStatus = newStatus

        // Trigger haptic feedback immediately on success
        if case .success = newStatus {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        UIView.transition(with: containerView, duration: 0.3, options: .transitionCrossDissolve) {
            self.updateUI(for: newStatus)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        view.addSubview(containerView)
        containerView.addSubview(iconContainerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(retryButton)
        containerView.addSubview(dismissButton)
        
        // Add activity indicator to icon container
        iconContainerView.addSubview(activityIndicator)
        
        // Create height constraint for message label (can be set to 0 when hidden)
        messageLabelHeightConstraint = messageLabel.heightAnchor.constraint(equalToConstant: 0)
        messageLabelHeightConstraint?.priority = .defaultHigh
        
        // Set a fixed width for consistent sizing during state transitions
        let containerWidth = min(280, UIScreen.main.bounds.width - 64)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: containerWidth),
            
            iconContainerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            iconContainerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 60),
            iconContainerView.heightAnchor.constraint(equalToConstant: 60),
            
            activityIndicator.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainerView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            retryButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            retryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            retryButton.heightAnchor.constraint(equalToConstant: 50),
            
            dismissButton.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 12),
            dismissButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            dismissButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            dismissButton.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        // Set up min height constraint for consistent sizing (used during processing/success states)
        // Height for: 32 (top padding) + 60 (icon) + 20 (spacing) + ~28 (title) + 32 (bottom padding) = ~172
        containerMinHeightConstraint = containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 172)
        containerMinHeightConstraint?.priority = .defaultHigh
    }
    
    private func updateUI(for status: ReceiptStatusType) {
        // Clear previous icon
        iconContainerView.subviews.forEach { view in
            if view != activityIndicator {
                view.removeFromSuperview()
            }
        }

        // Deactivate previous bottom constraint
        containerBottomConstraint?.isActive = false

        switch status {
        case .uploading(let subtitle):
            titleLabel.text = "Uploading Receipt..."
            messageLabel.text = subtitle
            messageLabel.isHidden = subtitle.isEmpty
            messageLabelHeightConstraint?.isActive = subtitle.isEmpty
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false
            retryButton.isHidden = true
            dismissButton.isHidden = true

            // Enable min height for consistent sizing during transitions
            containerMinHeightConstraint?.isActive = true

            // Set bottom constraint from title or message label (no buttons)
            if subtitle.isEmpty {
                containerBottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
            } else {
                containerBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
            }

        case .processing(let subtitle):
            titleLabel.text = "Processing..."
            messageLabel.text = subtitle
            messageLabel.isHidden = subtitle.isEmpty
            messageLabelHeightConstraint?.isActive = subtitle.isEmpty
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false
            retryButton.isHidden = true
            dismissButton.isHidden = true

            // Enable min height for consistent sizing during transitions
            containerMinHeightConstraint?.isActive = true

            // Set bottom constraint from title or message label (no buttons)
            if subtitle.isEmpty {
                containerBottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
            } else {
                containerBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
            }

        case .success(let message):
            titleLabel.text = "Success!"
            messageLabel.text = message
            messageLabel.isHidden = message.isEmpty
            messageLabelHeightConstraint?.isActive = message.isEmpty
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
            setupSuccessIcon()
            retryButton.isHidden = true
            dismissButton.isHidden = true

            // Enable min height for consistent sizing during transitions
            containerMinHeightConstraint?.isActive = true

            // Set bottom constraint from title or message label (no buttons)
            if message.isEmpty {
                containerBottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
            } else {
                containerBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
            }

        case .failed(let message, let canRetry):
            titleLabel.text = "Upload Failed"
            messageLabel.text = message
            messageLabel.isHidden = message.isEmpty
            messageLabelHeightConstraint?.isActive = message.isEmpty
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
            setupErrorIcon()
            retryButton.isHidden = !canRetry || onRetry == nil
            dismissButton.isHidden = false
            dismissButton.setTitle(canRetry ? "Cancel" : "Dismiss", for: .normal)

            // Disable min height for failed state (has buttons, needs more space)
            containerMinHeightConstraint?.isActive = false

            // Set bottom constraint from dismiss button (buttons are visible)
            containerBottomConstraint = dismissButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        }

        // Activate the new bottom constraint
        containerBottomConstraint?.isActive = true
    }
    
    private func setupSuccessIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
        let image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        iconContainerView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupErrorIcon() {
        // Create gradient circle
        let circleLayer = CAGradientLayer()
        circleLayer.colors = [
            UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0).cgColor,
            UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
        ]
        circleLayer.startPoint = CGPoint(x: 0, y: 0)
        circleLayer.endPoint = CGPoint(x: 1, y: 1)
        circleLayer.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        circleLayer.cornerRadius = 30
        
        iconContainerView.layer.addSublayer(circleLayer)
        
        // Add X mark
        let xConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        let xImage = UIImage(systemName: "xmark", withConfiguration: xConfig)
        let xImageView = UIImageView(image: xImage)
        xImageView.tintColor = .white
        xImageView.contentMode = .scaleAspectFit
        xImageView.translatesAutoresizingMaskIntoConstraints = false
        
        iconContainerView.addSubview(xImageView)
        
        NSLayoutConstraint.activate([
            xImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            xImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            xImageView.widthAnchor.constraint(equalToConstant: 30),
            xImageView.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupActions() {
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }
    
    @objc private func retryTapped() {
        onRetry?()
    }
    
    @objc private func dismissTapped() {
        onDismiss()
    }
}

/// Legacy error view controller - kept for backward compatibility
typealias ReceiptErrorViewController = ReceiptStatusViewController

// MARK: - Preview

#Preview("Uploading") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptStatusView(
            status: .uploading(subtitle: "Sending to Claude Vision API"),
            onRetry: nil,
            onDismiss: {}
        )
    }
}

#Preview("Processing") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptStatusView(
            status: .processing(subtitle: "Extracting items and prices"),
            onRetry: nil,
            onDismiss: {}
        )
    }
}

#Preview("Success") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptStatusView(
            status: .success(message: "Receipt uploaded successfully!"),
            onRetry: nil,
            onDismiss: {}
        )
    }
}

#Preview("Failed with Retry") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptStatusView(
            status: .failed(
                message: "Please check your internet connection and try again.",
                canRetry: true
            ),
            onRetry: {
                print("Retry tapped")
            },
            onDismiss: {}
        )
    }
}

#Preview("Failed without Retry") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptStatusView(
            status: .failed(
                message: "Unsupported file type.",
                canRetry: false
            ),
            onRetry: nil,
            onDismiss: {}
        )
    }
}


#Preview("Error with Retry") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptErrorView(
            title: "Processing Failed!",
            message: "Failed to upload receipt to server. Please check your internet connection and try again.",
            onRetry: {
                print("Retry tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
}

#Preview("Error without Retry") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptErrorView(
            title: "Processing Failed!",
            message: "Receipt quality too low for accurate processing. Please ensure good lighting and try again.",
            onRetry: nil,
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
}
#Preview("Quality Error with Details") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        ReceiptErrorView(
            title: "Quality Check Failed",
            message: """
            Receipt quality too low for accurate processing.
            
            Issues detected:
            • Image is too blurry
            • Poor lighting conditions
            
            Quality Score: 45%
            Minimum Required: 60%
            
            Tips:
            • Ensure good lighting
            • Hold device steady
            • Capture entire receipt
            """,
            onRetry: {
                print("Retry tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
}

#Preview("Overlay Style") {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()
        
        VStack {
            Text("Main Content")
                .font(.largeTitle)
                .foregroundStyle(.white)
        }
    }
    .receiptErrorOverlay(
        isPresented: .constant(true),
        message: "Failed to upload receipt. Please check your internet connection.",
        onRetry: {
            print("Retry tapped")
        }
    )
}

