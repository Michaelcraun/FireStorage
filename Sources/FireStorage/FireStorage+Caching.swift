import Foundation
import Chronometer

extension Store {
    public typealias CachedData = (filename: String, data: [String: Any])
    
    public struct Cache {
        private let defaults = UserDefaults(suiteName: "FireStorage")
        private let lastStoreKey = "Last_Store"
        
        private var files: FileManager { FileManager.default }
        private var documents: URL { files.urls(for: .documentDirectory, in: .userDomainMask)[0] }
        private var documentStorage: URL { return documents.appendingPathComponent("FireStorage") }
        
        public var shouldFetch: Bool {
            guard let lastFetch = get(valueFor: lastStoreKey) as? String,
                  let lastFetchDate = lastFetch.date() else { return true }
            return lastFetchDate.timeIntervalSinceNow < 24*60*60
        }
        
        // MARK: - UserDefaults support
        public func get(valueFor key: String) -> Any? {
            return defaults?.value(forKey: "FireStorage_\(key)")
        }
        
        public func set(value: Any, for key: String) {
            defaults?.set(value, forKey: "FireStorage_\(key)")
        }
        
        // MARK: - File caching
        public func cache(dictionary: [String : Any], filename: String) throws {
            self.set(value: Date().description, for: lastStoreKey)
            
            let filename = "\(filename).json"
            let path = documentStorage.appendingPathComponent(filename)
            
            do {
                let json = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
                try json.write(to: path)
                
                Store.printDebug("JSON successfully cached to \(path.absoluteString)")
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
                throw error
            }
        }
        
        public func fetch() throws -> [CachedData] {
            var data: [CachedData] = []
            
            do {
                let storedFiles = try files.contentsOfDirectory(atPath: documentStorage.absoluteString)
                for file in storedFiles {
                    print(file)
                }
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
                throw error
            }
            
            return data
        }
    }
}
