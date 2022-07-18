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
}

public var environmentOverride: Environment?

public var environment: Environment {
    if let environmentOverride = environmentOverride {
        return environmentOverride
    }
    
    guard let path = Bundle.main.appStoreReceiptURL?.path else { return .production }
    if path.contains("CoreSimulator") {
        return .development
    } else if path.contains("sandboxReceipt") {
        return .testing
    } else {
        return .production
    }
}
