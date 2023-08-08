import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

public protocol FirestoreStructurable: AnyObject {
    /// The root of all collections in the Firestore structure. All collection objects added to the
    /// FirestoreStructurable object should use this property.
    var firestore: FirebaseFirestore.Firestore { get }
    
    /// One of three enforced collections, the 'account' collection is where user data is stored
    /// This collection must be enforced to allow for easier sign-in and registration methods.
    /// To affect what data is stored in this collection, override the AppUser class and supply
    /// the Auth methods your own calls.
    var accounts: CollectionReference { get }
    
    /// One of three enforced collections, the 'errors' collecion is where error data is automagically
    /// stored on your database.
    var errors: CollectionReference { get }
    
    /// One fo three enforced collections, the 'public' collection is where public data concerning
    /// your database is stored. To date, this simply includes an array of taken usernames, but
    /// will contain much more data in the future, such as version history or other possibly useful
    /// information.
    var `public`: CollectionReference { get }
    
    /// A collection of CollectionReferences that are automatically fetched on project start.
    /// The result of fetching these collections are communicated back to the application
    /// via the FirestoreDelegate.firestoreDidFetch(data:from:) method.
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
