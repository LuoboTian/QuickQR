import Foundation

struct Favorite: Codable {
    let id: UUID
    var name: String
    let text: String
}

final class QRLibrary {
    private(set) var recent: [String] = []
    private(set) var favorites: [Favorite] = []
    private let file: URL
    init(file: URL) throws {
        self.file = file
        if FileManager.default.fileExists(atPath: file.path) {
            favorites = try JSONDecoder().decode([Favorite].self, from: Data(contentsOf: file))
        }
    }
    func generated(_ text: String) {
        recent.removeAll { $0 == text }
        recent.insert(text, at: 0)
        recent = Array(recent.prefix(10))
    }
    func clearRecent() { recent = [] }
    func save(name: String, text: String) throws {
        var updated = favorites
        updated.append(Favorite(id: UUID(), name: name, text: text))
        try persist(updated)
        favorites = updated
    }
    func delete(_ id: UUID) throws {
        let updated = favorites.filter { $0.id != id }
        try persist(updated)
        favorites = updated
    }
    private func persist(_ entries: [Favorite]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
