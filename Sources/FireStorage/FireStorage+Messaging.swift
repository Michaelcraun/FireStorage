//
//  File.swift
//  
//
//  Created by Michael Craun on 7/21/22.
//

import Foundation
import FirebaseMessaging

extension Store {
    public struct Messaging {
        public typealias MessagingAuthorizationCompletion = (Bool, Error?) -> Void
        public typealias MessagingSendCompletion = (Error?) -> Void
        public typealias MessagingTokenCompletion = (String?, Error?) -> Void
        
        private var messaging: FirebaseMessaging.Messaging { FirebaseMessaging.Messaging.messaging() }
        private var delegate: (UNUserNotificationCenterDelegate & MessagingDelegate)?
//        private var serverKey: String?
        
        public mutating func set<T:UNUserNotificationCenterDelegate & MessagingDelegate>(delegate: T) {
                self.delegate = delegate
            }
        
//        public mutating func set(serverKey: String) {
//            self.serverKey = serverKey
//        }
        
        public func setNotificationCategories() {
            
        }
        
        public func registerForRemoteNotificationsWith(
            options: UNAuthorizationOptions = [.alert, .badge, .sound],
            completion: @escaping MessagingAuthorizationCompletion) {
                guard let delegate = delegate else {
                    Store.firestore.registerError(message: "\(#function) was called before delegate was set")
                    Store.printDebug("\(#function) was called before delegate was set! Please call set(delegate:) before continuing.")
                    return completion(false, "\(#function) was called before delegate was set")
                }
                
                messaging.delegate = delegate
                UNUserNotificationCenter.current().delegate = delegate
                UNUserNotificationCenter.current().requestAuthorization(options: options) { allowed, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(false, error)
                    } else if !allowed {
                        Store.firestore.registerError(message: "user did not allow notifications")
                        completion(false, nil)
                    } else {
                        setNotificationCategories()
                        completion(true, nil)
                    }
                }
            }
        
        public func token(completion: @escaping MessagingTokenCompletion) {
            messaging.token { token, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                } else if let token = token {
                    completion(token, nil)
                }
            }
        }
        
//        public func send(
//            message: String,
//            title: String,
//            to tokens: [String],
//            completion: MessagingSendCompletion? = nil) {
//                guard let serverKey = serverKey else {
//                    Store.firestore.registerError(message: "no server key supplied")
//                    Store.printDebug("No server key supplied! Please call set(serverKey:) before continuing.")
//                    Store.printDebug("You can get your sever key from your Firebase project console under the Cloud Messaging tab.")
//                    completion?("no server key supplied")
//                    return
//                }
//
//                if let url = URL(string: "https://fcm.googleapis.com/fcm/send") {
//                    let payload: [String : Any] = [
//                        "notification" : [
//                            "title" : title,
//                            "badge" : 1,
//                            "body" : message,
//                            "sound" : "default"
//                        ]
//                    ]
//
//                    var request = URLRequest(url: url)
//                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//                    request.setValue(serverKey, forHTTPHeaderField: "Authorization")
//                    request.httpMethod = "POST"
//                    request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
//                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
//                        if let error = error {
//                            Store.firestore.registerError(message: error.localizedDescription)
//                            completion?(error)
//                        } else if let response = response as? HTTPURLResponse, response.statusCode != 200 {
//                            Store.firestore.registerError(message: "http status code \(response.statusCode)")
//                            completion?("http status code \(response.statusCode)")
//                        } else {
//                            Store.printDebug("message sent successfully")
//                            completion?(nil)
//                        }
//                    }
//                    task.resume()
//                } else {
//                    Store.firestore.registerError(message: "could not create url")
//                    completion?("could not create url")
//                }
//            }
    }
}
