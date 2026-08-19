import SpriteKit

/// The bedroom. Drawn entirely from shapes and labels — no art assets yet.
final class RoomScene: SKScene {

    /// Room chrome (wall, floor, outline, title). Rebuilt whenever the scene resizes.
    private let roomNode = SKNode()
    /// The character. A persistent container so it keeps its own state across resizes.
    private let characterNode = SKNode()

    /// The playable area of the room in scene coordinates.
    private var roomRect: CGRect = .zero

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.13, green: 0.12, blue: 0.16, alpha: 1)
        addChild(roomNode)
        addChild(characterNode)
        // The room chrome draws in 0...3, so the character always sits above it.
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

    /// Builds the placeholder character, sized relative to the room.
    /// The container's position is the character's feet.
    private func layoutCharacter() {
        characterNode.removeAllChildren()

        let height = roomRect.height * 0.30
        let bodyWidth = height * 0.42
        let headRadius = height * 0.16
        let bodyHeight = height - headRadius * 2
        let outlineColor = SKColor(white: 0.2, alpha: 0.6)

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

        characterNode.position = CGPoint(x: roomRect.midX,
                                         y: roomRect.minY + roomRect.height * 0.10)
    }
}
