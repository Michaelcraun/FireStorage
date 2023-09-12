import XCTest
@testable import FireStorage
@testable import FirebaseFirestore
@testable import FirebaseFirestoreSwift
@testable import Firebase

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
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        // Disable verbose logging so we don't need database integration
        Store.init(plist: "FireStorage-PROD", devPlist: "FireStorage-DEV")
        Store.verboseLoggingEnabled = false
        completion(nil)
    }
    
    func testShouldFetch() {
        // Reset latest update date to allow these tests to pass
        Store.cache.setLatestUpdate(date: nil)
        
        // By default (first install)...
        Store.cache.setLatestUpdate(date: "1/1/2022".date()!)
        XCTAssertEqual(Store.cache.shouldFetch, true)
        
        // If the last update doesn't match what we have stored...
        Store.cache.setLatestUpdate(date: "1/1/2023".date()!)
        XCTAssertEqual(Store.cache.shouldFetch, true)
        
        // If the last update matches what we have stored...
        Store.cache.setLatestUpdate(date: "1/1/2023".date()!)
        XCTAssertEqual(Store.cache.shouldFetch, false)
    }
    
    func testStoreJson() throws {
        let dictionary: [[String : Any]] = [
            [
                "this": "is",
                "a": "test"
            ]
        ]
        
        Store.cache.cache(data: dictionary, filename: "this_is_a_test")
    }
    
    func testFetch() throws {
        let data = Store.cache.fetch(jsonFromFileNamed: "this_is_a_test")
        
        XCTAssertEqual(data!.first!["this"] as! String, "is")
        XCTAssertEqual(data!.first!["a"] as! String, "test")
    }
    
}
