//
//  ViewController.swift
//  ApperoExampleUIKit
//
//  Created by Rory Prior on 28/05/2024.
//

import UIKit
import SwiftUI
import Appero

class ViewController: UIViewController {

    @IBOutlet var themePicker: UISegmentedControl!
    var hostingController: UIHostingController<ApperoPresentationView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        themePicker.selectedSegmentIndex = 0
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showApperoNotification(_:)),
            name: Appero.kApperoFeedbackPromptNotification,
            object: nil
        )
    }
    
    @IBAction func changeTheme(sender: Any?) {
        switch themePicker.selectedSegmentIndex {
            case 1:
                Appero.instance.theme = LightTheme()
            case 2:
                Appero.instance.theme = DarkTheme()
            default:
                Appero.instance.theme = DefaultTheme()
        }
    }

    @IBAction func veryPositive(sender: Any?) {
        Appero.instance.log(experience: .strongPositive, context: "Very positive tapped")
    }
    
    @IBAction func positive(sender: Any?) {
        Appero.instance.log(experience: .positive, context: "Positive tapped")
    }
    
    @IBAction func neutral(sender: Any?) {
        Appero.instance.log(experience: .neutral, context: "Neutral tapped")
    }
    
    @IBAction func negative(sender: Any?) {
        Appero.instance.log(experience: .negative, context: "Negative tapped")
    }
    
    @IBAction func veryNegative(sender: Any?) {
        Appero.instance.log(experience: .strongNegative, context: "Very negative tapped")
    }
    
    @IBAction func triggerFeedbackPrompt(sender: Any?) {
        openAppero()
    }
    
    // Show the Appero feedback prompt when the notification is triggered from the server response to posting an experience.
    @objc func showApperoNotification(_: Notification) {
        Task { @MainActor in
            openAppero()
        }
    }
    
    // Present the Appero feedback UI in a SwiftUI hosting view controller
    func openAppero() {
        let apperoView = ApperoPresentationView() { [weak self] in
            
            guard let self = self else {
                return
            }
            
            // remove the child view controller when the panel is dismissed
            self.hostingController?.willMove(toParent: nil)
            self.hostingController?.view.removeFromSuperview()
            self.hostingController?.removeFromParent()
        }
        
        hostingController = UIHostingController(rootView: apperoView)
        hostingController?.view.translatesAutoresizingMaskIntoConstraints = false
        
        if let hostingController = hostingController {
            hostingController.view.backgroundColor = .clear
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            hostingController.didMove(toParent: self)
        }
    }
}

