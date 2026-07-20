//
//  ErrorExtensions.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import OBAKitCore

// MARK: - Error Formatting Helper

extension Error {
    /// Maps a raw error to a user-friendly, localized message suitable for the watchOS UI.
    var watchOSUserFacingMessage: String {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return OBALoc("common.error.no_internet", value: "No internet connection.", comment: "No internet")
            case .timedOut:
                return OBALoc("common.error.timed_out", value: "Request timed out.", comment: "Timed out")
            default:
                return OBALoc("common.error.unable_connect", value: "Unable to connect.", comment: "Unable to connect")
            }
        }
        
        if self is DecodingError {
            return OBALoc("common.error.decoding", value: "Data format error.", comment: "Decoding error")
        }
        
        if let apiError = self as? OBAAPIError {
            switch apiError {
            case .notFound:
                return OBALoc("common.error.not_found", value: "Not found.", comment: "Not found")
            case .badServerResponse:
                return OBALoc("common.error.server_error", value: "Server error.", comment: "Server error")
            case .decodingError:
                return OBALoc("common.error.decoding", value: "Data format error.", comment: "Decoding error")
            case .invalidURL:
                return OBALoc("common.error.invalid_url", value: "Invalid request.", comment: "Invalid URL")
            case .other:
                return OBALoc("common.error.unable_load", value: "Unable to load data.", comment: "Unable to load data")
            }
        }
        
        let desc = self.localizedDescription.lowercased()
        let normalized = desc.replacingOccurrences(of: "’", with: "'")
        if normalized.contains("the data couldn't be read") || normalized.contains("format") {
            return OBALoc("common.error.decoding", value: "Data format error.", comment: "Decoding error")
        }
        
        return OBALoc("common.error.unexpected", value: "An unexpected error occurred.", comment: "Unexpected error")
    }
}
