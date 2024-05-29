# Appero SDK for iOS

The in-app feedback widget that drives organic growth.

### Requirements

* iOS 15 or later for the basic library functions
* iOS 16 or later to use the built-in feedback UI

## Adding the Appero SDK to your project

The Appero SDK for iOS is distributed as a Swift Package. To add the package, enter the project view in Xcode, and under the package dependencies tab tap the plus (+) button. When prompted with the package browser popup paste this repository URL into the search field

```
https://github.com/pocketworks/appero-sdk-ios 
```

During this beta period, select the dependency rule **Branch** and choose **Main** as the target branch for the latest stable version. Upon commercial release we will switch to using versioned releases.

## Getting Started

The Appero SDK for iOS is based around a shared instance model that can be accessed from anywhere in your code once initialised. We recommend initialising Appero in either your main view's init() method for a SwiftUI app or in applicationDidFinishLaunching in a storyboard/UIKit based app.

```
Appero.instance.start(
    apiKey: "your_api_key",
    clientId: "your_client_id"
)
```

You can then access the instance to access the SDK's functionality from anywhere in your app it makes sense.

For example triggering the send feedback API can to be called as such

```
Task {
    await Appero.instance.postFeedback(
        rating: 5,
        feedback: "Posted from the SwiftUI Example App"
    )
}
```

## Monitoring User Experience

One of the core ideas in Appero is that we're tracking positive and negative user interactions to build an experience score. Once this score crosses a threshold we've defined, we want to prompt the user to give us their feedback, be it positive or constructive. We provide two mechanisms to track this experience, either using `log(experience: Experience)` or `log(points: Int)`. Logging points as an integrer allows you to define your own scale, or you can use our Experience enum that defines a Likert scale from very positive to very negative. The threshold value can set using the property `ratingThreshold`.

```
Appero.instance.log(experience: .strongPositive)
```

When adding Appero to a flow in your app, consider each point where the user can have a positive experience, a neutral one or a negative one and work out a threshold score that makes sense for it overall.

At some point you may wish to reset the users experience points and reprompt them for feedback. This should be done cautiously, we recommend recording and check a date value of when the user was last prompted.

```
Appero.instance.resetExperienceAndPrompt()
```

## Triggering the Appero Feedback UI

Appero is built using SwiftUI and is very easy to integrate into your app, even if you're using UIKit. To integrate with SwiftUI use the .sheet property on a view in your app's view hierarchy. The UI can then be triggered using a state variable based on your user's experience point value or in response to direct interaction (e.g a button).

```
struct ContentView: View {
    
    @State private var showingAppero: Bool = false
    
    var body: some View {
        YourAppsView {
        }
        .sheet(isPresented: $showingAppero) {
            ApperoRatingView(productName: "Your App")
        }
    }
}
```

Use the property `shouldShowAppero` to determine whether or not to prompt should be shown based on the experience score and whether feedback has already been submitted.

## Basic Themeing of the UI

Appero by default uses the standard iOS system colours and responds to changes to the appearance as the rest of the system dose, supporting light and dark mode. Appero also comes supplied with a light and dark theme, these both have a fixed colour palette that doesn't change in response to system appearance changes.

You will likely wish to create your own theme so the Appero UI respects your app's branding. This is done by adopting the `ApperoTheme` protocol on your custom theme struct which defines the colours you need to provide. The theme can then by applied by setting the theme property on the Appero instance as below.

```
Appero.instance.theme = DarkTheme()
```

## Handling User Sessions

By default the Appero SDK tracks user experience through a points value recorded against a unique user ID that is generated on demand and then persisted in UserDefaults. If you have an existing unique user ID, for example from an account based system, this can be substituted instead.

```
Appero.instance.setUser("your_unique_user_id")
```

When using a custom user ID it's important to remember to reset the user on Appero when a logout occurs. This allows the mood values to be recorded independently on one device for multiple users.

```
Appero.instance.resetUser()
```