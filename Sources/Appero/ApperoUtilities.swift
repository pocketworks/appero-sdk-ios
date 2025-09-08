//
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
