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
    /// What this becomes when it is dropped on something *different*, keyed by
    /// the other item's id.
    ///
    /// Merging is a pair of the same thing; mixing is a pair of two things that
    /// go together, and it is how a Cake meets Frosting. Written once, on
    /// whichever half of the pair it reads better on — a Frosting knows what it
    /// does to a Cake, and a Cake has never heard of Frosting — because
    /// `mixResult` asks both sides and so it works whichever one is carried to
    /// the other. Empty is the normal answer: most things go with nothing.
    let mixes: [String: String]
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
        let filename = (imageName as NSString).pathExtension.isEmpty
            ? "\(imageName).png" : imageName
        return "needs \(filename)"
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
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.85, green: 0.66, blue: 0.42, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),
        ItemDefinition(id: "teddy-big",
                       name: "Big Teddy",
                       imageName: "big-bear",
                       mergesInto: "teddy-giant",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),
        ItemDefinition(id: "teddy-giant",
                       name: "Giant Teddy",
                       imageName: "big-bear",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.62, green: 0.34, blue: 0.16, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),

        ItemDefinition(id: "bow",
                       name: "Bow",
                       imageName: "bow",
                       mergesInto: "bow-fancy",
                       // A bow is a thing you tie onto something, and a teddy is a something.
                       mixes: ["teddy-small": "teddy-bow"],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.95, green: 0.62, blue: 0.76, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "bow-fancy",
                       name: "Fancy Bow",
                       imageName: "fancy-bow",
                       mergesInto: "tiara",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.85, green: 0.42, blue: 0.62, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "tiara",
                       name: "Tiara",
                       imageName: "tiara",
                       mergesInto: "crown",
                       mixes: [:],
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "crown",
                       name: "Crown",
                       imageName: "crown",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 2.0,
                       placeholderColor: SKColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        ItemDefinition(id: "cupcake-block",
                       name: "Cupcake Block",
                       imageName: "none",
                       mergesInto: "cake-block",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.98, green: 0.85, blue: 0.62, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-block",
                       name: "Cake Block",
                       imageName: "none",
                       mergesInto: "cake-giant-block",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.92, green: 0.66, blue: 0.45, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-giant-block",
                       name: "Giant Cake Block",
                       imageName: "none",
                       mergesInto: "wedding-cake-block",
                       mixes: [:],
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.78, green: 0.45, blue: 0.36, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "wedding-cake-block",
                       name: "Wedding Cake Block",
                       imageName: "none",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 2.0,
                       placeholderColor: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cupcake",
                       name: "Cupcake",
                       imageName: "cupcake",
                       mergesInto: "cake",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.98, green: 0.85, blue: 0.62, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake",
                       name: "Cake",
                       imageName: "cake",
                       mergesInto: "cake-giant",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.92, green: 0.66, blue: 0.45, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-giant",
                       name: "Giant Cake",
                       imageName: "cake-giant",
                       mergesInto: "wedding-cake",
                       mixes: [:],
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.78, green: 0.45, blue: 0.36, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "wedding-cake",
                       name: "Wedding Cake",
                       imageName: "cake-gianter",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 2.0,
                       placeholderColor: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),

        ItemDefinition(id: "dress",
                       name: "Dress",
                       imageName: "dress",
                       mergesInto: "party-dress",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.62, green: 0.78, blue: 0.94, alpha: 1),
                       carry: .body,
                       reaction: .proud,
                       sound: "cloth"),
        ItemDefinition(id: "party-dress",
                       name: "Party Dress",
                       imageName: "party-dress",
                       mergesInto: "ball-gown",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.48, green: 0.60, blue: 0.90, alpha: 1),
                       carry: .body,
                       reaction: .proud,
                       sound: "cloth"),
        ItemDefinition(id: "ball-gown",
                       name: "Ball Gown",
                       imageName: "ball-gown",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.40, green: 0.36, blue: 0.78, alpha: 1),
                       carry: .body,
                       reaction: .proud,
                       sound: "cloth"),

        ItemDefinition(id: "leaf",
                       name: "Leaf",
                       imageName: "leaf",
                       mergesInto: "sapling",
                       // Nobody asked for this and it is the best one.
                       mixes: ["cupcake": "cupcake-leafy"],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.58, green: 0.82, blue: 0.44, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: "leaf"),
        ItemDefinition(id: "sapling",
                       name: "Sapling",
                       imageName: "sapling",
                       mergesInto: "tree",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.38, green: 0.68, blue: 0.36, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: "leaf"),
        ItemDefinition(id: "tree",
                       name: "Tree",
                       imageName: "tree",
                       mergesInto: nil,
                       mixes: [:],
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
                       // Frosting is the thing being applied, so it is the half of the pair
                       // that carries the recipe: a Cake has never heard of Frosting.
                       mixes: ["cupcake": "cupcake-red", "cake": "cake-red"],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.88, green: 0.26, blue: 0.28, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "goo"),
        ItemDefinition(id: "blue-frosting",
                       name: "Blue Frosting",
                       imageName: "blue-frosting",
                       mergesInto: nil,
                       // Frosting is the thing being applied, so it is the half of the pair
                       // that carries the recipe: a Cake has never heard of Frosting.
                       mixes: ["cupcake": "cupcake-blue", "cake": "cake-blue"],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.32, green: 0.48, blue: 0.88, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "goo"),
        ItemDefinition(id: "pink-frosting",
                       name: "Pink Frosting",
                       imageName: "pink-frosting",
                       mergesInto: nil,
                       // Frosting is the thing being applied, so it is the half of the pair
                       // that carries the recipe: a Cake has never heard of Frosting.
                       mixes: ["cupcake": "cupcake-pink", "cake": "cake-pink"],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.96, green: 0.55, blue: 0.72, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "goo"),

        ItemDefinition(id: "headband",
                       name: "Headband",
                       imageName: "headband",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.92, green: 0.40, blue: 0.62, alpha: 1),
                       carry: .head,
                       reaction: .proud,
                       sound: "trinket"),
        // Nothing is dealt these and nothing merges up to them: every one of
        // them is the result of a mix, and the only way to a Red Cake is to have
        // carried a Red Frosting to a Cake. They are ordinary catalog entries in
        // every other way — a frosted Cupcake merges into a frosted Cake, and
        // that Cake tops out its own little chain and throws its own confetti.
        ItemDefinition(id: "cupcake-red",
                       name: "Red Cupcake",
                       imageName: "cupcake-red",
                       mergesInto: "cake-red",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.93, green: 0.42, blue: 0.40, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-red",
                       name: "Red Cake",
                       imageName: "cake-red",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.88, green: 0.30, blue: 0.30, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cupcake-blue",
                       name: "Blue Cupcake",
                       imageName: "cupcake-blue",
                       mergesInto: "cake-blue",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.55, green: 0.66, blue: 0.93, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-blue",
                       name: "Blue Cake",
                       imageName: "cake-blue",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.40, green: 0.54, blue: 0.90, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cupcake-pink",
                       name: "Pink Cupcake",
                       imageName: "cupcake-pink",
                       mergesInto: "cake-pink",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.97, green: 0.68, blue: 0.80, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "cake-pink",
                       name: "Pink Cake",
                       imageName: "cake-pink",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.95, green: 0.56, blue: 0.72, alpha: 1),
                       carry: .hand,
                       reaction: .yum,
                       sound: "cake"),
        ItemDefinition(id: "teddy-bow",
                       name: "Teddy With A Bow",
                       imageName: "teddy-bow",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.14,
                       placeholderColor: SKColor(red: 0.90, green: 0.56, blue: 0.52, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: "teddy"),
        ItemDefinition(id: "cupcake-leafy",
                       name: "Leafy Cupcake",
                       imageName: "cupcake-leafy",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.74, green: 0.82, blue: 0.50, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: "leaf"),

        ItemDefinition(id: "child-art",
                       name: "Child Art",
                       imageName: "child-art.png",
                       mergesInto: "pretty-painting",
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.52, green: 0.78, blue: 0.92, alpha: 1),
                       carry: .hand,
                       reaction: .proud,
                       sound: nil),
        ItemDefinition(id: "pretty-painting",
                       name: "Pretty Painting",
                       imageName: "pretty-painting",
                       mergesInto: "lona-misa",
                       mixes: [:],
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.42, green: 0.64, blue: 0.82, alpha: 1),
                       carry: .hand,
                       reaction: .proud,
                       sound: nil),
        ItemDefinition(id: "lona-misa",
                       name: "Lona Misa",
                       imageName: "lona-misa",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.72, green: 0.62, blue: 0.38, alpha: 1),
                       carry: .hand,
                       reaction: .proud,
                       sound: nil),

        ItemDefinition(id: "vampire",
                       name: "Vampire",
                       imageName: "vampire",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.68, green: 0.12, blue: 0.18, alpha: 1),
                       carry: .hand,
                       reaction: .silly,
                       sound: nil),
        ItemDefinition(id: "dog",
                       name: "Dog",
                       imageName: "dog",
                       mergesInto: nil,
                       mixes: [:],
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.72, green: 0.50, blue: 0.24, alpha: 1),
                       carry: .hand,
                       reaction: .love,
                       sound: nil),
    ]

    /// The biggest `scale` anything in the catalog has. A view with a fixed
    /// amount of room per item — the Stuff shelf — fits the whole range into that
    /// room rather than letting the top of a chain spill over its neighbours, so
    /// it needs to know where the range ends.
    static let maxScale: CGFloat = all.map { $0.scale }.max() ?? 1

    /// The bottom of every chain: the items nothing else merges into.
    static let chainBottoms: [ItemDefinition] = all.filter { candidate in
        !all.contains { $0.mergesInto == candidate.id }
    }

    /// Everything that only ever comes out of a mix. Read off the recipes rather
    /// than listed, so an item stops being dealt out the moment somebody makes it
    /// the result of one and starts again if they take that recipe away.
    static let mixResults: Set<String> = Set(all.flatMap { $0.mixes.values })

    /// What `Get Stuff` hands out: the bottom of every chain, except the ones
    /// that only exist by being discovered. A new chain becomes reachable simply
    /// by being listed above — but a Red Cake handed over by the shelf would be a
    /// Red Cake nobody made, and finding out that frosting goes on cake is the
    /// whole of what mixing is for.
    static let starters: [ItemDefinition] = chainBottoms.filter { !mixResults.contains($0.id) }

    /// Every merge chain, bottom to top. Built by walking `mergesInto` from each
    /// chain bottom, so adding a chain to `all` is still the only step there is —
    /// and a chain that can only be discovered is still a chain, and still listed
    /// in the Catalog, whether or not the shelf will ever deal out its first link.
    static let chains: [[ItemDefinition]] = chainBottoms.map { starter in
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

    /// What these two become when they meet, if they go together at all.
    ///
    /// Asked of the *pair* rather than of one of them, because mixing is
    /// symmetric: a Frosting carried to a Cake and a Cake carried to a Frosting
    /// are the same thing happening. So a recipe is written once, on whichever
    /// half of the pair it reads better on, and works whichever way round a
    /// child does it. Both saying so is a slip while editing the list rather
    /// than a state to have an opinion about — the item being carried wins,
    /// which is the one whose own recipe was being followed.
    ///
    /// A pair of the same thing is a merge and never a mix, so an item that
    /// somehow lists itself is refused here rather than turning one Cake into
    /// two halves of something.
    static func mixResult(_ item: ItemDefinition, _ other: ItemDefinition) -> ItemDefinition? {
        guard item.id != other.id,
              let resultID = item.mixes[other.id] ?? other.mixes[item.id] else { return nil }
        return definition(id: resultID)
    }

    /// Two entries with the same id is a slip while editing the list, not a
    /// state the game has to have an opinion about — the first one wins. It used
    /// to be `uniqueKeysWithValues`, which trapped, so a mistyped id took the app
    /// down on launch with nothing to read. A catalog you can edit freely is the
    /// whole premise here, and that includes editing it wrong for a minute.
    private static let byID: [String: ItemDefinition] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
}
