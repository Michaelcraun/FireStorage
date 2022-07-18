//
//  File.swift
//  
//
//  Created by Michael Craun on 7/18/22.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
