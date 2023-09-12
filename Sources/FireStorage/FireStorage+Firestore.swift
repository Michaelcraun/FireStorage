import FirebaseFirestore
import FirebaseFirestoreSwift

extension Store {
    public typealias FirestoreBooleanCompletion = (Bool, Error?) -> Void
    public typealias FirestoreErrorCompletion = (Error?) -> Void
    
    public struct Firestore {
        public typealias FirestoreErrorCompletion = (Error?) -> Void
        public typealias FirestoreFetchCompletion = (_ error: Error?, _ data: [[String : Any]]?, _ collection: CollectionReference) -> Void
        
        public let structure: FirestoreStructurable
        private var delegate: FirestoreDelegate?
        
        private var lastCheckKey: String = "Last_Check"
        
        init() {
            self.structure = EmptyFirestoreStructure()
        }
        
        init(structure: FirestoreStructurable) {
            self.structure = structure
        }
        
        public func endAllObservers() {
            // TODO: Implement?
        }
        
        public func registerError(
            message: String,
            file: String = #file,
            function: String = #function,
            line: Int = #line,
            completion: FirestoreErrorCompletion? = nil) {
                if Store.verboseLoggingEnabled {
                    Store.printDebug("\(message) This error will be registered to the database.")
                    
                    let error = FirestoreError(error: message, file: file, function: function, line: line)
                    structure.errors.put(data: error) { reference, error in
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
            self.checkForDatabaseUpdates { error in
                for collection in self.structure.startupCollections {
                    self.fetch(collection: collection)
                }
            }
        }
        
        /// Conditionally fetches the date the database was last updated. Will not attempt to fetch if the last attempt to fetch
        /// was within the last 24 hours.
        private func checkForDatabaseUpdates(completion: @escaping FirestoreErrorCompletion) {
            func getLastUpdateDate(completion: @escaping (Date?, Error?) -> Void) {
                structure.public.getDocuments { snapshot, error in
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
                            Store.cache.setLatestUpdate(date: date)
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
                    Store.cache.setLatestUpdate(date: date)
                }
                return completion(nil)
            }
        }
        
        private func fetch(collection: CollectionReference) {
            func fetchAndCache() {
                collection.getDocuments { snapshot, error in
                    if let error = error {
                        registerStartup(error: error)
                    } else if let snapshot = snapshot {
                        let data = snapshot.documents.map({
                            #if DEBUG
                            if Store.verboseLoggingEnabled {
                                if let jsonData = try? JSONSerialization.data(withJSONObject: $0.data()),
                                   let json = String(data: jsonData, encoding: .utf8) {
                                    Store.printDebug("Fetched object from \(collection.collectionID) collection: \(json)")
                                } else {
                                    Store.printDebug("Could not serialize data from: \($0.data())")
                                }
                            }
                            #endif
                            
                            return $0.data()
                        })
                        Store.cache.cache(data: data, filename: collection.collectionID)
                        delegate?.firestoreDidFetch(data: data, from: collection.collectionID)
                    }
                }
            }
            
            // If caching is telling us we should fetch...
            if Store.cache.shouldFetch {
                fetchAndCache()
                return
            }
            
            // Otherwise, attempt to fetch the cached data first
            if let data = Store.cache.fetch(jsonFromFileNamed: collection.collectionID) {
                delegate?.firestoreDidFetch(data: data, from: collection.collectionID)
                return
            }
            
            // If that fails, default to fetching data from the database
            fetchAndCache()
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
        var date: String = Date().description
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
                            Store.firestore.registerError(message: error.localizedDescription)
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
            self.addSnapshotListener { snapshot, error in
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
