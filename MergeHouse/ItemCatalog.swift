import SpriteKit

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
}

/// Every item in the prototype. A new merge chain is entries in this list and
/// nothing else — no gameplay code knows what a teddy is.
enum ItemCatalog {

    static let all: [ItemDefinition] = [
        ItemDefinition(id: "teddy-small",
                       name: "Little Teddy",
                       imageName: "teddy-small",
                       mergesInto: "teddy-big",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.85, green: 0.66, blue: 0.42, alpha: 1)),
        ItemDefinition(id: "teddy-big",
                       name: "Big Teddy",
                       imageName: "teddy-big",
                       mergesInto: "teddy-giant",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1)),
        ItemDefinition(id: "teddy-giant",
                       name: "Giant Teddy",
                       imageName: "teddy-giant",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.62, green: 0.34, blue: 0.16, alpha: 1)),

        ItemDefinition(id: "bow",
                       name: "Bow",
                       imageName: "bow",
                       mergesInto: "bow-fancy",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.95, green: 0.62, blue: 0.76, alpha: 1)),
        ItemDefinition(id: "bow-fancy",
                       name: "Fancy Bow",
                       imageName: "bow-fancy",
                       mergesInto: "tiara",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.85, green: 0.42, blue: 0.62, alpha: 1)),
        ItemDefinition(id: "tiara",
                       name: "Tiara",
                       imageName: "tiara",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1)),

        ItemDefinition(id: "cupcake",
                       name: "Cupcake",
                       imageName: "cupcake",
                       mergesInto: "cake",
                       scale: 1.0,
                       placeholderColor: SKColor(red: 0.98, green: 0.85, blue: 0.62, alpha: 1)),
        ItemDefinition(id: "cake",
                       name: "Cake",
                       imageName: "cake",
                       mergesInto: "cake-giant",
                       scale: 1.28,
                       placeholderColor: SKColor(red: 0.92, green: 0.66, blue: 0.45, alpha: 1)),
        ItemDefinition(id: "cake-giant",
                       name: "Giant Cake",
                       imageName: "cake-giant",
                       mergesInto: nil,
                       scale: 1.6,
                       placeholderColor: SKColor(red: 0.78, green: 0.45, blue: 0.36, alpha: 1)),
    ]

    /// The bottom of every chain: the items nothing else merges into. These are
    /// what `Get Stuff` hands out, so a new chain becomes reachable simply by
    /// being listed above.
    static let starters: [ItemDefinition] = all.filter { candidate in
        !all.contains { $0.mergesInto == candidate.id }
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
