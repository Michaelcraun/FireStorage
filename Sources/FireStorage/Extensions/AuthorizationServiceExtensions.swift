//
//  File.swift
//  
//
//  Created by Michael Craun on 7/20/22.
//

import AuthenticationServices

extension ASAuthorizationAppleIDCredential {
    var username: String {
        let characters = self.user.replacingOccurrences(of: ".", with: "")
        var result: String = ""
        for _ in 0..<10 {
            if let char = characters.randomElement() {
                result.append(char)
            }
        }
        return "user\(result.uppercased())"
    }
}
