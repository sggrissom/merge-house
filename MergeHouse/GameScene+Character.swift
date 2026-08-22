import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Character

    /// Builds the character, sized relative to the room and to whoever you are
    /// currently playing as. The container's position is the character's feet.
    func layoutCharacter() {
        // Only the body is rebuilt. Anything the character is carrying is a
        // sibling of it, and is redrawn separately at the end — otherwise
        // switching character would drop everything they were holding.
        characterBodyNode.removeAllChildren()

        characterHeight = roomRect.height * 0.30 * character.scale
        let height = characterHeight

        // Build at the origin, unrotated, so the accumulated frame comes out
        // in local coordinates.
        characterNode.position = .zero
        characterNode.zRotation = 0

        characterBodyNode.addChild(makeCharacterArtwork(for: character, height: height))

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = usingPiece?.definition.use?.label ?? character.name
        label.fontSize = max(12, height * 0.15)
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .bottom
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: height + height * 0.06)
        characterBodyNode.addChild(label)

        // Measured before the highlight is added, so the ring drawn around the
        // character does not itself count as part of them.
        characterLocalFrame = characterBodyNode.calculateAccumulatedFrame()
        characterBodyNode.addChild(makeCharacterHighlight())

        if let piece = usingPiece {
            characterNode.zRotation = piece.definition.use?.pose.rotation ?? 0
            characterNode.position = seatPosition(for: piece)
        } else {
            characterNode.position = clampedCharacterPosition(scenePosition(for: characterAnchor))
        }

        relayoutCarriedItems()
    }

    /// Redraws whatever the character is carrying. Their size and their carry
    /// points both belong to whoever they are, so a resize or a change of
    /// character moves the hat as well as the head.
    func relayoutCarriedItems() {
        let carried = items.filter { $0.location.carryStyle != nil }
        guard !carried.isEmpty else { return }
        for item in carried {
            itemNodes[item.id]?.removeFromParent()
            itemNodes[item.id] = nil
            addItemNode(for: item)
        }
        refreshItemDepths()
    }

    /// The ring that says "let go and they will take this". Hidden until a
    /// carryable item is dragged over them.
    func makeCharacterHighlight() -> SKNode {
        let padding = max(4, characterHeight * 0.04)
        let box = characterLocalFrame.insetBy(dx: -padding, dy: -padding)
        let highlight = SKShapeNode(rect: box, cornerRadius: padding * 2)
        highlight.name = Self.characterHighlightName
        highlight.fillColor = .clear
        highlight.strokeColor = Self.itemMergeStroke
        highlight.lineWidth = 5
        highlight.isHidden = true
        highlight.zPosition = -0.5
        return highlight
    }

    static let characterHighlightName = "carry-highlight"

    func highlightCharacter(_ on: Bool) {
        characterBodyNode.childNode(withName: Self.characterHighlightName)?.isHidden = !on
    }

    /// The character's own box in scene coordinates: their drawing and name tag,
    /// but not whatever they are carrying — a held Giant Teddy would otherwise
    /// count as part of them and drag the whole figure onto the bed with it.
    func characterSceneFrame() -> CGRect {
        let local = characterLocalFrame
        let corners = [CGPoint(x: local.minX, y: local.minY),
                       CGPoint(x: local.maxX, y: local.minY),
                       CGPoint(x: local.maxX, y: local.maxY),
                       CGPoint(x: local.minX, y: local.maxY)]
            .map { characterNode.convert($0, to: self) }

        var box = CGRect(origin: corners[0], size: .zero)
        for corner in corners.dropFirst() {
            box = box.union(CGRect(origin: corner, size: .zero))
        }
        return box
    }

    /// The current character's drawing, standing on the origin. Falls back to a
    /// stick figure in their own colours if the artwork is missing, the same way
    /// items do — which is how a character can be picked before being drawn.
    func makeCharacterArtwork(for definition: CharacterDefinition,
                                      height: CGFloat) -> SKNode {
        if let artwork = Artwork.named(definition.imageName) {
            let sprite = SKSpriteNode(texture: artwork.texture)
            // The drawing is trimmed, so `height` is the character's actual
            // height and the anchor is actually their feet: they stand on the
            // floor rather than on whatever empty space their file left below them.
            sprite.size = CGSize(width: height * artwork.aspect, height: height)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            return sprite
        }

        let placeholder = SKNode()
        let bodyWidth = height * 0.42
        let headRadius = height * 0.16
        let bodyHeight = height - headRadius * 2
        let outlineColor = SKColor(white: 0.2, alpha: 0.6)

        let bodyRect = CGRect(x: -bodyWidth / 2, y: 0, width: bodyWidth, height: bodyHeight)
        let body = SKShapeNode(rect: bodyRect, cornerRadius: bodyWidth * 0.35)
        body.fillColor = definition.bodyColor
        body.strokeColor = outlineColor
        body.lineWidth = 2
        placeholder.addChild(body)

        let head = SKShapeNode(circleOfRadius: headRadius)
        head.position = CGPoint(x: 0, y: bodyHeight + headRadius * 0.85)
        head.fillColor = definition.skinColor
        head.strokeColor = outlineColor
        head.lineWidth = 2
        placeholder.addChild(head)

        return placeholder
    }

    // MARK: - Character placement

    func scenePosition(for anchor: CGPoint) -> CGPoint {
        CGPoint(x: roomRect.minX + anchor.x * roomRect.width,
                y: roomRect.minY + anchor.y * roomRect.height)
    }

    func characterAnchor(for position: CGPoint) -> CGPoint {
        guard roomRect.width > 0, roomRect.height > 0 else { return characterAnchor }
        return CGPoint(x: (position.x - roomRect.minX) / roomRect.width,
                       y: (position.y - roomRect.minY) / roomRect.height)
    }

    /// Keeps the whole character — label included — inside the room.
    func clampedCharacterPosition(_ position: CGPoint) -> CGPoint {
        let minX = roomRect.minX - characterLocalFrame.minX
        let maxX = roomRect.maxX - characterLocalFrame.maxX
        let minY = roomRect.minY - characterLocalFrame.minY
        let maxY = roomRect.maxY - characterLocalFrame.maxY
        return CGPoint(x: min(max(position.x, minX), max(minX, maxX)),
                       y: min(max(position.y, minY), max(minY, maxY)))
    }
}
