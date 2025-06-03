//
//  ContentView.swift
//  ApperoExampleSwiftUI
//
//  Created by Rory Prior on 24/05/2024.
//

import SwiftUI
import Appero

struct ContentView: View {
    
    @State private var showingAppero = false
    private var negativeVibe = false
    @State private var theme = 0
    
    var body: some View {
        VStack {
            Spacer()
            Text("Appero theme:")
            Picker("", selection: $theme) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.vertical)
            .onChange(of: theme) { tag in
                switch tag {
                    case 1:
                        Appero.instance.theme = LightTheme()
                    case 2:
                        Appero.instance.theme = DarkTheme()
                    default:
                        Appero.instance.theme = DefaultTheme()
                }
            }
            Button(action: {
                logPositiveVibes()
            }, label: {
                VStack() {
                    Image(systemName: "star.fill")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("Tap here for Positive Vibes")
                }
            })
            Button(action: {
                logNegativeVibes()
            }, label: {
                VStack() {
                    Image(systemName: "star.slash")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("Tap here for Negative Vibes")
                }
            })
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAppero) {
            if negativeVibe {
                ApperoRatingView(productName: "ApperoExampleSwiftUI", frustrationMessage: "Negative vibes detected!")
            } else {
                ApperoRatingView(productName: "ApperoExampleSwiftUI")
            }
        }
    }
    
    func logNegativeVibes() {
        negativeVibe = true
        showingAppero = true
    }
    
    func logPositiveVibes() {
        negativeVibe = false
        Appero.instance.log(experience: .strongPositive)
        showingAppero = Appero.instance.shouldShowAppero
    }
}

#Preview {
    ContentView()
}
