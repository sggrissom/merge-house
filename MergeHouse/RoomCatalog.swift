import SpriteKit
import UIKit

/// What a character does on a piece of furniture, and what they are said to be
/// doing while they do it.
///
/// The same split the rest of the prototype runs on: the *pose* is the part the
/// game has to understand — it decides where the character is put and which way
/// up they are — and the *label* is the part only a person cares about. A Bed
/// and a Bath both lie you down; only one of them is sleeping.
struct FurnitureUse {
    enum Pose {
        case sitting
        case lyingDown

        /// Which way up the character is on a piece held this way.
        var rotation: CGFloat {
            self == .lyingDown ? .pi / 2 : 0
        }
    }

    let pose: Pose
    /// What the character's name tag reads while they are on it.
    let label: String
}

/// One kind of furniture: what it is called, what it should look like, and
/// whether a character can get on it at all.
///
/// The furniture's half of the bargain a room strikes. A Bed knows it is a thing
/// you lie on and nothing else; *where* the bed is — how far across the room, how
/// big — is that room's business, in `FurniturePlacement`. So a new piece works
/// in every room that lists it, and a new room furnishes itself out of pieces
/// that already know how they are used.
struct FurnitureDefinition {
    let id: String
    let name: String
    /// The asset the real drawing will use. Until it exists the piece draws as a
    /// labeled box, the same as an item without artwork.
    let imageName: String?
    /// How a character uses this, if they can. `nil` is furniture you only ever
    /// walk past.
    let use: FurnitureUse?
    /// Where this piece's top is, as a fraction of its own height — `0.9` for a
    /// table, `0.05` for a rug, `1.0` for a stove. `nil` is a piece with no top:
    /// anything let go over it falls past it to the floor.
    ///
    /// The furniture half of the same bargain `use` strikes. A Table says it has
    /// a top and how high up itself that top is; how big the table is and where
    /// it stands is the room's business, and *what* ends up on it is nobody's —
    /// no code here knows that a cake goes on tables.
    let surface: CGFloat?
    /// Placeholder fill, used only while `imageName` has no artwork behind it.
    let color: SKColor

    var artwork: UIImage? {
        guard let imageName = imageName else { return nil }
        return UIImage(named: imageName)
    }

    var missingArtworkNote: String {
        guard let imageName = imageName else { return "no image set" }
        return "needs \(imageName).png"
    }
}

/// Everything a room can be furnished with. A new piece is one entry here and
/// one line in whichever rooms have it.
enum FurnitureCatalog {

    static let all: [FurnitureDefinition] = [

        FurnitureDefinition(id: "bed",
                            name: "Bed",
                            imageName: "bed",
                            use: FurnitureUse(pose: .lyingDown, label: "Sleeping"),
                            // A blanket to put a teddy on.
                            surface: 0.6,
                            color: SKColor(red: 0.55, green: 0.66, blue: 0.85, alpha: 1)),
        FurnitureDefinition(id: "chair",
                            name: "Chair",
                            imageName: "chair",
                            use: FurnitureUse(pose: .sitting, label: "Sitting"),
                            // The seat, whether it is a person or a bear sitting on it.
                            surface: 0.55,
                            color: SKColor(red: 0.55, green: 0.75, blue: 0.58, alpha: 1)),
        FurnitureDefinition(id: "table",
                            name: "Table",
                            imageName: "table",
                            use: nil,
                            surface: 0.9,
                            color: SKColor(red: 0.62, green: 0.45, blue: 0.31, alpha: 1)),
        FurnitureDefinition(id: "sofa",
                            name: "Sofa",
                            imageName: "sofa",
                            use: FurnitureUse(pose: .sitting, label: "Lounging"),
                            surface: 0.5,
                            color: SKColor(red: 0.72, green: 0.48, blue: 0.62, alpha: 1)),
        FurnitureDefinition(id: "rug",
                            name: "Rug",
                            imageName: "rug",
                            use: FurnitureUse(pose: .sitting, label: "Playing"),
                            // Barely off the floor, which is the point of a rug.
                            surface: 0.05,
                            color: SKColor(red: 0.84, green: 0.60, blue: 0.40, alpha: 1)),
        FurnitureDefinition(id: "counter",
                            name: "Counter",
                            imageName: "counter",
                            use: nil,
                            surface: 0.95,
                            color: SKColor(red: 0.70, green: 0.68, blue: 0.60, alpha: 1)),
        FurnitureDefinition(id: "stove",
                            name: "Stove",
                            imageName: "stove",
                            use: nil,
                            // The hob, right on top.
                            surface: 1.0,
                            color: SKColor(red: 0.42, green: 0.44, blue: 0.50, alpha: 1)),
        FurnitureDefinition(id: "toy-box",
                            name: "Toy Box",
                            imageName: "toy-box",
                            use: nil,
                            // The lid. Putting things *in* it is a later idea.
                            surface: 1.0,
                            color: SKColor(red: 0.86, green: 0.56, blue: 0.30, alpha: 1)),
    ]

    static func definition(id: String) -> FurnitureDefinition? {
        byID[id]
    }

    /// The first of any duplicate id wins, for the reason `ItemCatalog.byID`
    /// gives: a slip while editing the list should not be a crash on launch.
    private static let byID: [String: FurnitureDefinition] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
}

/// One piece of furniture standing somewhere in a room.
///
/// Everything is a fraction of the room, never a number of points, so the same
/// line describes the same corner of the room on a phone, on an iPad and after a
/// rotation. It is the room half of the bargain: the piece says what it is, this
/// says where it is.
struct FurniturePlacement {
    /// A `FurnitureCatalog` id. One that no longer exists is simply left out of
    /// the room rather than being an error — the catalogs here are meant to be
    /// edited freely.
    let furniture: String
    /// Horizontal centre, as a fraction of the room's width.
    let centerX: CGFloat
    /// Bottom edge — where the piece stands — as a fraction of the room's height.
    let bottomY: CGFloat
    let width: CGFloat
    let height: CGFloat
}

/// One placement resolved against the catalog: what the piece is, and the id the
/// rest of the game knows this particular one by.
struct PlacedFurniture {
    /// Unique within its room, so a room with two chairs can say which one is
    /// being sat on. The first is `chair`, the second `chair-2`.
    let id: String
    let definition: FurnitureDefinition
    let placement: FurniturePlacement
}

/// One room you can be in: what it is called, what it looks like, and what is in it.
///
/// The same bargain as the item and character catalogs. `imageName` is the
/// backdrop the real drawing will use, and a room without one falls back to a
/// flat wall and floor in its own colours — so a room is playable the moment it
/// is listed, and drawing it later is a PNG and no code change.
struct RoomDefinition {
    let id: String
    let name: String
    let imageName: String?
    /// Placeholder wall fill, used only while `imageName` has no artwork behind it.
    let wallColor: SKColor
    /// Placeholder floor fill, likewise.
    let floorColor: SKColor
    /// Where the floor meets the wall, as a fraction of the room's height.
    ///
    /// It draws the placeholder's floor, and it is also the line things stand
    /// on: an item let go above it falls to it, so a room reads as a room rather
    /// than a scrapbook of things pinned to the wall. Below it is the front of
    /// the room, where an item stays exactly where it was put — a picnic laid
    /// out in the foreground is a thing a child should be allowed to do.
    ///
    /// A drawn room has to say where its own floor line is, since the backdrop
    /// knows and nothing else does. It is the one number a `.png` cannot carry.
    let floorHeight: CGFloat
    /// What is in the room, back to front: a later piece draws over an earlier one.
    let furniture: [FurniturePlacement]

    /// The furniture actually in this room, in draw order, each with the id it is
    /// known by. A placement naming a piece that is no longer in the catalog is
    /// dropped rather than throwing the room away.
    var pieces: [PlacedFurniture] {
        var counts: [String: Int] = [:]
        return furniture.compactMap { placement in
            guard let definition = FurnitureCatalog.definition(id: placement.furniture) else {
                return nil
            }
            let seen = (counts[definition.id] ?? 0) + 1
            counts[definition.id] = seen
            let id = seen == 1 ? definition.id : "\(definition.id)-\(seen)"
            return PlacedFurniture(id: id, definition: definition, placement: placement)
        }
    }

    /// One piece of this room's furniture, by the id it is known by.
    func piece(id: String) -> PlacedFurniture? {
        pieces.first { $0.id == id }
    }

    var artwork: UIImage? {
        guard let imageName = imageName else { return nil }
        return UIImage(named: imageName)
    }

    /// What to call the missing file, so the picker can tell you what to draw next.
    var missingArtworkNote: String {
        guard let imageName = imageName else { return "no image set" }
        return "needs \(imageName).png"
    }
}

/// Every room in the house. A new room is one entry in this list and nothing
/// else — no gameplay code knows what a kitchen is.
enum RoomCatalog {

    static let all: [RoomDefinition] = [

        RoomDefinition(id: "bedroom",
                       name: "Bedroom",
                       imageName: "bedroom",
                       wallColor: SKColor(red: 0.79, green: 0.83, blue: 0.92, alpha: 1),
                       floorColor: SKColor(red: 0.72, green: 0.56, blue: 0.40, alpha: 1),
                       floorHeight: 0.38,
                       furniture: [
                           // The chair sits further back in the room than the
                           // table, so it is listed first and draws behind it.
                           FurniturePlacement(furniture: "bed", centerX: 0.18, bottomY: 0.08,
                                              width: 0.28, height: 0.16),
                           FurniturePlacement(furniture: "chair", centerX: 0.78, bottomY: 0.24,
                                              width: 0.13, height: 0.16),
                           FurniturePlacement(furniture: "table", centerX: 0.80, bottomY: 0.05,
                                              width: 0.20, height: 0.13),
                       ]),

        RoomDefinition(id: "kitchen",
                       name: "Kitchen",
                       imageName: "kitchen",
                       wallColor: SKColor(red: 0.90, green: 0.88, blue: 0.78, alpha: 1),
                       floorColor: SKColor(red: 0.64, green: 0.64, blue: 0.68, alpha: 1),
                       floorHeight: 0.34,
                       furniture: [
                           FurniturePlacement(furniture: "counter", centerX: 0.20, bottomY: 0.26,
                                              width: 0.30, height: 0.14),
                           FurniturePlacement(furniture: "stove", centerX: 0.46, bottomY: 0.24,
                                              width: 0.14, height: 0.16),
                           FurniturePlacement(furniture: "chair", centerX: 0.68, bottomY: 0.20,
                                              width: 0.12, height: 0.15),
                           FurniturePlacement(furniture: "table", centerX: 0.80, bottomY: 0.05,
                                              width: 0.24, height: 0.14),
                       ]),

        RoomDefinition(id: "playroom",
                       name: "Playroom",
                       imageName: "playroom",
                       wallColor: SKColor(red: 0.94, green: 0.86, blue: 0.72, alpha: 1),
                       floorColor: SKColor(red: 0.80, green: 0.62, blue: 0.46, alpha: 1),
                       floorHeight: 0.40,
                       furniture: [
                           FurniturePlacement(furniture: "sofa", centerX: 0.80, bottomY: 0.22,
                                              width: 0.26, height: 0.16),
                           FurniturePlacement(furniture: "toy-box", centerX: 0.14, bottomY: 0.20,
                                              width: 0.16, height: 0.14),
                           // Laid out at the front of the room, so the character
                           // sitting on it draws over everything else.
                           FurniturePlacement(furniture: "rug", centerX: 0.44, bottomY: 0.05,
                                              width: 0.40, height: 0.10),
                       ]),
    ]

    /// Where you are before you go anywhere.
    static let starting: RoomDefinition = all[0]

    static func definition(id: String) -> RoomDefinition? {
        byID[id]
    }

    /// The first of any duplicate id wins, for the reason `ItemCatalog.byID` gives.
    private static let byID: [String: RoomDefinition] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
}
