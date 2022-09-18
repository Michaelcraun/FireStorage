//
//  File.swift
//  
//
//  Created by Michael Craun on 9/17/22.
//

import Foundation

public protocol FirestoreDelegate: AnyObject {
    func firestoreDidFetch(data: [[String : Any]], from collection: String)
    func firestoreDidEncounter(error: Error)
}
