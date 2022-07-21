//
//  File.swift
//  
//
//  Created by Michael Craun on 7/18/22.
//

import Foundation
import FirebaseDatabase

extension Store {
    public struct Database {
        public var reference: DatabaseReference { FirebaseDatabase.Database.database().reference() }
        
        // MARK: - Database
        public var database: DatabaseReference { reference.child("database") }
        public var core: DatabaseReference { database.child("core") }
        public var actions: DatabaseReference { core.child("action") }
        public var armors: DatabaseReference { core.child("armor") }
        public var occupations: DatabaseReference { core.child("occupation") }
        public var races: DatabaseReference { core.child("race") }
        public var subraces: DatabaseReference { core.child("subrace") }
        public var traits: DatabaseReference { core.child("trait") }
        public var weapons: DatabaseReference { core.child("weapon") }
        
        // MARK: - Application
        public var `public`: DatabaseReference { reference.child("public") }
        
        // MARK: - Users
        public var users: DatabaseReference { reference.child("users") }
        
        // MARK: - Characters
        public var characters: DatabaseReference { reference.child("character") }
        
        public func endAllObservers() {
            reference.removeAllObservers()
            database.removeAllObservers()
            core.removeAllObservers()
            actions.removeAllObservers()
            armors.removeAllObservers()
            occupations.removeAllObservers()
            races.removeAllObservers()
            subraces.removeAllObservers()
            traits.removeAllObservers()
            weapons.removeAllObservers()
            `public`.removeAllObservers()
            users.removeAllObservers()
            characters.removeAllObservers()
        }
    }
}

extension DatabaseReference {
    public typealias DatabaseGetCompletion<T:Codable> = (T?, Error?) -> Void
    public typealias DatabasePutCompletion = (DatabaseReference?, Error?) -> Void
    public typealias DatabaseRemoveCompletion = (Error?) -> Void
    
    public func get<T:Codable>(
        dataWithId id: String,
        ofType type: T.Type,
        completion: @escaping DatabaseGetCompletion<T>) {
            self.child(id).observeSingleEvent(of: .value) { snapshot in
                if let value = snapshot.value as? [String : Any] {
                    do {
                        let json = try JSONSerialization.data(withJSONObject: value, options: .prettyPrinted)
                        let data = try JSONDecoder().decode(type, from: json)
                        completion(data, nil)
                    } catch {
                        Store.firestore.registerError(message: error.localizedDescription)
                        completion(nil, error)
                    }
                } else {
                    Store.firestore.registerError(message: "No data available [\(id)]")
                }
            }
        }
    
    public func put<T:Codable>(
        data: T,
        forId id: String,
        completion: DatabasePutCompletion? = nil) {
            do {
                let encoded = try JSONEncoder().encode(data)
                if let json = try JSONSerialization.jsonObject(with: encoded, options: .allowFragments) as? [String : Any] {
                    self.child(id).updateChildValues(json) { error, reference in
                        if let error = error {
                            Store.firestore.registerError(message: error.localizedDescription)
                        }
                        completion?(reference, error)
                    }
                }
            } catch {
                completion?(nil, error)
            }
        }
    
    public func remove(
        id: String,
        completion: DatabaseRemoveCompletion? = nil) {
            self.child(id).removeValue { error, reference in
                if let error = error {
                    Store.firestore.registerError(message: error.localizedDescription)
                }
                completion?(error)
            }
        }
}

extension DatabaseQuery {
    public typealias DatabaseObserveCompletion = (DataSnapshot) -> Void
    
    public func observe(
        _ eventType: DataEventType,
        completion: @escaping DatabaseObserveCompletion) {
            self.removeAllObservers()
            self.observe(eventType, with: completion)
        }
}
