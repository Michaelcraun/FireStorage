//
//  File.swift
//  
//
//  Created by Michael Craun on 7/21/22.
//

import Foundation

public struct PublicDatabase: Codable {
    var usernames: [String]?
    
    mutating func addUsername(_ username: String) {
        usernames?.append(username)
        Store.firestore.public.put(data: usernames, forId: "usernames")
    }
    
    mutating func removeUsername(_ username: String) {
        guard let index = usernames?.firstIndex(of: username) else { return }
        usernames?.remove(at: index)
        Store.firestore.public.put(data: usernames, forId: "usernames")
    }
    
    func contains(_ username: String) -> Bool {
        return usernames?.contains(username) ?? true
    }
}
