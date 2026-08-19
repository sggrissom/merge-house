import SpriteKit

/// The bedroom. Drawn entirely from shapes and labels — no art assets yet.
final class RoomScene: SKScene {

    /// Room chrome (wall, floor, outline, title). Rebuilt whenever the scene resizes.
    private let roomNode = SKNode()
    /// Placeholder furniture. Rebuilt whenever the scene resizes.
    private let furnitureNode = SKNode()
    /// The character. A persistent container so it keeps its own state across resizes.
    private let characterNode = SKNode()

    /// The playable area of the room in scene coordinates.
    private var roomRect: CGRect = .zero

    /// Where the character stands, as a fraction of `roomRect`, so a resize or
    /// rotation keeps it in the same relative spot instead of resetting it.
    private var characterAnchor = CGPoint(x: 0.5, y: 0.10)
    /// The character's bounds relative to its own origin (its feet), used for clamping.
    private var characterLocalFrame: CGRect = .zero

    private var dragTouch: UITouch?
    private var dragOffset: CGPoint = .zero

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.13, green: 0.12, blue: 0.16, alpha: 1)
        addChild(roomNode)
        addChild(furnitureNode)
        addChild(characterNode)
        // Room chrome draws in 0...3, then furniture, then the character on top.
        furnitureNode.zPosition = 5
        characterNode.zPosition = 10
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    /// Rebuilds everything for the current scene size. Called again on rotation/resize.
    private func layoutScene() {
        // didChangeSize can fire before the scene is set up; wait until it is.
        guard roomNode.parent != nil, size.width > 0, size.height > 0 else { return }

        let margin = min(size.width, size.height) * 0.04
        roomRect = CGRect(x: margin,
                          y: margin,
                          width: size.width - margin * 2,
                          height: size.height - margin * 2)

        layoutRoom()
        layoutFurniture()
        layoutCharacter()
    }

    private func layoutRoom() {
        roomNode.removeAllChildren()

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

    // MARK: - Furniture

    private func layoutFurniture() {
        furnitureNode.removeAllChildren()

        let bed = makeFurniture(named: "Bed",
                                rect: rectInRoom(centerX: 0.18, bottomY: 0.08,
                                                 width: 0.28, height: 0.16),
                                color: SKColor(red: 0.55, green: 0.66, blue: 0.85, alpha: 1))
        bed.zPosition = 0
        furnitureNode.addChild(bed)

        // The chair sits further back in the room than the table, so it draws behind it.
        let chair = makeFurniture(named: "Chair",
                                  rect: rectInRoom(centerX: 0.78, bottomY: 0.24,
                                                   width: 0.13, height: 0.16),
                                  color: SKColor(red: 0.55, green: 0.75, blue: 0.58, alpha: 1))
        chair.zPosition = 1
        furnitureNode.addChild(chair)

        let table = makeFurniture(named: "Table",
                                  rect: rectInRoom(centerX: 0.80, bottomY: 0.05,
                                                   width: 0.20, height: 0.13),
                                  color: SKColor(red: 0.62, green: 0.45, blue: 0.31, alpha: 1))
        table.zPosition = 2
        furnitureNode.addChild(table)
    }

    /// A labeled placeholder box. Real artwork can replace the shape later.
    private func makeFurniture(named name: String, rect: CGRect, color: SKColor) -> SKNode {
        let node = SKNode()

        let box = SKShapeNode(rect: rect, cornerRadius: min(rect.width, rect.height) * 0.15)
        box.fillColor = color
        box.strokeColor = SKColor(white: 0.2, alpha: 0.6)
        box.lineWidth = 2
        node.addChild(box)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = name
        label.fontSize = max(11, min(rect.width * 0.22, rect.height * 0.35))
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        node.addChild(label)

        return node
    }

    /// Builds a rect from fractions of the room: horizontal centre, bottom edge, and size.
    private func rectInRoom(centerX: CGFloat, bottomY: CGFloat,
                            width: CGFloat, height: CGFloat) -> CGRect {
        let w = roomRect.width * width
        let h = roomRect.height * height
        return CGRect(x: roomRect.minX + roomRect.width * centerX - w / 2,
                      y: roomRect.minY + roomRect.height * bottomY,
                      width: w,
                      height: h)
    }

    // MARK: - Character

    /// Builds the placeholder character, sized relative to the room.
    /// The container's position is the character's feet.
    private func layoutCharacter() {
        characterNode.removeAllChildren()

        let height = roomRect.height * 0.30
        let bodyWidth = height * 0.42
        let headRadius = height * 0.16
        let bodyHeight = height - headRadius * 2
        let outlineColor = SKColor(white: 0.2, alpha: 0.6)

        // Build at the origin so the accumulated frame comes out in local coordinates.
        characterNode.position = .zero

        let bodyRect = CGRect(x: -bodyWidth / 2, y: 0, width: bodyWidth, height: bodyHeight)
        let body = SKShapeNode(rect: bodyRect, cornerRadius: bodyWidth * 0.35)
        body.fillColor = SKColor(red: 0.90, green: 0.36, blue: 0.55, alpha: 1)
        body.strokeColor = outlineColor
        body.lineWidth = 2
        characterNode.addChild(body)

        let head = SKShapeNode(circleOfRadius: headRadius)
        head.position = CGPoint(x: 0, y: bodyHeight + headRadius * 0.85)
        head.fillColor = SKColor(red: 0.98, green: 0.84, blue: 0.72, alpha: 1)
        head.strokeColor = outlineColor
        head.lineWidth = 2
        characterNode.addChild(head)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Girl"
        label.fontSize = max(12, height * 0.15)
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .bottom
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: bodyHeight + headRadius * 1.85 + height * 0.04)
        characterNode.addChild(label)

        characterLocalFrame = characterNode.calculateAccumulatedFrame()
        characterNode.position = clampedCharacterPosition(scenePosition(for: characterAnchor))
    }

    // MARK: - Character placement

    private func scenePosition(for anchor: CGPoint) -> CGPoint {
        CGPoint(x: roomRect.minX + anchor.x * roomRect.width,
                y: roomRect.minY + anchor.y * roomRect.height)
    }

    private func anchor(for position: CGPoint) -> CGPoint {
        guard roomRect.width > 0, roomRect.height > 0 else { return characterAnchor }
        return CGPoint(x: (position.x - roomRect.minX) / roomRect.width,
                       y: (position.y - roomRect.minY) / roomRect.height)
    }

    /// Keeps the whole character — label included — inside the room.
    private func clampedCharacterPosition(_ position: CGPoint) -> CGPoint {
        let minX = roomRect.minX - characterLocalFrame.minX
        let maxX = roomRect.maxX - characterLocalFrame.maxX
        let minY = roomRect.minY - characterLocalFrame.minY
        let maxY = roomRect.maxY - characterLocalFrame.maxY
        return CGPoint(x: min(max(position.x, minX), max(minX, maxX)),
                       y: min(max(position.y, minY), max(minY, maxY)))
    }

    // MARK: - Dragging

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragTouch == nil, let touch = touches.first else { return }
        let location = touch.location(in: self)
        guard characterNode.calculateAccumulatedFrame().contains(location) else { return }

        dragTouch = touch
        dragOffset = CGPoint(x: characterNode.position.x - location.x,
                             y: characterNode.position.y - location.y)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = dragTouch, touches.contains(touch) else { return }
        let location = touch.location(in: self)
        let target = CGPoint(x: location.x + dragOffset.x,
                             y: location.y + dragOffset.y)
        characterNode.position = clampedCharacterPosition(target)
        characterAnchor = anchor(for: characterNode.position)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag(touches)
    }

    private func endDrag(_ touches: Set<UITouch>) {
        guard let touch = dragTouch, touches.contains(touch) else { return }
        dragTouch = nil
    }
}
