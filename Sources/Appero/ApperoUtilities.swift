//
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

//  ApperoUtilities.swift
//  Appero
//
//  Created by Rory Prior on 19/08/2025.
//

internal struct ApperoDebug {
    static func log(_ message: String) {
        if Appero.instance.isDebug {
            print("[Appero] \(message)")
        }
    }
}

public enum ApperoUtilities {
    public static func requestAppStoreRating() {
        #if os(macOS)
        SKStoreReviewController.requestReview()
        #else
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        #endif
    }
}
