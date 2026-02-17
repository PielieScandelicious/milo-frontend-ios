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
                                Text(L("try_again"))
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
                        Text(canRetry ? L("cancel") : L("dismiss"))
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
            return L("uploading_receipt")
        case .processing:
            return L("processing")
        case .success:
            return L("done_excl")
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
        title: String = L("upload_failed"),
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
        title: String = L("processing_failed"),
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
        button.setTitle(L("try_again"), for: .normal)
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
        button.setTitle(L("dismiss"), for: .normal)
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
            titleLabel.text = L("uploading_receipt")
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
            titleLabel.text = L("processing")
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
            titleLabel.text = L("done_excl")
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
            dismissButton.setTitle(canRetry ? L("cancel") : L("dismiss"), for: .normal)

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

// MARK: - UIKit Premium Success Animation View

/// A UIKit-based premium success animation that matches the SwiftUI PremiumSuccessAnimation
class UIKitConfettiView: UIView {

    private let accentColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
    private var animationLayers: [CALayer] = []
    private var glowLayer: CAGradientLayer?

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
        // Remove any existing animation layers
        animationLayers.forEach { $0.removeFromSuperlayer() }
        animationLayers.removeAll()
        glowLayer?.removeFromSuperlayer()

        // Use screen bounds as fallback if view bounds aren't ready
        let viewBounds = bounds.width > 0 ? bounds : UIScreen.main.bounds
        let centerX = viewBounds.width / 2
        let centerY = viewBounds.height / 2

        // Create ambient glow
        createAmbientGlow(centerX: centerX, centerY: centerY)

        // Create expanding rings
        createExpandingRings(centerX: centerX, centerY: centerY)

        // Create shimmer particles
        createShimmerParticles(centerX: centerX, centerY: centerY)

        // Clean up after animations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.animationLayers.forEach { $0.removeFromSuperlayer() }
            self?.animationLayers.removeAll()
            self?.glowLayer?.removeFromSuperlayer()
        }
    }

    private func createAmbientGlow(centerX: CGFloat, centerY: CGFloat) {
        let glowSize: CGFloat = 400

        let gradientLayer = CAGradientLayer()
        gradientLayer.type = .radial
        gradientLayer.colors = [
            accentColor.withAlphaComponent(0.3).cgColor,
            accentColor.withAlphaComponent(0.1).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(
            x: centerX - glowSize / 2,
            y: centerY - glowSize / 2,
            width: glowSize,
            height: glowSize
        )
        gradientLayer.opacity = 0
        gradientLayer.transform = CATransform3DMakeScale(0.8, 0.8, 1)

        layer.addSublayer(gradientLayer)
        glowLayer = gradientLayer

        // Animate glow in
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.6
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false

        let scaleUp = CABasicAnimation(keyPath: "transform.scale")
        scaleUp.fromValue = 0.8
        scaleUp.toValue = 1.2
        scaleUp.duration = 0.6
        scaleUp.timingFunction = CAMediaTimingFunction(name: .easeOut)
        scaleUp.fillMode = .forwards
        scaleUp.isRemovedOnCompletion = false

        gradientLayer.add(fadeIn, forKey: "fadeIn")
        gradientLayer.add(scaleUp, forKey: "scaleUp")

        // Fade to subtle glow
        let fadeToSubtle = CABasicAnimation(keyPath: "opacity")
        fadeToSubtle.fromValue = 1
        fadeToSubtle.toValue = 0.4
        fadeToSubtle.duration = 1.5
        fadeToSubtle.beginTime = CACurrentMediaTime() + 0.6
        fadeToSubtle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fadeToSubtle.fillMode = .forwards
        fadeToSubtle.isRemovedOnCompletion = false

        gradientLayer.add(fadeToSubtle, forKey: "fadeToSubtle")
    }

    private func createExpandingRings(centerX: CGFloat, centerY: CGFloat) {
        for i in 0..<3 {
            let delay = Double(i) * 0.15
            let maxScale = 2.5 + Double(i) * 0.5
            let duration = 1.0 + Double(i) * 0.2
            let strokeWidth = 2.0 - Double(i) * 0.5

            let ringLayer = CAShapeLayer()
            let ringPath = UIBezierPath(
                arcCenter: CGPoint(x: 50, y: 50),
                radius: 50,
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: true
            )
            ringLayer.path = ringPath.cgPath
            ringLayer.fillColor = UIColor.clear.cgColor
            ringLayer.strokeColor = accentColor.cgColor
            ringLayer.lineWidth = CGFloat(strokeWidth)
            ringLayer.frame = CGRect(x: centerX - 50, y: centerY - 50, width: 100, height: 100)
            ringLayer.opacity = 0
            ringLayer.transform = CATransform3DMakeScale(0.3, 0.3, 1)

            // Add gradient effect to ring
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = ringLayer.bounds
            gradientLayer.colors = [
                accentColor.withAlphaComponent(0.8).cgColor,
                accentColor.withAlphaComponent(0.4).cgColor,
                accentColor.withAlphaComponent(0.1).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
            gradientLayer.mask = ringLayer

            let containerLayer = CALayer()
            containerLayer.frame = CGRect(x: centerX - 50, y: centerY - 50, width: 100, height: 100)
            containerLayer.addSublayer(gradientLayer)
            containerLayer.opacity = 0
            containerLayer.transform = CATransform3DMakeScale(0.3, 0.3, 1)

            layer.addSublayer(containerLayer)
            animationLayers.append(containerLayer)

            // Fade in
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 0.8
            fadeIn.duration = 0.3
            fadeIn.beginTime = CACurrentMediaTime() + delay
            fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false

            // Scale up
            let scaleUp = CABasicAnimation(keyPath: "transform.scale")
            scaleUp.fromValue = 0.3
            scaleUp.toValue = maxScale
            scaleUp.duration = duration
            scaleUp.beginTime = CACurrentMediaTime() + delay + 0.1
            scaleUp.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scaleUp.fillMode = .forwards
            scaleUp.isRemovedOnCompletion = false

            // Fade out
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 0.8
            fadeOut.toValue = 0
            fadeOut.duration = 0.5
            fadeOut.beginTime = CACurrentMediaTime() + delay + duration * 0.5
            fadeOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false

            containerLayer.add(fadeIn, forKey: "fadeIn")
            containerLayer.add(scaleUp, forKey: "scaleUp")
            containerLayer.add(fadeOut, forKey: "fadeOut")
        }
    }

    private func createShimmerParticles(centerX: CGFloat, centerY: CGFloat) {
        let particleCount = 24

        for i in 0..<particleCount {
            let angle = (Double(i) / Double(particleCount)) * 2 * .pi
            let distance = CGFloat.random(in: 80...180)
            let size = CGFloat.random(in: 2...5)
            let wave = i % 3
            let delay = Double(wave) * 0.1 + Double.random(in: 0...0.2)
            let duration = Double.random(in: 1.2...1.8)

            // Create particle with radial gradient
            let particleLayer = CAGradientLayer()
            particleLayer.type = .radial
            particleLayer.colors = [
                UIColor.white.cgColor,
                accentColor.withAlphaComponent(0.8).cgColor,
                UIColor.clear.cgColor
            ]
            particleLayer.locations = [0, 0.3, 1]
            particleLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            particleLayer.endPoint = CGPoint(x: 1, y: 1)
            particleLayer.frame = CGRect(x: 0, y: 0, width: size * 2, height: size * 2)
            particleLayer.cornerRadius = size

            // Starting position (slightly inward)
            let startDistance = distance * 0.3
            let startX = centerX + CGFloat(cos(angle)) * startDistance - size
            let startY = centerY + CGFloat(sin(angle)) * startDistance - size
            particleLayer.position = CGPoint(x: startX + size, y: startY + size)
            particleLayer.opacity = 0
            particleLayer.transform = CATransform3DMakeScale(0, 0, 1)

            layer.addSublayer(particleLayer)
            animationLayers.append(particleLayer)

            // Target position
            let targetX = centerX + CGFloat(cos(angle)) * distance
            let targetY = centerY + CGFloat(sin(angle)) * distance

            // Fade in and scale up
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 0.3
            fadeIn.beginTime = CACurrentMediaTime() + delay
            fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false

            let scaleIn = CABasicAnimation(keyPath: "transform.scale")
            scaleIn.fromValue = 0
            scaleIn.toValue = 1
            scaleIn.duration = 0.3
            scaleIn.beginTime = CACurrentMediaTime() + delay
            scaleIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scaleIn.fillMode = .forwards
            scaleIn.isRemovedOnCompletion = false

            // Float outward
            let positionAnimation = CABasicAnimation(keyPath: "position")
            positionAnimation.fromValue = CGPoint(x: startX + size, y: startY + size)
            positionAnimation.toValue = CGPoint(x: targetX, y: targetY)
            positionAnimation.duration = duration
            positionAnimation.beginTime = CACurrentMediaTime() + delay
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            positionAnimation.fillMode = .forwards
            positionAnimation.isRemovedOnCompletion = false

            // Fade out with blur effect (scale down)
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = 0.6
            fadeOut.beginTime = CACurrentMediaTime() + delay + duration * 0.5
            fadeOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false

            let scaleOut = CABasicAnimation(keyPath: "transform.scale")
            scaleOut.fromValue = 1
            scaleOut.toValue = 0.5
            scaleOut.duration = 0.6
            scaleOut.beginTime = CACurrentMediaTime() + delay + duration * 0.5
            scaleOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
            scaleOut.fillMode = .forwards
            scaleOut.isRemovedOnCompletion = false

            particleLayer.add(fadeIn, forKey: "fadeIn")
            particleLayer.add(scaleIn, forKey: "scaleIn")
            particleLayer.add(positionAnimation, forKey: "position")
            particleLayer.add(fadeOut, forKey: "fadeOut")
            particleLayer.add(scaleOut, forKey: "scaleOut")
        }
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
            },
            onDismiss: {
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
            },
            onDismiss: {
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
        }
    )
}

