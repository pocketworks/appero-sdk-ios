# Appero SDK for iOS

The in-app feedback widget that drives organic growth.

### Requirements

* iOS 15 or later for the basic library functions
* iOS 16 or later to use the built-in feedback UI
* This is primarily a Swift based SDK but some core functions are available in Objective-C to aid integration in mixed codebases

## Adding the Appero SDK to your project

The Appero SDK for iOS is distributed as a Swift Package. To add the package, enter the project view in Xcode, and under the package dependencies tab tap the plus (+) button. When prompted with the package browser popup paste this repository URL into the search field

```
https://github.com/pocketworks/appero-sdk-ios 
```

__Important:__ If your app isn't localised or doesn't include an English localisation, please add `CFBundleAllowMixedLocalizations` to your info.plist and set its value to `true` or text in the Appero UI may not appear correctly. We're hoping to add more localisations to Appero in future releases.

Appero caches experiences and feedback that's been logged to a json file, so that in the event that the user's device is offline or a network request fails, we don't lose any data. Appero will attempt to resend this data later when the connection is restored. The json file is stored in your app's documents directory. The file can be cleared using `Appero.instance.reset()`, you may want to call this in the event that a user logs out or deletes their account in your app. The user ID supplied to Appero is also cached, however for that we store it in the User Defaults dictionary. This allows us to persist the automatic UUID we generate to identify users for instances where a custom user ID has not been specified. We would recommend in most cases where you have an app with some kind of accounts feature, to use a common ID between your backend, Appero and any other analytics services to make it easier to manage your data and protect user privacy.

## Getting Started

The Appero SDK for iOS is based around a shared instance model that can be accessed from anywhere in your code once initialised. We recommend initialising Appero in either your main view's init() method for a SwiftUI app or in applicationDidFinishLaunching in a storyboard/UIKit based app.

Swift:
```
Appero.instance.start(
    apiKey: "your_api_key",
    clientId: "your_user_id"
)
```

Objective-C
```
    [[Appero instance] startWithApiKey: @"your_api_key" 
                                userId: @"your_user_id"]
```
    
You can then access the instance to access the SDK's functionality from anywhere in your app it makes sense.

## Monitoring User Experience

One of the core ideas in Appero is that we're tracking positive and negative user experiences. Once the number of experiences logged crosses the threshold defined on the Appero dashboard, we want to prompt the user to give us their feedback – be it positive or constructive. We call `log(experience: Experience, context: String)` to record individual experiences. The context string is used to categorise the experience and can be used to track outcomes of user flows, monitor for error states and so on.

Swift:
```
Appero.instance.log(experience: .strongPositive, context: "User started free trial")
```

Objective-C
```
[[Appero instance] logWithExperience: ExperienceRatingStrongPositive context: @"User started free trial"];
```

Typical types of user experience you will want to add logging for are:
* Completion of flows - positive if the user achieved what they wanted to or negative if they didn't.
* In response to direct feedback requests (e.g. tapping thumbs up or down to a search result or suggestion to indicate its relevance)
* Error states; you can determine the severity of these by considering if the error is temporary (network connection dropping) or more serious such as an error response from your server.
* Starting or cancelling of subscriptions or in-app purchases

It's also possible to get creative, for example setting up a time threshold the user remains on a given screen to indicate positive behaviour if that's what we desire or negative if it indicates the inability to complete a task easily.

__Important:__ We strongly recommend that you avoid sending sensitive user information in the context for experiences. This includes, but is not limited to, addresses, phone numbers, email addresses, banking and credit card details.

## Triggering the Appero Feedback UI

Appero is built using SwiftUI and is very easy to integrate into your app, even if you're using UIKit. To integrate with SwiftUI use the .sheet property on a view in your app's view hierarchy. The UI can then be triggered using a state variable based on your user's experience point value or in response to direct interaction (e.g a button).

```
struct ContentView: View {
    
    @State private var showingAppero: Bool = false
    
    var body: some View {
        YourAppsView {
        }
        .sheet(isPresented: $showingAppero) {
            ApperoFeedbackView()
        }
    }
}
```

The UI text is configurable through the Appero dashboard and can be configured separately for the negative and neutral/positive flows.

Use the property `shouldShowAppero` to determine whether or not the prompt should be shown based on the experience score and whether feedback has already been submitted. When testing your integration we recommend setting a low experience threshold.

For UIKit based apps we leverage Apple's `UIHostingController` with the helper container view `ApperoPresentationView` which we can present as a child view controller over the top of whatever view controller you have displayed. Define the `UIHostingController<ApperoPresentationView>` as an instance var on your view controller.

```
let apperoView = ApperoPresentationView() { [weak self] in
    
     guard let self = self else { return }
    // remove the child view controller when the panel is dismissed
    self.hostingController?.willMove(toParent: nil)
    self.hostingController?.view.removeFromSuperview()
    self.hostingController?.removeFromParent()
}

hostingController = UIHostingController(rootView: apperoView)
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

## Basic Themeing of the UI

Appero by default uses the standard iOS system colours and responds to changes to the appearance as the rest of the system dose, supporting light and dark mode. Appero also comes supplied with a light and dark theme, these both have a fixed colour palette that doesn't change in response to system appearance changes.

You will likely wish to create your own theme so the Appero UI respects your app's branding. This is done by adopting the `ApperoTheme` protocol on your custom theme struct which defines the colours you need to provide. The theme can then by applied by setting the theme property on the Appero instance as below.

```
Appero.instance.theme = DarkTheme()
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
