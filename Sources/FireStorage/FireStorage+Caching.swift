import Foundation
import Chronometer

extension Store {
    public class Cache {
        private let defaults = UserDefaults(suiteName: "FireStorage")
        private let latestDatabaseUpdateKey = "Latest_Database_Update_Date"
        
        private var files: FileManager { FileManager.default }
        
        // MARK: - File and directory management
        private func documentStorage() -> URL {
            // We want to always store files in a ./FireStorage folder, even if we're passing in a baseDirectory
            return files.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FireStorage")
        }
        
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
        
        // MARK: - File caching and management
        private func createDirectoryStructureIfNeeded() {
            if !files.fileExists(atPath: documentStorage().absoluteString) {
                do {
                    try files.createDirectory(at: documentStorage(), withIntermediateDirectories: true)
                } catch {
                    let errorDescription = "Could not create project directory at \(documentStorage().absoluteString)"
                    Store.firestore.registerError(message: "\(errorDescription) [\(error.localizedDescription)]")
                }
            }
        }
        
        public func cache(data: [[String : Any]], filename: String) {
            createDirectoryStructureIfNeeded()
            
            let filename = "\(filename).json"
            let path = documentStorage().appendingPathComponent(filename)
            
            do {
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
            
            guard shouldFetch(filename: filename) else {
                removeFile(with: filename)
                return nil
            }
            
            let path = documentStorage().appendingPathComponent(filename)
            do {
                let data = try Data(contentsOf: path)
                return try JSONSerialization.jsonObject(with: data) as? [[String : Any]]
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
            }
            return nil
        }
        
        public func removeFile(with name: String) {
            let modName = name.contains(".json") ? name : "\(name).json"
            let path = documentStorage().appendingPathComponent(modName)
            removeFile(at: path)
        }
        
        private func removeFile(at path: URL) {
            if files.fileExists(atPath: path.absoluteString) {
                do {
                    try files.removeItem(at: path)
                } catch {
                    Store.firestore.registerError(message: error.localizedDescription)
                }
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
