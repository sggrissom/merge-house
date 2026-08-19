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
    /// The loose items, in the Stuff area or placed in the room. They draw above
    /// the Stuff panel, so this layer sits on top of everything else.
    private let itemsNode = SKNode()

    /// The playable area of the room in scene coordinates.
    private var roomRect: CGRect = .zero
    /// The Stuff area below the room, where mergeable items will live.
    private var stuffRect: CGRect = .zero
    private var furniturePieces: [FurniturePiece] = []
    private var furnitureBoxes: [FurnitureKind: SKShapeNode] = [:]

    private var getStuffButton: SKNode?
    private var getStuffButtonRect: CGRect = .zero

    /// Every item that exists, back to front: the last one draws on top and is
    /// the first to be picked up.
    private var items: [Item] = []
    /// The node showing each item, keyed by item id.
    private var itemNodes: [Int: SKNode] = [:]
    private var nextItemID = 0
    /// The part of the Stuff area new items are dealt into: clear of the title and button.
    private var stuffSpawnRect: CGRect = .zero
    /// Placeholder size for one item, scaled to the current Stuff area.
    private var itemBaseSize: CGSize = .zero

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
        case item(id: Int)
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
        addChild(itemsNode)
        // Room chrome draws in 0...3, then furniture, then the character on top.
        furnitureNode.zPosition = 5
        characterNode.zPosition = 10
        stuffNode.zPosition = 20
        itemsNode.zPosition = 25
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
        layoutItems()
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
        itemBaseSize = CGSize(width: itemHeight * 2.1, height: itemHeight)
        stuffSpawnRect = CGRect(x: stuffRect.minX + inset,
                                y: stuffRect.minY + inset,
                                width: max(itemBaseSize.width,
                                           getStuffButtonRect.minX - inset * 2 - stuffRect.minX),
                                height: max(itemBaseSize.height,
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
        spawnItem()
    }

    // MARK: - Items

    /// Where an item currently lives. Items start in the Stuff area and can be
    /// carried into the Bedroom, where they become part of the dollhouse.
    private enum ItemLocation {
        case stuff
        case room
    }

    /// One loose object. Its position is stored as a fraction of whichever area
    /// it is in, so a resize or rotation keeps it in the same relative spot.
    private struct Item {
        let id: Int
        let definition: ItemDefinition
        var location: ItemLocation
        var anchor: CGPoint
    }

    private func spawnItem() {
        let node = addItem(definition: ItemCatalog.randomStarter(), location: .stuff,
                           anchor: nextSpawnAnchor())
        node.setScale(0.6)
        node.run(.scale(to: 1.0, duration: 0.12))
    }

    /// Adds one item to the model and the scene, on top of everything else.
    @discardableResult
    private func addItem(definition: ItemDefinition, location: ItemLocation,
                         anchor: CGPoint) -> SKNode {
        let item = Item(id: nextItemID, definition: definition,
                        location: location, anchor: anchor)
        nextItemID += 1
        items.append(item)
        let node = addItemNode(for: item)
        refreshItemDepths()
        return node
    }

    private func removeItem(id: Int) {
        itemNodes[id]?.removeFromParent()
        itemNodes[id] = nil
        if let index = itemIndex(id: id) {
            items.remove(at: index)
        }
    }

    private func itemSize(for definition: ItemDefinition) -> CGSize {
        CGSize(width: itemBaseSize.width * definition.scale,
               height: itemBaseSize.height * definition.scale)
    }

    private func layoutItems() {
        itemsNode.removeAllChildren()
        itemNodes = [:]
        for item in items {
            addItemNode(for: item)
        }
        refreshItemDepths()
    }

    @discardableResult
    private func addItemNode(for item: Item) -> SKNode {
        let node = makeItemNode(for: item)
        itemNodes[item.id] = node
        itemsNode.addChild(node)
        return node
    }

    /// Draw order follows `items`, so moving an item to the end of the
    /// array is what brings it to the front.
    private func refreshItemDepths() {
        for (index, item) in items.enumerated() {
            itemNodes[item.id]?.zPosition = CGFloat(index)
        }
    }

    private func itemIndex(id: Int) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// The topmost item under a touch, if any. A little slop around the box
    /// makes small items easier to grab with a finger.
    private func topItem(at location: CGPoint) -> Item? {
        let slop = itemBaseSize.height * 0.12
        for item in items.reversed() {
            guard let node = itemNodes[item.id] else { continue }
            if node.calculateAccumulatedFrame().insetBy(dx: -slop, dy: -slop).contains(location) {
                return item
            }
        }
        return nil
    }

    // MARK: - Merging

    private static let itemHighlightName = "merge-highlight"
    private static let itemStroke = SKColor(white: 0.15, alpha: 0.7)
    private static let itemMergeStroke = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)

    /// The item `dragged` would merge with if it were released now, if any.
    ///
    /// Like the furniture test, this compares overlapping *area* rather than a
    /// single point, so an item dropped anywhere across its partner counts.
    private func mergeTarget(for dragged: Item) -> Item? {
        // Merging happens in the Stuff area. Things placed in the room are being
        // played with, and should not disappear into a merge when pushed together.
        guard dragged.location == .stuff,
              ItemCatalog.mergeResult(for: dragged.definition) != nil,
              let draggedFrame = itemNodes[dragged.id]?.calculateAccumulatedFrame() else {
            return nil
        }
        let draggedArea = draggedFrame.width * draggedFrame.height
        var best: (item: Item, overlap: CGFloat)?

        for other in items where other.id != dragged.id &&
            other.definition.id == dragged.definition.id && other.location == .stuff {
            guard let otherFrame = itemNodes[other.id]?.calculateAccumulatedFrame() else { continue }
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
        for item in items {
            let highlight = itemNodes[item.id]?.childNode(withName: Self.itemHighlightName)
            highlight?.isHidden = item.id != id
        }
    }

    /// On release, merge the dragged item into whatever it was dropped on.
    /// Otherwise it simply stays where it was put.
    private func settleItem(id: Int) {
        highlightMergeTarget(nil)
        guard let index = itemIndex(id: id), let node = itemNodes[id] else { return }
        node.removeAllActions()

        // Whichever area it was let go over is the one it now belongs to.
        let dropLocation = location(forDropAt: node.position)
        let resting = clampedItemPosition(node.position,
                                          size: itemSize(for: items[index].definition),
                                          in: dropLocation)
        items[index].location = dropLocation
        items[index].anchor = itemAnchor(for: resting, in: dropLocation)
        node.position = resting

        let dropped = items[index]
        guard let target = mergeTarget(for: dropped),
              let result = ItemCatalog.mergeResult(for: dropped.definition) else {
            node.run(.scale(to: 1.0, duration: 0.08))
            return
        }

        merge(dropped, target, into: result)
    }

    /// Both source items disappear and the next item up appears where the pair met.
    private func merge(_ dragged: Item, _ target: Item, into result: ItemDefinition) {
        let meetingPoint = itemNodes[target.id]?.position ?? itemPosition(for: target)

        removeItem(id: dragged.id)
        removeItem(id: target.id)

        let resting = clampedItemPosition(meetingPoint, size: itemSize(for: result), in: .stuff)
        let node = addItem(definition: result, location: .stuff,
                           anchor: anchor(for: resting, in: .stuff))
        node.setScale(0.5)
        node.run(.sequence([.scale(to: 1.15, duration: 0.10),
                            .scale(to: 1.0, duration: 0.08)]))
    }

    /// An item node: its artwork if the asset exists, a labeled placeholder box
    /// if it does not, plus a merge highlight that is hidden until it is needed.
    /// Everything is built around the node's own centre so it can be positioned
    /// and scaled by its middle.
    private func makeItemNode(for item: Item) -> SKNode {
        let boxSize = itemSize(for: item.definition)
        let node = SKNode()
        node.position = itemPosition(for: item)
        node.addChild(makeItemArtwork(for: item.definition, size: boxSize))

        let highlight = SKShapeNode(rect: CGRect(x: -boxSize.width / 2, y: -boxSize.height / 2,
                                                 width: boxSize.width, height: boxSize.height),
                                    cornerRadius: boxSize.height * 0.22)
        highlight.name = Self.itemHighlightName
        highlight.fillColor = .clear
        highlight.strokeColor = Self.itemMergeStroke
        highlight.lineWidth = 5
        highlight.isHidden = true
        node.addChild(highlight)

        return node
    }

    /// Missing artwork is a normal state, not an error: anything without a drawing
    /// yet falls back to a labeled box of the right size.
    private func makeItemArtwork(for definition: ItemDefinition, size boxSize: CGSize) -> SKNode {
        if let imageName = definition.imageName, let image = UIImage(named: imageName) {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            let fit = min(boxSize.width / sprite.size.width,
                          boxSize.height / sprite.size.height)
            sprite.size = CGSize(width: sprite.size.width * fit,
                                 height: sprite.size.height * fit)
            return sprite
        }

        let placeholder = SKNode()

        let box = SKShapeNode(rect: CGRect(x: -boxSize.width / 2, y: -boxSize.height / 2,
                                           width: boxSize.width, height: boxSize.height),
                              cornerRadius: boxSize.height * 0.22)
        box.fillColor = definition.placeholderColor
        box.strokeColor = Self.itemStroke
        box.lineWidth = 2
        placeholder.addChild(box)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = definition.name
        label.fontSize = max(10, min(boxSize.width * 0.17, boxSize.height * 0.30))
        label.fontColor = SKColor(white: 0.12, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        placeholder.addChild(label)

        return placeholder
    }

    /// Picks where a newly spawned item lands: the grid slot in the spawn area
    /// that is furthest from everything already lying there, so items spread out
    /// instead of piling up. If every slot is crowded it nudges the newcomer so
    /// it is not hidden exactly behind an older one.
    private func nextSpawnAnchor() -> CGPoint {
        let spacing = itemBaseSize.height * 0.25
        let columns = max(1, Int((stuffSpawnRect.width + spacing) / (itemBaseSize.width + spacing)))
        let rows = max(1, Int((stuffSpawnRect.height + spacing) / (itemBaseSize.height + spacing)))

        let taken = items.filter { $0.location == .stuff }
            .compactMap { itemNodes[$0.id]?.position }

        var bestPoint = stuffSpawnRect.origin
        var bestClearance = -CGFloat.greatestFiniteMagnitude

        for row in 0..<rows {
            for column in 0..<columns {
                let x = stuffSpawnRect.minX + itemBaseSize.width / 2 +
                    CGFloat(column) * (itemBaseSize.width + spacing)
                // Dealt from the top of the spawn area downwards.
                let y = stuffSpawnRect.maxY - itemBaseSize.height / 2 -
                    CGFloat(row) * (itemBaseSize.height + spacing)
                let point = clampedItemPosition(CGPoint(x: x, y: y),
                                                size: itemBaseSize, in: .stuff)

                let clearance = taken.map { hypot($0.x - point.x, $0.y - point.y) }.min()
                    ?? CGFloat.greatestFiniteMagnitude
                if clearance > bestClearance {
                    bestClearance = clearance
                    bestPoint = point
                }
            }
        }

        if bestClearance < itemBaseSize.height {
            let nudge = itemBaseSize.height * 0.35
            bestPoint = clampedItemPosition(CGPoint(x: bestPoint.x + .random(in: -nudge...nudge),
                                                    y: bestPoint.y + .random(in: -nudge...nudge)),
                                            size: itemBaseSize, in: .stuff)
        }

        return anchor(for: bestPoint, in: .stuff)
    }

    private func rect(for location: ItemLocation) -> CGRect {
        switch location {
        case .stuff: return stuffRect
        case .room: return roomRect
        }
    }

    private func itemPosition(for item: Item) -> CGPoint {
        let area = rect(for: item.location)
        let position = CGPoint(x: area.minX + item.anchor.x * area.width,
                               y: area.minY + item.anchor.y * area.height)
        return clampedItemPosition(position, size: itemSize(for: item.definition), in: item.location)
    }

    private func itemAnchor(for position: CGPoint, in location: ItemLocation) -> CGPoint {
        let area = rect(for: location)
        guard area.width > 0, area.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: (position.x - area.minX) / area.width,
                       y: (position.y - area.minY) / area.height)
    }

    /// Which area an item dropped at this point belongs to. Anything not over the
    /// room — including the gap between the two — counts as Stuff.
    private func location(forDropAt position: CGPoint) -> ItemLocation {
        roomRect.contains(position) ? .room : .stuff
    }

    /// Keeps a whole item inside its area. In the Stuff panel it also stays clear
    /// of the Get Stuff button — an item parked on the button could not be picked
    /// up again, because the tap would spawn a new one instead.
    private func clampedItemPosition(_ position: CGPoint, size boxSize: CGSize,
                                     in location: ItemLocation) -> CGPoint {
        let area = rect(for: location)
        // A fixed breathing space, not a fraction of the area — the room is far
        // taller than the Stuff panel and would otherwise fence items off its walls.
        let margin = itemBaseSize.height * 0.2
        var rightEdge = area.maxX
        if location == .stuff, !getStuffButtonRect.isEmpty {
            rightEdge = getStuffButtonRect.minX
        }

        let minX = area.minX + margin + boxSize.width / 2
        let maxX = rightEdge - margin - boxSize.width / 2
        let minY = area.minY + margin + boxSize.height / 2
        let maxY = area.maxY - margin - boxSize.height / 2
        return CGPoint(x: min(max(position.x, minX), max(minX, maxX)),
                       y: min(max(position.y, minY), max(minY, maxY)))
    }

    /// While a drag is in progress an item is free to move anywhere across the
    /// room and the Stuff area; it is only pulled fully inside one of them on release.
    private func clampedDragPosition(_ position: CGPoint) -> CGPoint {
        let bounds = roomRect.union(stuffRect)
        return CGPoint(x: min(max(position.x, bounds.minX), bounds.maxX),
                       y: min(max(position.y, bounds.minY), bounds.maxY))
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

    private func characterAnchor(for position: CGPoint) -> CGPoint {
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
        if let item = topItem(at: location), let node = itemNodes[item.id] {
            beginItemDrag(item, node: node, touch: touch, at: location)
            return
        }

        if characterNode.calculateAccumulatedFrame().contains(location) {
            beginCharacterDrag(touch: touch, at: location)
        }
    }

    private func beginCharacterDrag(touch: UITouch, at location: CGPoint) {
        if characterUsing != nil {
            // Stand her up where she is, then let the drag carry on from there.
            characterAnchor = characterAnchor(for: characterNode.position)
            characterUsing = nil
            layoutCharacter()
        }

        dragTouch = touch
        dragSubject = .character
        dragOffset = CGPoint(x: characterNode.position.x - location.x,
                             y: characterNode.position.y - location.y)
    }

    private func beginItemDrag(_ item: Item, node: SKNode,
                                    touch: UITouch, at location: CGPoint) {
        // Bring it to the front so it is not dragged underneath its neighbours.
        if let index = itemIndex(id: item.id) {
            let moved = items.remove(at: index)
            items.append(moved)
            refreshItemDepths()
        }

        dragTouch = touch
        dragSubject = .item(id: item.id)
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
            characterAnchor = characterAnchor(for: characterNode.position)
            highlightFurniture(dropTarget())

        case .item(let id):
            guard let node = itemNodes[id], let index = itemIndex(id: id) else { return }
            node.position = clampedDragPosition(target)
            // Keep the model in step so a rotation mid-drag does not snap it back.
            let carriedTo = self.location(forDropAt: node.position)
            items[index].location = carriedTo
            items[index].anchor = itemAnchor(for: node.position, in: carriedTo)
            highlightMergeTarget(mergeTarget(for: items[index])?.id)
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
        case .item(let id):
            settleItem(id: id)
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

