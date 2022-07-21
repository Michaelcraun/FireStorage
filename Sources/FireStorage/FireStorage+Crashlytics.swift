//
//  File.swift
//  
//
//  Created by Michael Craun on 7/21/22.
//

import Foundation
import FirebaseCrashlytics

extension Store {
    public struct Crashlytics {
        private var crashlytics: FirebaseCrashlytics.Crashlytics { FirebaseCrashlytics.Crashlytics.crashlytics() }
        
        public func testCrash() {
            Store.printDebug("WARNING: Testing crashes while running the project from Xcode is not supported!")
            Store.printDebug("Please stop running the application and then cause this function to be called.")
            let test: String? = nil
            print(test!)
        }
        
        public func set(userID: String, customValues: [String : Any]) {
            crashlytics.setUserID(userID)
            crashlytics.setCustomKeysAndValues(customValues)
        }
    }
}
