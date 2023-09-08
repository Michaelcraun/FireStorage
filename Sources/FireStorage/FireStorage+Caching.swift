import Foundation
import Chronometer

extension Store {
    public class Cache {
        private let defaults = UserDefaults(suiteName: "FireStorage")
        
        private var files: FileManager { FileManager.default }
        private var documents: URL { files.urls(for: .documentDirectory, in: .userDomainMask)[0] }
        private var documentStorage: URL { return documents.appendingPathComponent("FireStorage") }
        
        public var shouldFetch: Bool = false
        
        // MARK: - UserDefaults support
        public func get(valueFor key: String) -> Any? {
            return defaults?.value(forKey: "FireStorage_\(key)")
        }
        
        public func set(value: Any?, for key: String) {
            defaults?.set(value, forKey: "FireStorage_\(key)")
        }
        
        public func setLatestUpdate(date: Date?) {
            let key = "Last_Update_Date"
            let tempUpdate = get(valueFor: key) as? String
            
            guard let date = date else {
                set(value: nil, for: key)
                shouldFetch = true
                return
            }
            
            if let tempUpdateDate = tempUpdate?.date() {
                if tempUpdateDate == date {
                    shouldFetch = false
                    return
                }
            }
            
            set(value: date.description, for: key)
            shouldFetch = true
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
                
                Store.printDebug("JSON successfully cached to \(path.absoluteString)")
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
            }
        }
        
        public func fetch(jsonFromFileNamed filename: String) -> [[String : Any]]? {
            let filename = "\(filename).json"
            let path = documentStorage.appendingPathComponent(filename)
            
            do {
                let data = try Data(contentsOf: path)
                return try JSONSerialization.jsonObject(with: data) as? [[String : Any]]
            } catch {
                Store.firestore.registerError(message: error.localizedDescription)
            }
            return nil
        }
        
        private func removeFile(at path: URL) throws {
            if files.fileExists(atPath: path.absoluteString) {
                try files.removeItem(at: path)
            }
        }
    }
}
