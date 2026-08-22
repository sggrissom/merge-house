import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Room

    func layoutRoom() {
        roomNode.removeAllChildren()

        if let backdrop = makeBackdrop(named: room.imageName, in: roomRect) {
            backdrop.zPosition = 0
            roomNode.addChild(backdrop)
        } else {
            let placeholder = makePlaceholderRoom(for: room, in: roomRect)
            placeholder.zPosition = 0
            roomNode.addChild(placeholder)
        }

        let outline = SKShapeNode(rect: roomRect)
        outline.fillColor = .clear
        outline.strokeColor = SKColor(white: 0.25, alpha: 1)
        outline.lineWidth = 3
        outline.zPosition = 2
        roomNode.addChild(outline)

        let titleSize = max(20, roomRect.height * 0.07)
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = room.name
        label.fontSize = titleSize
        label.fontColor = SKColor(white: 0.25, alpha: 1)
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: roomRect.midX, y: roomRect.maxY - roomRect.height * 0.05)
        label.zPosition = 3
        roomNode.addChild(label)

        // The same caption an undrawn item or character gets, in the same place
        // the name is: a room with no backdrop yet says which file would give it one.
        guard room.artwork == nil else { return }
        let note = SKLabelNode(fontNamed: "AvenirNext-Medium")
        note.text = room.missingArtworkNote
        note.fontSize = titleSize * 0.45
        note.fontColor = SKColor(white: 0.30, alpha: 1)
        note.verticalAlignmentMode = .top
        note.horizontalAlignmentMode = .center
        note.position = CGPoint(x: roomRect.midX, y: label.position.y - titleSize * 1.1)
        note.zPosition = 3
        roomNode.addChild(note)
    }

    /// The room artwork, scaled to fill `rect`. The artwork's aspect ratio rarely
    /// matches the room's, and letterboxing would show the scene's dark backing
    /// through the room, so the overflowing side is cropped off the texture
    /// instead of being drawn outside the room.
    ///
    /// Deliberately not `Artwork.named`, which trims a drawing to its opaque
    /// pixels: a backdrop is the whole canvas by definition, and there is nothing
    /// floating in it to trim to.
    func makeBackdrop(named name: String?, in rect: CGRect) -> SKSpriteNode? {
        guard let name = name, rect.width > 0, rect.height > 0,
              let image = UIImage(named: name) else { return nil }

        let whole = SKTexture(imageNamed: name)
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        // Fractions of the texture to keep, in the unit coordinates SKTexture
        // wants, centred on what is cropped.
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let keepX = min(1, rect.width / (imageSize.width * scale))
        let keepY = min(1, rect.height / (imageSize.height * scale))
        let cropped = SKTexture(rect: CGRect(x: (1 - keepX) / 2, y: (1 - keepY) / 2,
                                             width: keepX, height: keepY),
                                in: whole)

        let sprite = SKSpriteNode(texture: cropped, size: rect.size)
        sprite.position = CGPoint(x: rect.midX, y: rect.midY)
        return sprite
    }

    /// The flat wall and floor a room has before it has been drawn — in that
    /// room's own two colours, so a Kitchen is already not a Bedroom before
    /// either of them exists as a picture.
    func makePlaceholderRoom(for definition: RoomDefinition, in rect: CGRect) -> SKNode {
        let node = SKNode()
        let floorHeight = rect.height * definition.floorHeight

        let wallNode = SKShapeNode(rect: CGRect(x: rect.minX,
                                                y: rect.minY + floorHeight,
                                                width: rect.width,
                                                height: rect.height - floorHeight))
        wallNode.fillColor = definition.wallColor
        wallNode.strokeColor = .clear
        wallNode.zPosition = 0
        node.addChild(wallNode)

        let floorNode = SKShapeNode(rect: CGRect(x: rect.minX,
                                                 y: rect.minY,
                                                 width: rect.width,
                                                 height: floorHeight))
        floorNode.fillColor = definition.floorColor
        floorNode.strokeColor = .clear
        floorNode.zPosition = 1
        node.addChild(floorNode)

        return node
    }

    // MARK: - Going next door

    /// Moves to another room. You take yourself and everything you are carrying;
    /// what you had put down stays where you left it, which is the point of
    /// putting it down in a particular room.
    func goToRoom(_ definition: RoomDefinition) {
        guard definition.id != room.id else { return }
        room = definition
        // Whatever you were sitting on is in the room you just left. Standing up
        // on the way out is clearer than arriving mysteriously seated, and the
        // room you come back to still has the chair.
        characterUsing = nil

        playSound(.door)

        layoutRoom()
        layoutFurniture()
        layoutCharacter()
        // Rebuilt rather than nudged: the items of the room you left have to stop
        // being drawn and the ones here have to start.
        layoutItems()
        refreshStuffCount()
        setNeedsSave()

        for node in [roomNode, furnitureNode, itemsNode] {
            node.removeAllActions()
            node.alpha = 0
            node.run(.fadeIn(withDuration: 0.18))
        }
    }

    // MARK: - Furniture

    func layoutFurniture() {
        furnitureNode.removeAllChildren()

        // Room order is draw order, back to front: a chair listed before a table
        // draws behind it.
        furniturePieces = room.pieces.map { placed in
            FurniturePiece(id: placed.id,
                           definition: placed.definition,
                           rect: rectInRoom(centerX: placed.placement.centerX,
                                            bottomY: placed.placement.bottomY,
                                            width: placed.placement.width,
                                            height: placed.placement.height))
        }

        furnitureBoxes = [:]
        for (index, piece) in furniturePieces.enumerated() {
            let box = makeFurniture(for: piece)
            box.zPosition = CGFloat(index)
            furnitureNode.addChild(box)
            furnitureBoxes[piece.id] = box
        }
    }

    /// One piece: its artwork if the asset exists, a labeled box if it does not,
    /// plus the outline that says the character would land here — hidden until
    /// they are dragged over it.
    func makeFurniture(for piece: FurniturePiece) -> SKNode {
        let node = SKNode()
        let rect = piece.rect

        if let artwork = Artwork.named(piece.definition.imageName) {
            let sprite = SKSpriteNode(texture: artwork.texture)
            // Fitted inside its footprint rather than reshaped to the same area
            // the way an item is: furniture is not being compared with the piece
            // next to it, it is standing in a spot the room measured out for it.
            sprite.size = contained(CGSize(width: rect.height * artwork.aspect,
                                           height: rect.height),
                                    in: rect.size)
            sprite.position = CGPoint(x: rect.midX, y: rect.minY + sprite.size.height / 2)
            node.addChild(sprite)
        } else {
            node.addChild(makePlaceholderFurniture(for: piece))
        }

        let highlight = SKShapeNode(rect: rect,
                                    cornerRadius: min(rect.width, rect.height) * 0.15)
        highlight.name = Self.furnitureHighlightName
        highlight.fillColor = .clear
        highlight.strokeColor = Self.furnitureHighlightStroke
        highlight.lineWidth = 6
        highlight.isHidden = true
        node.addChild(highlight)

        return node
    }

    /// A labeled box, for a piece with no artwork yet.
    ///
    /// It is captioned with the filename that would replace it, the same as
    /// everything else here — but only in a room that has no backdrop either. A
    /// drawn room has already drawn its own bed, and the box on top of it is
    /// only there to be sat on: nagging for `bed.png` over a picture of a bed is
    /// asking for artwork that is already on the screen.
    func makePlaceholderFurniture(for piece: FurniturePiece) -> SKNode {
        let rect = piece.rect
        let box = SKShapeNode(rect: rect, cornerRadius: min(rect.width, rect.height) * 0.15)
        box.fillColor = piece.definition.color
        box.strokeColor = Self.furnitureStroke
        box.lineWidth = 2

        let nameSize = max(11, min(rect.width * 0.22, rect.height * 0.35))
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = piece.definition.name
        label.fontSize = nameSize
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        box.addChild(label)

        guard room.artwork == nil else { return box }

        // Room made for the caption underneath.
        label.position = CGPoint(x: rect.midX, y: rect.midY + nameSize * 0.35)
        let note = SKLabelNode(fontNamed: "AvenirNext-Medium")
        note.text = piece.definition.missingArtworkNote
        note.fontSize = nameSize * 0.6
        note.fontColor = SKColor(white: 0.15, alpha: 0.7)
        note.verticalAlignmentMode = .center
        note.horizontalAlignmentMode = .center
        note.position = CGPoint(x: rect.midX, y: rect.midY - nameSize * 0.55)
        shrinkToFit(note, width: rect.width * 0.92)
        box.addChild(note)

        return box
    }

    static let furnitureStroke = SKColor(white: 0.2, alpha: 0.6)
    static let furnitureHighlightStroke = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)
    static let furnitureHighlightName = "furniture-highlight"

    /// Outlines the piece the character would land on if released now.
    func highlightFurniture(_ id: String?) {
        for (pieceID, box) in furnitureBoxes {
            box.childNode(withName: Self.furnitureHighlightName)?.isHidden = pieceID != id
        }
    }

    /// Builds a rect from fractions of the room: horizontal centre, bottom edge, and size.
    func rectInRoom(centerX: CGFloat, bottomY: CGFloat,
                            width: CGFloat, height: CGFloat) -> CGRect {
        let w = roomRect.width * width
        let h = roomRect.height * height
        return CGRect(x: roomRect.minX + roomRect.width * centerX - w / 2,
                      y: roomRect.minY + roomRect.height * bottomY,
                      width: w,
                      height: h)
    }

    func piece(for id: String) -> FurniturePiece? {
        furniturePieces.first { $0.id == id }
    }

    /// Where the character's origin (their feet) goes when they use a piece.
    func seatPosition(for piece: FurniturePiece) -> CGPoint {
        let rect = piece.rect
        if piece.definition.use?.pose == .lyingDown {
            // Lying across the piece. Rotated 90°, so the body extends left from here.
            return CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY)
        }
        return CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.10)
    }
}
