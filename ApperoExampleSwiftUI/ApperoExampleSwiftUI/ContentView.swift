import SwiftUI
import Appero

struct ContentView: View {
    
    @State private var showingAppero = false
    @State private var theme = 0
    @State private var forceOfflineMode = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Appero SDK Demo")
                .font(.title)
                .bold()
            
            VStack {
                Text("Theme:")
                Picker("", selection: $theme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: theme) { oldTag, newTag in
                    switch newTag {
                        case 1:
                            Appero.instance.theme = LightTheme()
                        case 2:
                            Appero.instance.theme = DarkTheme()
                        default:
                            Appero.instance.theme = DefaultTheme()
                    }
                }
            }
            
            VStack(spacing: 15) {
                Button(action: {
                    log(experience: .strongPositive, context: "Very positive button tapped")
                }, label: {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .imageScale(.large)
                            .foregroundStyle(.green)
                        Text("Very Positive")
                    }
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    log(experience: .positive, context: "Positive button tapped")
                }, label: {
                    HStack {
                        Image(systemName: "hand.thumbsup")
                            .imageScale(.large)
                            .foregroundStyle(.green)
                        Text("Positive")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    log(experience: .neutral, context: "Neutral button tapped")
                }, label: {
                    HStack {
                        Image(systemName: "circle.dotted")
                            .imageScale(.large)
                            .foregroundStyle(.orange)
                        Text("Neutral")
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    log(experience: .negative, context: "Negative button tapped")
                }, label: {
                    HStack {
                        Image(systemName: "hand.thumbsdown")
                            .imageScale(.large)
                            .foregroundStyle(.red)
                        Text("Negative")
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    log(experience: .strongNegative, context: "Strong negative button tapped")
                }, label: {
                    HStack {
                        Image(systemName: "hand.thumbsdown.fill")
                            .imageScale(.large)
                            .foregroundStyle(.red)
                        Text("Very Negative")
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    showFeedbackPrompt()
                }, label: {
                    HStack {
                        Image(systemName: "bubble.right")
                            .imageScale(.large)
                            .foregroundStyle(.blue)
                        Text("Show Feedback UI")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                })
            }
            
            VStack {
                Text("Status:")
                    .font(.headline)
                Text("Should show feedback: \(Appero.instance.shouldShowFeedbackPrompt ? "Yes" : "No")")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAppero) {
            ApperoFeedbackView(
                productName: Bundle.main.bundleIdentifier ?? "My app"
            )
        }
    }
    
    func log(experience: Appero.ExperienceRating, context: String) {
        Appero.instance.log(experience: experience, context: context)
        checkShouldShowFeedback()
    }
    
    func showFeedbackPrompt() {
        showingAppero = true
    }
    
    func checkShouldShowFeedback() {
        // Check if we should automatically show the feedback prompt
        if Appero.instance.shouldShowFeedbackPrompt {
            showingAppero = true
            Appero.instance.shouldShowFeedbackPrompt = false // Reset after showing
        }
    }
}

#Preview {
    ContentView()
}
