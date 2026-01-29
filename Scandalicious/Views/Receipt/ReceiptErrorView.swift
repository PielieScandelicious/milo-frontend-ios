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
    case failed(message: String, canRetry: Bool, title: String = "Upload Failed")
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
            if case .failed(_, let canRetry, _) = status {
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
            return "Done!"
        case .failed(_, _, let title):
            return title
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
        case .failed(let message, _, _):
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
        title: String = "Upload Failed",
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
            status: .failed(message: message, canRetry: onRetry != nil, title: title),
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
    private var hasShownConfetti = false

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

    private let confettiView: UIKitConfettiView = {
        let view = UIKitConfettiView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Trigger confetti if initially presented with success status
        if case .success = currentStatus, !hasShownConfetti {
            hasShownConfetti = true

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            confettiView.isHidden = false
            confettiView.startConfetti()
        }
    }

    func updateStatus(_ newStatus: ReceiptStatusType) {
        currentStatus = newStatus

        // Trigger haptic feedback and confetti on success
        if case .success = newStatus, !hasShownConfetti {
            hasShownConfetti = true

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Show confetti after layout is complete
            confettiView.isHidden = false
            view.layoutIfNeeded()
            DispatchQueue.main.async { [weak self] in
                self?.confettiView.startConfetti()
            }
        } else if case .success = newStatus {
            // Already showed confetti, just show the view
            confettiView.isHidden = false
        } else {
            confettiView.isHidden = true
            hasShownConfetti = false // Reset for potential future success state
        }

        UIView.transition(with: containerView, duration: 0.3, options: .transitionCrossDissolve) {
            self.updateUI(for: newStatus)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        view.addSubview(containerView)
        containerView.addSubview(iconContainerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(retryButton)
        containerView.addSubview(dismissButton)

        // Add confetti view last (in front of everything)
        view.addSubview(confettiView)

        // Add activity indicator to icon container
        iconContainerView.addSubview(activityIndicator)

        // Confetti view constraints - full screen
        NSLayoutConstraint.activate([
            confettiView.topAnchor.constraint(equalTo: view.topAnchor),
            confettiView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            confettiView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            confettiView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
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
            titleLabel.text = "Done!"
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

        case .failed(let message, let canRetry, let title):
            titleLabel.text = title
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
        // Create animated checkmark
        let checkmarkView = AnimatedCheckmarkView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false

        iconContainerView.addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            checkmarkView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 60),
            checkmarkView.heightAnchor.constraint(equalToConstant: 60)
        ])

        // Start animation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            checkmarkView.animate()
        }
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

// MARK: - UIKit Confetti View

/// A UIKit-based confetti animation view that matches the SwiftUI CaptureSuccessOverlay confetti
class UIKitConfettiView: UIView {

    private let confettiColors: [UIColor] = [
        UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0),    // Green
        UIColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 1.0),   // Light green
        UIColor.systemYellow,
        UIColor.systemOrange,
        UIColor.systemPink,
        UIColor.systemPurple,
        UIColor.systemBlue,
        UIColor.systemCyan,
        UIColor.systemRed,
        UIColor.systemMint
    ]

    private var confettiLayers: [CALayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    func startConfetti() {
        // Remove any existing confetti
        confettiLayers.forEach { $0.removeFromSuperlayer() }
        confettiLayers.removeAll()

        // Use screen bounds as fallback if view bounds aren't ready
        let viewBounds = bounds.width > 0 ? bounds : UIScreen.main.bounds

        let totalPieces = 80
        let centerX = viewBounds.width / 2
        let centerY = viewBounds.height / 2

        for i in 0..<totalPieces {
            // Calculate burst angle - distribute evenly with small variation
            let baseAngle = (Double(i) / Double(totalPieces)) * 360.0
            let angleVariation = Double.random(in: -8...8)
            let angle = (baseAngle + angleVariation) * .pi / 180

            // Random distance for depth variation
            let distance = CGFloat.random(in: 150...400)

            // Calculate final position
            let burstX = CGFloat(cos(angle)) * distance
            let burstY = CGFloat(sin(angle)) * distance
            let gravityOffset = CGFloat.random(in: 100...300)
            let finalY = burstY + gravityOffset

            // Create confetti piece
            let size = CGFloat.random(in: 6...16)
            let shapeType = Int.random(in: 0...3)
            let pieceLayer = createConfettiPiece(size: size, shapeType: shapeType, colorIndex: i % confettiColors.count)
            pieceLayer.position = CGPoint(x: centerX, y: centerY)
            pieceLayer.opacity = 0
            layer.addSublayer(pieceLayer)
            confettiLayers.append(pieceLayer)

            // Animation parameters
            let wave = i % 3
            let waveDelay = Double(wave) * 0.05 + Double.random(in: 0...0.1)
            let animationDuration = Double.random(in: 0.8...1.4)
            let finalRotation = Double.random(in: 540...1080) * .pi / 180

            // Pop in animation
            let scaleIn = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleIn.values = [0, 1.1, 1.0]
            scaleIn.keyTimes = [0, 0.6, 1.0]
            scaleIn.duration = 0.2
            scaleIn.beginTime = CACurrentMediaTime() + waveDelay
            scaleIn.fillMode = .forwards
            scaleIn.isRemovedOnCompletion = false

            // Fade in
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 0.1
            fadeIn.beginTime = CACurrentMediaTime() + waveDelay
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false

            // Position animation (burst outward with gravity)
            let positionAnimation = CABasicAnimation(keyPath: "position")
            positionAnimation.fromValue = CGPoint(x: centerX, y: centerY)
            positionAnimation.toValue = CGPoint(x: centerX + burstX, y: centerY + finalY)
            positionAnimation.duration = animationDuration
            positionAnimation.beginTime = CACurrentMediaTime() + waveDelay
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            positionAnimation.fillMode = .forwards
            positionAnimation.isRemovedOnCompletion = false

            // Rotation animation
            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotationAnimation.fromValue = 0
            rotationAnimation.toValue = finalRotation
            rotationAnimation.duration = animationDuration
            rotationAnimation.beginTime = CACurrentMediaTime() + waveDelay
            rotationAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            rotationAnimation.fillMode = .forwards
            rotationAnimation.isRemovedOnCompletion = false

            // Fade out near the end
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = 0.4
            fadeOut.beginTime = CACurrentMediaTime() + waveDelay + animationDuration * 0.7
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false

            // Apply animations
            pieceLayer.add(scaleIn, forKey: "scaleIn")
            pieceLayer.add(fadeIn, forKey: "fadeIn")
            pieceLayer.add(positionAnimation, forKey: "position")
            pieceLayer.add(rotationAnimation, forKey: "rotation")
            pieceLayer.add(fadeOut, forKey: "fadeOut")
        }

        // Clean up after animations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.confettiLayers.forEach { $0.removeFromSuperlayer() }
            self?.confettiLayers.removeAll()
        }
    }

    private func createConfettiPiece(size: CGFloat, shapeType: Int, colorIndex: Int) -> CALayer {
        let layer = CAShapeLayer()
        layer.fillColor = confettiColors[colorIndex].cgColor

        let path: UIBezierPath

        switch shapeType {
        case 0: // Circle
            path = UIBezierPath(ovalIn: CGRect(x: -size/2, y: -size/2, width: size, height: size))
        case 1: // Rectangle
            path = UIBezierPath(rect: CGRect(x: -size/2, y: -size*0.3, width: size, height: size * 0.6))
        case 2: // Triangle
            path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: -size/2))
            path.addLine(to: CGPoint(x: size/2, y: size/2))
            path.addLine(to: CGPoint(x: -size/2, y: size/2))
            path.close()
        default: // Star
            path = createStarPath(size: size * 1.2)
        }

        layer.path = path.cgPath
        return layer
    }

    private func createStarPath(size: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let outerRadius = size / 2
        let innerRadius = outerRadius * 0.4
        let points = 5

        for i in 0..<(points * 2) {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = (Double(i) * .pi / Double(points)) - (.pi / 2)
            let point = CGPoint(
                x: CGFloat(cos(angle)) * radius,
                y: CGFloat(sin(angle)) * radius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        return path
    }
}

// MARK: - Animated Checkmark View

/// A custom view that draws an animated green checkmark with a circle
class AnimatedCheckmarkView: UIView {

    private let circleLayer = CAShapeLayer()
    private let checkmarkLayer = CAShapeLayer()

    private let successGreen = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        backgroundColor = .clear

        // Circle layer
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2),
            radius: bounds.width / 2 - 2,
            startAngle: -CGFloat.pi / 2,
            endAngle: 3 * CGFloat.pi / 2,
            clockwise: true
        )

        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = successGreen.cgColor
        circleLayer.lineWidth = 3
        circleLayer.lineCap = .round
        circleLayer.strokeEnd = 0
        layer.addSublayer(circleLayer)

        // Checkmark layer
        let checkmarkPath = UIBezierPath()
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2

        // Draw checkmark path
        checkmarkPath.move(to: CGPoint(x: centerX - 12, y: centerY + 2))
        checkmarkPath.addLine(to: CGPoint(x: centerX - 3, y: centerY + 11))
        checkmarkPath.addLine(to: CGPoint(x: centerX + 14, y: centerY - 10))

        checkmarkLayer.path = checkmarkPath.cgPath
        checkmarkLayer.fillColor = UIColor.clear.cgColor
        checkmarkLayer.strokeColor = successGreen.cgColor
        checkmarkLayer.lineWidth = 4
        checkmarkLayer.lineCap = .round
        checkmarkLayer.lineJoin = .round
        checkmarkLayer.strokeEnd = 0
        layer.addSublayer(checkmarkLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Update circle path for new bounds
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2),
            radius: bounds.width / 2 - 2,
            startAngle: -CGFloat.pi / 2,
            endAngle: 3 * CGFloat.pi / 2,
            clockwise: true
        )
        circleLayer.path = circlePath.cgPath

        // Update checkmark path for new bounds
        let checkmarkPath = UIBezierPath()
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2

        checkmarkPath.move(to: CGPoint(x: centerX - 12, y: centerY + 2))
        checkmarkPath.addLine(to: CGPoint(x: centerX - 3, y: centerY + 11))
        checkmarkPath.addLine(to: CGPoint(x: centerX + 14, y: centerY - 10))

        checkmarkLayer.path = checkmarkPath.cgPath
    }

    func animate() {
        // Animate circle
        let circleAnimation = CABasicAnimation(keyPath: "strokeEnd")
        circleAnimation.fromValue = 0
        circleAnimation.toValue = 1
        circleAnimation.duration = 0.4
        circleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        circleAnimation.fillMode = .forwards
        circleAnimation.isRemovedOnCompletion = false
        circleLayer.add(circleAnimation, forKey: "circleAnimation")

        // Animate checkmark with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }

            let checkmarkAnimation = CABasicAnimation(keyPath: "strokeEnd")
            checkmarkAnimation.fromValue = 0
            checkmarkAnimation.toValue = 1
            checkmarkAnimation.duration = 0.3
            checkmarkAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            checkmarkAnimation.fillMode = .forwards
            checkmarkAnimation.isRemovedOnCompletion = false
            self.checkmarkLayer.add(checkmarkAnimation, forKey: "checkmarkAnimation")

            // Add a subtle scale bounce
            let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnimation.values = [1.0, 1.15, 1.0]
            scaleAnimation.keyTimes = [0, 0.5, 1.0]
            scaleAnimation.duration = 0.3
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.layer.add(scaleAnimation, forKey: "scaleAnimation")
        }
    }
}

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

