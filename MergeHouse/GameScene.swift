import SpriteKit

/// The whole play area: the bedroom on top, the Stuff area below.
/// Drawn from shapes and labels, with artwork swapped in wherever it exists.
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

    /// Every tool button in the Stuff panel, with the rect it answers taps in.
    private var toolButtons: [(tool: StuffTool, node: SKNode, rect: CGRect)] = []
    /// Whether loose items caption themselves. On by default: while the art is
    /// still going in, telling a Bow from a Fancy Bow by shape alone is a guess.
    private var showItemLabels = true
    /// Reads out how much is loose, so a shelf with more on it than fits still
    /// says how much that is.
    private var stuffCountLabel: SKLabelNode?
    /// The Catalog sheet. Empty while it is closed.
    private let catalogNode = SKNode()
    /// Where each entry in the open Catalog sits, so a tap can spawn one.
    private var catalogCells: [(rect: CGRect, id: String)] = []
    private var catalogSheetRect: CGRect = .zero
    private var catalogCloseRect: CGRect = .zero

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
    /// One cell of the Stuff shelf: an item plus the room its name tag needs.
    private var itemSlotSize: CGSize = .zero
    /// Base size for an item on display in the room. Held apart from the shelf's
    /// size so that filling the shelf up does not shrink the dollhouse.
    private var roomItemBaseSize: CGSize = .zero

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
        addChild(catalogNode)
        // Room chrome draws in 0...3, then furniture, then the character on top.
        furnitureNode.zPosition = 5
        characterNode.zPosition = 10
        stuffNode.zPosition = 20
        itemsNode.zPosition = 25
        // The Catalog is a sheet over the whole scene, so it sits above everything.
        catalogNode.zPosition = 100
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

        // The room keeps the majority of the screen; Stuff takes a band along the
        // bottom — deep enough for two rows of items, since one row overflowed
        // the moment you tapped Get Stuff more than a handful of times.
        let stuffHeight = content.height * 0.30
        stuffRect = CGRect(x: content.minX,
                           y: content.minY,
                           width: content.width,
                           height: stuffHeight)
        roomRect = CGRect(x: content.minX,
                          y: content.minY + stuffHeight + gap,
                          width: content.width,
                          height: content.height - stuffHeight - gap)

        let roomItemHeight = roomRect.height * 0.13
        roomItemBaseSize = CGSize(width: roomItemHeight * 1.5, height: roomItemHeight)

        layoutRoom()
        layoutFurniture()
        layoutCharacter()
        layoutStuff()
        layoutItems()
        if isCatalogOpen {
            layoutCatalog()
        }
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

    /// The explore-mode toolbar. These exist to make the prototype easy to poke
    /// at — spawn things, see what merges into what, and clear the decks again —
    /// not because a finished game would have any of them.
    private enum StuffTool: String, CaseIterable {
        case getStuff = "Get Stuff"
        case catalog = "Catalog"
        case tidy = "Tidy Up"
        case mergeAll = "Merge All"
        case labels = "Labels"
        case trash = "Trash"

        /// A second line of small print, where the button needs one.
        var subtitle: String? {
            switch self {
            case .catalog: return "see everything"
            case .trash: return "drop one, or tap to clear"
            default: return nil
            }
        }

        var color: SKColor {
            switch self {
            case .getStuff: return SKColor(red: 0.35, green: 0.55, blue: 0.92, alpha: 1)
            case .catalog: return SKColor(red: 0.45, green: 0.40, blue: 0.78, alpha: 1)
            case .tidy: return SKColor(red: 0.28, green: 0.60, blue: 0.55, alpha: 1)
            case .mergeAll: return SKColor(red: 0.80, green: 0.58, blue: 0.24, alpha: 1)
            case .labels: return SKColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1)
            case .trash: return SKColor(red: 0.72, green: 0.32, blue: 0.34, alpha: 1)
            }
        }
    }

    private static let toolColumns = 2

    private func layoutStuff() {
        stuffNode.removeAllChildren()
        toolButtons = []

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

        let count = SKLabelNode(fontNamed: "AvenirNext-Medium")
        count.fontSize = titleFontSize * 0.5
        count.fontColor = SKColor(white: 0.62, alpha: 1)
        count.verticalAlignmentMode = .top
        count.horizontalAlignmentMode = .left
        count.position = CGPoint(x: title.position.x + title.frame.width + titleFontSize * 0.4,
                                 y: stuffRect.maxY - inset - titleFontSize * 0.22)
        count.zPosition = 1
        stuffNode.addChild(count)
        stuffCountLabel = count
        refreshStuffCount()

        layoutTools(inset: inset)

        // Items are dealt into the space left of the toolbar and below the title.
        // The shelf is sized first and the items to fit it, rather than the other
        // way round, so there are always whole rows rather than one and a bit.
        stuffSpawnRect = CGRect(x: stuffRect.minX + inset,
                                y: stuffRect.minY + inset * 0.5,
                                width: max(stuffRect.width * 0.2,
                                           buttonColumnMinX - inset * 2 - stuffRect.minX),
                                height: max(stuffRect.height * 0.3,
                                            stuffRect.height - inset * 1.5 - titleFontSize))

        itemSlotSize = slotSize(rows: stuffRows)
        // Squarer than the old placeholder box: names now hang underneath an item
        // rather than being written across it, so the box no longer has to be wide.
        itemBaseSize = CGSize(width: itemSlotSize.width / 1.18,
                              height: itemSlotSize.height * 0.62)
    }

    /// How many rows the shelf is divided into right now. It grows as the shelf
    /// fills — a crowded shelf of smaller items is far easier to read than a neat
    /// shelf with the leftovers heaped in the corner.
    private var stuffRows = GameScene.minStuffRows
    private static let minStuffRows = 2
    private static let maxStuffRows = 3

    private func slotSize(rows: Int) -> CGSize {
        let slotHeight = stuffSpawnRect.height / CGFloat(max(1, rows))
        let itemHeight = slotHeight * 0.62
        return CGSize(width: itemHeight * 1.5 * 1.18, height: slotHeight)
    }

    /// How many items fit on a shelf of this many rows.
    private func shelfCapacity(rows: Int) -> Int {
        let slot = slotSize(rows: rows)
        guard slot.width > 0 else { return 0 }
        return max(1, Int(stuffSpawnRect.width / slot.width)) * rows
    }

    /// Re-splits the shelf if what is on it no longer fits the current rows.
    /// Called whenever the loose items change, which is what keeps Get Stuff from
    /// ever burying anything.
    private func refreshStuffDensity() {
        let loose = items.filter { $0.location == .stuff }.count
        var rows = Self.minStuffRows
        while rows < Self.maxStuffRows && loose > shelfCapacity(rows: rows) {
            rows += 1
        }
        guard rows != stuffRows else { return }
        stuffRows = rows
        layoutStuff()
        layoutItems()
    }

    /// Every position on the shelf, in reading order. Items are dealt into these
    /// rather than scattered, so a full Stuff area stays something you can scan.
    private func stuffSlots() -> [CGPoint] {
        guard itemSlotSize.width > 0, itemSlotSize.height > 0 else { return [] }
        let columns = max(1, Int(stuffSpawnRect.width / itemSlotSize.width))
        var points: [CGPoint] = []
        for row in 0..<stuffRows {
            for column in 0..<columns {
                // Sat high in its slot, leaving the bottom of the slot for the name tag.
                points.append(CGPoint(
                    x: stuffSpawnRect.minX + (CGFloat(column) + 0.5) * itemSlotSize.width,
                    y: stuffSpawnRect.maxY - (CGFloat(row) + 0.42) * itemSlotSize.height))
            }
        }
        return points
    }

    /// The toolbar: a grid of buttons filling the right-hand end of the panel.
    private func layoutTools(inset: CGFloat) {
        let tools = StuffTool.allCases
        let columns = Self.toolColumns
        let rows = Int(ceil(Double(tools.count) / Double(columns)))
        let gap = stuffRect.height * 0.05

        let buttonHeight = (stuffRect.height - inset * 2 - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let buttonWidth = min(stuffRect.width * 0.20, stuffRect.height * 2.0)
        let gridWidth = buttonWidth * CGFloat(columns) + gap * CGFloat(columns - 1)
        let gridLeft = stuffRect.maxX - inset - gridWidth
        let gridTop = stuffRect.maxY - inset

        for (index, tool) in tools.enumerated() {
            let column = index % columns
            let row = index / columns
            let rect = CGRect(x: gridLeft + CGFloat(column) * (buttonWidth + gap),
                              y: gridTop - CGFloat(row + 1) * buttonHeight - CGFloat(row) * gap,
                              width: buttonWidth,
                              height: buttonHeight)
            let node = makeStuffButton(rect: rect, title: tool.rawValue,
                                       subtitle: tool.subtitle, color: tool.color)
            node.zPosition = 2
            stuffNode.addChild(node)
            toolButtons.append((tool, node, rect))
        }

        refreshLabelsButton()
    }

    /// The left edge of the toolbar, which items keep clear of.
    private var buttonColumnMinX: CGFloat {
        toolButtons.reduce(stuffRect.maxX) { min($0, $1.rect.minX) }
    }

    private func button(for tool: StuffTool) -> (node: SKNode, rect: CGRect)? {
        guard let match = toolButtons.first(where: { $0.tool == tool }) else { return nil }
        return (match.node, match.rect)
    }

    private static let buttonBackgroundName = "button-background"

    /// Built around its own centre so it can scale when pressed.
    private func makeStuffButton(rect: CGRect, title: String,
                                 subtitle: String?, color: SKColor) -> SKNode {
        let node = SKNode()
        node.position = CGPoint(x: rect.midX, y: rect.midY)

        let background = SKShapeNode(rect: CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                                  width: rect.width, height: rect.height),
                                     cornerRadius: rect.height * 0.35)
        background.name = Self.buttonBackgroundName
        background.fillColor = color
        background.strokeColor = SKColor(white: 0.9, alpha: 0.8)
        background.lineWidth = 2
        node.addChild(background)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = max(13, rect.height * 0.34)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: subtitle == nil ? 0 : rect.height * 0.12)
        node.addChild(label)

        if let subtitle = subtitle {
            let caption = SKLabelNode(fontNamed: "AvenirNext-Medium")
            caption.text = subtitle
            caption.fontSize = max(8, rect.height * 0.19)
            caption.fontColor = SKColor(white: 1, alpha: 0.75)
            caption.verticalAlignmentMode = .center
            caption.horizontalAlignmentMode = .center
            caption.position = CGPoint(x: 0, y: -rect.height * 0.20)
            node.addChild(caption)
        }

        return node
    }

    private func pressButton(_ button: SKNode?) {
        guard let button = button else { return }
        button.removeAllActions()
        button.setScale(1)
        button.run(.sequence([.scale(to: 0.92, duration: 0.06),
                              .scale(to: 1.0, duration: 0.09)]))
    }

    private func refreshStuffCount() {
        let onShelf = items.filter { $0.location == .stuff }.count
        let inRoom = items.count - onShelf
        var text = onShelf == 1 ? "1 item" : "\(onShelf) items"
        if inRoom > 0 {
            text += " · \(inRoom) in the room"
        }
        stuffCountLabel?.text = text
    }

    private func toolTapped(_ tool: StuffTool) {
        pressButton(button(for: tool)?.node)
        switch tool {
        case .getStuff: spawnItem()
        case .catalog: toggleCatalog()
        case .tidy: tidyStuff()
        case .mergeAll: mergeEverything()
        case .labels: toggleItemLabels()
        case .trash: clearStuffTapped()
        }
    }

    /// The Labels button says what it will do next, so its state is readable
    /// without hunting for a caption somewhere else.
    private func refreshLabelsButton() {
        guard let node = button(for: .labels)?.node,
              let background = node.childNode(withName: Self.buttonBackgroundName) as? SKShapeNode
        else { return }
        background.fillColor = showItemLabels
            ? StuffTool.labels.color
            : SKColor(white: 0.24, alpha: 1)
    }

    private func toggleItemLabels() {
        showItemLabels.toggle()
        refreshLabelsButton()
        layoutItems()
    }

    /// Wipes every loose item, in the Stuff area and in the room alike.
    /// Any drag in progress is dropped with it, since its item is gone.
    private func clearStuffTapped() {
        guard !items.isEmpty else { return }

        if case .item = dragSubject {
            dragTouch = nil
            dragSubject = nil
        }
        highlightMergeTarget(nil)
        highlightTrash(false)

        for item in items {
            guard let node = itemNodes[item.id] else { continue }
            node.run(.sequence([.group([.scale(to: 0.4, duration: 0.12),
                                        .fadeOut(withDuration: 0.12)]),
                                .removeFromParent()]))
        }
        items.removeAll()
        itemNodes.removeAll()
        refreshStuffCount()
        refreshStuffDensityAfterPoof()
    }

    /// Re-splitting the shelf rebuilds every node, which would cut a disappearing
    /// item's animation off halfway. This waits for the poof to finish first.
    private func refreshStuffDensityAfterPoof() {
        run(.sequence([.wait(forDuration: 0.16),
                       .run { [weak self] in self?.refreshStuffDensity() }]))
    }

    // MARK: - Explore tools

    /// Lays every loose item in the Stuff area out on a grid, in catalog order,
    /// so a pile that has been shoved around becomes a readable shelf again.
    /// Items carried into the room are left where they are; they are on display.
    private func tidyStuff() {
        refreshStuffDensity()
        let loose = items.enumerated()
            .filter { $0.element.location == .stuff }
            .sorted { left, right in
                let leftIndex = ItemCatalog.sortIndex(of: left.element.definition)
                let rightIndex = ItemCatalog.sortIndex(of: right.element.definition)
                if leftIndex != rightIndex { return leftIndex < rightIndex }
                return left.offset < right.offset
            }
        guard !loose.isEmpty else { return }

        // A flow, not a fixed grid: a Giant Cake is twice the width of a Bow, and
        // laying both on the same pitch is what made big items sit on their
        // neighbours. Each item takes the room it actually needs, and the row
        // wraps when it runs out.
        let gap = itemBaseSize.width * 0.16
        var penX = stuffSpawnRect.minX
        var row = 0
        var overflow: CGFloat = 0

        for entry in loose {
            let boxSize = itemSize(for: entry.element.definition, in: .stuff)
            if penX > stuffSpawnRect.minX, penX + boxSize.width > stuffSpawnRect.maxX {
                row += 1
                penX = stuffSpawnRect.minX
            }
            // Past the last row the leftovers fan out from the corner: still a
            // pile, but a pile that reads as "there is more here than fits".
            if row >= stuffRows {
                overflow += itemBaseSize.height * 0.16
            }
            let rowIndex = min(row, stuffRows - 1)
            let point = clampedItemPosition(
                CGPoint(x: penX + boxSize.width / 2 + overflow,
                        y: stuffSpawnRect.maxY - (CGFloat(rowIndex) + 0.42) * itemSlotSize.height
                            - overflow),
                size: boxSize, in: .stuff)
            penX += boxSize.width + gap

            items[entry.offset].anchor = itemAnchor(for: point, in: .stuff)
            guard let node = itemNodes[entry.element.id] else { continue }
            node.removeAllActions()
            node.run(.move(to: point, duration: 0.18))
        }

        // Redraw order follows the sort, so the shelf reads left to right on top too.
        let sortedIDs = loose.map { $0.element.id }
        items.sort { left, right in
            let leftSlot = sortedIDs.firstIndex(of: left.id) ?? sortedIDs.count
            let rightSlot = sortedIDs.firstIndex(of: right.id) ?? sortedIDs.count
            return leftSlot < rightSlot
        }
        refreshItemDepths()
    }

    /// Merges every pair it can, over and over, until nothing else will combine.
    /// The fastest way to see the top of a chain — and which artwork is missing
    /// up there — without dragging the same bow together sixteen times.
    private func mergeEverything() {
        // Bounded rather than `while true`: a catalog that loops back on itself
        // would otherwise spin here forever.
        for _ in 0..<200 {
            guard let pair = nextMergeablePair() else { break }
            guard let result = ItemCatalog.mergeResult(for: pair.0.definition) else { break }
            merge(pair.0, pair.1, into: result)
        }
        tidyStuff()
    }

    /// Any two matching items in the Stuff area that have somewhere to go.
    private func nextMergeablePair() -> (Item, Item)? {
        var seen: [String: Item] = [:]
        for item in items where item.location == .stuff {
            guard ItemCatalog.mergeResult(for: item.definition) != nil else { continue }
            if let partner = seen[item.definition.id] {
                return (item, partner)
            }
            seen[item.definition.id] = item
        }
        return nil
    }

    /// Fades one item out and forgets it. The single-item counterpart to Trash.
    private func discardItem(id: Int) {
        guard let node = itemNodes[id] else { return }
        node.removeAllActions()
        node.run(.sequence([.group([.scale(to: 0.3, duration: 0.14),
                                    .fadeOut(withDuration: 0.14)]),
                            .removeFromParent()]))
        itemNodes[id] = nil
        if let index = itemIndex(id: id) {
            items.remove(at: index)
        }
        refreshStuffCount()
        refreshStuffDensityAfterPoof()
    }

    /// Whether an item let go here should be thrown away.
    private func isOverTrash(_ position: CGPoint) -> Bool {
        guard let trash = button(for: .trash) else { return false }
        return trash.rect.contains(position)
    }

    private func highlightTrash(_ on: Bool) {
        guard let trash = button(for: .trash),
              let background = trash.node.childNode(withName: Self.buttonBackgroundName)
                as? SKShapeNode else { return }
        background.strokeColor = on ? Self.itemMergeStroke : SKColor(white: 0.9, alpha: 0.8)
        background.lineWidth = on ? 5 : 2
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

    /// Drops one item into the Stuff area. `Get Stuff` deals a random starter;
    /// the Catalog hands in whichever entry was tapped, so anything in the game
    /// can be looked at without merging up to it first.
    @discardableResult
    private func spawnItem(_ definition: ItemDefinition = ItemCatalog.randomStarter()) -> SKNode {
        let anchor = nextSpawnAnchor()
        addItem(definition: definition, location: .stuff, anchor: anchor)
        let id = nextItemID - 1
        // Adding this one may have re-split the shelf, which rebuilds every node,
        // so the one to animate is looked up after that rather than held onto.
        refreshStuffDensity()
        let node = itemNodes[id] ?? SKNode()
        node.setScale(0.6)
        node.run(.scale(to: 1.0, duration: 0.12))
        return node
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
        refreshStuffCount()
        return node
    }

    private func removeItem(id: Int) {
        itemNodes[id]?.removeFromParent()
        itemNodes[id] = nil
        if let index = itemIndex(id: id) {
            items.remove(at: index)
        }
        refreshStuffCount()
    }

    /// The size one item draws at. Items are dealt out small enough to fit the
    /// shelf and shown larger once they are in the room, which is the point of
    /// carrying one in there.
    private func baseSize(in location: ItemLocation) -> CGSize {
        switch location {
        case .stuff: return itemBaseSize
        case .room: return roomItemBaseSize
        }
    }

    private func itemSize(for definition: ItemDefinition, in location: ItemLocation) -> CGSize {
        let base = baseSize(in: location)
        return CGSize(width: base.width * definition.scale,
                      height: base.height * definition.scale)
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

    /// An item's box in scene coordinates: where it is now, at the size its
    /// level says it should be. Measured rather than taken from the node so a
    /// name caption hanging below it does not count as part of the item.
    private func itemFrame(for item: Item) -> CGRect? {
        guard let position = itemNodes[item.id]?.position else { return nil }
        let size = itemSize(for: item.definition, in: item.location)
        return CGRect(x: position.x - size.width / 2, y: position.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// The topmost item under a touch, if any. A little slop around the box
    /// makes small items easier to grab with a finger.
    private func topItem(at location: CGPoint) -> Item? {
        let slop = itemBaseSize.height * 0.12
        for item in items.reversed() {
            guard let frame = itemFrame(for: item) else { continue }
            if frame.insetBy(dx: -slop, dy: -slop).contains(location) {
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
              let draggedFrame = itemFrame(for: dragged) else {
            return nil
        }
        let draggedArea = draggedFrame.width * draggedFrame.height
        var best: (item: Item, overlap: CGFloat)?

        for other in items where other.id != dragged.id &&
            other.definition.id == dragged.definition.id && other.location == .stuff {
            guard let otherFrame = itemFrame(for: other) else { continue }
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
        highlightTrash(false)
        guard let index = itemIndex(id: id), var node = itemNodes[id] else { return }
        node.removeAllActions()

        // Dropped on the Trash button: this one item goes, and nothing else.
        if isOverTrash(node.position) {
            discardItem(id: id)
            return
        }

        // Whichever area it was let go over is the one it now belongs to.
        let dropLocation = location(forDropAt: node.position)
        let resting = clampedItemPosition(node.position,
                                          size: itemSize(for: items[index].definition,
                                                         in: dropLocation),
                                          in: dropLocation)
        let movedArea = items[index].location != dropLocation
        items[index].location = dropLocation
        items[index].anchor = itemAnchor(for: resting, in: dropLocation)
        node.position = resting
        refreshStuffCount()

        // Carried between the shelf and the room, it is redrawn at that area's size.
        if movedArea {
            node.removeFromParent()
            node = addItemNode(for: items[index])
            refreshItemDepths()
        }

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

        let resting = clampedItemPosition(meetingPoint, size: itemSize(for: result, in: .stuff),
                                          in: .stuff)
        let node = addItem(definition: result, location: .stuff,
                           anchor: itemAnchor(for: resting, in: .stuff))
        node.setScale(0.5)
        node.run(.sequence([.scale(to: 1.15, duration: 0.10),
                            .scale(to: 1.0, duration: 0.08)]))
    }

    /// An item node: its artwork if the asset exists, a labeled placeholder box
    /// if it does not, plus a merge highlight that is hidden until it is needed.
    /// Everything is built around the node's own centre so it can be positioned
    /// and scaled by its middle.
    private func makeItemNode(for item: Item) -> SKNode {
        let boxSize = itemSize(for: item.definition, in: item.location)
        let node = SKNode()
        node.position = itemPosition(for: item)
        node.addChild(makeItemArtwork(for: item.definition, size: boxSize))

        // Artwork carries no name of its own, and two levels of the same chain
        // differ only in size. A caption is what makes a pile readable.
        if showItemLabels, item.definition.artwork != nil {
            node.addChild(makeItemCaption(item.definition.name,
                                          fontSize: max(9, baseSize(in: item.location).height * 0.20),
                                          topY: -boxSize.height / 2))
        }

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

    /// A name tag under an item, on its own dark pill so it stays readable over
    /// the wall, the floor and the Stuff panel alike.
    private func makeItemCaption(_ text: String, fontSize: CGFloat, topY: CGFloat) -> SKNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let padding = fontSize * 0.45
        let pillWidth = max(label.frame.width + padding * 2, fontSize * 2)
        let pillHeight = fontSize + padding
        let pill = SKShapeNode(rect: CGRect(x: -pillWidth / 2, y: -pillHeight / 2,
                                            width: pillWidth, height: pillHeight),
                               cornerRadius: pillHeight / 2)
        pill.fillColor = SKColor(white: 0.08, alpha: 0.75)
        pill.strokeColor = .clear
        pill.position = CGPoint(x: 0, y: topY - pillHeight * 0.55)
        pill.addChild(label)
        return pill
    }

    /// Missing artwork is a normal state, not an error: anything without a drawing
    /// yet falls back to a labeled box of the right size.
    private func makeItemArtwork(for definition: ItemDefinition, size boxSize: CGSize) -> SKNode {
        if let image = definition.artwork {
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

    /// Picks where a newly spawned item lands: the first free slot on the shelf,
    /// so things line up as they are dealt instead of landing on each other. Once
    /// every slot is taken it falls back to the emptiest one, nudged a little so
    /// the newcomer is not hidden exactly behind an older item.
    private func nextSpawnAnchor() -> CGPoint {
        let slots = stuffSlots()
        guard !slots.isEmpty else {
            return itemAnchor(for: CGPoint(x: stuffSpawnRect.midX, y: stuffSpawnRect.midY),
                              in: .stuff)
        }

        let taken = items.filter { $0.location == .stuff }
            .compactMap { itemNodes[$0.id]?.position }
        let occupied = min(itemSlotSize.width, itemSlotSize.height) * 0.5

        var bestPoint = slots[0]
        var bestClearance = -CGFloat.greatestFiniteMagnitude

        for slot in slots {
            let clearance = taken.map { hypot($0.x - slot.x, $0.y - slot.y) }.min()
                ?? CGFloat.greatestFiniteMagnitude
            if clearance > occupied {
                return itemAnchor(for: clampedItemPosition(slot, size: itemBaseSize, in: .stuff),
                                  in: .stuff)
            }
            if clearance > bestClearance {
                bestClearance = clearance
                bestPoint = slot
            }
        }

        let nudge = itemBaseSize.height * 0.3
        let crowded = clampedItemPosition(CGPoint(x: bestPoint.x + .random(in: -nudge...nudge),
                                                  y: bestPoint.y + .random(in: -nudge...nudge)),
                                          size: itemBaseSize, in: .stuff)
        return itemAnchor(for: crowded, in: .stuff)
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
        return clampedItemPosition(position, size: itemSize(for: item.definition, in: item.location),
                                   in: item.location)
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
    /// of the button column — an item parked on a button could not be picked up
    /// again, because the tap would hit the button instead.
    private func clampedItemPosition(_ position: CGPoint, size boxSize: CGSize,
                                     in location: ItemLocation) -> CGPoint {
        let area = rect(for: location)
        // A fixed breathing space, not a fraction of the area — the room is far
        // taller than the Stuff panel and would otherwise fence items off its walls.
        let margin = baseSize(in: location).height * 0.2
        var rightEdge = area.maxX
        if location == .stuff {
            rightEdge = buttonColumnMinX
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

    private static let characterImageName = "Basic_human_drawing"

    /// Builds the character, sized relative to the room.
    /// The container's position is the character's feet.
    private func layoutCharacter() {
        characterNode.removeAllChildren()

        let height = roomRect.height * 0.30

        // Build at the origin, unrotated, so the accumulated frame comes out
        // in local coordinates.
        characterNode.position = .zero
        characterNode.zRotation = 0

        characterNode.addChild(makeCharacterArtwork(height: height))

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = characterUsing?.characterLabel ?? "Girl"
        label.fontSize = max(12, height * 0.15)
        label.fontColor = SKColor(white: 0.15, alpha: 1)
        label.verticalAlignmentMode = .bottom
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: height + height * 0.06)
        characterNode.addChild(label)

        characterLocalFrame = characterNode.calculateAccumulatedFrame()

        if let kind = characterUsing, let piece = piece(for: kind) {
            characterNode.zRotation = kind.characterRotation
            characterNode.position = seatPosition(for: piece)
        } else {
            characterNode.position = clampedCharacterPosition(scenePosition(for: characterAnchor))
        }
    }

    /// The character's drawing, standing on the origin. Falls back to a shape
    /// placeholder if the artwork is missing, the same way items do.
    private func makeCharacterArtwork(height: CGFloat) -> SKNode {
        if let image = UIImage(named: Self.characterImageName) {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            let scale = height / sprite.size.height
            sprite.size = CGSize(width: sprite.size.width * scale, height: height)
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
        body.fillColor = SKColor(red: 0.90, green: 0.36, blue: 0.55, alpha: 1)
        body.strokeColor = outlineColor
        body.lineWidth = 2
        placeholder.addChild(body)

        let head = SKShapeNode(circleOfRadius: headRadius)
        head.position = CGPoint(x: 0, y: bodyHeight + headRadius * 0.85)
        head.fillColor = SKColor(red: 0.98, green: 0.84, blue: 0.72, alpha: 1)
        head.strokeColor = outlineColor
        head.lineWidth = 2
        placeholder.addChild(head)

        return placeholder
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

        // The Catalog is a sheet: while it is open it swallows every touch.
        if isCatalogOpen {
            catalogTapped(at: location)
            return
        }

        if let tool = toolButtons.first(where: { $0.rect.contains(location) })?.tool {
            toolTapped(tool)
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
            highlightTrash(isOverTrash(node.position))
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

    // MARK: - Catalog

    /// The Catalog is the answer to "what is actually in this game?": every chain
    /// laid out bottom to top, every drawing that exists, and the filename of every
    /// drawing that does not. Tapping an entry deals one out, so the top of a chain
    /// can be looked at without merging up to it.

    private var isCatalogOpen: Bool { !catalogNode.children.isEmpty }

    private func toggleCatalog() {
        if isCatalogOpen {
            closeCatalog()
        } else {
            layoutCatalog()
        }
    }

    private func closeCatalog() {
        catalogNode.removeAllChildren()
        catalogCells = []
        catalogCloseRect = .zero
        catalogSheetRect = .zero
    }

    private func layoutCatalog() {
        catalogNode.removeAllChildren()
        catalogCells = []

        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = SKColor(white: 0, alpha: 0.62)
        dim.strokeColor = .clear
        catalogNode.addChild(dim)

        catalogSheetRect = CGRect(origin: .zero, size: size)
            .insetBy(dx: size.width * 0.05, dy: size.height * 0.05)
        let sheet = SKShapeNode(rect: catalogSheetRect,
                                cornerRadius: catalogSheetRect.height * 0.04)
        sheet.fillColor = SKColor(red: 0.16, green: 0.15, blue: 0.20, alpha: 1)
        sheet.strokeColor = SKColor(white: 0.42, alpha: 1)
        sheet.lineWidth = 3
        catalogNode.addChild(sheet)

        let inset = catalogSheetRect.height * 0.05
        let titleSize = max(20, catalogSheetRect.height * 0.065)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Catalog"
        title.fontSize = titleSize
        title.fontColor = SKColor(white: 0.95, alpha: 1)
        title.verticalAlignmentMode = .top
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: catalogSheetRect.minX + inset,
                                 y: catalogSheetRect.maxY - inset)
        catalogNode.addChild(title)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = "every chain, bottom to top — tap an item to deal one out"
        hint.fontSize = titleSize * 0.45
        hint.fontColor = SKColor(white: 0.68, alpha: 1)
        hint.verticalAlignmentMode = .top
        hint.horizontalAlignmentMode = .left
        hint.position = CGPoint(x: catalogSheetRect.minX + inset,
                                y: catalogSheetRect.maxY - inset - titleSize * 1.15)
        catalogNode.addChild(hint)

        catalogCloseRect = CGRect(x: catalogSheetRect.maxX - inset - titleSize * 3.4,
                                  y: catalogSheetRect.maxY - inset - titleSize,
                                  width: titleSize * 3.4, height: titleSize * 1.3)
        catalogNode.addChild(makeStuffButton(rect: catalogCloseRect, title: "Close",
                                             subtitle: nil,
                                             color: SKColor(red: 0.42, green: 0.40, blue: 0.48, alpha: 1)))

        layoutCatalogChains(in: CGRect(x: catalogSheetRect.minX + inset,
                                       y: catalogSheetRect.minY + inset,
                                       width: catalogSheetRect.width - inset * 2,
                                       height: catalogSheetRect.height - inset * 2 - titleSize * 2.1))
    }

    /// One row per chain, one column per merge level, columns aligned across rows
    /// so chains of different lengths can be compared at a glance.
    private func layoutCatalogChains(in body: CGRect) {
        let chains = ItemCatalog.chains
        guard !chains.isEmpty else { return }
        let longest = chains.map { $0.count }.max() ?? 1

        let rowHeight = body.height / CGFloat(chains.count)
        let columnWidth = body.width / CGFloat(longest)

        for (row, chain) in chains.enumerated() {
            let rowTop = body.maxY - CGFloat(row) * rowHeight
            let tallest = chain.map { $0.scale }.max() ?? 1

            for (column, definition) in chain.enumerated() {
                let slot = CGRect(x: body.minX + CGFloat(column) * columnWidth,
                                  y: rowTop - rowHeight,
                                  width: columnWidth, height: rowHeight)
                let cell = slot.insetBy(dx: columnWidth * 0.07, dy: rowHeight * 0.09)
                catalogNode.addChild(makeCatalogCell(for: definition, in: cell,
                                                     relativeScale: definition.scale / tallest))
                catalogCells.append((cell, definition.id))

                if column < chain.count - 1 {
                    let arrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
                    arrow.text = "\u{2192}"
                    arrow.fontSize = max(14, rowHeight * 0.22)
                    arrow.fontColor = SKColor(white: 0.60, alpha: 1)
                    arrow.verticalAlignmentMode = .center
                    arrow.horizontalAlignmentMode = .center
                    arrow.position = CGPoint(x: slot.maxX, y: cell.midY + rowHeight * 0.06)
                    catalogNode.addChild(arrow)
                }
            }
        }
    }

    /// One entry: the drawing at a size that shows its place in the chain, its
    /// name, how many are loose in the world right now, and — when there is no
    /// drawing yet — the filename that would give it one.
    private func makeCatalogCell(for definition: ItemDefinition, in cell: CGRect,
                                 relativeScale: CGFloat) -> SKNode {
        let node = SKNode()

        let background = SKShapeNode(rect: cell, cornerRadius: cell.height * 0.10)
        background.fillColor = SKColor(white: 1, alpha: 0.06)
        background.strokeColor = SKColor(white: 1, alpha: 0.14)
        background.lineWidth = 2
        node.addChild(background)

        let nameSize = max(11, cell.height * 0.12)
        let artCentre = CGPoint(x: cell.midX, y: cell.midY + cell.height * 0.10)
        // Later links draw bigger, so a chain visibly grows across the row.
        let artBox = CGSize(width: cell.width * 0.72 * (0.62 + 0.38 * relativeScale),
                            height: cell.height * 0.50 * (0.62 + 0.38 * relativeScale))

        if let image = definition.artwork {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            let fit = min(artBox.width / sprite.size.width, artBox.height / sprite.size.height)
            sprite.size = CGSize(width: sprite.size.width * fit, height: sprite.size.height * fit)
            sprite.position = artCentre
            node.addChild(sprite)
        } else {
            let box = SKShapeNode(rect: CGRect(x: artCentre.x - artBox.width / 2,
                                               y: artCentre.y - artBox.height / 2,
                                               width: artBox.width, height: artBox.height),
                                  cornerRadius: artBox.height * 0.18)
            box.fillColor = definition.placeholderColor.withAlphaComponent(0.55)
            box.strokeColor = Self.catalogMissingArt
            box.lineWidth = 3
            node.addChild(box)

            let mark = SKLabelNode(fontNamed: "AvenirNext-Bold")
            mark.text = "?"
            mark.fontSize = artBox.height * 0.5
            mark.fontColor = SKColor(white: 0.15, alpha: 0.8)
            mark.verticalAlignmentMode = .center
            mark.horizontalAlignmentMode = .center
            mark.position = artCentre
            node.addChild(mark)
        }

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.text = definition.name
        name.fontSize = nameSize
        name.fontColor = SKColor(white: 0.95, alpha: 1)
        name.verticalAlignmentMode = .center
        name.horizontalAlignmentMode = .center
        name.position = CGPoint(x: cell.midX, y: cell.minY + cell.height * 0.22)
        node.addChild(name)

        let note = SKLabelNode(fontNamed: "AvenirNext-Medium")
        note.fontSize = nameSize * 0.78
        note.verticalAlignmentMode = .center
        note.horizontalAlignmentMode = .center
        note.position = CGPoint(x: cell.midX, y: cell.minY + cell.height * 0.09)
        if definition.artwork == nil {
            note.text = definition.missingArtworkNote
            note.fontColor = Self.catalogMissingArt
        } else {
            note.text = definition.mergesInto == nil ? "top of the chain" : "merges in pairs"
            note.fontColor = SKColor(white: 0.55, alpha: 1)
        }
        node.addChild(note)

        let count = items.filter { $0.definition.id == definition.id }.count
        if count > 0 {
            let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
            badge.text = "\u{00D7}\(count)"
            badge.fontSize = nameSize
            badge.fontColor = SKColor(red: 1.0, green: 0.86, blue: 0.42, alpha: 1)
            badge.verticalAlignmentMode = .top
            badge.horizontalAlignmentMode = .right
            badge.position = CGPoint(x: cell.maxX - cell.width * 0.06,
                                     y: cell.maxY - cell.height * 0.06)
            node.addChild(badge)
        }

        return node
    }

    private static let catalogMissingArt = SKColor(red: 1.0, green: 0.68, blue: 0.30, alpha: 1)

    /// Taps while the sheet is up: an entry deals one out, Close or a tap on the
    /// dimmed surround puts it away, and anything else is swallowed.
    private func catalogTapped(at location: CGPoint) {
        if catalogCloseRect.contains(location) {
            closeCatalog()
            return
        }

        if let id = catalogCells.first(where: { $0.rect.contains(location) })?.id,
           let definition = ItemCatalog.definition(id: id) {
            spawnItem(definition)
            // Rebuilt so the entry's count badge shows the tap landed.
            layoutCatalog()
            return
        }

        if !catalogSheetRect.contains(location) {
            closeCatalog()
        }
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

