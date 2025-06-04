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
        Appero.instance.start(
            apiKey: "PerD+p+Ciw2B9l6HuPucpLABI6wuLkiM2iwLPpDBYEw",
            userId: "test_user_1",
        )
        Appero.instance.theme = DefaultTheme()  // set the theme to use for the Appero UI
        Appero.instance.ratingThreshold = 10   // the threshold at which point we'll trigger the Appero UI
        Appero.instance.register(frustration: Appero.Frustration(
            identifier: kFrustrationButtonTapped
            threshold: 2,
            promptText: "This text can be customised to emphasise with the user"
        )
        
        // for the demo app we want to reset things on each launch, you likely wouldn't want to do this in a real app.
        Appero.instance.resetExperienceAndPrompt()
    }
}
