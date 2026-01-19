//
//  ShareViewController.swift
//  Dobby Share Extension
//
//  UIKit bridge for the Share Extension
//

import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get the shared items from the extension context
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            closeExtension()
            return
        }
        
        // Create SwiftUI view with the shared items
        let shareView = ShareExtensionView(sharedItems: extensionItems)
            .environment(\.extensionContext, extensionContext)
        
        // Host the SwiftUI view
        let hostingController = UIHostingController(rootView: shareView)
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        // Set up constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
