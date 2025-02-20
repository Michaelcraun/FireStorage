import XCTest
@testable import FireStorage
@testable import Firebase

final class FireStorageGeneralTests: XCTestCase {
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func testVerboseLogging_disabled() {
        Store.verboseLoggingEnabled = false
        Store.printDebug("hello world")
    }
    
    func testsVerboseLogging_enabled() {
        Store.verboseLoggingEnabled = true
        Store.printDebug("hello world")
    }
    
}
