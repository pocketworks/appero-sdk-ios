import SwiftUI
import Appero

struct ContentView: View {
    
    @State private var showingAppero = false
    @State private var theme = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Appero SDK Demo")
                .font(.title)
                .bold()
            
            VStack {
                Text("Appero UI theme:")
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
                    Appero.instance.log(experience: .strongPositive, context: "Very positive button tapped")
                    checkShouldShowFeedback()
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
                    Appero.instance.log(experience: .positive, context: "Positive button tapped")
                    checkShouldShowFeedback()
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
                    Appero.instance.log(experience: .neutral, context: "Neutral button tapped")
                    checkShouldShowFeedback()
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
                    Appero.instance.log(experience: .negative, context: "Negative button tapped")
                    checkShouldShowFeedback()
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
                    Appero.instance.log(experience: .strongNegative, context: "Strong negative button tapped")
                    checkShouldShowFeedback()
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
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAppero) {
            ApperoFeedbackView(
                productName: Bundle.main.bundleIdentifier ?? "My app"
            )
        }
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
