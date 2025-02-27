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
        //
        // The above might be a pipe dream. Should contemplate this for a future release
        // and come up with a better solution.
        
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
        
        public func endAllObservers() {
            
        }
        
        public func registerError(
            message: String,
            file: String = #file,
            function: String = #function,
            line: Int = #line,
            completion: FirestoreErrorCompletion? = nil) {
                if environment == .unitTesting {
                    Store.printDebug("[WARN] Error reporting disabled while unit testing!")
                    Store.printDebug(message)
                    completion?(nil)
                    return
                }
                
                let error = FirestoreError(
                    error: message,
                    file: URL(fileURLWithPath: file).lastPathComponent,
                    function: function,
                    line: line,
                    date: Date().description)
                
                errors.put(data: error) { reference, error in
                    if let error = error {
                        Store.printDebug("[ERROR] Unable to log \(message) to database: \(error.localizedDescription)")
                        completion?(error)
                    } else if let reference = reference {
                        Store.printDebug("\(message) logged to database [\(reference.documentID)]")
                        completion?(nil)
                    }
                }
            }
        
        public mutating func set(delegate: FirestoreDelegate) {
            self.delegate = delegate
            self.start()
        }
        
        public func start() {
            self.fetch(collection: self.actions)
            self.fetch(collection: self.armors)
            self.fetch(collection: self.occupations)
            self.fetch(collection: self.races)
            self.fetch(collection: self.subraces)
            self.fetch(collection: self.traits)
            self.fetch(collection: self.weapons)
        }
        
        // If either of the following conditions are true, then data should be fetced from the
        // database and cached locally:
        // 1. The database tells us we should -> The database has a public.database document stored
        //    which contains a list of updates. When the database is updated, this array should also be
        //    updated to contain a new update Timestamp.
        // 2. A specific amount of time has passed -> This is dictated by Store.maximumCacheAge and
        //    automatically handled by the Cache logic itself.
        private func fetch(collection: CollectionReference) {
            // Query the database to check for a database update
            checkForDatabaseUpdates { error in
                // If an error is returned, we need to fetch from the database; otherwise, continue.
                if let error = error {
                    self.fetchAndCache(collection: collection, reason: error.localizedDescription)
                    return
                }
                
                // Caching automatically handles when we need to not use cached data, so use
                // the data that comes back from fetching from the cache, if we have it...
                if let cached = Store.cache.fetch(jsonFromFileNamed: collection.collectionID) {
                    self.delegate?.firestoreDidFetch(data: cached, from: collection.collectionID)
                    return
                }
                
                // Otherwise, fetch data from the database and cache it.
                self.fetchAndCache(collection: collection, reason: "cache expired or empty")
            }
        }
        
        // Returning an error via the completion of this function indicates that data should be fetched
        // from the database.
        private func checkForDatabaseUpdates(completion: @escaping FirestoreErrorCompletion) {
            // Update timestamps are stored in the public document
            self.public.getDocuments { snapshot, error in
                // If there's an error while fetching the document; otherwise, process the documents here
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                    return completion(error)
                }
                
                // Store any possible error to complete later so that we can process all documents,
                // if needed...
                var error: Error?
                for document in snapshot?.documents ?? [] {
                    switch document.documentID {
                    case "database":
                        let latest = (document.data()["updates"] as? [Timestamp])?.last?.dateValue()
                        let latestCached = Store.cache.getLatestDatabaseUpdate()
                        if let database = latest, let cached = latestCached {
                            let elapsed = database.timeIntervalSince(cached)
                            if elapsed >= Store.maximumCacheAge {
                                error = "elapsed time greater than allotted [\(elapsed) >= \(Store.maximumCacheAge)]"
                            }
                        }
                    // Process any other documents that might be stored in the public collection here...
                    // case "someFutureCollection":
                    // ...
                    default:
                        Store.printDebug("unhandled public document [\(document.documentID)]")
                    }
                }
                
                return completion(error)
            }
        }
        
        // Fetch data from the database and cache it locally.
        // Cache automatically stores cache date, so no need to do it manually.
        private func fetchAndCache(collection: CollectionReference, reason: String) {
            let collectionID = collection.collectionID
            Store.printDebug("fetching data from database for \(collectionID) [\(reason)]")
            
            collection.getDocuments { snapshot, error in
                if let error = error {
                    registerStartup(error: error)
                } else if let snapshot = snapshot {
                    let data = snapshot.documents.map({
                        if let jsonData = try? JSONSerialization.data(withJSONObject: $0.data()),
                           let json = String(data: jsonData, encoding: .utf8) {
                            Store.printDebug("Fetched object from \(collectionID) collection: \(json)")
                        } else {
                            Store.printDebug("Could not serialize data from: \($0.data())")
                        }
                        
                        return $0.data()
                    })
                    Store.cache.cache(data: data, filename: collectionID)
                    delegate?.firestoreDidFetch(data: data, from: collectionID)
                }
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
    public typealias FirestoreObserveCompletion<T:Codable> = (_ new: [T]?, _ updated: [T]?, _ removed: [T]?, _ error: Error?) -> Void
    
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
        query: Query? = nil,
        completion: @escaping FirestoreObserveCompletion<T>) {
            func handleListenerCallBack(snapshot: QuerySnapshot?, error: Error?) {
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
                            let errorDescription = "Unable to parse \(String(describing: T.self)) data"
                            Store.firestore.registerError(message: "\(errorDescription) [\(error.localizedDescription)]")
                        }
                    }
                    
                    completion(new, updated, removed, nil)
                } else {
                    Store.firestore.registerError(message: "No data found [\(self.collectionID)]")
                    completion(nil, nil, nil, "No data found [\(self.collectionID)]")
                }
            }
            
            if let query = query {
                query.addSnapshotListener { snapshot, error in
                    handleListenerCallBack(snapshot: snapshot, error: error)
                }
            } else {
                self.addSnapshotListener { snapshot, error in
                    handleListenerCallBack(snapshot: snapshot, error: error)
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
