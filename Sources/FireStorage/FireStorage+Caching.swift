import Foundation
import Chronometer

extension Store {
    public class Cache {
        private let defaults = UserDefaults(suiteName: "FireStorage")
        private let latestDatabaseUpdateKey = "Latest_Database_Update_Date"
        
        private var files: FileManager { FileManager.default }
        private var documents: URL { files.urls(for: .cachesDirectory, in: .userDomainMask)[0] }
        private var documentStorage: URL { return documents.appendingPathComponent("FireStorage") }
        
        // MARK: - UserDefaults support
        public func get(valueFor key: String) -> Any? {
            return defaults?.value(forKey: "FireStorage_\(key)")
        }
        
        public func set(value: Any?, for key: String) {
            defaults?.set(value, forKey: "FireStorage_\(key)")
        }
        
        public func getLatestDatabaseUpdate() -> Date? {
            return (get(valueFor: latestDatabaseUpdateKey) as? String)?.date()
        }
        
        public func setLatestDatabaseUpdate(date: Date?) {
            set(value: date?.description, for: latestDatabaseUpdateKey)
        }
        
        // MARK: - File caching
        private func createDirectoryStructureIfNeeded() {
            if !files.fileExists(atPath: documentStorage.absoluteString) {
                try? files.createDirectory(at: documentStorage, withIntermediateDirectories: true)
            }
        }
        
        public func cache(data: [[String : Any]], filename: String) {
            createDirectoryStructureIfNeeded()
            
            let filename = "\(filename).json"
            let path = documentStorage.appendingPathComponent(filename)
            
            do {
                try removeFile(at: path)
                let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                try json.write(to: path)
                
                // Set last cached date for this file
                set(value: Date().description, for: key(for: filename))
                
                Store.printDebug("JSON successfully cached to \(path.absoluteString)")
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
            }
        }
        
        public func fetch(jsonFromFileNamed filename: String) -> [[String : Any]]? {
            let filename = "\(filename).json"
            
            guard shouldFetch(filename: filename) else { return nil }
            
            let path = documentStorage.appendingPathComponent(filename)
            if files.fileExists(atPath: path.absoluteString) {
                do {
                    let data = try Data(contentsOf: path)
                    return try JSONSerialization.jsonObject(with: data) as? [[String : Any]]
                } catch {
                    Store.firestore.registerError(message: error.localizedDescription)
                }
            }
            return nil
        }
        
        private func removeFile(at path: URL) throws {
            if files.fileExists(atPath: path.absoluteString) {
                try files.removeItem(at: path)
            }
        }
        
        private func key(for filename: String) -> String {
            return "\(filename)_Last_Update_Date"
        }
        
        private func shouldFetch(filename: String) -> Bool {
            guard let lastUpdate = get(valueFor: key(for: filename)) as? String,
                  let lastUpdateDate = lastUpdate.date() else { return false }
            let distance = Date().timeIntervalSince(lastUpdateDate)
            return distance <= Store.maximumCacheAge
        }
    }
}
