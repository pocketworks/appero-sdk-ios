//
//  ApperoAPIClient
//  Copyright Pocketworks Mobile Ltd.
//  Created by Rory Prior on 23/05/2024.
//

import Foundation

enum ApperoAPIError: Error {
    case noData
    case networkError(statusCode: Int)
    case noResponse
}

struct ApperoAPIClient {

    enum Method: String {
        case get
        case put
        case post
        case patch
        case delete
    }
    
    private static let apiBaseURL = URL(string: "https://app.appero.co.uk/api/v1")!
    private static let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
    
    
    
    @discardableResult
    static func sendRequest(endPoint: String, fields: [String: Any], method: ApperoAPIClient.Method, authorization: String) async throws -> Data {

        var request = URLRequest(url: ApperoAPIClient.apiBaseURL.appendingPathComponent(endPoint))
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("Bearer: " + authorization, forHTTPHeaderField: "Authorization")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fields, options: [])
        
        let (responseBody, response) = try await ApperoAPIClient.session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw ApperoAPIError.noResponse
        }
        
        switch response.statusCode {
            case (200...204):
                // success
                return responseBody
            default:
                // failure
                throw ApperoAPIError.networkError(statusCode: response.statusCode)
        }
    }
}
