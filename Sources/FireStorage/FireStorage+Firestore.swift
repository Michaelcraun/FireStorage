//
//  File.swift
//  
//
//  Created by Michael Craun on 7/18/22.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

extension Store {
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
        //
        // Alright, so I've thought about this and we're going to take an arguably
        // unconventional approach to this. At runtime, we're going to load the collection
        // structure from a provided json file. This method will create a new Swift file and
        // add it to the project structure.
        
        public typealias FirestoreErrorCompletion = (Error?) -> Void
        
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
        
        public mutating func set(delegate: FirestoreDelegate) {
            self.delegate = delegate
            self.start()
        }
        
        public func start() {
            fetch(collection: actions)
            fetch(collection: armors)
            fetch(collection: occupations)
            fetch(collection: races)
            fetch(collection: subraces)
            fetch(collection: traits)
            fetch(collection: weapons)
        }
        
        private func fetch(collection: CollectionReference) {
            collection.getDocuments { snapshot, error in
                if let error = error {
                    registerStartup(error: error)
                } else if let snapshot = snapshot {
                    let data = snapshot.documents.map({ $0.data() })
                    delegate?.firestoreDidFetch(data: data, from: collection.collectionID)
                }
            }
        }
        
        private func registerStartup(error: Error) {
            Store.printDebug(error.localizedDescription)
            Store.firestore.registerError(message: error.localizedDescription)
            delegate?.firestoreDidEncounter(error: error)
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
