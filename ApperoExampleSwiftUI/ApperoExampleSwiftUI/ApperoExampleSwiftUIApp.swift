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
            apiKey: "your api key",
            clientId: "your client id"
        )
        Appero.instance.theme = DefaultTheme()  // set the theme to use for the Appero UI
        Appero.instance.ratingThreshold = 10   // the threshold at which point we'll trigger the Appero UI
        
        // for the demo app we want to reset things on each launch, you likely wouldn't want to do this in a real app.
        Appero.instance.resetExperienceAndPrompt()
    }
}
