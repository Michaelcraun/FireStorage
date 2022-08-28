//
//  File.swift
//  
//
//  Created by Michael Craun on 7/18/22.
//

import FirebaseFirestore

extension Store {
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
        public typealias FirestoreCompendiumCompletion = (Error?) -> Void
        
        private var firestore: FirebaseFirestore.Firestore { FirebaseFirestore.Firestore.firestore() }
        
        // MARK: - Users
        public var accounts: CollectionReference { firestore.collection("account") }
        
        // MARK: - Database
        public var actions: CollectionReference { firestore.collection("action") }
        public var armors: CollectionReference { firestore.collection("armor") }
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
        
        public func endAllObservers() {
            
        }
        
        public func registerError(
            message: String,
            file: String = #file,
            function: String = #function,
            line: Int = #line,
            completion: FirestoreErrorCompletion? = nil) {
                let error = FirestoreError(
                    error: message,
                    file: URL(fileURLWithPath: file).lastPathComponent,
                    function: function,
                    line: line,
                    date: Date().description)
                
                errors.put(data: error) { reference, error in
                    if let error = error {
                        Store.printDebug("[ERROR] Unable to log error to database: \(error.localizedDescription)")
                        completion?(error)
                    } else if let reference = reference {
                        Store.printDebug("[ERROR] \(message) logged to database [\(reference.documentID)]")
                        completion?(nil)
                    }
                }
            }
    }
}

extension Store.Firestore {
    private struct FirestoreError: Codable {
        var error: String
        var file: String
        var function: String
        var line: Int
        var date: String
    }
}

extension CollectionReference {
    public typealias FirestoreGetCompletion = (Data?, Error?) -> Void
    public typealias FirestoreGetArrayCompletion = ([Data]?, Error?) -> Void
    public typealias FirestorePutCompletion = (DocumentReference?, Error?) -> Void
    public typealias FirestoreRemoveCompletion = (Error?) -> Void
    public typealias FirestoreObserveCompletion = ([Data]?, [Data]?, [Data]?, Error?) -> Void
    
    public func get(
        completion: @escaping FirestoreGetArrayCompletion) {
            self.getDocuments { snapshot, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                } else if let snapshot = snapshot {
                    var errors: [String] = []
                    let objects: [Data] = snapshot.documents.compactMap({
                        do {
                            let json = try JSONSerialization.data(withJSONObject: $0, options: .prettyPrinted)
                            return json
                        } catch {
                            errors.append(error.localizedDescription)
                            return nil
                        }
                    })
                    
                    if !errors.isEmpty {
                        let combined = errors.joined(separator: ",")
                        let error = "Encountered errors while fetching documents from \(self.collectionID): \(combined)"
                        Store.firestore.registerError(message: error)
                        completion(objects, error)
                    }
                } else {
                    Store.firestore.registerError(message: "No data available for \(self.collectionID)")
                    completion(nil, "No data available for \(self.collectionID)")
                }
            }
        }
    
    public func get(
        dataWithId id: String,
        completion: @escaping FirestoreGetCompletion) {
            self.document(id).getDocument { snapshot, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                } else if let data = snapshot?.data() {
                    do {
                        let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                        completion(json, nil)
                    } catch {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(nil, error)
                    }
                } else {
                    Store.firestore.registerError(message: "No data available [\(id)]")
                    completion(nil, "No data available [\(id)]")
                }
            }
        }
    
    public func put<T:Codable>(
        data: T,
        forId id: String? = nil,
        completion: FirestorePutCompletion? = nil) {
        let documentId = id ?? self.document().documentID
        let document = self.document(documentId)
        
        do {
            let encoded = try JSONEncoder().encode(data)
            if let json = try JSONSerialization.jsonObject(with: encoded, options: .allowFragments) as? [String : Any] {
                document.setData(json, merge: true) { error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                    }
                    completion?(document, error)
                }
            }
        } catch {
            completion?(nil, error)
        }
    }
    
    public func remove(
        id: String,
        completion: FirestoreRemoveCompletion? = nil) {
        self.document(id).delete { error in
            if let error = error {
                Store.firestore.registerError(message: error.localizedDescription)
            }
            completion?(error)
        }
    }
    
    public func observeChildren(
        completion: @escaping FirestoreObserveCompletion) {
        self.addSnapshotListener { snapshot, error in
            if let error = error {
                Store.firestore.registerError(message: error.localizedDescription)
                completion(nil, nil, nil, error)
            } else if let snapshot = snapshot {
                var new: [Data] = []
                var updated: [Data] = []
                var removed: [Data] = []
                
                for change in snapshot.documentChanges {
                    let data = change.document.data()
                    
                    do {
                        let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                        
                        switch change.type {
                        case .added: new.append(json)
                        case .modified: updated.append(json)
                        case .removed: removed.append(json)
                        }
                    } catch {
                        Store.firestore.registerError(message: error.localizedDescription)
                    }
                }
                
                completion(new, updated, removed, nil)
            } else {
                Store.firestore.registerError(message: "No data found [\(self.collectionID)]")
                completion(nil, nil, nil, "No data found [\(self.collectionID)]")
            }
        }
    }
}

extension Query {
    public typealias FirestoreObserveCompletion = ([Data]?, [Data]?, [Data]?, Error?) -> Void
    
    public func observe(
        completion: @escaping FirestoreObserveCompletion) {
        self.addSnapshotListener { snapshot, error in
            if let error = error {
                Store.firestore.registerError(message: error.localizedDescription)
                completion(nil, nil, nil, error)
            } else if let snapshot = snapshot {
                var new: [Data] = []
                var updated: [Data] = []
                var removed: [Data] = []
                
                for change in snapshot.documentChanges {
                    let data = change.document.data()
                    
                    do {
                        let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                        
                        switch change.type {
                        case .added: new.append(json)
                        case .modified: updated.append(json)
                        case .removed: removed.append(json)
                        }
                    } catch {
                        Store.firestore.registerError(message: error.localizedDescription)
                    }
                }
                
                completion(new, updated, removed, nil)
            } else {
                Store.firestore.registerError(message: "No data found [\(self.description)]")
                completion(nil, nil, nil, "No data found [\(self.description)]")
            }
        }
    }
}
