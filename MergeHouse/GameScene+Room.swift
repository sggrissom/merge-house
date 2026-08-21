import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Room

    func layoutRoom() {
        roomNode.removeAllChildren()

        if let backdrop = makeBackdrop(in: roomRect) {
            backdrop.zPosition = 0
            roomNode.addChild(backdrop)
        } else {
            addPlaceholderRoom()
        }

        let outline = SKShapeNode(rect: roomRect)
        outline.fillColor = .clear
        outline.strokeColor = SKColor(white: 0.25, alpha: 1)
        outline.lineWidth = 3
        outline.zPosition = 2
        roomNode.addChild(outline)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Bedroom"
        label.fontSize = max(20, roomRect.height * 0.07)
        label.fontColor = SKColor(white: 0.25, alpha: 1)
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: roomRect.midX, y: roomRect.maxY - roomRect.height * 0.05)
        label.zPosition = 3
        roomNode.addChild(label)
    }

    static let backdropImageName = "bedroom"

    /// The room artwork, scaled to fill `rect`. The artwork's aspect ratio rarely
    /// matches the room's, and letterboxing would show the scene's dark backing
    /// through the room, so the overflowing side is cropped off the texture
    /// instead of being drawn outside the room.
    func makeBackdrop(in rect: CGRect) -> SKSpriteNode? {
        guard rect.width > 0, rect.height > 0,
              let image = UIImage(named: Self.backdropImageName) else { return nil }

        let whole = SKTexture(imageNamed: Self.backdropImageName)
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

    /// The flat wall and floor the room had before there was artwork. Kept as the
    /// fallback so a missing image leaves a playable room rather than a hole.
    func addPlaceholderRoom() {
        let floorHeight = roomRect.height * 0.38
        let wall = CGRect(x: roomRect.minX,
                          y: roomRect.minY + floorHeight,
                          width: roomRect.width,
                          height: roomRect.height - floorHeight)
        let floor = CGRect(x: roomRect.minX,
                           y: roomRect.minY,
                           width: roomRect.width,
                           height: floorHeight)

        let wallNode = SKShapeNode(rect: wall)
        wallNode.fillColor = SKColor(red: 0.79, green: 0.83, blue: 0.92, alpha: 1)
        wallNode.strokeColor = .clear
        wallNode.zPosition = 0
        roomNode.addChild(wallNode)

        let floorNode = SKShapeNode(rect: floor)
        floorNode.fillColor = SKColor(red: 0.72, green: 0.56, blue: 0.40, alpha: 1)
        floorNode.strokeColor = .clear
        floorNode.zPosition = 1
        roomNode.addChild(floorNode)
    }

    // MARK: - Furniture

    func layoutFurniture() {
        furnitureNode.removeAllChildren()

        // The chair sits further back in the room than the table, so it draws behind it.
        furniturePieces = [
            FurniturePiece(kind: .bed,
                           rect: rectInRoom(centerX: 0.18, bottomY: 0.08,
                                            width: 0.28, height: 0.16)),
            FurniturePiece(kind: .chair,
                           rect: rectInRoom(centerX: 0.78, bottomY: 0.24,
                                            width: 0.13, height: 0.16)),
            FurniturePiece(kind: .table,
                           rect: rectInRoom(centerX: 0.80, bottomY: 0.05,
                                            width: 0.20, height: 0.13)),
        ]

        furnitureBoxes = [:]
        for (index, piece) in furniturePieces.enumerated() {
            let box = makeFurniture(named: piece.kind.rawValue,
                                    rect: piece.rect,
                                    color: piece.kind.color)
            box.zPosition = CGFloat(index)
            furnitureNode.addChild(box)
            furnitureBoxes[piece.kind] = box
        }
    }

    /// A labeled placeholder box. Real artwork can replace the shape later.
    func makeFurniture(named name: String, rect: CGRect, color: SKColor) -> SKShapeNode {
        let box = SKShapeNode(rect: rect, cornerRadius: min(rect.width, rect.height) * 0.15)
        box.fillColor = color
        box.strokeColor = Self.furnitureStroke
        box.lineWidth = 2

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = name
        label.fontSize = max(11, min(rect.width * 0.22, rect.height * 0.35))
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        box.addChild(label)

        return box
    }

    static let furnitureStroke = SKColor(white: 0.2, alpha: 0.6)
    static let furnitureHighlightStroke = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)

    /// Outlines the piece the character would land on if released now.
    func highlightFurniture(_ kind: FurnitureKind?) {
        for (boxKind, box) in furnitureBoxes {
            let isTarget = boxKind == kind
            box.strokeColor = isTarget ? Self.furnitureHighlightStroke : Self.furnitureStroke
            box.lineWidth = isTarget ? 6 : 2
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

    func piece(for kind: FurnitureKind) -> FurniturePiece? {
        furniturePieces.first { $0.kind == kind }
    }

    /// Where the character's origin (their feet) goes when they use a piece.
    func seatPosition(for piece: FurniturePiece) -> CGPoint {
        let rect = piece.rect
        switch piece.kind {
        case .bed:
            // Lying across the bed. Rotated 90°, so the body extends left from here.
            return CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY)
        case .chair, .table:
            return CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.10)
        }
    }
}
