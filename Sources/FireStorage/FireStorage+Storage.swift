//
//  File.swift
//  
//
//  Created by Michael Craun on 7/19/22.
//

import Foundation
import FirebaseStorage

extension Store {
    public struct Storage {
        private var reference: StorageReference { FirebaseStorage.Storage.storage().reference() }
        
        public var accounts: StorageReference { reference.child("account") }
        public var characters: StorageReference { reference.child("character") }
        public var products: StorageReference { reference.child("product") }
    }
}

extension StorageReference {
    public typealias StorageGetCompletion = (Data?, Error?) -> Void
    public typealias StoragePutCompletion = (Error?) -> Void
    public typealias StorageRemoveCompletion = StoragePutCompletion
    
    public func get(id: String, completion: @escaping StorageGetCompletion) {
        self.child(id).getData(maxSize: Int64(Store.maxDownloadMegabytes * 1024 * 1024)) { data, error in
            if let error = error {
                Store.firestore.registerError(message: error.localizedDescription)
                completion(nil, error)
            } else if let data = data {
                completion(data, nil)
            }
        }
    }
    
    public func put(data: Data, withId id: String, completion: StoragePutCompletion? = nil) {
        self.child(id).putData(data) { metadata, error in
            if let error = error {
                Store.firestore.registerError(message: error.localizedDescription)
            }
            completion?(error)
        }
    }
    
    public func remove(id: String, completion: StorageRemoveCompletion? = nil) {
        self.child(id).delete { error in
            if let error = error {
                Store.firestore.registerError(message: error.localizedDescription)
            }
            completion?(error)
        }
    }
}
