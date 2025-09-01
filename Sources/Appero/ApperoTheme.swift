//
//  ApperoTheme.swift
//  Copyright Pocketworks Mobile Ltd.
//  Created by Rory Prior on 28/05/2024.
//

import SwiftUI

public protocol ApperoTheme {
    var backgroundColor: Color { get }
    var primaryTextColor: Color { get }
    var secondaryTextColor: Color { get }
    var buttonColor: Color { get }
    var buttonTextColor: Color { get }
    var textFieldBackgroundColor: Color { get }
    var cursorColor: Color { get }
    var headingFont: Font { get }
    var bodyFont: Font { get }
    var buttonFont: Font { get }
    var captionFont: Font { get }
    func imageFor(rating: ApperoRating) -> Image
}

public enum ApperoRating: Int {
    case veryPoor = 1
    case poor = 2
    case average = 3
    case good = 4
    case veryGood = 5
}

public struct DefaultTheme: ApperoTheme {
    
    public init() {
    }
    
    public var backgroundColor: Color {
        return Color(.systemBackground)
    }
    
    public var primaryTextColor: Color {
        return Color(.label)
    }
    
    public var secondaryTextColor: Color {
        return Color(.secondaryLabel)
    }
    
    public var buttonColor: Color {
        return Color(.systemBlue)
    }
    
    public var buttonTextColor: Color {
        return Color(.white)
    }
    
    public var textFieldBackgroundColor: Color {
        return Color(.secondarySystemBackground)
    }
    
    public var cursorColor: Color {
        return Color(.systemBlue)
    }
    
    public var headingFont: Font {
        return Font.system(.headline, design: .default)
    }
    
    public var bodyFont: Font {
        return Font.system(.body, design: .default)
    }
    
    public var buttonFont: Font {
        if #available(iOS 16.0, *) {
            return Font.system(.body, design: .default, weight: .bold)
        } else {
            return Font.system(.body, design: .default).weight(.bold)
        }
    }
    
    public var captionFont: Font {
        return Font.system(.caption, design: .default)
    }
    
    public func imageFor(rating: ApperoRating) -> Image {
        switch rating {
            case .veryPoor:
                return Image("rating1", bundle: .appero)
            case .poor:
                return Image("rating2", bundle: .appero)
            case .average:
                return Image("rating3", bundle: .appero)
            case .good:
                return Image("rating4", bundle: .appero)
            case .veryGood:
                return Image("rating5", bundle: .appero)
        }
    }
}

public struct LightTheme: ApperoTheme {
    
    public init() {
    }
    
    public var backgroundColor: Color {
        return .white
    }
    
    public var primaryTextColor: Color {
        return Color(hex: "003143")
    }
    
    public var secondaryTextColor: Color {
        return Color(hex: "707070")
    }
    
    public var buttonColor: Color {
        return Color(hex: "50A95F")
    }
    
    public var buttonTextColor: Color {
        return .white
    }
    
    public var textFieldBackgroundColor: Color {
        return Color(hex: "F5F5F5")
    }
    
    public var cursorColor: Color {
        return Color(hex: "50A95F")
    }
    
    public var headingFont: Font {
        return Font.custom("Helvetica-Bold", size: 18, relativeTo: .headline)
    }
    
    public var bodyFont: Font {
        return Font.custom("Helvetica", size: 16, relativeTo: .body)
    }
    
    public var buttonFont: Font {
        return Font.custom("Helvetica-Bold", size: 16, relativeTo: .body)
    }
    
    public var captionFont: Font {
        return Font.custom("Helvetica", size: 14, relativeTo: .caption)
    }
    
    public func imageFor(rating: ApperoRating) -> Image {
        switch rating {
            case .veryPoor:
                return Image("rating1", bundle: .appero)
            case .poor:
                return Image("rating2", bundle: .appero)
            case .average:
                return Image("rating3", bundle: .appero)
            case .good:
                return Image("rating4", bundle: .appero)
            case .veryGood:
                return Image("rating5", bundle: .appero)
        }
    }
}

public struct DarkTheme: ApperoTheme {
    
    public init() {
    }
    
    public var backgroundColor: Color {
        return Color(hex: "040312")
    }
    
    public var primaryTextColor: Color {
        return .white
    }
    
    public var secondaryTextColor: Color {
        return Color(hex: "C8C6CD")
    }
    
    public var buttonColor: Color {
        return Color(hex: "00A0E4")
    }
    
    public var buttonTextColor: Color {
        return .white
    }
    
    public var textFieldBackgroundColor: Color {
        return Color(hex: "080935")
    }
    
    public var cursorColor: Color {
        return Color(hex: "00A0E4")
    }
    
    public var headingFont: Font {
        return Font.custom("Georgia-Bold", size: 18, relativeTo: .headline)
    }
    
    public var bodyFont: Font {
        return Font.custom("Georgia", size: 16, relativeTo: .body)
    }
    
    public var buttonFont: Font {
        return Font.custom("Georgia", size: 16, relativeTo: .body)
    }
    
    public var captionFont: Font {
        return Font.custom("Georgia", size: 14, relativeTo: .caption)
    }
    
    public func imageFor(rating: ApperoRating) -> Image {
        switch rating {
            case .veryPoor:
                return Image("rating1-alt", bundle: .appero)
            case .poor:
                return Image("rating2-alt", bundle: .appero)
            case .average:
                return Image("rating3-alt", bundle: .appero)
            case .good:
                return Image("rating4-alt", bundle: .appero)
            case .veryGood:
                return Image("rating5-alt", bundle: .appero)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
