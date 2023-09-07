import XCTest
@testable import FireStorage
@testable import Firebase

final class FireStorageTests: XCTestCase {
    override func setUp(completion: @escaping (Error?) -> Void) {
        Store.verboseLoggingEnabled = false
        completion(nil)
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
