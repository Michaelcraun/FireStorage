//
//  File.swift
//  
//
//  Created by Michael Craun on 7/20/22.
//

import AuthenticationServices

extension ASAuthorizationAppleIDCredential {
    func firstname() -> String {
        return self.fullName?.givenName ?? "user"
    }
    
    func lastname() -> String {
        if let familyName = self.fullName?.familyName {
            return familyName
        }
        
        let characters = self.user.replacingOccurrences(of: ".", with: "")
        var result: String = ""
        for _ in 0..<10 {
            if let char = characters.randomElement() {
                result.append(char)
            }
        }
        return result
    }
    
    func username() -> String {
        return "\(firstname()).\(lastname())"
    }
}
