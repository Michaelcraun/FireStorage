import XCTest
@testable import FireStorage
@testable import Firebase

final class FireStorageTests: XCTestCase {
    
    let defaults = UserDefaults(suiteName: "FireStorage")
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        Store.verboseLoggingEnabled = false
    }
    
    func testShouldFetch() {
        XCTAssertEqual(Store.cache.shouldFetch, true)
    }
    
    func testShouldFetch_TooMuchTimePassed() {
        let lastFetchDate = Date().addingTimeInterval(30*60*60)
        defaults?.set(lastFetchDate.description, forKey: "FireStorage_Last_Fetch")
        
        XCTAssertEqual(Store.cache.shouldFetch, true)
    }
    
    func testShouldNotFetch() {
        let lastFetchDate = Date().addingTimeInterval(23*60*60)
        defaults?.set(lastFetchDate.description, forKey: "FireStorage_Last_Fetch")
        
        XCTAssertEqual(Store.cache.shouldFetch, false)
    }
    
    func testStoreJson() throws {
        let dictionary = [
            "this": "is",
            "a": "test"
        ]
        
        try Store.cache.cache(dictionary: dictionary, filename: "this_is_a_test")
    }
    
    func testFetch() throws {
        print(try Store.cache.fetch())
    }
    
}
