import Foundation

open class PublicDatabase: Codable {
    var usernames: [String]?

    func addUsername(_ username: String) {
        usernames?.append(username)
        Store.firestore.structure.public.put(data: usernames, forId: "usernames")
    }

    func removeUsername(_ username: String) {
        guard let index = usernames?.firstIndex(of: username) else { return }
        usernames?.remove(at: index)
        Store.firestore.structure.public.put(data: usernames, forId: "usernames")
    }

    func contains(_ username: String) -> Bool {
        return usernames?.contains(username) ?? true
    }
}
