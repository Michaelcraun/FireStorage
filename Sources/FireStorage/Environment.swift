//
//  File.swift
//  
//
//  Created by Michael Craun on 7/17/22.
//

import Foundation

public enum Environment {
    case development
    case production
    case testing
    case unitTesting
}

public var environment: Environment {
    if let environmentOverride = Store.environmentOverride {
        return environmentOverride
    }
    
    guard let path = Bundle.main.appStoreReceiptURL?.path else { return .production }
    
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return .unitTesting
    }
    
    if path.contains("sandboxReceipt") {
        return .testing
    }
    
    #if DEBUG
    return .development
    #endif
    
    // It's not true at all that this will never be returned... if the app is running in
    // a non-debug environment, this will definitely be returned.
    return .production
}
