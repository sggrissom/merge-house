import SpriteKit
import UIKit

/// How a character can have an item: not what the item *does*, but where on a
/// body it goes.
///
/// This is deliberately only the item's half of the bargain. A Bow knows it is a
/// thing worn on the head and nothing more; where the head actually is on any
/// particular character — and how big a hat should be there — is that
/// character's business, in `CarryPoint`. Neither side has to know about the
/// other, so a new item works on every character and a new character wears
/// everything already in the game.
enum CarryStyle: String, CaseIterable {
    case head
    case hand
    case body

    /// How carried things stack on the body. You hold a teddy in front of the
    /// dress you are wearing, and a hat sits over both — so the order is fixed
    /// here rather than left to whichever item happened to be put on last.
    var depth: CGFloat {
        switch self {
        case .body: return 1
        case .head: return 2
        case .hand: return 3
        }
    }

    /// How the Catalog describes it.
    var note: String {
        switch self {
        case .head: return "on the head"
        case .hand: return "held"
        case .body: return "worn"
        }
    }
}

/// What a character thinks of being handed one of these.
///
/// The item's half of a second bargain, built like the first one. An item says
/// it is the kind of thing that is *loved*, or *eaten*; how a character shows
/// that — what the bubble over their shoulder actually draws — is the
/// character's business, in `makeReactionMark`. So a Teddy never learns what a
/// Baby is, a new item is welcomed by everyone in the game the day it is added,
/// and a new character comes with an opinion about everything already in it.
///
/// An item that says nothing gets a sparkle, which is why every use of this is
/// an `Optional` rather than a case called `none`: having no particular opinion
/// is the normal state, not a fifth reaction.
enum Reaction {
    /// A heart. For the things you love rather than use.
    case love
    /// A star. For the things you put on and stand up straighter in.
    case proud
    /// Crumbs. For the things that do not survive being given to somebody.
    case yum
    /// A squiggle. For the things that are simply funny to be handed.
    case silly
}

/// One kind of object in the game: what it is called, what it should look like,
/// and what a pair of them merges into.
///
/// `imageName` is the asset the real drawing will use. Until that asset exists —
/// the normal state for every item right now — the item draws as a placeholder.
/// Dropping the PNG into the asset catalog is all it takes to replace one.
struct ItemDefinition {
    let id: String
    let name: String
    let imageName: String?
    /// The id of the item a pair of these becomes. `nil` tops out the chain.
    let mergesInto: String?
    /// Size relative to the base placeholder, so merge levels read at a glance.
    let scale: CGFloat
    /// Placeholder fill, used only while `imageName` has no artwork behind it.
    let placeholderColor: SKColor
    /// Where this goes on a character, if it can go on one at all. `nil` is an
    /// item you only ever put down — a Cake dropped on someone lands beside them.
    let carry: CarryStyle?
    /// What a character thinks of being given this. `nil` gets a generic
    /// sparkle, so leaving it out is a perfectly good answer.
    let reaction: Reaction?
    /// What this thing sounds like — a word, not a filename, and shared by
    /// everything made of the same stuff. The third of the same bargain `carry`
    /// and `reaction` strike: a Teddy says it is soft, and `SoundEvent` says
    /// what is happening to it. `teddy` plus a merge asks for `teddy-merge`,
    /// falling back to the shared `merge`, falling back to silence.
    ///
    /// `nil` — no particular noise of its own — is a perfectly good answer, and
    /// so is a word with no file behind it, which is what all of them are today.
    let sound: String?

    /// The drawing behind this item, if the asset actually exists. Missing art is
    /// the normal state during exploration, so this is an `Optional`, not an error.
    var artwork: UIImage? {
        guard let imageName = imageName else { return nil }
        return UIImage(named: imageName)
    }

    /// What to call the missing file, so the Catalog can tell you what to draw next.
    var missingArtworkNote: String {
        guard let imageName = imageName else { return "no image set" }
        return "needs \(imageName).png"
    }
}

/// Every item in the prototype. A new merge chain is entries in this list and
/// nothing else — no gameplay code knows what a teddy is.
enum ItemCatalog {

    static let all: [ItemDefinition] = [

        ItemDefinition(id: "teddy-small",
                       name: "Little Teddy",
                       imageName: "bear",
                       mergesInto: "teddy-big",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.85, green: 0.66, blue: 0.42, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),
        ItemDefinition(id: "teddy-big",
                       name: "Big Teddy",
                       imageName: "big-bear",
                       mergesInto: "teddy-giant",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),
        ItemDefinition(id: "teddy-giant",
                       name: "Giant Teddy",
                       imageName: "big-bear",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.62, green: 0.34, blue: 0.16, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),

        ItemDefinition(id: "bow",
                       name: "Bow",
                       imageName: "bow",
                       mergesInto: "bow-fancy",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.95, green: 0.62, blue: 0.76, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "bow-fancy",
                       name: "Fancy Bow",
                       imageName: "fancy-bow",
                       mergesInto: "tiara",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.85, green: 0.42, blue: 0.62, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "tiara",
                       name: "Tiara",
                       imageName: "tiara",
                       mergesInto: "crown",
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "crown",
                       name: "Crown",
                       imageName: "crown",
                       mergesInto: nil,
                       scale: 2.0,
                       placeholderColor: SKColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "cupcake-block",
                       name: "Cupcake",
                       imageName: "none",
                       mergesInto: "cake-block",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.98, green: 0.85, blue: 0.62, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-block",
                       name: "Cake",
                       imageName: "none",
                       mergesInto: "cake-giant-block",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.92, green: 0.66, blue: 0.45, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-giant-block",
                       name: "Giant Cake",
                       imageName: "none",
                       mergesInto: "wedding-cake-block",
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.78, green: 0.45, blue: 0.36, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "wedding-cake-block",
                       name: "Wedding Cake",
                       imageName: "none",
                       mergesInto: nil,
                       scale: 2.0,
                       placeholderColor: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cupcake",
                       name: "Cupcake",
                       imageName: "cupcake",
                       mergesInto: "cake",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.98, green: 0.85, blue: 0.62, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake",
                       name: "Cake",
                       imageName: "cake",
                       mergesInto: "cake-giant",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.92, green: 0.66, blue: 0.45, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-giant",
                       name: "Giant Cake",
                       imageName: "cake-giant",
                       mergesInto: "wedding-cake",
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.78, green: 0.45, blue: 0.36, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "wedding-cake",
                       name: "Wedding Cake",
                       imageName: "cake-gianter",
                       mergesInto: nil,
                       scale: 2.0,
                       placeholderColor: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),

        ItemDefinition(id: "dress",
                       name: "Dress",
                       imageName: "dress",
                       mergesInto: "party-dress",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.62, green: 0.78, blue: 0.94, alpha: 1),
                       carry: .body,
                       reaction: .proud,
                       sound: "cloth"),
        ItemDefinition(id: "party-dress",
                       name: "Party Dress",
                       imageName: "party-dress",
                       mergesInto: "ball-gown",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.48, green: 0.60, blue: 0.90, alpha: 1),
                       carry: .body,
                       reaction: .proud,
                       sound: "cloth"),
        ItemDefinition(id: "ball-gown",
                       name: "Ball Gown",
                       imageName: "ball-gown",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.40, green: 0.36, blue: 0.78, alpha: 1),
                       carry: .body,
                       reaction: .proud,
                       sound: "cloth"),

        ItemDefinition(id: "leaf",
                       name: "Leaf",
                       imageName: "leaf",
                       mergesInto: "sapling",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.58, green: 0.82, blue: 0.44, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: "leaf"),
        ItemDefinition(id: "sapling",
                       name: "Sapling",
                       imageName: "sapling",
                       mergesInto: "tree",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.38, green: 0.68, blue: 0.36, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: "leaf"),
        ItemDefinition(id: "tree",
                       name: "Tree",
                       imageName: "tree",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.22, green: 0.50, blue: 0.28, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: "leaf"),

        // Three colours of the same thing rather than a chain: nothing merges
        // into a frosting and a frosting merges into nothing, so each is dealt
        // out and stays what it is.
        ItemDefinition(id: "red-frosting",
                       name: "Red Frosting",
                       imageName: "red-frosting",
                       mergesInto: nil,
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.88, green: 0.26, blue: 0.28, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "goo"),
        ItemDefinition(id: "blue-frosting",
                       name: "Blue Frosting",
                       imageName: "blue-frosting",
                       mergesInto: nil,
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.32, green: 0.48, blue: 0.88, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "goo"),
        ItemDefinition(id: "pink-frosting",
                       name: "Pink Frosting",
                       imageName: "pink-frosting",
                       mergesInto: nil,
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.96, green: 0.55, blue: 0.72, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "goo"),

        ItemDefinition(id: "headband",
                       name: "Headband",
                       imageName: "headband",
                       mergesInto: nil,
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.92, green: 0.40, blue: 0.62, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "lona-misa",
                       name: "Lona Misa",
                       imageName: "lona-misa",
                       mergesInto: nil,
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.72, green: 0.62, blue: 0.38, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: nil),
    ]

    /// The biggest `scale` anything in the catalog has. A view with a fixed
    /// amount of room per item — the Stuff shelf — fits the whole range into that
    /// room rather than letting the top of a chain spill over its neighbours, so
    /// it needs to know where the range ends.
    static let maxScale: CGFloat = all.map { $0.scale }.max() ?? 1

    /// The bottom of every chain: the items nothing else merges into. These are
    /// what `Get Stuff` hands out, so a new chain becomes reachable simply by
    /// being listed above.
    static let starters: [ItemDefinition] = all.filter { candidate in
        !all.contains { $0.mergesInto == candidate.id }
    }

    /// Every merge chain, bottom to top. Built by walking `mergesInto` from each
    /// starter, so adding a chain to `all` is still the only step there is.
    static let chains: [[ItemDefinition]] = starters.map { starter in
        var chain = [starter]
        var seen: Set<String> = [starter.id]
        while let next = mergeResult(for: chain[chain.count - 1]), !seen.contains(next.id) {
            chain.append(next)
            seen.insert(next.id)
        }
        return chain
    }

    /// How far up its chain a thing is, counting the bottom of the chain as 1.
    ///
    /// Read off `chains`, so it stays true as the catalog is edited and nothing
    /// has to number itself. A thing in no chain at all — which cannot happen,
    /// since a chain of one is still a chain — would be at the bottom of one.
    static func level(of definition: ItemDefinition) -> Int {
        levelByID[definition.id] ?? 1
    }

    private static let levelByID: [String: Int] = {
        var levels: [String: Int] = [:]
        for chain in chains {
            for (index, definition) in chain.enumerated() {
                // The shortest way to a thing wins, for an item that two chains
                // both climb through: it is the same thing at the same size, and
                // it should not sound different depending on how it was reached.
                levels[definition.id] = min(levels[definition.id] ?? .max, index + 1)
            }
        }
        return levels
    }()

    /// Catalog order, used to sort loose items so a chain reads left to right.
    static func sortIndex(of definition: ItemDefinition) -> Int {
        all.firstIndex { $0.id == definition.id } ?? all.count
    }

    /// One random level-one item.
    static func randomStarter() -> ItemDefinition {
        starters.randomElement() ?? all[0]
    }

    static func definition(id: String) -> ItemDefinition? {
        byID[id]
    }

    /// What a pair of `item` merges into, if anything.
    static func mergeResult(for item: ItemDefinition) -> ItemDefinition? {
        guard let nextID = item.mergesInto else { return nil }
        return definition(id: nextID)
    }

    /// Two entries with the same id is a slip while editing the list, not a
    /// state the game has to have an opinion about — the first one wins. It used
    /// to be `uniqueKeysWithValues`, which trapped, so a mistyped id took the app
    /// down on launch with nothing to read. A catalog you can edit freely is the
    /// whole premise here, and that includes editing it wrong for a minute.
    private static let byID: [String: ItemDefinition] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
}
