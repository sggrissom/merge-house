import Foundation

/// What is worth keeping when the app closes: the things the child made and
/// where they put them.
///
/// This is deliberately its own vocabulary rather than the scene's private types
/// written straight to disk. Renaming a case of `GameScene.ItemLocation` should
/// not silently change the shape of everyone's save file, and the save should be
/// readable without knowing how the scene happens to be built today.
struct SavedGame: Codable {

    /// Bumped only when the shape below changes in a way an old file cannot be
    /// read as. There is no migration and there should not be one: an
    /// unrecognised version starts fresh, which for a prototype costs a shelf of
    /// bows and saves a whole class of bug.
    static let currentVersion = 1

    let version: Int
    let items: [SavedItem]
    /// The id of the character being played as.
    let character: String?
    /// Where they were standing, as a fraction of the room.
    let characterX: Double
    let characterY: Double
    /// The raw value of the furniture they were using, if any.
    let characterUsing: String?
}

/// One loose object: what it is, where it is, and — if it is on the character —
/// how it is being carried.
struct SavedItem: Codable {
    /// An `ItemCatalog` id. Deliberately the id and not an index: the catalog is
    /// meant to be edited freely, and reordering it must not turn every saved
    /// teddy into a cupcake.
    let item: String
    /// `"stuff"`, `"room"` or `"carried"`.
    let place: String
    /// A `CarryStyle` raw value, when `place` is `"carried"`.
    let carry: String?
    /// Position as a fraction of whichever area it is in. Ignored when carried,
    /// since a carried item's position comes from the character's carry point.
    let x: Double
    let y: Double
}

/// Where the save lives: one JSON file in Application Support.
///
/// A file rather than `UserDefaults`, which was the first thing tried here and
/// is the wrong tool: it batches its disk writes, so a save made seconds before
/// the app is killed is simply gone. An atomic write lands or it does not, and
/// the file is readable — which for a prototype built around catalogs you are
/// meant to edit by hand is worth something on its own.
enum SaveStore {

    private static var url: URL? {
        let manager = FileManager.default
        guard let directory = try? manager.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil, create: true) else {
            return nil
        }
        return directory.appendingPathComponent("merge-house-save.json")
    }

    static func load() -> SavedGame? {
        guard let url = url,
              let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.version == SavedGame.currentVersion else {
            return nil
        }
        return saved
    }

    static func save(_ game: SavedGame) {
        guard let url = url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(game) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
