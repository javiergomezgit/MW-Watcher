//
//  MarketDataServer.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/30/26.
//

import FirebaseAppCheck
import Foundation

///The Bullish Square API on Railway, which holds the market-data key and shares each answer
///between every user.
///
///The app used to call RapidAPI directly, so every device spent from one shared monthly quota.
///Requests here are answered from the server's cache wherever another user already asked.
enum MarketDataServer {

    ///Not a secret. The server only answers requests carrying a valid App Check token.
    static let baseURL = "https://bullish-square-api-production.up.railway.app"

    enum RequestError: LocalizedError {
        case invalidURL(String)
        case noAppCheckToken

        var errorDescription: String? {
            switch self {
            case .invalidURL(let path):
                return "Could not build a server address for \(path)."
            case .noAppCheckToken:
                return "This device could not prove it is running the genuine app."
            }
        }
    }

    ///A GET request for `path` with an App Check token attached. The completion always runs
    ///exactly once, on whichever queue Firebase delivers the token.
    static func authorizedRequest(path: String, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let url = URL(string: baseURL + path) else {
            completion(.failure(RequestError.invalidURL(path)))
            return
        }

        //Cached by Firebase and refreshed shortly before it expires, so this is normally
        //immediate rather than a network round trip per request.
        AppCheck.appCheck().token(forcingRefresh: false) { token, error in
            guard let token else {
                //In a debug build this usually means the install's debug token has not been
                //added in the Firebase console yet - look for it earlier in the console log.
                print("App Check token unavailable: \(String(describing: error))")
                completion(.failure(error ?? RequestError.noAppCheckToken))
                return
            }

            var request = URLRequest(url: url, timeoutInterval: 10)
            request.httpMethod = "GET"
            request.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")
            completion(.success(request))
        }
    }
}
