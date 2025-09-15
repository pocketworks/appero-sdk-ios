//
//  ApperoRatingView.swift
//  Copyright Pocketworks Mobile Ltd.
//  Created by Rory Prior on 25/05/2024.
//

import SwiftUI
import UIKit

/// Provides the Appero feedback UI within a view to be displayed inside a modal sheet
@available(iOS 16.4, *)
public struct ApperoFeedbackView: View {
    
    enum ApperoPanel {
        case rating
        case frustration
        case thanks
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    let strings: Appero.FeedbackUIStrings
    let usesSystemMaterial = Appero.instance.theme.usesSystemMaterial
    
    @State private var selectedPanelHeight: PresentationDetent
    @State private var flowType: Appero.FlowType
    @State private var rating: Int = 0
    @State private var showThanks: Bool = false
    @State private var sheetContentHeight = CGFloat(0)
    
    private let ratingDetent = PresentationDetent.height(UIFontMetrics.default.scaledValue(for: 200))
    private let feedbackDetent = PresentationDetent.fraction(UIFontMetrics.default.scaledValue(for: 0.5))
    private let thanksDetent = PresentationDetent.height(UIFontMetrics.default.scaledValue(for: 250))
    
    public init(flowType: Appero.FlowType? = nil) {
        if let flowType = flowType {
            self.flowType = flowType
            switch flowType {
                case .neutral, .positive:
                    selectedPanelHeight = ratingDetent
                default:
                    selectedPanelHeight = feedbackDetent
            }
        } else {
            self.flowType = Appero.instance.flowType
            switch Appero.instance.flowType {
                case .neutral, .positive:
                    selectedPanelHeight = ratingDetent
                default:
                    selectedPanelHeight = feedbackDetent
            }
        }
        self.strings = Appero.instance.feedbackUIStrings
    }
    
    public var body: some View {
        if usesSystemMaterial {
            feedbackBody
                .presentationBackground(.regularMaterial)
        } else {
            feedbackBody
        }
    }
    
    public var feedbackBody: some View {
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

                
                if showThanks {
                    ThanksView(rating: rating) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding(.horizontal)
                } else {
                    
                    switch flowType {
                        case .positive, .neutral:
                            FeedbackView(strings: Appero.instance.feedbackUIStrings, onRatingChosen: { rating in
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
                                self.showThanks = true
                                selectedPanelHeight = rating > 3 ? thanksDetent : ratingDetent
                                Appero.instance.shouldShowFeedbackPrompt = false
                            })
                            .padding(.horizontal)
                            
                        case .negative:
                            NegativeFlowView(
                                strings: Appero.instance.feedbackUIStrings,
                                onCancel: {
                                    presentationMode.wrappedValue.dismiss()
                                },
                                onSubmit: { feedback in
                                    Task {
                                        await Appero.instance.postFeedback(
                                            rating: 1,
                                            feedback: feedback
                                        )
                                    }
                                    Appero.instance.analyticsDelegate?.logApperoFeedback(rating: 1, feedback: feedback)
                                    self.rating = 1
                                    self.showThanks = true
                                }
                            )
                            .padding(.horizontal)
                    }
                }
            }
        }
        .background(usesSystemMaterial ? .clear : Appero.instance.theme.backgroundColor)
        .presentationDetents([thanksDetent, feedbackDetent, ratingDetent], selection: $selectedPanelHeight)
        .presentationDragIndicator(.hidden)
        .animation(.easeOut(duration: 0.2), value: selectedPanelHeight)
    }
}

@available(iOS 16, *)
private struct FeedbackView: View {
    
    let kFeedbackLimit = 240
    
    let strings: Appero.FeedbackUIStrings
    let onRatingChosen: (_ rating: Int)->(Void)
    let onSubmit: (_ rating: Int, _ feedback: String)->(Void)
    
    @State var showFeedbackForm: Bool = false
    @State var rating: Int = 0
    @State var feedbackText: String = ""
    
    @FocusState private var feedbackFieldFocused: Bool
    
    var ratingPromptText: String {
        switch rating {
            case 1...2:
                return String(localized: "RatingPromptNegative", bundle: .appero)
            case 3:
                return String(localized: "RatingPromptNeutral", bundle: .appero)
            case 4...5:
                return String(localized: "RatingPromptPositive", bundle: .appero)
            default:
                return "Unexpected state"
        }
    }
    
    var body: some View {
        VStack() {
            Spacer()
            Text(strings.title)
                .font(Appero.instance.theme.headingFont)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer()
            Text(strings.subtitle)
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
                Text(ratingPromptText)
                    .multilineTextAlignment(.center)
                    .font(Appero.instance.theme.bodyFont)
                    .foregroundColor(Appero.instance.theme.primaryTextColor)
                VStack() {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 8.0)
                            .foregroundColor(Appero.instance.theme.textFieldBackgroundColor)
                        TextField(text: $feedbackText, prompt: Text(strings.prompt).foregroundColor(Appero.instance.theme.primaryTextColor.opacity(0.5)),
                                  axis: .vertical, label: {})
                        .lineLimit(2...5)
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
                            Text(String(localized: "SendFeedback", bundle: .appero))
                                .font(Appero.instance.theme.buttonFont)
                                .foregroundStyle(Appero.instance.theme.buttonTextColor)
                            Spacer()
                        }
                    }
                    .buttonStyle(ApperoButtonStyle())
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                }
                .animation(.bouncy, value: showFeedbackForm) // Fixed deprecated animation
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 16, *)
private struct NegativeFlowView: View {
    
    let kFeedbackLimit = 240
    
    let strings: Appero.FeedbackUIStrings
    let onCancel: ()->(Void)
    let onSubmit: (_ feedback: String)->(Void)
    
    @State var feedbackText: String = ""
    @State var submitEnabled = false
    
    @FocusState private var feedbackFieldFocused: Bool
    
    var body: some View {
        VStack() {
            Spacer()
            Text(strings.title)
                .font(Appero.instance.theme.headingFont)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer()
            Text(strings.subtitle)
                .font(Appero.instance.theme.bodyFont)
                .foregroundColor(Appero.instance.theme.primaryTextColor)
                .multilineTextAlignment(.center)
            VStack() {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8.0)
                        .foregroundColor(Appero.instance.theme.textFieldBackgroundColor)
                    TextField(text: $feedbackText, prompt: Text(strings.prompt).foregroundColor(Appero.instance.theme.primaryTextColor.opacity(0.5)),
                              axis: .vertical, label: {})
                    .lineLimit(1...5)
                    .foregroundColor(Appero.instance.theme.primaryTextColor)
                    .font(Appero.instance.theme.bodyFont)
                    .padding(.all)
                    .accentColor(Appero.instance.theme.cursorColor)
                    .onChange(of: feedbackText) { text in
                        feedbackText = String(text.prefix(kFeedbackLimit))
                        submitEnabled = feedbackText.count > 0
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
                        Text(String(localized: "SendFeedback", bundle: .appero))
                            .font(Appero.instance.theme.buttonFont)
                            .foregroundStyle(Appero.instance.theme.buttonTextColor)
                        Spacer()
                    }
                }
                .disabled(!submitEnabled)
                .buttonStyle(ApperoButtonStyle())
                Button {
                    onCancel()
                } label: {
                    HStack() {
                        Spacer()
                        Text(String(localized: "NotNow", bundle: .appero))
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
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
            .background(Appero.instance.theme.buttonColor)
            .foregroundStyle(Appero.instance.theme.buttonTextColor)
            .font(Appero.instance.theme.buttonFont)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.05 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
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

private struct RatingView: View {
    
    @State var selectedRating: Int = 0
    var onRatingSelected: ((_ rating: Int)->(Void))?
    
    let localizableStrings: [String.LocalizationValue] = ["RatingVeryNegative", "RatingNegative", "RatingNeutral", "RatingPositive", "RatingVeryPositive"]
    
    var body: some View {
        HStack {
            ForEach((1...5), id: \.self) { index in
                Button(action: {
                    self.ratingSelected(index: index)
                }, label: {
                    Appero.instance.theme.imageFor(rating: ApperoRating(rawValue: index) ?? .average)
                        .opacity(selectedRating == 0 || selectedRating == index ? 1.0 : 0.3)
                })
                .accessibilityLabel(String(localized: localizableStrings[index - 1], bundle: .appero))
            }
        }
    }
    
    func ratingSelected(index: Int) {
        selectedRating = index
        onRatingSelected?(index)
    }
}

/// Supports showing the Appero panel from UIKit in a hosting controller.
@available(iOS 16.4, *)
public struct ApperoPresentationView: View {
    
    let onDismiss: (()->())?
     
    @State var presented = true
    
    
    /// This view is a convenience for showing the Appero feedback UI on a UIKit app in a UIHostingController. The hosting view controller should be added as a child view controller of the view controller where you plan to allow the feedback sheet to appear. See the ApperoExampleUIKit project for a sample implementation of this approach.
    /// - Parameters:
    ///   - onDismiss: the action to be carried out on dismissing the panel, typically to remove the child view controller from its parent.
    public init(onDismiss: (() -> ())?) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        EmptyView()
        .sheet(isPresented: $presented, onDismiss: {
            onDismiss?()
        }) {
            ApperoFeedbackView()
        }
    }
}


private struct ThanksView: View {
    
    let rating: Int
    let onDismiss: ()->()
    
    var message: String {
        switch rating {
            case 1...2:
                return String(localized: "ThanksMessageNegative", bundle: .appero)
            case 3:
                return String(localized: "ThanksMessageNeutral", bundle: .appero)
            case 4...5:
                return String(localized: "ThanksMessagePositive", bundle: .appero)
            default:
                return "Unexpected state"
        }
    }
    
    var title: String {
        switch rating {
            case 1...3:
                return String(localized: "ThankYouTitle", bundle: .appero)
            case 4...5:
                return String(localized: "RateUsTitle", bundle: .appero)
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
                        Text(String(localized: "Rate", bundle: .appero))
                        Spacer()
                    }
                }
                .buttonStyle(ApperoButtonStyle())
                Button {
                    onDismiss()
                } label: {
                    HStack() {
                        Spacer()
                        Text(String(localized: "NotNow", bundle: .appero))
                        Spacer()
                    }
                }
                .buttonStyle(ApperoTextButtonStyle())
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
            } else {
                Button {
                    onDismiss()
                } label: {
                    HStack() {
                        Spacer()
                        Text(String(localized: "Done", bundle: .appero))
                        Spacer()
                    }
                }
                .buttonStyle(ApperoButtonStyle())
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17, *)
#Preview {
    @Previewable @State var showPanel = true
    Color(.red)
    .frame(width: .infinity, height: .infinity)
    .sheet(isPresented: $showPanel) {
        ApperoFeedbackView(flowType: .negative)
            .environment(\.locale, .init(identifier: "en"))
    }
}
