//
//  File.swift
//  
//
//  Created by Michael Craun on 7/19/22.
//

import Foundation

public class AppUser: Codable {
    public var email: String?
    public var first: String?
    public var last: String?
    public var photo: String?
    public var uid: String?
    public var username: String?
    
    // MARK: - Public accessors
    public var displayName: String {
        if let username = username {
            return username
        }
        
        if let email = email {
            return email
        }
        
        if let first = first, let last = last {
            return "\(first) \(last)"
        }
        return ""
    }
    
    public var fullName: String {
        guard let first = first, let last = last else { return username ?? email ?? "" }
        return "\(first) \(last)"
    }
    
    public required init(email: String?, uid: String?, userData: [String : Any]) {
        self.email = email
        self.uid = uid
        
        self.first = userData["first"] as? String
        self.last = userData["last"] as? String
        self.photo = userData["photo"] as? String
        self.username = userData["username"] as? String
    }
    
    public func deleteAllData(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}
