import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

public protocol FirestoreStructurable: AnyObject {
    // Enforced collections
    var firestore: FirebaseFirestore.Firestore { get }
    var accounts: CollectionReference { get }
    var errors: CollectionReference { get }
    var `public`: CollectionReference { get }
    
    var startupCollections: [CollectionReference] { get }
}

extension FirestoreStructurable {
    public var firestore: FirebaseFirestore.Firestore { return FirebaseFirestore.Firestore.firestore() }
    public var accounts: CollectionReference { return firestore.collection("account") }
    public var errors: CollectionReference { return firestore.collection("error") }
    public var `public`: CollectionReference { return firestore.collection("public") }
}

public class EmptyFirestoreStructure: FirestoreStructurable {
    public var startupCollections: [CollectionReference] { return [] }
}
