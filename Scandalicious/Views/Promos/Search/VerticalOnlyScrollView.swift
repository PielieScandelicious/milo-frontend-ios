//
//  VerticalOnlyScrollView.swift
//  Scandalicious
//
//  UIKit-backed scroll wrapper used by the focused-search overlay.
//  SwiftUI's ScrollView leaks diagonal/circular pan into sibling gesture
//  recognizers when nested deep in a ZStack/TabView tree; pinning the
//  hosted content's width to the scroll view's content layout guide and
//  disabling horizontal bounce makes vertical motion the only possible
//  translation.
//

import SwiftUI
import UIKit

struct VerticalOnlyScrollView<Content: View>: UIViewRepresentable {
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: AnyView(content()))
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.isDirectionalLockEnabled = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.bounces = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear

        let host = context.coordinator.host
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        scrollView.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.host.rootView = AnyView(content())
    }

    final class Coordinator {
        let host: UIHostingController<AnyView>
        init(rootView: AnyView) {
            self.host = UIHostingController(rootView: rootView)
            self.host.view.backgroundColor = .clear
            // Critical: without this the hosting controller's view does not
            // report its SwiftUI-derived intrinsic height back to the
            // UIScrollView, so contentSize collapses to the scroll view's
            // bounds — page can't scroll and content appears mis-positioned.
            if #available(iOS 16.0, *) {
                self.host.sizingOptions = [.intrinsicContentSize]
            }
        }
    }
}
