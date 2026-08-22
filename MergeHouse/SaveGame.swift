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
    ///
    /// Naming a save did not bump it, and nor did rooms, because a field that may
    /// be absent is not a shape an old file cannot be read as — see `name`,
    /// `saved` and `room`.
    static let currentVersion = 1

    let version: Int
    /// What this save is called on the menu. Optional because the one file
    /// written before saves had names is still a perfectly good game, and losing
    /// it over a missing label would be a silly way to lose it.
    let name: String?
    /// When it was last written, which is what the menu sorts and dates by.
    /// Optional for the same reason.
    let saved: Date?
    let items: [SavedItem]
    /// The id of the character being played as.
    let character: String?
    /// The id of the room being stood in. Optional because the saves written
    /// before there was more than one room were all of them in the Bedroom, and
    /// that is exactly what a missing value means.
    let room: String?
    /// Where they were standing, as a fraction of the room.
    let characterX: Double
    let characterY: Double
    /// The id of the piece of furniture they were using, if any.
    let characterUsing: String?

    /// A game nobody has played yet. Written the moment a save is named, so a
    /// new game is on the menu before it has anything in it — a slot you cannot
    /// see until you have made something is a slot you would think had failed.
    static func empty(name: String) -> SavedGame {
        SavedGame(version: currentVersion, name: name, saved: Date(), items: [],
                  character: nil, room: nil, characterX: 0.5, characterY: 0.10,
                  characterUsing: nil)
    }
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
    /// Which room it was left in, when `place` is `"room"`. A `RoomCatalog` id
    /// and not an index, for the reason `item` is: the catalog is meant to be
    /// edited freely. Absent in a save written before there was a second room.
    let room: String?
    /// A `CarryStyle` raw value, when `place` is `"carried"`.
    let carry: String?
    /// Position as a fraction of whichever area it is in. Ignored when carried,
    /// since a carried item's position comes from the character's carry point.
    let x: Double
    let y: Double
}

/// One save as the menu needs to know it: enough to list, pick and delete
/// without reading anyone's shelf of bows into memory.
///
/// The `id` is the file's own name, so a slot is a thing on disk rather than a
/// position in a list — the same reason a saved item stores a catalog id. Two
/// saves may happily share a `name`; the child naming both of them "mine" is not
/// an error worth stopping them for.
struct SaveSlot: Identifiable, Hashable {
    let id: String
    let name: String
    let saved: Date
}

/// Where the saves live: one JSON file each, in a folder in Application Support.
///
/// Files rather than `UserDefaults`, which was the first thing tried here and is
/// the wrong tool: it batches its disk writes, so a save made seconds before the
/// app is killed is simply gone. An atomic write lands or it does not, and the
/// file is readable — which for a prototype built around catalogs you are meant
/// to edit by hand is worth something on its own.
///
/// One file per save rather than one file holding all of them, for the same
/// reason: writing the game you are playing must not be able to damage the three
/// you are not.
enum SaveStore {

    private static let folderName = "merge-house-saves"
    /// Where the single unnamed save used to live, before there could be more
    /// than one of them.
    private static let legacyFileName = "merge-house-save.json"

    private static var applicationSupport: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    private static var directory: URL? {
        guard let base = applicationSupport?.appendingPathComponent(folderName) else { return nil }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func url(for id: String) -> URL? {
        directory?.appendingPathComponent("\(id).json")
    }

    /// Every save, most recently played first — which is the order you want them
    /// in, because the game you are in the middle of is the one you are coming
    /// back for.
    static func slots() -> [SaveSlot] {
        adoptLegacySave()
        guard let directory = directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }

        let slots = files.compactMap { file -> SaveSlot? in
            guard file.pathExtension == "json" else { return nil }
            let id = file.deletingPathExtension().lastPathComponent
            guard let game = load(id) else { return nil }
            // A file written before saves were dated still has a date: the one
            // the filesystem kept for it.
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            return SaveSlot(id: id,
                            name: game.name ?? "Untitled",
                            saved: game.saved ?? modified ?? .distantPast)
        }
        return slots.sorted { $0.saved > $1.saved }
    }

    /// Names a new save and writes it, so the caller gets back a slot that
    /// already exists rather than a promise that one will.
    static func create(name: String) -> SaveSlot {
        let id = UUID().uuidString
        let game = SavedGame.empty(name: name)
        save(game, id: id)
        return SaveSlot(id: id, name: game.name ?? name, saved: game.saved ?? Date())
    }

    static func load(_ id: String) -> SavedGame? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let url = url(for: id),
              let data = try? Data(contentsOf: url),
              let saved = try? decoder.decode(SavedGame.self, from: data),
              saved.version == SavedGame.currentVersion else {
            return nil
        }
        return saved
    }

    static func save(_ game: SavedGame, id: String) {
        guard let url = url(for: id) else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(game) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func delete(_ id: String) {
        guard let url = url(for: id) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Renames in place: the file keeps its id, so a save the menu is showing
    /// stays the same save.
    static func rename(_ id: String, to name: String) {
        guard let game = load(id) else { return }
        save(SavedGame(version: game.version, name: name, saved: game.saved,
                       items: game.items, character: game.character, room: game.room,
                       characterX: game.characterX, characterY: game.characterY,
                       characterUsing: game.characterUsing),
             id: id)
    }

    /// Takes the one file written before saves had names and makes it the first
    /// named save, once.
    ///
    /// Not a migration in the sense the version field exists to refuse — the
    /// shape on disk is unchanged. It is a file being moved to where saves are
    /// kept now and given a label, which is worth ten lines to avoid throwing
    /// away the game somebody was in the middle of.
    private static func adoptLegacySave() {
        let manager = FileManager.default
        guard let legacy = applicationSupport?.appendingPathComponent(legacyFileName),
              manager.fileExists(atPath: legacy.path),
              let directory = directory else { return }
        let id = UUID().uuidString
        do {
            try manager.moveItem(at: legacy,
                                 to: directory.appendingPathComponent("\(id).json"))
        } catch {
            return
        }
        rename(id, to: "Earlier game")
    }
}
