import SpriteKit

/// The whole play area: the bedroom on top, the Stuff area below.
/// Drawn entirely from shapes and labels — no art assets yet.
final class GameScene: SKScene {

    // MARK: - Furniture model

    private enum FurnitureKind: String {
        case bed = "Bed"
        case chair = "Chair"
        case table = "Table"

        /// What the character's label reads while using this piece.
        /// `nil` means the piece cannot be used.
        var characterLabel: String? {
            switch self {
            case .bed: return "Sleeping"
            case .chair: return "Sitting"
            case .table: return nil
            }
        }

        /// The character lies down on the bed and stays upright everywhere else.
        var characterRotation: CGFloat {
            self == .bed ? .pi / 2 : 0
        }

        var color: SKColor {
            switch self {
            case .bed: return SKColor(red: 0.55, green: 0.66, blue: 0.85, alpha: 1)
            case .chair: return SKColor(red: 0.55, green: 0.75, blue: 0.58, alpha: 1)
            case .table: return SKColor(red: 0.62, green: 0.45, blue: 0.31, alpha: 1)
            }
        }
    }

    private struct FurniturePiece {
        let kind: FurnitureKind
        let rect: CGRect
    }

    // MARK: - Nodes and state

    /// Room chrome (wall, floor, outline, title). Rebuilt whenever the scene resizes.
    private let roomNode = SKNode()
    /// Placeholder furniture. Rebuilt whenever the scene resizes.
    private let furnitureNode = SKNode()
    /// The character. A persistent container so it keeps its own state across resizes.
    private let characterNode = SKNode()
    /// The Stuff area panel and its button. Rebuilt whenever the scene resizes.
    private let stuffNode = SKNode()
    /// The loose items sitting in the Stuff area, drawn on top of its panel.
    private let stuffItemsNode = SKNode()

    /// The playable area of the room in scene coordinates.
    private var roomRect: CGRect = .zero
    /// The Stuff area below the room, where mergeable items will live.
    private var stuffRect: CGRect = .zero
    private var furniturePieces: [FurniturePiece] = []
    private var furnitureBoxes: [FurnitureKind: SKShapeNode] = [:]

    private var getStuffButton: SKNode?
    private var getStuffButtonRect: CGRect = .zero

    /// The items currently in the Stuff area, back to front: the last one draws
    /// on top and is the first to be picked up.
    private var stuffItems: [StuffItem] = []
    /// The node showing each item, keyed by item id.
    private var stuffItemNodes: [Int: SKNode] = [:]
    private var nextStuffItemID = 0
    /// The part of the Stuff area new items are dealt into: clear of the title and button.
    private var stuffSpawnRect: CGRect = .zero
    /// Placeholder size for one item, scaled to the current Stuff area.
    private var stuffItemSize: CGSize = .zero

    /// Where the character stands, as a fraction of `roomRect`, so a resize or
    /// rotation keeps it in the same relative spot instead of resetting it.
    private var characterAnchor = CGPoint(x: 0.5, y: 0.10)
    /// The piece the character is currently using, if any. While set, her position
    /// comes from that piece rather than from `characterAnchor`.
    private var characterUsing: FurnitureKind?
    /// The character's bounds relative to its own origin (its feet), used for clamping.
    private var characterLocalFrame: CGRect = .zero

    /// What the current drag is moving.
    private enum DragSubject {
        case character
        case stuffItem(id: Int)
    }

    private var dragTouch: UITouch?
    private var dragSubject: DragSubject?
    private var dragOffset: CGPoint = .zero

    // MARK: - Setup

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.13, green: 0.12, blue: 0.16, alpha: 1)
        addChild(roomNode)
        addChild(furnitureNode)
        addChild(characterNode)
        addChild(stuffNode)
        addChild(stuffItemsNode)
        // Room chrome draws in 0...3, then furniture, then the character on top.
        furnitureNode.zPosition = 5
        characterNode.zPosition = 10
        stuffNode.zPosition = 20
        stuffItemsNode.zPosition = 25
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
        let gap = margin * 0.6
        let content = CGRect(x: margin,
                             y: margin,
                             width: size.width - margin * 2,
                             height: size.height - margin * 2)

        // The room keeps the majority of the screen; Stuff takes a band along the bottom.
        let stuffHeight = content.height * 0.26
        stuffRect = CGRect(x: content.minX,
                           y: content.minY,
                           width: content.width,
                           height: stuffHeight)
        roomRect = CGRect(x: content.minX,
                          y: content.minY + stuffHeight + gap,
                          width: content.width,
                          height: content.height - stuffHeight - gap)

        layoutRoom()
        layoutFurniture()
        layoutCharacter()
        layoutStuff()
        layoutStuffItems()
    }

    // MARK: - Room

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
    private func makeFurniture(named name: String, rect: CGRect, color: SKColor) -> SKShapeNode {
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

    private static let furnitureStroke = SKColor(white: 0.2, alpha: 0.6)
    private static let furnitureHighlightStroke = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)

    /// Outlines the piece the character would land on if released now.
    private func highlightFurniture(_ kind: FurnitureKind?) {
        for (boxKind, box) in furnitureBoxes {
            let isTarget = boxKind == kind
            box.strokeColor = isTarget ? Self.furnitureHighlightStroke : Self.furnitureStroke
            box.lineWidth = isTarget ? 6 : 2
        }
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

    private func piece(for kind: FurnitureKind) -> FurniturePiece? {
        furniturePieces.first { $0.kind == kind }
    }

    /// Where the character's origin (her feet) goes when she uses a piece.
    private func seatPosition(for piece: FurniturePiece) -> CGPoint {
        let rect = piece.rect
        switch piece.kind {
        case .bed:
            // Lying across the bed. She is rotated 90°, so her body extends left from here.
            return CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY)
        case .chair, .table:
            return CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.10)
        }
    }

    // MARK: - Stuff area

    private func layoutStuff() {
        stuffNode.removeAllChildren()

        let inset = stuffRect.height * 0.12

        let panel = SKShapeNode(rect: stuffRect, cornerRadius: stuffRect.height * 0.12)
        panel.fillColor = SKColor(red: 0.20, green: 0.19, blue: 0.24, alpha: 1)
        panel.strokeColor = SKColor(white: 0.35, alpha: 1)
        panel.lineWidth = 3
        panel.zPosition = 0
        stuffNode.addChild(panel)

        let titleFontSize = max(16, stuffRect.height * 0.22)
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Stuff"
        title.fontSize = titleFontSize
        title.fontColor = SKColor(white: 0.85, alpha: 1)
        title.verticalAlignmentMode = .top
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: stuffRect.minX + inset, y: stuffRect.maxY - inset)
        title.zPosition = 1
        stuffNode.addChild(title)

        let buttonWidth = min(stuffRect.width * 0.32, stuffRect.height * 2.2)
        let buttonHeight = stuffRect.height * 0.42
        getStuffButtonRect = CGRect(x: stuffRect.maxX - inset - buttonWidth,
                                    y: stuffRect.midY - buttonHeight / 2,
                                    width: buttonWidth,
                                    height: buttonHeight)
        let button = makeGetStuffButton(rect: getStuffButtonRect)
        button.zPosition = 2
        stuffNode.addChild(button)
        getStuffButton = button

        // Items are dealt into the space left of the button and below the title.
        let itemHeight = stuffRect.height * 0.30
        stuffItemSize = CGSize(width: itemHeight * 2.1, height: itemHeight)
        stuffSpawnRect = CGRect(x: stuffRect.minX + inset,
                                y: stuffRect.minY + inset,
                                width: max(stuffItemSize.width,
                                           getStuffButtonRect.minX - inset * 2 - stuffRect.minX),
                                height: max(stuffItemSize.height,
                                            stuffRect.height - inset * 2 - titleFontSize))
    }

    /// Built around its own centre so it can scale when pressed.
    private func makeGetStuffButton(rect: CGRect) -> SKNode {
        let node = SKNode()
        node.position = CGPoint(x: rect.midX, y: rect.midY)

        let background = SKShapeNode(rect: CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                                  width: rect.width, height: rect.height),
                                     cornerRadius: rect.height * 0.35)
        background.fillColor = SKColor(red: 0.35, green: 0.55, blue: 0.92, alpha: 1)
        background.strokeColor = SKColor(white: 0.9, alpha: 0.8)
        background.lineWidth = 2
        node.addChild(background)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Get Stuff"
        label.fontSize = max(13, rect.height * 0.42)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    /// Each tap drops one more placeholder item into the Stuff area.
    private func getStuffTapped() {
        if let button = getStuffButton {
            button.removeAllActions()
            button.setScale(1)
            button.run(.sequence([.scale(to: 0.92, duration: 0.06),
                                  .scale(to: 1.0, duration: 0.09)]))
        }
        spawnStuffItem()
    }

    // MARK: - Stuff items

    /// The kinds of loose object that exist so far. Two of the same kind merge
    /// into whatever `mergeResult` names.
    private enum StuffItemKind {
        case littleTeddy
        case bigTeddy

        var name: String {
            switch self {
            case .littleTeddy: return "Little Teddy"
            case .bigTeddy: return "Big Teddy"
            }
        }

        /// What a pair of these becomes. `nil` means they do not merge.
        var mergeResult: StuffItemKind? {
            switch self {
            case .littleTeddy: return .bigTeddy
            case .bigTeddy: return nil
            }
        }

        /// Size relative to the base placeholder, so levels read at a glance.
        var scale: CGFloat {
            switch self {
            case .littleTeddy: return 1.0
            case .bigTeddy: return 1.28
            }
        }

        var color: SKColor {
            switch self {
            case .littleTeddy: return SKColor(red: 0.85, green: 0.66, blue: 0.42, alpha: 1)
            case .bigTeddy: return SKColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1)
            }
        }
    }

    /// One loose object in the Stuff area. Its position is stored as a fraction of
    /// `stuffRect` so a resize or rotation keeps it in the same relative spot.
    private struct StuffItem {
        let id: Int
        let kind: StuffItemKind
        var anchor: CGPoint
    }

    private func spawnStuffItem() {
        let anchor = spawnAnchor(forItemAt: stuffItems.count)
        let node = addStuffItem(kind: .littleTeddy, anchor: anchor)
        node.setScale(0.6)
        node.run(.scale(to: 1.0, duration: 0.12))
    }

    /// Adds one item to the model and the scene, on top of everything else.
    @discardableResult
    private func addStuffItem(kind: StuffItemKind, anchor: CGPoint) -> SKNode {
        let item = StuffItem(id: nextStuffItemID, kind: kind, anchor: anchor)
        nextStuffItemID += 1
        stuffItems.append(item)
        let node = addStuffItemNode(for: item)
        refreshStuffItemDepths()
        return node
    }

    private func removeStuffItem(id: Int) {
        stuffItemNodes[id]?.removeFromParent()
        stuffItemNodes[id] = nil
        if let index = stuffItemIndex(id: id) {
            stuffItems.remove(at: index)
        }
    }

    private func itemSize(for kind: StuffItemKind) -> CGSize {
        CGSize(width: stuffItemSize.width * kind.scale,
               height: stuffItemSize.height * kind.scale)
    }

    private func layoutStuffItems() {
        stuffItemsNode.removeAllChildren()
        stuffItemNodes = [:]
        for item in stuffItems {
            addStuffItemNode(for: item)
        }
        refreshStuffItemDepths()
    }

    @discardableResult
    private func addStuffItemNode(for item: StuffItem) -> SKNode {
        let node = makeStuffItemNode(for: item)
        stuffItemNodes[item.id] = node
        stuffItemsNode.addChild(node)
        return node
    }

    /// Draw order follows `stuffItems`, so moving an item to the end of the
    /// array is what brings it to the front.
    private func refreshStuffItemDepths() {
        for (index, item) in stuffItems.enumerated() {
            stuffItemNodes[item.id]?.zPosition = CGFloat(index)
        }
    }

    private func stuffItemIndex(id: Int) -> Int? {
        stuffItems.firstIndex { $0.id == id }
    }

    /// The topmost item under a touch, if any. A little slop around the box
    /// makes small items easier to grab with a finger.
    private func topStuffItem(at location: CGPoint) -> StuffItem? {
        let slop = stuffItemSize.height * 0.12
        for item in stuffItems.reversed() {
            guard let node = stuffItemNodes[item.id] else { continue }
            if node.calculateAccumulatedFrame().insetBy(dx: -slop, dy: -slop).contains(location) {
                return item
            }
        }
        return nil
    }

    // MARK: - Merging

    private static let stuffItemBoxName = "box"
    private static let stuffItemStroke = SKColor(white: 0.15, alpha: 0.7)
    private static let stuffItemMergeStroke = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)

    /// The item `dragged` would merge with if it were released now, if any.
    ///
    /// Like the furniture test, this compares overlapping *area* rather than a
    /// single point, so a teddy dropped anywhere across its partner counts.
    private func mergeTarget(for dragged: StuffItem) -> StuffItem? {
        guard dragged.kind.mergeResult != nil,
              let draggedFrame = stuffItemNodes[dragged.id]?.calculateAccumulatedFrame() else {
            return nil
        }
        let draggedArea = draggedFrame.width * draggedFrame.height
        var best: (item: StuffItem, overlap: CGFloat)?

        for other in stuffItems where other.id != dragged.id && other.kind == dragged.kind {
            guard let otherFrame = stuffItemNodes[other.id]?.calculateAccumulatedFrame() else { continue }
            let intersection = draggedFrame.intersection(otherFrame)
            guard !intersection.isNull else { continue }

            let overlap = intersection.width * intersection.height
            let otherArea = otherFrame.width * otherFrame.height
            // A quarter of the smaller of the two, so brushing past does not merge.
            guard overlap >= min(draggedArea, otherArea) * 0.25 else { continue }
            if let current = best, overlap <= current.overlap { continue }

            best = (other, overlap)
        }

        return best?.item
    }

    /// Outlines the item the dragged one would merge with.
    private func highlightMergeTarget(_ id: Int?) {
        for item in stuffItems {
            guard let box = stuffItemNodes[item.id]?
                .childNode(withName: Self.stuffItemBoxName) as? SKShapeNode else { continue }
            let isTarget = item.id == id
            box.strokeColor = isTarget ? Self.stuffItemMergeStroke : Self.stuffItemStroke
            box.lineWidth = isTarget ? 5 : 2
        }
    }

    /// On release, merge the dragged item into whatever it was dropped on.
    /// Otherwise it simply stays where it was put.
    private func settleStuffItem(id: Int) {
        highlightMergeTarget(nil)
        guard let index = stuffItemIndex(id: id), let node = stuffItemNodes[id] else { return }
        let dragged = stuffItems[index]
        node.removeAllActions()

        guard let target = mergeTarget(for: dragged), let result = dragged.kind.mergeResult else {
            node.run(.scale(to: 1.0, duration: 0.08))
            return
        }

        merge(dragged, target, into: result)
    }

    /// Both source items disappear and the next kind up appears where the pair met.
    private func merge(_ dragged: StuffItem, _ target: StuffItem, into kind: StuffItemKind) {
        let meetingPoint = stuffItemNodes[target.id]?.position ??
            stuffPosition(for: target.anchor)

        removeStuffItem(id: dragged.id)
        removeStuffItem(id: target.id)

        let anchor = anchorInStuff(for: clampedStuffItemPosition(meetingPoint, size: itemSize(for: kind)))
        let node = addStuffItem(kind: kind, anchor: anchor)
        node.setScale(0.5)
        node.run(.sequence([.scale(to: 1.15, duration: 0.10),
                            .scale(to: 1.0, duration: 0.08)]))
    }

    /// A labeled placeholder box built around its own centre, so it can be
    /// positioned and scaled by its middle. Real artwork can replace the shape later.
    private func makeStuffItemNode(for item: StuffItem) -> SKNode {
        let boxSize = itemSize(for: item.kind)
        let node = SKNode()
        node.position = clampedStuffItemPosition(stuffPosition(for: item.anchor), size: boxSize)

        let box = SKShapeNode(rect: CGRect(x: -boxSize.width / 2, y: -boxSize.height / 2,
                                           width: boxSize.width, height: boxSize.height),
                              cornerRadius: boxSize.height * 0.22)
        box.name = Self.stuffItemBoxName
        box.fillColor = item.kind.color
        box.strokeColor = Self.stuffItemStroke
        box.lineWidth = 2
        node.addChild(box)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = item.kind.name
        label.fontSize = max(10, min(boxSize.width * 0.17, boxSize.height * 0.30))
        label.fontColor = SKColor(white: 0.12, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    /// Deals items into a grid across the spawn area, wrapping back to the first
    /// slot once it is full. Nothing stops items sharing a slot yet — they can be
    /// moved apart once items become draggable.
    private func spawnAnchor(forItemAt index: Int) -> CGPoint {
        let spacing = stuffItemSize.height * 0.25
        let columns = max(1, Int((stuffSpawnRect.width + spacing) / (stuffItemSize.width + spacing)))
        let rows = max(1, Int((stuffSpawnRect.height + spacing) / (stuffItemSize.height + spacing)))
        let slots = columns * rows
        let slot = index % slots
        let column = slot % columns
        let row = slot / columns
        // Once the grid is full it starts again, nudged so the new item is not
        // hidden exactly behind the old one.
        let cascade = stuffItemSize.height * 0.18 * CGFloat((index / slots) % 3)

        let x = stuffSpawnRect.minX + stuffItemSize.width / 2 + cascade +
            CGFloat(column) * (stuffItemSize.width + spacing)
        // Dealt from the top of the spawn area downwards.
        let y = stuffSpawnRect.maxY - stuffItemSize.height / 2 - cascade -
            CGFloat(row) * (stuffItemSize.height + spacing)

        return anchorInStuff(for: clampedStuffItemPosition(CGPoint(x: x, y: y),
                                                           size: stuffItemSize))
    }

    private func stuffPosition(for anchor: CGPoint) -> CGPoint {
        CGPoint(x: stuffRect.minX + anchor.x * stuffRect.width,
                y: stuffRect.minY + anchor.y * stuffRect.height)
    }

    private func anchorInStuff(for position: CGPoint) -> CGPoint {
        guard stuffRect.width > 0, stuffRect.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: (position.x - stuffRect.minX) / stuffRect.width,
                       y: (position.y - stuffRect.minY) / stuffRect.height)
    }

    /// Keeps a whole item inside the Stuff panel, whatever the current size, and
    /// clear of the Get Stuff button — an item parked on the button could not be
    /// picked up again, because the tap would spawn a new one instead.
    private func clampedStuffItemPosition(_ position: CGPoint, size boxSize: CGSize) -> CGPoint {
        let margin = stuffRect.height * 0.06
        let rightEdge = getStuffButtonRect.isEmpty ? stuffRect.maxX : getStuffButtonRect.minX
        let minX = stuffRect.minX + margin + boxSize.width / 2
        let maxX = rightEdge - margin - boxSize.width / 2
        let minY = stuffRect.minY + margin + boxSize.height / 2
        let maxY = stuffRect.maxY - margin - boxSize.height / 2
        return CGPoint(x: min(max(position.x, minX), max(minX, maxX)),
                       y: min(max(position.y, minY), max(minY, maxY)))
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

        // Build at the origin, unrotated, so the accumulated frame comes out
        // in local coordinates.
        characterNode.position = .zero
        characterNode.zRotation = 0

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
        label.text = characterUsing?.characterLabel ?? "Girl"
        label.fontSize = max(12, height * 0.15)
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .bottom
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: bodyHeight + headRadius * 1.85 + height * 0.04)
        characterNode.addChild(label)

        characterLocalFrame = characterNode.calculateAccumulatedFrame()

        if let kind = characterUsing, let piece = piece(for: kind) {
            characterNode.zRotation = kind.characterRotation
            characterNode.position = seatPosition(for: piece)
        } else {
            characterNode.position = clampedCharacterPosition(scenePosition(for: characterAnchor))
        }
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

        if getStuffButtonRect.contains(location) {
            getStuffTapped()
            return
        }

        // Loose items sit in front of everything, so they get first refusal.
        if let item = topStuffItem(at: location), let node = stuffItemNodes[item.id] {
            beginStuffItemDrag(item, node: node, touch: touch, at: location)
            return
        }

        if characterNode.calculateAccumulatedFrame().contains(location) {
            beginCharacterDrag(touch: touch, at: location)
        }
    }

    private func beginCharacterDrag(touch: UITouch, at location: CGPoint) {
        if characterUsing != nil {
            // Stand her up where she is, then let the drag carry on from there.
            characterAnchor = anchor(for: characterNode.position)
            characterUsing = nil
            layoutCharacter()
        }

        dragTouch = touch
        dragSubject = .character
        dragOffset = CGPoint(x: characterNode.position.x - location.x,
                             y: characterNode.position.y - location.y)
    }

    private func beginStuffItemDrag(_ item: StuffItem, node: SKNode,
                                    touch: UITouch, at location: CGPoint) {
        // Bring it to the front so it is not dragged underneath its neighbours.
        if let index = stuffItemIndex(id: item.id) {
            let moved = stuffItems.remove(at: index)
            stuffItems.append(moved)
            refreshStuffItemDepths()
        }

        dragTouch = touch
        dragSubject = .stuffItem(id: item.id)
        dragOffset = CGPoint(x: node.position.x - location.x,
                             y: node.position.y - location.y)

        node.removeAllActions()
        node.run(.scale(to: 1.08, duration: 0.08))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = dragTouch, touches.contains(touch), let subject = dragSubject else { return }
        let location = touch.location(in: self)
        let target = CGPoint(x: location.x + dragOffset.x,
                             y: location.y + dragOffset.y)

        switch subject {
        case .character:
            characterNode.position = clampedCharacterPosition(target)
            characterAnchor = anchor(for: characterNode.position)
            highlightFurniture(dropTarget())

        case .stuffItem(let id):
            guard let node = stuffItemNodes[id], let index = stuffItemIndex(id: id) else { return }
            let item = stuffItems[index]
            node.position = clampedStuffItemPosition(target, size: itemSize(for: item.kind))
            stuffItems[index].anchor = anchorInStuff(for: node.position)
            highlightMergeTarget(mergeTarget(for: item)?.id)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag(touches)
    }

    private func endDrag(_ touches: Set<UITouch>) {
        guard let touch = dragTouch, touches.contains(touch) else { return }
        let subject = dragSubject
        dragTouch = nil
        dragSubject = nil
        guard let subject = subject else { return }

        switch subject {
        case .character:
            settleCharacter()
        case .stuffItem(let id):
            settleStuffItem(id: id)
        }
    }

    /// Which usable piece the character is currently over, if any.
    ///
    /// This compares how much of her *overlaps* each piece rather than testing a
    /// single point. Her origin is at her feet, so a point test only matched when
    /// she was grabbed low down — dragging her body onto the bed left her feet
    /// below it and nothing happened.
    private func dropTarget() -> FurnitureKind? {
        let characterFrame = characterNode.calculateAccumulatedFrame()
        let characterArea = characterFrame.width * characterFrame.height
        var best: (kind: FurnitureKind, overlap: CGFloat)?

        for piece in furniturePieces where piece.kind.characterLabel != nil {
            let intersection = characterFrame.intersection(piece.rect)
            guard !intersection.isNull else { continue }

            let overlap = intersection.width * intersection.height
            let pieceArea = piece.rect.width * piece.rect.height
            // A quarter of the smaller of the two, so brushing past does not count.
            guard overlap >= min(characterArea, pieceArea) * 0.25 else { continue }
            if let current = best, overlap <= current.overlap { continue }

            best = (piece.kind, overlap)
        }

        return best?.kind
    }

    /// On release, snap the character onto whichever piece she was dropped on.
    /// Otherwise she simply stays where she was put.
    private func settleCharacter() {
        highlightFurniture(nil)
        guard let kind = dropTarget() else { return }
        characterUsing = kind
        layoutCharacter()
    }
}
