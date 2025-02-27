import XCTest
@testable import FireStorage
@testable import Firebase

final class FireStorageCachingTests: XCTestCase {
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        Store.environmentOverride = .unitTesting
        
        Store.cache.removeFile(with: "action")
        Store.cache.removeFile(with: "this_is_a_test")
        
        completion(nil)
    }
    
    func testCaching_firstInstall() {
        Store.cache.setLatestDatabaseUpdate(date: nil)
        
        // Should fetch -> Cache returning nil means it doesn't have anything OR the cache
        // has determined that the data here is outdatad
        XCTAssertNil(Store.cache.fetch(jsonFromFileNamed: "action"))
    }
    
    func testCaching_elapsedTime() {
        Store.cache.cache(data: [[:]], filename: "action")
        Store.maximumCacheAge = 0
        
        sleep(1)
        
        // Should fetch -> Cache returning nil means it doesn't have anything OR the cache
        // has determined that the data here is outdatad
        XCTAssertNil(Store.cache.fetch(jsonFromFileNamed: "action"))
    }
    
    func testCaching_timeNotElapsed() {
        Store.cache.cache(data: [[:]], filename: "action")
        Store.maximumCacheAge = 60
        
        // Should not fetch -> Cache returning non-nil value means the cache has data that is
        // not outdated and should be used
        XCTAssertNotNil(Store.cache.fetch(jsonFromFileNamed: "action"))
    }
    
    func testFetch_storeAndFetchJson() throws {
        let dictionary: [[String : Any]] = [
            [
                "this": "is",
                "a": "test"
            ]
        ]
        
        Store.cache.cache(data: dictionary, filename: "this_is_a_test")
        XCTAssertNotNil(Store.cache.fetch(jsonFromFileNamed: "this_is_a_test"))
    }
    
}
