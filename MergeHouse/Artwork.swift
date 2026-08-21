import SpriteKit
import UIKit

// MARK: - Artwork

/// A drawing, cropped to the part of its file that is actually drawn on.
///
/// Every PNG here is a canvas with the subject floating somewhere inside it, and
/// how much of the canvas the subject covers is an accident of how the picture
/// was made rather than anything about the thing it shows. `bear.png` fills 97%
/// of its height; `tiara.png` fills 42%; `sapling.png` fills 30%. Sizing a
/// sprite by its file therefore sizes it by that accident — which is why a Tiara
/// drew *smaller* than the Fancy Bow it merges up from, and why the Girl stood a
/// third shorter than she was asked to, hovering above the floor with a hit box
/// twice as wide as she was.
///
/// So nothing is sized by its file. Every drawing is cropped to its opaque pixels
/// and it is that crop the game gives a size to, which makes `scale` in
/// `ItemCatalog` and a character's height mean what they say whatever the art
/// happens to do inside its canvas. Trimming is not something new art has to be
/// put through first — dropping the PNG in is still the whole job.
struct Artwork {
    let texture: SKTexture
    /// The drawn part's width over its height. Boxes are shaped to this so a wide
    /// thing and a tall thing of the same level read as the same size.
    let aspect: CGFloat

    /// The trimmed drawing for an asset name, or `nil` if there is no such asset —
    /// which is the normal state for anything not drawn yet, not an error.
    /// Cached, because trimming means reading pixels and the answer never changes.
    static func named(_ name: String?) -> Artwork? {
        guard let name = name else { return nil }
        if let known = cache[name] { return known.artwork }

        guard let image = UIImage(named: name) else {
            cache[name] = Entry(artwork: nil)
            return nil
        }

        let whole = SKTexture(image: image)
        let texture = opaqueRect(of: image).map { SKTexture(rect: $0, in: whole) } ?? whole
        let size = texture.size()
        let artwork = Artwork(texture: texture,
                              aspect: size.height > 0 ? size.width / size.height : 1)
        cache[name] = Entry(artwork: artwork)
        return artwork
    }

    /// A missing asset is cached too, so a catalog entry with no artwork yet does
    /// not send every redraw back to the bundle looking for it.
    private struct Entry {
        let artwork: Artwork?
    }

    private static var cache: [String: Entry] = [:]

    /// The part of an image that is not fully transparent, in the unit
    /// coordinates `SKTexture(rect:in:)` wants — origin at the bottom left.
    /// `nil` means take the whole canvas: either it is already cropped, or it is
    /// blank, and blowing up nothing to fill a box would be worse than leaving it.
    ///
    /// The scan is deliberately coarse. It is deciding where to cut a 2048px
    /// drawing, so a few pixels of slack are invisible, while reading four
    /// million of them per asset is not free.
    private static func opaqueRect(of image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }

        let columns = min(cgImage.width, 192)
        let rows = min(cgImage.height, 192)
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)

        let scanned = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: columns, height: rows,
                bitsPerComponent: 8, bytesPerRow: columns * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            // Averaged down rather than point sampled: a thin edge has to survive
            // the shrink, or the crop would cut it off.
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: columns, height: rows))
            return true
        }
        guard scanned else { return nil }

        var minColumn = columns, maxColumn = -1
        var minRow = rows, maxRow = -1
        for row in 0..<rows {
            for column in 0..<columns where pixels[(row * columns + column) * 4 + 3] > 0 {
                minColumn = min(minColumn, column)
                maxColumn = max(maxColumn, column)
                minRow = min(minRow, row)
                maxRow = max(maxRow, row)
            }
        }
        guard maxColumn >= minColumn, maxRow >= minRow else { return nil }

        let width = CGFloat(maxColumn - minColumn + 1) / CGFloat(columns)
        let height = CGFloat(maxRow - minRow + 1) / CGFloat(rows)
        guard width < 1 || height < 1 else { return nil }

        // Bitmap rows run down from the top; texture coordinates run up from the
        // bottom, so the last row scanned is the first row of the crop.
        return CGRect(x: CGFloat(minColumn) / CGFloat(columns),
                      y: CGFloat(rows - 1 - maxRow) / CGFloat(rows),
                      width: width, height: height)
    }
}
