import Foundation

/// Persists per-scene star ratings (1–5) to a JSON file on disk.
/// Writes to ~/Library/Application Support/Ennui/ratings.json
class RatingManager: ObservableObject {
    @Published private(set) var ratings: [String: Int] = [:]

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ennuiDir = appSupport.appendingPathComponent("Ennui", isDirectory: true)
        try? FileManager.default.createDirectory(at: ennuiDir, withIntermediateDirectories: true)
        self.fileURL = ennuiDir.appendingPathComponent("ratings.json")
        load()
    }

    func rating(for scene: SceneKind) -> Int? {
        ratings[scene.rawValue]
    }

    func rating(forKey key: String) -> Int? {
        ratings[key]
    }

    func rate(scene: SceneKind, stars: Int) {
        let clamped = max(1, min(5, stars))
        ratings[scene.rawValue] = clamped
        save()
    }

    func rate(key: String, stars: Int) {
        let clamped = max(1, min(5, stars))
        ratings[key] = clamped
        save()
    }

    func clearRating(for scene: SceneKind) {
        ratings.removeValue(forKey: scene.rawValue)
        save()
    }

    func clearRating(forKey key: String) {
        ratings.removeValue(forKey: key)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        ratings = dict
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[RatingManager] save failed: \(error)")
            #endif
        }
    }
}
