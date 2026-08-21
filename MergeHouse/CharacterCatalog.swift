import SpriteKit
import UIKit

/// Where one kind of carried thing sits on a character, and how big it draws.
///
/// This is the character's half of the bargain that `CarryStyle` starts. The
/// item says "I am worn on the head"; this says where the head is *on me*, which
/// is the part that genuinely varies. `girl.png` is a small figure floating in a
/// large square, so her hat sits at 0.80 of her height; the stick figure fills
/// its frame and wants 0.93. Neither of them is wrong, and neither the Bow nor
/// the game code has to know the difference.
///
/// Everything is a fraction of the character's drawn height — x included — so a
/// resize, a rotation, or a character with a different `scale` all keep working.
struct CarryPoint {
    /// Sideways offset from the character's centre line.
    let x: CGFloat
    /// Height above the character's feet.
    let y: CGFloat
    /// The item's height, as a fraction of the character's.
    let size: CGFloat
    /// Whether the item draws over the character or behind them.
    let inFront: Bool

    /// What a character gets for any carry point they have not tuned. Measured
    /// against the placeholder stick figure, which fills its frame the way most
    /// tightly-cropped artwork does.
    static func standard(for style: CarryStyle) -> CarryPoint {
        switch style {
        case .head: return CarryPoint(x: 0, y: 0.93, size: 0.24, inFront: true)
        case .hand: return CarryPoint(x: 0.20, y: 0.46, size: 0.28, inFront: true)
        case .body: return CarryPoint(x: 0, y: 0.50, size: 0.38, inFront: true)
        }
    }
}

/// One character you can be: what they are called, what they should look like,
/// and how they are drawn until that drawing exists.
///
/// The same bargain the items make. `imageName` is the asset the real drawing
/// will use, and every character falls back to a stick figure in their own
/// colours until the PNG lands. Dropping the file in is all it takes to replace one.
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
    /// Where carried things sit on this particular character. Anything left out
    /// falls back to `CarryPoint.standard`, so a new character needs no entries
    /// here at all until a hat lands somewhere silly — then you tune that one
    /// line rather than teaching the hat about them.
    let carryPoints: [CarryStyle: CarryPoint]

    /// Where a thing of this kind goes on this character.
    func carryPoint(for style: CarryStyle) -> CarryPoint {
        carryPoints[style] ?? CarryPoint.standard(for: style)
    }

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
                            imageName: "girl",
                            scale: 1.0,
                            bodyColor: SKColor(red: 0.90, green: 0.36, blue: 0.55, alpha: 1),
                            skinColor: SKColor(red: 0.98, green: 0.84, blue: 0.72, alpha: 1),
                            carryPoints: [
                                .head: CarryPoint(x: 0, y: 0.80, size: 0.22, inFront: true),
                                .hand: CarryPoint(x: 0.185, y: 0.45, size: 0.20, inFront: true),
                                .body: CarryPoint(x: 0, y: 0.48, size: 0.30, inFront: true),
                            ]),
        CharacterDefinition(id: "boy",
                            name: "Boy",
                            imageName: "Basic_human_drawing",
                            scale: 1.0,
                            bodyColor: SKColor(red: 0.32, green: 0.55, blue: 0.88, alpha: 1),
                            skinColor: SKColor(red: 0.94, green: 0.78, blue: 0.62, alpha: 1),
                            carryPoints: [:]),
        CharacterDefinition(id: "princess",
                            name: "Princess",
                            imageName: "princess",
                            scale: 1.04,
                            bodyColor: SKColor(red: 0.72, green: 0.44, blue: 0.86, alpha: 1),
                            skinColor: SKColor(red: 0.99, green: 0.87, blue: 0.76, alpha: 1),
                            carryPoints: [:]),
        CharacterDefinition(id: "baby",
                            name: "Baby",
                            imageName: "baby",
                            scale: 0.62,
                            bodyColor: SKColor(red: 0.98, green: 0.83, blue: 0.42, alpha: 1),
                            skinColor: SKColor(red: 0.97, green: 0.82, blue: 0.70, alpha: 1),
                            carryPoints: [:]),
        CharacterDefinition(id: "mum",
                            name: "Mum",
                            imageName: "mum",
                            scale: 1.24,
                            bodyColor: SKColor(red: 0.28, green: 0.62, blue: 0.56, alpha: 1),
                            skinColor: SKColor(red: 0.78, green: 0.58, blue: 0.44, alpha: 1),
                            carryPoints: [:]),
        CharacterDefinition(id: "dad",
                            name: "Dad",
                            imageName: "dad",
                            scale: 1.30,
                            bodyColor: SKColor(red: 0.55, green: 0.48, blue: 0.38, alpha: 1),
                            skinColor: SKColor(red: 0.86, green: 0.68, blue: 0.52, alpha: 1),
                            carryPoints: [:]),
    ]

    /// Who you are before you pick anyone.
    static let starting: CharacterDefinition = all[0]

    static func definition(id: String) -> CharacterDefinition? {
        byID[id]
    }

    private static let byID: [String: CharacterDefinition] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
