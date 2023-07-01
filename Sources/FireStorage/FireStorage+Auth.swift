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
        public typealias AuthSignUpCompletion<T:AppUser> = (T?, Error?) -> Void
        public typealias AuthSignOutCompletion = (Error?) -> Void
        public typealias AuthUserDataCompletion<T:AppUser> = (T?, Error?) -> Void
        
        private var auth: FirebaseAuth.Auth { FirebaseAuth.Auth.auth() }
        public var currentUser: User? { auth.currentUser }
        
        public func generateNonce() -> String? {
            var randomBytes = [UInt8](repeating: 0, count: 32)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            if errorCode != errSecSuccess {
                let message = "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                Store.firestore.registerError(message: message)
                return nil
            }
            
            let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            return String(randomBytes.map { byte in
                // Pick a random character from the set, wrapping around if needed.
                charset[Int(byte) % charset.count]
            })
        }
        
        public func generateSha256(from input: String) -> String? {
            let inputData = Data(input.utf8)
            let hashedData = SHA256.hash(data: inputData)
            let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
            return hashString
        }
        
        public func getUser<T:AppUser>(
            dataWithType type: T.Type,
            completion:AuthUserDataCompletion<T>? = nil) {
                if let currentUser = currentUser {
                    Store.firestore.accounts.get(dataWithId: currentUser.uid, ofType: type) { data, error in
                        if let error = error {
                            Store.firestore.registerError(message: error.localizedDescription)
                            completion?(nil, error)
                        } else if let data = data {
                            completion?(data, nil)
                        }
                    }
                } else {
                    Store.firestore.registerError(message: "user not signed in")
                    completion?(nil, "user not signed in")
                }
            }
        
        public func remove(
            user: AppUser,
            completion: @escaping AuthRemoveCompletion) {
                Store.endAllObservers()
                
                if let currentUser = currentUser {
                    user.deleteAllData { error in
                        if let error = error {
                            Store.firestore.registerError(message: error.localizedDescription)
                            completion(error)
                        } else {
                            Store.firestore.accounts.remove(id: currentUser.uid) { error in
                                if let error = error {
                                    Store.firestore.registerError(message: error.localizedDescription)
                                    completion(error)
                                } else {
                                    currentUser.delete { error in
                                        if let error = error {
                                            Store.firestore.registerError(message: error.localizedDescription)
                                        }
                                        completion(error)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Store.firestore.registerError(message: "user not signed in")
                    completion("user not signed in")
                }
            }
        
        public func signInWith<T:AppUser>(
            email: String,
            password: String,
            type: T.Type,
            completion: @escaping AuthSignInCompletion<T>) {
                auth.signIn(withEmail: email, password: password) { result, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(nil, error)
                    } else {
                        self.getUser(dataWithType: type) { user, error in
                            completion(user, error)
                        }
                    }
                }
            }
        
        public func signInWith<T:AppUser>(
            apple credential: ASAuthorizationAppleIDCredential,
            nonce: String?,
            type: T.Type,
            completion: @escaping AuthSignInCompletion<T>) {
                if let appleToken = credential.identityToken, let token = String(data: appleToken, encoding: .utf8) {
                    let cred = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: nonce)
                    auth.signIn(with: cred) { (result, error) in
                        if let error = error {
                            Store.firestore.registerError(message: error.localizedDescription)
                            completion(nil, error)
                        } else if let result = result {
                            let email = result.user.email
                            let uid = result.user.uid
                            let first = credential.firstname()
                            let last = credential.lastname()
                            let userData: [String : Any] = [
                                "first": first,
                                "last": last,
                                "username": "\(first.lowercased()).\(last.lowercased())"
                            ]
                            let user = T(email: email, uid: uid, userData: userData)
                            Store.firestore.accounts.put(data: user, forId: result.user.uid) { reference, error in
                                self.getUser(dataWithType: type) { user, error in
                                    completion(user, error)
                                }
                            }
                        } else {
                            Store.firestore.registerError(message: "unknown error")
                            completion(nil, "unknown error")
                        }
                    }
                } else {
                    Store.firestore.registerError(message: "Unable to fetch and serialize identity token")
                    completion(nil, "Unable to fetch and serialize identity token")
                }
            }
        
        public func signUpWith<T:AppUser>(
            email: String,
            password: String,
            userData: [String : Any],
            type: T.Type,
            completion: @escaping AuthSignUpCompletion<T>) {
                #warning("TODO: Should I handle usernames here or should the app handle it?")
                auth.createUser(withEmail: email, password: password) { result, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(nil, error)
                    } else if let result = result {
                        let user = T(email: email, uid: result.user.uid, userData: userData)
                        Store.firestore.accounts.put(data: user, forId: result.user.uid) { reference, error in
                            self.getUser(dataWithType: type) { user, error in
                                completion(user, error)
                            }
                        }
                    } else {
                        Store.firestore.registerError(message: "unknown error")
                        completion(nil, "unknown error")
                    }
                }
            }
        
        public func signOut(completion: @escaping AuthSignOutCompletion) {
            Store.endAllObservers()
            
            do {
                try auth.signOut()
                completion(nil)
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
                completion(error)
            }
        }
        
        public func errorCode(from error: Error) -> AuthErrorCode.Code? {
            return AuthErrorCode.Code(rawValue: error._code)
        }
    }
}
