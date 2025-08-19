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
                .onChange(of: theme) { oldValue, newValue in
                    switch newValue {
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
                    logPositiveExperience()
                }, label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .imageScale(.large)
                            .foregroundStyle(.green)
                        Text("Log Positive Experience")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    logNeutralExperience()
                }, label: {
                    HStack {
                        Image(systemName: "star.leadinghalf.filled")
                            .imageScale(.large)
                            .foregroundStyle(.orange)
                        Text("Log Neutral Experience")
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                })
                
                Button(action: {
                    logNegativeExperience()
                }, label: {
                    HStack {
                        Image(systemName: "star.slash")
                            .imageScale(.large)
                            .foregroundStyle(.red)
                        Text("Log Negative Experience")
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
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
    
    func logPositiveExperience() {
        Appero.instance.log(experience: .strongPositive, context: "User tapped positive button")
        checkShouldShowFeedback()
    }
    
    func logNeutralExperience() {
        Appero.instance.log(experience: .neutral, context: "User tapped neutral button")
        checkShouldShowFeedback()
    }
    
    func logNegativeExperience() {
        Appero.instance.log(experience: .strongNegative, context: "User tapped negative button")
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
