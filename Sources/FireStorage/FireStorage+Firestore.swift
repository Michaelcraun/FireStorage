//
//  File.swift
//  
//
//  Created by Michael Craun on 7/18/22.
//

import FirebaseFirestore

extension FirebaseStorage {
    /* Firestore data structure
     * + NPCGen5e
     * +-> account
     * +-> action
     *     +-> source: String ("core", "community", or uid)
     * +-> armor
     *     +-> source: String ("core", "community", or uid)
     * +-> detail
     * +-> error
     * +-> filter
     * +-> error
     * +-> levelData
     * +-> occupation
     *     +-> source: String ("core", "community", or uid)
     * +-> public
     * +-> products
     * +-> purchase
     * +-> race
     *     +-> source: String ("core", "community", or uid)
     * +-> subrace
     *     +-> source: String ("core", "community", or uid)
     * +-> trait
     *     +-> source: String ("core", "community", or uid)
     * +-> weapon
     *     +-> source: String ("core", "community", or uid)
     */
    
    public struct Firestore {
        public typealias FirestoreErrorCompletion = (Error?) -> Void
        
        private var firestore: FirebaseFirestore.Firestore { FirebaseFirestore.Firestore.firestore() }
        
        // MARK: - Users
        public var accounts: CollectionReference { firestore.collection("account") }
        public func account(uid: String) -> DocumentReference { return accounts.document(uid) }
        
        // MARK: - Database
        public var actions: CollectionReference { firestore.collection("action") }
        public var armors: CollectionReference { firestore.collection("armors") }
        public var details: CollectionReference { firestore.collection("detail") }
        public var levelDatas: CollectionReference { firestore.collection("levelData") }
        public var occupations: CollectionReference { firestore.collection("occupation") }
        public var races: CollectionReference { firestore.collection("race") }
        public var subraces: CollectionReference { firestore.collection("subrace") }
        public var traits: CollectionReference { firestore.collection("trait") }
        public var weapons: CollectionReference { firestore.collection("weapon") }
        
        // MARK: - Characters
        public var characters: CollectionReference { firestore.collection("character") }
        
        // MARK: - Application
        public var errors: CollectionReference { firestore.collection("error") }
        public var products: CollectionReference { firestore.collection("product") }
        public var `public`: CollectionReference { firestore.collection("public") }
        public var purchases: CollectionReference { firestore.collection("purchase") }
        
        public func registerError(message: String, file: String = #file, function: String = #function, line: Int = #line, completion: FirestoreErrorCompletion? = nil) {
            let error = FirestoreError(
                error: message,
                file: URL(fileURLWithPath: file).lastPathComponent,
                function: function,
                line: line,
                date: Date().description)
            
            errors.put(data: error) { reference, error in
                if let error = error {
                    FirebaseStorage.printDebug("[ERROR] Unable to log error to database: \(error.localizedDescription)")
                    completion?(error)
                } else if let reference = reference {
                    FirebaseStorage.printDebug("[ERROR] \(message) logged to database [\(reference.documentID)]")
                    completion?(nil)
                }
            }
        }
    }
}

extension FirebaseStorage.Firestore {
    private struct FirestoreError: Codable {
        var error: String
        var file: String
        var function: String
        var line: Int
        var date: String
    }
}

extension CollectionReference {
    public typealias FirestoreGetCompletion<T:Codable> = (T?, Error?) -> Void
    public typealias FirestorePutCompletion = (DocumentReference?, Error?) -> Void
    public typealias FirestoreRemoveCompletion = (Error?) -> Void
    
    public func get<T:Codable>(dataWithId id: String, ofType type: T.Type, completion: @escaping FirestoreGetCompletion<T>) {
        self.document(id).getDocument { snapshot, error in
            if let error = error {
                FirebaseStorage.firestore.registerError(message: error.localizedDescription)
                completion(nil, error)
            } else if let data = snapshot?.data() {
                do {
                    let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                    let value = try JSONDecoder().decode(type, from: json)
                    completion(value, nil)
                } catch {
                    FirebaseStorage.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                }
            } else {
                FirebaseStorage.firestore.registerError(message: "No data available [\(id)]")
                completion(nil, "No data available [\(id)]")
            }
        }
    }
    
    public func put<T:Codable>(data: T, forId id: String? = nil, completion: FirestorePutCompletion? = nil) {
        let documentId = id ?? self.document().documentID
        let document = self.document(documentId)
        
        do {
            let encoded = try JSONEncoder().encode(data)
            if let json = try JSONSerialization.jsonObject(with: encoded, options: .allowFragments) as? [String : Any] {
                document.setData(json, merge: true) { error in
                    if let error = error {
                        FirebaseStorage.firestore.registerError(message: error.localizedDescription)
                    }
                    completion?(document, error)
                }
            }
        } catch {
            completion?(nil, error)
        }
    }
    
    public func remove(id: String, completion: FirestoreRemoveCompletion? = nil) {
        self.document(id).delete { error in
            if let error = error {
                FirebaseStorage.firestore.registerError(message: error.localizedDescription)
            }
            completion?(error)
        }
    }
}
