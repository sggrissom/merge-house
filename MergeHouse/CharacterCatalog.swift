import SpriteKit
import UIKit

/// One character you can be: what she is called, what she should look like, and
/// how she is drawn until that drawing exists.
///
/// The same bargain the items make. `imageName` is the asset the real drawing
/// will use, and every character falls back to a stick figure in her own colours
/// until the PNG lands. Dropping the file in is all it takes to replace one.
struct CharacterDefinition {
    let id: String
    let name: String
    let imageName: String?
    /// Height relative to the default character, so a Baby reads as small and a
    /// grown-up as tall without either needing its own layout code.
    let scale: CGFloat
    /// Placeholder body fill, used only while `imageName` has no artwork behind it.
    let bodyColor: SKColor
    /// Placeholder head fill, likewise.
    let skinColor: SKColor

    /// The drawing behind this character, if the asset actually exists. Missing
    /// art is the normal state during exploration, so this is an `Optional`.
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

/// Everyone you can play as. A new character is one entry in this list and
/// nothing else — no gameplay code knows who the Girl is.
enum CharacterCatalog {

    static let all: [CharacterDefinition] = [

        CharacterDefinition(id: "girl",
                            name: "Girl",
                            imageName: "Basic_human_drawing",
                            scale: 1.0,
                            bodyColor: SKColor(red: 0.90, green: 0.36, blue: 0.55, alpha: 1),
                            skinColor: SKColor(red: 0.98, green: 0.84, blue: 0.72, alpha: 1)),
        CharacterDefinition(id: "boy",
                            name: "Boy",
                            imageName: "boy",
                            scale: 1.0,
                            bodyColor: SKColor(red: 0.32, green: 0.55, blue: 0.88, alpha: 1),
                            skinColor: SKColor(red: 0.94, green: 0.78, blue: 0.62, alpha: 1)),
        CharacterDefinition(id: "princess",
                            name: "Princess",
                            imageName: "princess",
                            scale: 1.04,
                            bodyColor: SKColor(red: 0.72, green: 0.44, blue: 0.86, alpha: 1),
                            skinColor: SKColor(red: 0.99, green: 0.87, blue: 0.76, alpha: 1)),
        CharacterDefinition(id: "baby",
                            name: "Baby",
                            imageName: "baby",
                            scale: 0.62,
                            bodyColor: SKColor(red: 0.98, green: 0.83, blue: 0.42, alpha: 1),
                            skinColor: SKColor(red: 0.97, green: 0.82, blue: 0.70, alpha: 1)),
        CharacterDefinition(id: "mum",
                            name: "Mum",
                            imageName: "mum",
                            scale: 1.24,
                            bodyColor: SKColor(red: 0.28, green: 0.62, blue: 0.56, alpha: 1),
                            skinColor: SKColor(red: 0.78, green: 0.58, blue: 0.44, alpha: 1)),
        CharacterDefinition(id: "dad",
                            name: "Dad",
                            imageName: "dad",
                            scale: 1.30,
                            bodyColor: SKColor(red: 0.55, green: 0.48, blue: 0.38, alpha: 1),
                            skinColor: SKColor(red: 0.86, green: 0.68, blue: 0.52, alpha: 1)),
    ]

    /// Who you are before you pick anyone.
    static let starting: CharacterDefinition = all[0]

    static func definition(id: String) -> CharacterDefinition? {
        byID[id]
    }

    private static let byID: [String: CharacterDefinition] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
