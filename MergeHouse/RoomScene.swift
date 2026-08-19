import SpriteKit

/// The bedroom. Drawn entirely from shapes and labels — no art assets yet.
final class RoomScene: SKScene {

    private let roomNode = SKNode()

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.13, green: 0.12, blue: 0.16, alpha: 1)
        addChild(roomNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        layoutRoom()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutRoom()
    }

    /// Rebuilds the room for the current scene size. Called again on rotation/resize.
    private func layoutRoom() {
        // didChangeSize can fire before the scene is set up; wait until it is.
        guard roomNode.parent != nil, size.width > 0, size.height > 0 else { return }
        roomNode.removeAllChildren()

        let margin = min(size.width, size.height) * 0.04
        let room = CGRect(x: margin,
                          y: margin,
                          width: size.width - margin * 2,
                          height: size.height - margin * 2)

        let floorHeight = room.height * 0.38
        let wall = CGRect(x: room.minX,
                          y: room.minY + floorHeight,
                          width: room.width,
                          height: room.height - floorHeight)
        let floor = CGRect(x: room.minX,
                           y: room.minY,
                           width: room.width,
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

        let outline = SKShapeNode(rect: room)
        outline.fillColor = .clear
        outline.strokeColor = SKColor(white: 0.25, alpha: 1)
        outline.lineWidth = 3
        outline.zPosition = 2
        roomNode.addChild(outline)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Bedroom"
        label.fontSize = max(20, room.height * 0.07)
        label.fontColor = SKColor(white: 0.25, alpha: 1)
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: room.midX, y: room.maxY - room.height * 0.05)
        label.zPosition = 3
        roomNode.addChild(label)
    }
}
