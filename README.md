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

## Getting Started

The Appero SDK for iOS is based around a shared instance model that can be accessed from anywhere in your code once initialised. We recommend initialising Appero in either your main view's init() method for a SwiftUI app or in applicationDidFinishLaunching in a storyboard/UIKit based app.

```
Appero.instance.start(
    apiKey: "your_api_key",
    userId: "your_user_id"
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

For UIKit based apps we leverage Apple's `UIHostingController` with the helper container view `ApperoPresentationView` which we can present as a child view controller over the top of whatever view controller you have displayed. Define the `UIHostingController<ApperoPresentationView>` as an instance var on your view controller.

```
let apperoRatingView = ApperoPresentationView(productName: "Your Product Name") {
    // remove the child view controller when the panel is dismissed
    self.hostingController?.willMove(toParent: nil)
    self.hostingController?.view.removeFromSuperview()
    self.hostingController?.removeFromParent()
}

hostingController = UIHostingController(rootView: apperoRatingView)
hostingController?.view.translatesAutoresizingMaskIntoConstraints = false

if let hostingController = hostingController {
    hostingController.view.backgroundColor = .clear
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    hostingController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    hostingController.didMove(toParent: self)
}
```

## Frustration Tracking

Separate from the main experience tracking, Appero lets you track specific pain points a user might encounter in their day-to-day use of your app. For example, you might want to trigger feedback if a user consistently fails to find a result when searching or if they specifically tap some UI like a thumbs down button on a suggestion.

Like user experience, frustrations are tracked per-user. There is no limit on how many frustrations that can be registered. The frustration feedback prompt is intended to be triggered only once per registered frustration and then not again, however if necessary you can reset and reregister frustrations to circumvent this restriction. _Remember if a user is having a bad time with a feature in your app, the last thing you want to do is to keep bombarding them with feedback requests about it!_

First register a frustration. Each frustration must have a unique identifier. This should be human readable and descriptive. You may find it's easier to define these as static constants somewhere as you'll want to use this identifier to log events and check if the threshold has been crossed. You can optionally specify a message that will appear when the frustration feedback prompt is triggered.

```        
static let kNoResultsFrustration = "No search results found"

Appero.instance.register(frustration: Appero.Frustration(
    identifier: kNoResultsFrustration,
    threshold: 3,
    userPrompt: "We noticed you couldn't find what you were looking for"
))
```

In this instance in our code when the user has performed a search and we've had no results returned we would trigger the log function on our Appero instance.

```
Appero.instance.log(frustration: kNoResultsFrustration)
```

To check whether it's time to present the frustration feedback prompt to the user, we can simply call `needsPrompt` with the identifier of the frustration:

```
if Appero.instance.needsPrompt(frustration: kNoResultsFrustration) {
    // present the frustration feedback prompt here
}
```

If the user dismisses the frustration feedback prompt the frustration will enter the deferred state. This is a fixed period of 30 days from the current date where the frustration can not be re-prompted.


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

When using a custom user ID it's important to remember to reset the user on Appero when a logout occurs. This allows the experience score to be recorded independently on one device for multiple users. The flag indicating whether a user has submitted feedback or not is also tied to their user ID.

```
Appero.instance.resetUser()
```

## Connecting to 3rd Party Analytics

If you want to capture people interacting with the Appero UI in your analytics, we allow setting an analytics delegate on Appero. Simply adopt the `ApperoAnalyticsDelegate` and implement the required functions, when these events are triggered in the UI it can then make the appropriate calls to your analytic provider's SDK. Here's a typical implementation for a fictitious analytics service:

```
struct MyAnalyticsDelegate: ApperoAnalyticsDelegate {
    func logApperoFeedback(rating: Int, feedback: String) {
        SomeAnalyticsService().logEvent("Appero feedback", values: ["rating": rating, "feedback": feedback])
    }
    
    func logRatingSelected(rating: Int) {
        SomeAnalyticsService().logEvent("Appero rating changed", values: ["rating": rating])
    }
}
```

Set the delegate on the Appero shared instance somewhere sensible like after you've set your client and API keys.

```
Appero.instance.analyticsDelegate = MyAnalyticsDelegate()
```
