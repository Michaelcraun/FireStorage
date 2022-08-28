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
        public typealias AuthSignInCompletion = (Data?, Error?) -> Void
        public typealias AuthSignUpCompletion = (Data?, Error?) -> Void
        public typealias AuthSignOutCompletion = (Error?) -> Void
        public typealias AuthUserDataCompletion = (Data?, Error?) -> Void
        
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
        
        public func getUser(
            completion:AuthUserDataCompletion? = nil) {
                if let currentUser = currentUser {
                    Store.firestore.accounts.get(dataWithId: currentUser.uid) { data, error in
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
        
        public func signInWith(
            email: String,
            password: String,
            completion: @escaping AuthSignInCompletion) {
                auth.signIn(withEmail: email, password: password) { result, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(nil, error)
                    } else {
                        self.getUser { user, error in
                            completion(user, error)
                        }
                    }
                }
            }
        
        public func signInWith<T:AppUser>(
            apple credential: ASAuthorizationAppleIDCredential,
            nonce: String?,
            type: T.Type,
            completion: @escaping AuthSignInCompletion) {
                if let appleToken = credential.identityToken, let token = String(data: appleToken, encoding: .utf8) {
                    let cred = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: nonce)
                    auth.signIn(with: cred) { (result, error) in
                        if let error = error {
                            Store.firestore.registerError(message: error.localizedDescription)
                            completion(nil, error)
                        } else if let result = result {
                            let email = result.user.email
                            let uid = result.user.uid
                            let userData: [String : Any] = [
                                "first": credential.fullName?.givenName as Any,
                                "last": credential.fullName?.familyName as Any,
                                "username": credential.username
                            ]
                            let user = T(email: email, uid: uid, userData: userData)
                            Store.firestore.accounts.put(data: user, forId: result.user.uid) { reference, error in
                                self.getUser { user, error in
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
            completion: @escaping AuthSignUpCompletion) {
                auth.createUser(withEmail: email, password: password) { result, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(nil, error)
                    } else if let result = result {
                        let user = T(email: email, uid: result.user.uid, userData: userData)
                        Store.firestore.accounts.put(data: user, forId: result.user.uid) { reference, error in
                            self.getUser { user, error in
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
    }
}
