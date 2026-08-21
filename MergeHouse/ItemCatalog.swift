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
                       carry: .hand),
        ItemDefinition(id: "teddy-big",
                       name: "Big Teddy",
                       imageName: "big-bear",
                       mergesInto: "teddy-giant",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1),
                       carry: .hand),
        ItemDefinition(id: "teddy-giant",
                       name: "Giant Teddy",
                       imageName: "big-bear",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.62, green: 0.34, blue: 0.16, alpha: 1),
                       carry: .hand),

        ItemDefinition(id: "bow",
                       name: "Bow",
                       imageName: "bow",
                       mergesInto: "bow-fancy",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.95, green: 0.62, blue: 0.76, alpha: 1),
                       carry: .head),
        ItemDefinition(id: "bow-fancy",
                       name: "Fancy Bow",
                       imageName: "fancy-bow",
                       mergesInto: "tiara",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.85, green: 0.42, blue: 0.62, alpha: 1),
                       carry: .head),
        ItemDefinition(id: "tiara",
                       name: "Tiara",
                       imageName: "tiara",
                       mergesInto: "crown",
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1),
                       carry: .head),
        ItemDefinition(id: "crown",
                       name: "Crown",
                       imageName: "crown",
                       mergesInto: nil,
                       scale: 2.0,
                       placeholderColor: SKColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .head),
        ItemDefinition(id: "cupcake",
                       name: "Cupcake",
                       imageName: "cupcake",
                       mergesInto: "cake",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.98, green: 0.85, blue: 0.62, alpha: 1),
                       carry: .hand),
        ItemDefinition(id: "cake",
                       name: "Cake",
                       imageName: "cake",
                       mergesInto: "cake-giant",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.92, green: 0.66, blue: 0.45, alpha: 1),
                       carry: .hand),
        ItemDefinition(id: "cake-giant",
                       name: "Giant Cake",
                       imageName: "cake-giant",
                       mergesInto: "wedding-cake",
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.78, green: 0.45, blue: 0.36, alpha: 1),
                       carry: .hand),
        ItemDefinition(id: "wedding-cake",
                       name: "Wedding Cake",
                       imageName: "cake-gianter",
                       mergesInto: nil,
                       scale: 2.0,
                       placeholderColor: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                       carry: .hand),

        ItemDefinition(id: "dress",
                       name: "Dress",
                       imageName: "dress",
                       mergesInto: "party-dress",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.62, green: 0.78, blue: 0.94, alpha: 1),
                       carry: .body),
        ItemDefinition(id: "party-dress",
                       name: "Party Dress",
                       imageName: "party-dress",
                       mergesInto: "ball-gown",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.48, green: 0.60, blue: 0.90, alpha: 1),
                       carry: .body),
        ItemDefinition(id: "ball-gown",
                       name: "Ball Gown",
                       imageName: "ball-gown",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.40, green: 0.36, blue: 0.78, alpha: 1),
                       carry: .body),
    ]

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

    private static let byID: [String: ItemDefinition] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
