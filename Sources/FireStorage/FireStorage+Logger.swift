//
//  File.swift
//  
//
//  Created by Michael Craun on 7/17/22.
//

import Foundation

extension FirebaseStorage {
    func printDebug(_ message: String) {
        #if DEBUG
        print("FireStorage:", message)
        #endif
    }
}
