//
//  AppCheckProviders.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/30/26.
//

import FirebaseAppCheck
import FirebaseCore

///Chooses how this build proves to the Bullish Square server that it is the genuine app.
///
///The server refuses every /v1 request that lacks a valid App Check token, because each one
///spends market-data quota. Set before FirebaseApp.configure(), which is when Firebase reads it.
final class BullishAppCheckProviderFactory: NSObject, AppCheckProviderFactory {

    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        //Simulators cannot run App Attest. The debug provider prints a token to the Xcode
        //console once per install; adding it under App Check > Manage debug tokens in the
        //Firebase console lets that one install through. Never compiled into a release build.
        return AppCheckDebugProvider(app: app)
        #else
        //Apple's attestation that this is the unmodified app on a real device. Needs the App
        //Attest capability on the target.
        return AppAttestProvider(app: app)
        #endif
    }
}
