import XCTest
@testable import FireStorage
@testable import Firebase

final class FireStorageTests: XCTestCase {
    override func setUp(completion: @escaping (Error?) -> Void) {
        // Disable verbose logging so we don't need database integration
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
