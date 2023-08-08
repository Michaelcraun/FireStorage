import XCTest
@testable import FireStorage
@testable import FirebaseFirestore
@testable import FirebaseFirestoreSwift

class NPCGen5eStructure: FirestoreStructurable {
    var actions: CollectionReference { firestore.collection("action") }
    var armors: CollectionReference { firestore.collection("armor") }
    var occupations: CollectionReference { firestore.collection("occupation") }
    var races: CollectionReference { firestore.collection("race") }
    var subraces: CollectionReference { firestore.collection("subrace") }
    var traits: CollectionReference { firestore.collection("trait") }
    var weapons: CollectionReference { firestore.collection("weapon") }
    
    var characters: CollectionReference { firestore.collection("character") }
    var products: CollectionReference { firestore.collection("product") }
    var purchases: CollectionReference { firestore.collection("purchase") }
    
    var startupCollections: [CollectionReference] {
        return [
            actions,
            armors,
            occupations,
            races,
            subraces,
            traits,
            weapons
        ]
    }
}

final class FireStorageTests: XCTestCase {
    let structure = NPCGen5eStructure()
    
    func testGetCharacters() {
        structure.characters.get(ofType: String.self) { texts, error in
            
        }
    }
}
