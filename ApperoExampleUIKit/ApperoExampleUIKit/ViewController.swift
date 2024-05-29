//
//  ViewController.swift
//  ApperoExampleUIKit
//
//  Created by Rory Prior on 28/05/2024.
//

import UIKit
import Appero

class ViewController: UIViewController {

    @IBOutlet var themePicker: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        themePicker.selectedSegmentIndex = 2
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

    @IBAction func openAppero(sender: Any?) {
        
    }
}

