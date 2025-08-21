//
//  ApperoExampleSwiftUIApp.swift
//  ApperoExampleSwiftUI
//
//  Created by Rory Prior on 24/05/2024.
//

import SwiftUI
import Appero

@main
struct ApperoExampleSwiftUIApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    static let kFrustrationButtonTapped = "frustration button tapped"
    
    init() {
        // Initialize Appero with the new API
        Appero.instance.start(
            apiKey: "PerD+p+Ciw2B9l6HuPucpLABI6wuLkiM2iwLPpDBYEw",
            clientId: "test_user_1"
        )
        
        Appero.instance.isDebug = true
        
        // Set the theme to use for the Appero UI
        Appero.instance.theme = DefaultTheme()
        
        // For the demo app we want to reset things on each launch
        // You likely wouldn't want to do this in a real app
        Appero.instance.reset()
        
        // Initialise the Appero instance.
        Appero.instance.start(
            apiKey: "PerD+p+Ciw2B9l6HuPucpLABI6wuLkiM2iwLPpDBYEw",
            clientId: "test_user_1"
        )
    }
}
