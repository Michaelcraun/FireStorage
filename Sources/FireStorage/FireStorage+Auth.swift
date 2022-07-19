//
//  File.swift
//  
//
//  Created by Michael Craun on 7/19/22.
//

import AuthenticationServices
import CryptoKit
import Foundation
import FirebaseAuth

extension Store {
    public struct Auth {
        public typealias AuthRemoveCompletion = (Error?) -> Void
        public typealias AuthSignInCompletion<T:AppUser> = (T?, Error?) -> Void
        public typealias AuthSignUpCompletion = () -> Void
        public typealias AuthSignOutCompletion = () -> Void
        public typealias AuthUserDataCompletion = (AppUser?, Error?) -> Void
        
        private var auth: FirebaseAuth.Auth { FirebaseAuth.Auth.auth() }
        private var currentNonce: String?
        public var currentUser: User? { auth.currentUser }
        
        mutating public func generateSha256Nonce() -> String {
            let charset: Array<Character> =
                Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            var result = ""
            var remainingLength = 32
            
            while remainingLength > 0 {
                let randoms: [UInt8] = (0 ..< 16).map { _ in
                    var random: UInt8 = 0
                    let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                    if errorCode != errSecSuccess {
                        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                    }
                    return random
                }
                
                randoms.forEach { random in
                    if random < charset.count {
                        result.append(charset[Int(random)])
                        remainingLength -= 1
                    }
                }
            }
            
            let inputData = Data(result.utf8)
            let hashedData = SHA256.hash(data: inputData)
            let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
            currentNonce = hashString
            return hashString
        }
        
        public func getUser<T:AppUser>(dataWithType type: T.Type, completion:AuthUserDataCompletion? = nil) {
            if let currentUser = currentUser {
                var user: T?
                var errors: [Error] = []
                
                let group = DispatchGroup()
                
                group.enter()
                Store.firestore.accounts.get(dataWithId: currentUser.uid, ofType: type) { data, error in
                    if let error = error {
                        errors.append(error)
                    } else if let data = data {
                        user = data
                    }
                    group.leave()
                }
                
                group.enter()
                Store.database.users.get(dataWithId: currentUser.uid, ofType: type) { data, error in
                    if let error = error {
                        errors.append(error)
                    } else if let data = data, user == nil {
                        user = data
                    }
                    group.leave()
                }
                
                if let user = user {
                    completion?(user, nil)
                } else {
                    let error = errors.map({ $0.localizedDescription }).joined()
                    Store.firestore.registerError(message: error)
                    completion?(nil, error)
                }
            } else {
                Store.firestore.registerError(message: "user not signed in")
                completion?(nil, "user not signed in")
            }
        }
        
        public func remove(user: AppUser, completion: @escaping AuthRemoveCompletion) {
            // This one is kinda tricky; when this method is called, it should:
            // 1. Allow the user class to delete all data it is assocated with
            // 2. Delete the user's profile from both RTD and Firestore (if either exists)
            // 3. Delete the user's auth account
            // 4. Sign the user out
            
            Store.endAllObservers()
            
            if let currentUser = currentUser {
                user.deleteAllData { error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(error)
                    } else {
                        let group = DispatchGroup()
                        var errors: [Error] = []
                        
                        group.enter()
                        Store.database.users.remove(id: currentUser.uid) { error in
                            if let error = error {
                                errors.append(error)
                            }
                            group.leave()
                        }
                        
                        group.enter()
                        Store.firestore.accounts.remove(id: currentUser.uid) { error in
                            if let error = error {
                                errors.append(error)
                            }
                            group.leave()
                        }
                        
                        group.notify(queue: .global()) {
                            if errors.isEmpty {
                                currentUser.delete { error in
                                    if let error = error {
                                        Store.firestore.registerError(message: error.localizedDescription)
                                    }
                                    completion(error)
                                }
                            } else {
                                let errors = errors.map({ $0.localizedDescription }).joined()
                                Store.firestore.registerError(message: errors)
                                completion(errors)
                            }
                        }
                    }
                }
            } else {
                Store.firestore.registerError(message: "user not signed in")
                completion("user not signed in")
            }
        }
        
        public func signInWith<T:AppUser>(email: String, password: String, type: T.Type, completion: @escaping AuthSignInCompletion<T>) {
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                } else {
                    self.getUser(dataWithType: type) { user, error in
                        completion(user as? T, error)
                    }
                }
            }
        }
        
        public func signInWith<T:AppUser>(apple credential: ASAuthorizationCredential, nonce: String?, type: T.Type, completion: AuthSignInCompletion<T>) {
            
        }
        
        public func signUpWith(email: String, password: String, userData: [String : Any], completion: @escaping AuthSignUpCompletion) {
            
        }
        
        public func signOut(completion: @escaping AuthSignOutCompletion) {
            Store.endAllObservers()
            
            
        }
    }
}
