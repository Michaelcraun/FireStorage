import XCTest
@testable import FireStorage
@testable import Firebase

final class FireStorageCachingTests: XCTestCase {
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func testCaching_firstInstall() {
        Store.cache.setLatestDatabaseUpdate(date: nil)
        
        // Should fetch
        XCTAssertNil(Store.cache.fetch(jsonFromFileNamed: "action"))
    }
    
    func testCaching_elapsedTime() {
        Store.cache.cache(data: [[:]], filename: "action")
        Store.maximumCacheAge = 0
        
        sleep(1)
        
        // Should fetch
        XCTAssertNil(Store.cache.fetch(jsonFromFileNamed: "action"))
    }
    
    func testCaching_timeNotElapsed() {
        Store.cache.cache(data: [[:]], filename: "action")
        Store.maximumCacheAge = 60
        
        // Should not fetch
        XCTAssertNotNil(Store.cache.fetch(jsonFromFileNamed: "action"))
    }
    
    func testCaching_databaseHasUpdates() {
        Store.firestore.start()
        
        // Should fetch
        
    }
    
    func testShouldFetch() {
        // Reset latest update date and set
        Store.cache.setLatestDatabaseUpdate(date: nil)
        Store.maximumCacheAge = 0
        
        // By default (first install)...
        
        // Cache some dummy data to update last cached date for this object to today's date...
        Store.cache.cache(data: [[:]], filename: "action")
        
        // If the last update doesn't match what we have stored...
        Store.cache.setLatestDatabaseUpdate(date: "1/1/2023".date()!)
//        XCTAssertEqual(Store.cache.shouldFetch, true)
        
        // If the last update matches what we have stored...
        Store.cache.setLatestDatabaseUpdate(date: "1/1/2023".date()!)
//        XCTAssertEqual(Store.cache.shouldFetch, false)
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
