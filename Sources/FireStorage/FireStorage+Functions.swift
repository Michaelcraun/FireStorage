//
//  File 2.swift
//  
//
//  Created by Michael Craun on 7/21/22.
//

import Foundation
import FirebaseFunctions

extension Store {
    public struct Functions {
        public typealias FunctionCompletion = (HTTPSCallableResult?, Error?) -> Void
        
        private var functions: FirebaseFunctions.Functions { FirebaseFunctions.Functions.functions() }
        
        public func callFunctionWith(
            name: String,
            with data: [String : Any],
            completion: FunctionCompletion? = nil) {
                functions.httpsCallable(name).call(data) { result, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion?(nil, error)
                    } else if let result = result {
                        completion?(result, nil)
                    } else {
                        Store.firestore.registerError(message: "unable to complete call")
                        completion?(nil, "unable to complete call")
                    }
                }
            }
    }
}
