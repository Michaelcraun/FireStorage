import Firebase
import Foundation

public struct FireStorage {
    @discardableResult
    public init(plist: String = "GoogleService-Info", devPlist: String? = nil) {
        switch environment {
        case .development, .testing:
            printDebug("This application is currently running in development!")
            if let devPlist = devPlist {
                if let options = loadGooglePlist(named: devPlist) {
                    FirebaseApp.configure(options: options)
                } else {
                    printDebug("WARNING: Could not load the development Google Service plist!")
                    startInProductionByDefault()
                }
            } else {
                printDebug("WARNING: No development Google Service plist was provided!")
                startInProductionByDefault()
            }
        default:
            printDebug("This application is currently running in production!")
            if let options = loadGooglePlist(named: plist) {
                FirebaseApp.configure(options: options)
            } else {
                printDebug("WARNING: Could not load the production Google Service plist!")
                startInProductionByDefault()
            }
        }
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
        
        return nil
    }
    
    func startInProductionByDefault() {
        printDebug("WARNING: This application is currently using the production database!")
        FirebaseApp.configure()
    }
}
