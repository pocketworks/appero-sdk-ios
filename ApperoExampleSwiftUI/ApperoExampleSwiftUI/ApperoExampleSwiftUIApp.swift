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
    
    init() {

        Appero.instance.start(
            apiKey: "PerD+p+Ciw2B9l6HuPucpLABI6wuLkiM2iwLPpDBYEw",
            userId: "test_user_1"
        )
        
        // Show debug info in the console
        Appero.instance.isDebug = true
        
        // Set the theme to use for the Appero UI
        Appero.instance.theme = DefaultTheme()
    }
}
