import Firebase
import Foundation

public struct Store {
    public static var auth = Store.Auth()
    public static let crashlytics = Store.Crashlytics()
    public static let database = Store.Database()
    public static var firestore = Store.Firestore()
    public static let functions = Store.Functions()
    public static var messaging = Store.Messaging()
    public static let storage = Store.Storage()
    
    public static let cache = Store.Cache()
    
    public static var environmentOverride: Environment?
    
    /// The maximum number of megabytes of data allowed for any one download from Firebase storage.
    public static var maxDownloadMegabytes: Int = 5
    
    /// A boolean toggle determining if verbose logging is enabled (enabled by default). The two states of this Boolean
    /// affect what messages are printed to the console.
    ///
    /// If enabled, all calls to `Store.firestore.registerError` will be logged to the console as well as
    /// logged to the Firestore instance under the `error` collection.
    ///
    /// - warning: Regardless of status, errors will always be logged to the Firestore instance!
    public static var verboseLoggingEnabled: Bool = true
    private static let verboseLoggingKey: String = "Verbose_Logging_Disabled_Reported"
    
    // MARK: File Caching
    /// A boolean toggle determining if file caching is enabled (enabled by default). If enabled, FireStorage will cache data
    /// downloaded from the database locally and will not fetch new data except for when a number of seconds has passed
    /// which is controlled via the `maximumCacheAge` value.
    public static var cachingEnabled: Bool = true
    /// The number of seconds that must pass before FireStorage will fetch data from Firestore. Defaults to 30 days.
    public static var maximumCacheAge: TimeInterval = 2592000.0
    
    @discardableResult
    public init(plist: String = "GoogleService-Info", devPlist: String? = nil) {
        switch environment {
        case .development, .testing:
            Store.printDebug("This application is currently running in development!")
            if let devPlist = devPlist {
                if let options = loadGooglePlist(named: devPlist) {
                    FirebaseApp.configure(options: options)
                } else {
                    Store.printDebug("WARNING: Could not load the development Google Service plist!")
                    startInProductionByDefault()
                }
            } else {
                Store.printDebug("WARNING: No development Google Service plist was provided!")
                startInProductionByDefault()
            }
        default:
            Store.printDebug("This application is currently running in production!")
            if let options = loadGooglePlist(named: plist) {
                FirebaseApp.configure(options: options)
            } else {
                Store.printDebug("WARNING: Could not load the production Google Service plist!")
                startInProductionByDefault()
            }
        }
        Store.cache.set(value: 0, for: Store.verboseLoggingKey)
    }
    
    public static func printDebug(_ message: String) {
        #if DEBUG
        if Store.verboseLoggingEnabled {
            print("FireStorage:", message)
        } else {
            reportVerboseLoggingDisabled()
        }
        #endif
    }
    
    public static func endAllObservers() {
        database.endAllObservers()
        firestore.endAllObservers()
    }
    
    public static func reportVerboseLoggingDisabled() {
        guard Store.cache.get(valueFor: verboseLoggingKey) as? Int == 0 else { return }
        Store.printDebug("WARNING: Verbose logging is disabled.")
        Store.printDebug("Errors encountered will not be logged to the database.")
        Store.cache.set(value: 1, for: verboseLoggingKey)
    }
    
    func loadGooglePlist(named name: String) -> FirebaseOptions? {
        for bundle in Bundle.allBundles {
            if let path = bundle.path(forResource: name, ofType: "plist") {
                return FirebaseOptions(contentsOfFile: path)
            }
        }
        
        for bundle in Bundle.allFrameworks {
            if let path = bundle.path(forResource: name, ofType: "plist") {
                return FirebaseOptions(contentsOfFile: path)
            }
        }
        
        if let path = Bundle.main.path(forResource: name, ofType: "plist") {
            return FirebaseOptions(contentsOfFile: path)
        }
        
        return nil
    }
    
    func startInProductionByDefault() {
        Store.printDebug("WARNING: This application is currently using the production database!")
        FirebaseApp.configure()
    }
}
