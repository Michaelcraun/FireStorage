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
    
    init(email: String?, password: String?, userData: [String : Any]) {
        self.email = email
    }
    
    public func deleteAllData(completion: @escaping (Error?) -> Void) {  }
}

class NPCGenUser: AppUser {
    func test() {
        Store.auth.remove(user: self) { error in
            
        }
    }
    
    override init(email: String?, password: String?, userData: [String : Any]) {
        super.init(email: email, password: password, userData: userData)
        
        
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    override func deleteAllData(completion: @escaping (Error?) -> Void) {
        
    }
}
