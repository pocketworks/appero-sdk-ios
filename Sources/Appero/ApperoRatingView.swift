//
//  ApperoRatingView.swift
//  ApperoExampleSwiftUI
//
//  Created by Rory Prior on 25/05/2024.
//

import SwiftUI

/// Provides the Appero feedback UI within a view to be displayed inside a modal sheet
@available(iOS 16, *)
public struct ApperoRatingView: View {
    
    enum ApperoPanel {
        case rating
        case thanks
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    let productName: String
    
    @State var selectedPanelHeight = PresentationDetent.fraction(0.33)
    @State var panelMode: ApperoPanel = .rating
    
    private let ratingDetent = PresentationDetent.fraction(0.33)
    private let feedbackDetent = PresentationDetent.fraction(0.7)
    private let thanksDetent = PresentationDetent.fraction(0.25)
    
    @State private var rating: Int = 0
    
    public init(productName: String) {
        self.productName = productName
    }
    
    public var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                HStack(alignment: .top, content: {
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .tint(.gray)
                    }
                    .padding(.top)
                    .padding(.trailing)
                })
                
                switch panelMode {
                    case .rating:
                        FeedbackView(productName: productName, onRatingChosen: { rating in
                            selectedPanelHeight = feedbackDetent
                        }, onSubmit: { rating, feedback in
                            Task {
                                await Appero.instance.postFeedback(
                                    rating: rating,
                                    feedback: feedback
                                )
                            }
                            Appero.instance.analyticsDelegate?.logApperoFeedback(rating: rating, feedback: feedback)
                            self.rating = rating
                            panelMode = .thanks
                            selectedPanelHeight = rating > 3 ? ratingDetent : thanksDetent
                            Appero.instance.hasRatingBeenPrompted = true
                        })
                        .padding(.horizontal)
                    case .thanks:
                        ThanksView(productName: productName, rating: rating) {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding(.horizontal)
                }
                
            }
        }
        .background(Appero.instance.theme.backgroundColor)
        .presentationDetents([thanksDetent, feedbackDetent, ratingDetent], selection: $selectedPanelHeight)
        .presentationDragIndicator(.hidden)
        .animation(.easeOut(duration: 0.2), value: selectedPanelHeight)
    }
}

@available(iOS 16, *)
private struct FeedbackView: View {
    
    let kFeedbackLimit = 120
    
    let productName: String
    let onRatingChosen: (_ rating: Int)->(Void)
    let onSubmit: (_ rating: Int, _ feedback: String)->(Void)
    
    @State var showFeedbackForm: Bool = false
    @State var rating: Int = 0
    @State var feedbackText: String = ""
    
    @FocusState private var feedbackFieldFocused: Bool
    
    var body: some View {
        VStack() {
            Spacer()
            Text("We’re happy to see that you’re using \(productName) 🎉")
                .font(Appero.instance.theme.headingFont)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer()
            Text("Let us know how we’re doing")
                .font(Appero.instance.theme.bodyFont)
                .padding(.leading)
                .padding(.trailing)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
            RatingView(onRatingSelected: { rating in
                showFeedbackForm = true
                onRatingChosen(rating)
                self.rating = rating
                Appero.instance.analyticsDelegate?.logRatingSelected(rating: rating)
            })
            Spacer()
            if showFeedbackForm {
                Text(promptText)
                    .multilineTextAlignment(.center)
                    .font(Appero.instance.theme.bodyFont)
                    .foregroundColor(Appero.instance.theme.primaryTextColor)
                VStack() {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 8.0)
                            .foregroundColor(Appero.instance.theme.textFieldBackgroundColor)
                        TextField(text: $feedbackText, prompt: Text("Share your thoughts here").foregroundColor(Appero.instance.theme.primaryTextColor.opacity(0.5)),
                                  axis: .vertical, label: {})
                        .lineLimit(1...5)
                        .foregroundColor(Appero.instance.theme.primaryTextColor)
                        .font(Appero.instance.theme.bodyFont)
                        .padding(.all)
                        .accentColor(Appero.instance.theme.cursorColor)
                        .onChange(of: feedbackText) { text in
                            feedbackText = String(text.prefix(kFeedbackLimit))
                        }
                        .focused($feedbackFieldFocused)
                    }.onTapGesture {
                        feedbackFieldFocused = true
                    }
                    HStack {
                        Spacer()
                        Text("\(feedbackText.count) / \(kFeedbackLimit)")
                            .font(Appero.instance.theme.captionFont)
                            .foregroundStyle(Appero.instance.theme.secondaryTextColor)
                    }
                    Spacer()
                    Button {
                        onSubmit(rating, feedbackText)
                    } label: {
                        HStack() {
                            Spacer()
                            Text("Send feedback")
                                .font(Appero.instance.theme.buttonFont)
                                .foregroundStyle(Appero.instance.theme.buttonTextColor)
                            Spacer()
                        }
                    }
                    .buttonStyle(ApperoButtonStyle())
                }
                .animation(.bouncy)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    var promptText: String {
        switch rating {
            case 1...2:
                return "We’re sorry you’re not enjoying it. Could you tell us what went wrong?"
            case 3:
                return "What made your experience positive?"
            case 4...5:
                return "What made your experience positive?"
            default:
                return "Unexpected state"
        }
    }
}

@available(iOS 16, *)
private struct FrustrationView: View {
    
    let kFeedbackLimit = 120
    
    let frustrationMessage: String
    let onCancel: ()->(Void)
    let onSubmit: (_ feedback: String)->(Void)
    
    @State var feedbackText: String = ""
    
    @FocusState private var feedbackFieldFocused: Bool
    
    var body: some View {
        VStack() {
            Spacer()
            Text(frustrationMessage)
                .font(Appero.instance.theme.headingFont)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer()
            Text("Would you mind telling us what went wrong?")
                .font(Appero.instance.theme.bodyFont)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
                .multilineTextAlignment(.center)
            VStack() {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8.0)
                        .foregroundColor(Appero.instance.theme.textFieldBackgroundColor)
                    TextField(text: $feedbackText, prompt: Text("Share your thoughts here").foregroundColor(Appero.instance.theme.primaryTextColor.opacity(0.5)),
                              axis: .vertical, label: {})
                    .lineLimit(1...5)
                    .foregroundColor(Appero.instance.theme.primaryTextColor)
                    .font(Appero.instance.theme.bodyFont)
                    .padding(.all)
                    .accentColor(Appero.instance.theme.cursorColor)
                    .onChange(of: feedbackText) { text in
                        feedbackText = String(text.prefix(kFeedbackLimit))
                    }
                    .focused($feedbackFieldFocused)
                }.onTapGesture {
                        feedbackFieldFocused = true
                }
                HStack {
                    Spacer()
                    Text("\(feedbackText.count) / \(kFeedbackLimit)")
                        .font(Appero.instance.theme.captionFont)
                        .foregroundStyle(Appero.instance.theme.secondaryTextColor)
                }
                Spacer()
                Button {
                    onSubmit(feedbackText)
                } label: {
                    HStack() {
                        Spacer()
                        Text("Send feedback")
                            .font(Appero.instance.theme.buttonFont)
                            .foregroundStyle(Appero.instance.theme.buttonTextColor)
                        Spacer()
                    }
                }
                .buttonStyle(ApperoButtonStyle())
                Button {
                    onCancel()
                } label: {
                    HStack() {
                        Spacer()
                        Text("Not now")
                            .font(Appero.instance.theme.buttonFont)
                            .foregroundStyle(Appero.instance.theme.buttonColor)
                        Spacer()
                    }
                }
                .buttonStyle(ApperoTextButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ApperoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
            .background(Appero.instance.theme.buttonColor)
            .foregroundStyle(Appero.instance.theme.buttonTextColor)
            .font(Appero.instance.theme.buttonFont)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.05 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct ApperoTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
            .foregroundStyle(Appero.instance.theme.buttonColor)
            .font(Appero.instance.theme.buttonFont)
            .scaleEffect(configuration.isPressed ? 1.05 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct RatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct RatingView: View {
    
    @State var selectedRating: Int = 0
    var onRatingSelected: ((_ rating: Int)->(Void))?
    
    var body: some View {
        HStack {
            ForEach((1...5), id: \.self) { index in
                Button(action: {
                    self.ratingSelected(index: index)
                }, label: {
                    Appero.instance.theme.imageFor(rating: ApperoRating(rawValue: index) ?? .average)
                        .opacity(selectedRating == 0 || selectedRating == index ? 1.0 : 0.3)
                })
                .buttonStyle(RatingButtonStyle())
            }
        }
    }
    
    func ratingSelected(index: Int) {
        selectedRating = index
        onRatingSelected?(index)
    }
}

/// Supports showing the Appero panel from UIKit in a hosting controller.
@available(iOS 16, *)
public struct ApperoPresentationView: View {
    
    let productName: String
    let onDismiss: (()->())?
     
    @State var presented = true
    
    
    /// This view is a convenience for showing the Appero feedback UI on a UIKit app in a UIHostingController. The hosting view controller should be added as a child view controller of the view controller where you plan to allow the feedback sheet to appear. See the ApperoExampleUIKit project for a sample implementation of this approach.
    /// - Parameters:
    ///   - productName: the product name you want to appear in the feedback UI
    ///   - onDismiss: the action to be carried out on dismissing the panel, typically to remove the child view controller from its parent.
    public init(productName: String, onDismiss: (() -> ())?) {
        self.productName = productName
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        EmptyView()
        .sheet(isPresented: $presented, onDismiss: {
            onDismiss?()
        }) {
            ApperoRatingView(productName: productName)
        }
    }
}


private struct ThanksView: View {
    
    let productName: String
    let rating: Int
    let onDismiss: ()->()
    
    var message: String {
        switch rating {
            case 1...2:
                return "Your feedback helps us improve your experience using \(productName)."
            case 3:
                return "Your feedback is really appreciated."
            case 4...5:
                return "Your feedback helps us improve your experience using \(productName)."
            default:
                return "Unexpected state"
        }
    }
    
    var title: String {
        switch rating {
            case 1...3:
                return "Thank you"
            case 4...5:
                return "Rate us"
            default:
                return "Unexpected state"
        }
    }

    var body: some View {
        VStack() {
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .padding(.horizontal)
                .foregroundStyle(Appero.instance.theme.primaryTextColor)
            Spacer()
            Text(message)
                .padding(.horizontal)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Appero.instance.theme.primaryTextColor)
            Spacer()
            if rating > 3 {
                Button {
                    Appero.instance.requestAppStoreRating()
                    onDismiss()
                } label: {
                    HStack() {
                        Spacer()
                        Text("Rate")
                        Spacer()
                    }
                }
                .buttonStyle(ApperoButtonStyle())
                Button {
                    onDismiss()
                } label: {
                    HStack() {
                        Spacer()
                        Text("Not now")
                        Spacer()
                    }
                }
                .buttonStyle(ApperoTextButtonStyle())
            } else {
                Button {
                    onDismiss()
                } label: {
                    HStack() {
                        Spacer()
                        Text("Done")
                        Spacer()
                    }
                }
                .buttonStyle(ApperoButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 16, *)
#Preview {
    FrustrationView(
        frustrationMessage: "We noticed you couldn’t find what you were looking for 😥"
    ) {
    } onSubmit: { feedback in
        
    }
}
