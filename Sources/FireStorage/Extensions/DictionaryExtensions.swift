//
//  File.swift
//  
//
//  Created by Michael Craun on 9/1/22.
//

import Foundation

extension Dictionary {
    func json() -> String {
        do {
            let json = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(data: json, encoding: .utf8) ?? "Could not convert to json"
        } catch {
            return "Could not convert to json [\(error.localizedDescription)]"
        }
    }
}
