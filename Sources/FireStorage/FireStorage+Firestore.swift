//
//  File.swift
//  
//
//  Created by Michael Craun on 7/18/22.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

extension Store {
    public typealias FirestoreBooleanCompletion = (Bool, Error?) -> Void
    public typealias FirestoreErrorCompletion = (Error?) -> Void
    
    public struct Firestore {
        // GOAL: I want this to be agnostic of what database it is hooked up to.
        // Thus, I need some way to add to and/or initialize an array of
        // CollectionReference to store and retrieve data from the Firestore database
        //
        // I also want the calls to this struct to be as simplistic and straight-
        // forward as possible. Something like this:
        //
        // Store.firestore.set(structure: ...)
        // Store.firestore.add(collection: "action")
        // Store.firestore.action.get(...)
        
        private var firestore: FirebaseFirestore.Firestore { FirebaseFirestore.Firestore.firestore() }
        private var delegate: FirestoreDelegate? 
        
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
        public var publicData: [String : Any] = [ : ]
        
        // MARK: - Data Caching Support
        private var lastUpdateKey: String = "Last_Update"
        private var lastCheckKey: String = "Last_Check"
        
        public func endAllObservers() {
            
        }
        
        public func registerError(
            message: String,
            file: String = #file,
            function: String = #function,
            line: Int = #line,
            completion: FirestoreErrorCompletion? = nil) {
                Store.printDebug("\(message) This error will be registered to the database.")
                
                if Store.verboseLoggingEnabled {
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
                } else {
                    Store.reportVerboseLoggingDisabled()
                    completion?(nil)
                }
            }
        
        public mutating func set(delegate: FirestoreDelegate) {
            self.delegate = delegate
            self.start()
        }
        
        public func start() {
            checkForDatabaseUpdates { error in
                self.fetch(collection: self.actions)
                self.fetch(collection: self.armors)
                self.fetch(collection: self.occupations)
                self.fetch(collection: self.races)
                self.fetch(collection: self.subraces)
                self.fetch(collection: self.traits)
                self.fetch(collection: self.weapons)
            }
        }
        
        /// Conditionally fetches the date the database was last updated. Will not attempt to fetch if the last attempt to fetch
        /// was within the last 24 hours.
        private func checkForDatabaseUpdates(completion: @escaping FirestoreErrorCompletion) {
            func getLastUpdateDate(completion: @escaping (Date?, Error?) -> Void) {
                self.public.getDocuments { snapshot, error in
                    if let error = error {
                        Store.firestore.registerError(message: error.localizedDescription)
                        return completion(nil, error)
                    } else if let timestamp = snapshot?.documents.first?.data()["lastUpdate"] as? Timestamp {
                        return completion(timestamp.dateValue(), nil)
                    } else {
                        return completion(Date(), nil)
                    }
                }
            }
            
            if let lastCheckDate = (Store.cache.get(valueFor: lastCheckKey) as? String)?.date() {
                if lastCheckDate.timeIntervalSince(Date()) > 24*60*60 {
                    getLastUpdateDate { date, error in
                        if let date = date, error == nil {
                            Store.cache.set(value: date.description, for: lastCheckKey)
                        }
                        return completion(nil)
                    }
                } else {
                    return completion("check completed within 24 hours")
                }
            } else {
                return completion("first check")
            }
            
            // 3. Gather the date the database was last updated
            getLastUpdateDate { date, error in
                if let date = date, error == nil {
                    Store.cache.set(value: date.description, for: lastCheckKey)
                }
                return completion(nil)
            }
        }
        
        private func fetch(collection: CollectionReference) {
            func fetchDataFromDatabase() {
                collection.getDocuments { snapshot, error in
                    if let error = error {
                        registerStartup(error: error)
                    } else if let snapshot = snapshot {
                        let data = snapshot.documents.map({ $0.data() })
                        // Cache the fetched data
                        #warning("TODO: Cache the fetched data")
                        delegate?.firestoreDidFetch(data: data, from: collection.collectionID)
                    }
                }
            }
            
            do {
                // Attempt to fetch the cached data first
                guard let data = try Store.cache.fetch(jsonFromFileNamed: collection.collectionID) else {
                    // If none exists, fetch data from the database
                    return fetchDataFromDatabase()
                }
                delegate?.firestoreDidFetch(data: data, from: collection.collectionID)
                return
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
                delegate?.firestoreDidFetch(data: [], from: collection.collectionID)
            }
        }
        
        private func registerStartup(error: Error) {
            Store.firestore.registerError(message: error.localizedDescription)
            delegate?.firestoreDidEncounter(error: error)
        }
    }
}

// MARK: - Error Structure
extension Store.Firestore {
    private struct FirestoreError: Codable {
        var error: String
        var file: String
        var function: String
        var line: Int
        var date: String
    }
}

// MARK: - CollectionReference Helpers
extension CollectionReference {
    public typealias FirestoreGetCompletion<T:Codable> = (T?, Error?) -> Void
    public typealias FirestoreGetArrayCompletion<T:Codable> = ([T]?, Error?) -> Void
    public typealias FirestorePutCompletion = (DocumentReference?, Error?) -> Void
    public typealias FirestoreRemoveCompletion = (Error?) -> Void
    public typealias FirestoreObserveCompletion<T:Codable> = ([T]?, [T]?, [T]?, Error?) -> Void
    
    public func get<T:Codable>(
        ofType type: T.Type,
        completion: @escaping FirestoreGetArrayCompletion<T>) {
            self.getDocuments { snapshot, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                } else if let snapshot = snapshot {
                    var errors: [String] = []
                    let objects: [T] = snapshot.documents.compactMap({
                        do {
                            let value = try $0.data(as: type)
                            return value
                        } catch {
                            errors.append(error.localizedDescription)
                            return nil
                        }
                    })
                    
                    if errors.isEmpty {
                        completion(objects, nil)
                    } else {
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
    
    public func get<T:Codable>(
        dataWithId id: String,
        ofType type: T.Type,
        completion: @escaping FirestoreGetCompletion<T>) {
            self.document(id).getDocument { snapshot, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, error)
                } else if let snapshot = snapshot {
                    do {
                        let value = try snapshot.data(as: type)
                        completion(value, nil)
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
    
    #warning("Should this be updated to handle arrays?")
    public func put<T:Codable>(
        data: T,
        forId id: String? = nil,
        completion: FirestorePutCompletion? = nil) {
            let documentId = id ?? self.document().documentID
            let document = self.document(documentId)
            
            do {
                let encoded = try JSONEncoder().encode(data)
                if let json = try JSONSerialization.jsonObject(with: encoded, options: .fragmentsAllowed) as? [String : Any] {
                    document.setData(json, merge: true) { error in
                        if let error = error {
                            Store.firestore.registerError(message: error.localizedDescription)
                        }
                        completion?(document, error)
                    }
                } else {
                    Store.firestore.registerError(message: "could not serialize object [\(data)]")
                    completion?(nil, "could not serialize object")
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
    
    public func observeChildren<T:Codable>(
        dataOfType type: T.Type,
        completion: @escaping FirestoreObserveCompletion<T>) {
            self.addSnapshotListener { snapshot, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, nil, nil, error)
                } else if let snapshot = snapshot {
                    var new: [T] = []
                    var updated: [T] = []
                    var removed: [T] = []
                    
                    for change in snapshot.documentChanges {
                        let data = change.document.data()
                        
                        do {
                            let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                            let object = try JSONDecoder().decode(type, from: json)
                            
                            switch change.type {
                            case .added: new.append(object)
                            case .modified: updated.append(object)
                            case .removed: removed.append(object)
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

// MARK: - Query Helpers
extension Query {
    public typealias FirestoreObserveCompletion<T:Codable> = ([T]?, [T]?, [T]?, Error?) -> Void
    
    public func observe<T:Codable>(
        dataOfType type: T.Type,
        completion: @escaping FirestoreObserveCompletion<T>) {
            let listener = self.addSnapshotListener { snapshot, error in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    completion(nil, nil, nil, error)
                } else if let snapshot = snapshot {
                    var new: [T] = []
                    var updated: [T] = []
                    var removed: [T] = []
                    
                    for change in snapshot.documentChanges {
                        let document = change.document
                        
                        do {
                            let object = try document.data(as: type)
                            
                            switch change.type {
                            case .added: new.append(object)
                            case .modified: updated.append(object)
                            case .removed: removed.append(object)
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
