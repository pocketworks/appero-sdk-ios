//
//  ApperoAPIClient
//  Copyright Pocketworks Mobile Ltd.
//  Created by Rory Prior on 23/05/2024.
//

import Foundation

enum ApperoAPIError: Error {
    case noData
    case networkError(statusCode: Int)
    case serverMessage(response: ApperoErrorResponse?)
    case noResponse
}

enum FlowType: String, Codable {
    /// indicates a positive overall experience
    case normal = "normal"
    /// indicates neither a positive or negative overall experience
    case neutral = "neutral"
    /// indicates a negative overall experience
    case frustration = "frustration"
}

struct ApperoErrorResponse: Codable {
    
    struct Details: Codable {
        let userId: [String]?
        let value: [String]?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case value
        }
    }
    
    let error: String?
    let message: String?
    let details: Details?
    
    func description() -> String {
        var returnString = ""
        if let error = error {
            returnString += "\(error)\n"
        }
        if let message = message {
            returnString += "         Server message: \(message)\n"
        }
        if let details = details {
            if let userId = details.userId?.first {
                returnString += "         > \(userId)\n"
            }
            if let value = details.value?.first {
                returnString += "         > \(value)"
            }
        }
        
        return returnString
    }
}

struct ApperoAPIClient {

    enum Method: String {
        case get
        case put
        case post
        case patch
        case delete
    }
    
    internal static let apiBaseURL = URL(string: "https://app.appero.co.uk/api/v1")!
    private static let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
    
    
    
    @discardableResult
    static func sendRequest(endPoint: String, fields: [String: Any], method: ApperoAPIClient.Method, authorization: String) async throws -> Data {

        var request = URLRequest(url: ApperoAPIClient.apiBaseURL.appendingPathComponent(endPoint))
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("Bearer " + authorization, forHTTPHeaderField: "Authorization")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fields, options: [])
        request.timeoutInterval = 10

        let (responseBody, response) = try await ApperoAPIClient.session.data(for: request)

        // Left in for future response debugging
        //ApperoDebug.log(String(data: responseBody ?? Data(), encoding: .utf8) ?? "No response body")
        
        guard let response = response as? HTTPURLResponse else {
            throw ApperoAPIError.noResponse
        }
        
        switch response.statusCode {
            case (200...204):
                // success
                return responseBody
            case 401, 422:
                // failure w/ error message
                throw ApperoAPIError.serverMessage(response: try? JSONDecoder().decode(ApperoErrorResponse.self, from: responseBody))
            default:
                // failure
                throw ApperoAPIError.networkError(statusCode: response.statusCode)
        }
    }
}
