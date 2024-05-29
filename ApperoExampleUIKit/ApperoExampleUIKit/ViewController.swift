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

    @IBAction func positiveVibes(sender: Any?) {
        Appero.instance.log(experience: .strongPositive)
        if Appero.instance.shouldShowAppero {
            openAppero()
        }
    }
    
    func openAppero() {
        let apperoRatingView = ApperoPresentationView {
            // remove the child view controller when the panel is dismissed
            self.hostingController?.willMove(toParent: nil)
            self.hostingController?.view.removeFromSuperview()
            self.hostingController?.removeFromParent()
        }
        
        hostingController = UIHostingController(rootView: apperoRatingView)
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

struct ApperoPresentationView: View {
    
    let onDismiss: (()->())?
     
    @State var presented = true
    
    var body: some View {
        EmptyView()
        .sheet(isPresented: $presented, onDismiss: {
            onDismiss?()
        }) {
            ApperoRatingView(productName: "ApperoExampleUIKit")
        }
    }
}

