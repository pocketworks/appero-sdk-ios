//  ApperoTheme.swift
//  ApperoExampleSwiftUI
//
//  Created by Rory Prior on 28/05/2024.
//

import SwiftUI

public protocol ApperoTheme {
    var backgroundColor: Color { get }
    var primaryTextColor: Color { get }
    var secondaryTextColor: Color { get }
    var buttonColor: Color { get }
    var buttonTextColor: Color { get }
    var textFieldBackground: Color { get }
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
    
    public var textFieldBackground: Color {
        return Color(.secondarySystemBackground)
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
    
    public var textFieldBackground: Color {
        return Color(hex: "F5F5F5")
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
    
    public var textFieldBackground: Color {
        return Color(hex: "080935")
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
