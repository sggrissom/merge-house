import SpriteKit
import UIKit

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
    /// The character. A persistent container so it keeps its own state across
    /// resizes — and so carried items have something to be children of.
    private let characterNode = SKNode()
    /// The character's own drawing and name tag, rebuilt on every layout.
    /// Held apart from `characterNode` so that whatever they are carrying — which
    /// lives alongside it — is not wiped out every time they are redrawn.
    private let characterBodyNode = SKNode()
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
    /// The size that readout wants to be. Held so it can be shrunk to fit a long
    /// tally and then grow back again, rather than only ever getting smaller.
    private var stuffCountFontSize: CGFloat = 0
    /// The open sheet — the Catalog or the character picker. Empty while closed.
    private let sheetNode = SKNode()
    /// Where each entry in the open sheet sits, so a tap can act on it. What the
    /// id means is the open sheet's business: an item to deal out, or a character
    /// to become.
    private var sheetCells: [(rect: CGRect, id: String)] = []
    private var sheetRect: CGRect = .zero
    private var sheetCloseRect: CGRect = .zero

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
    /// The piece the character is currently using, if any. While set, their
    /// position comes from that piece rather than from `characterAnchor`.
    private var characterUsing: FurnitureKind?
    /// The character's bounds relative to its own origin (its feet), used for clamping.
    private var characterLocalFrame: CGRect = .zero
    /// Who you are playing as. Everything about how the character draws comes
    /// from here, so switching is this one assignment plus a relayout.
    private var character = CharacterCatalog.starting
    /// How tall the character currently draws. Carry points are fractions of
    /// this, so it is the one number that turns a `CarryPoint` into a position.
    private var characterHeight: CGFloat = 0

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
        characterNode.addChild(characterBodyNode)
        addChild(stuffNode)
        addChild(itemsNode)
        addChild(sheetNode)
        // Room chrome draws in 0...3, then furniture, then the character on top.
        furnitureNode.zPosition = 5
        characterNode.zPosition = 10
        stuffNode.zPosition = 20
        itemsNode.zPosition = 25
        // The Catalog is a sheet over the whole scene, so it sits above everything.
        sheetNode.zPosition = 100
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        // Once, however many times the scene is presented. `didMove` fires again
        // on a re-present, and restoring twice would append a second copy of
        // everything in the save.
        if !hasRestored {
            hasRestored = true
            // The model is restored first and the nodes are built from it, which
            // is the same path a resize takes — so loading a save exercises no
            // code that ordinary play does not.
            restoreSavedGame()
        }
        layoutScene()
        refreshStuffDensity()

        // Removed first for the same reason: presenting twice must not leave two
        // observers writing the same save.
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(flushSave),
            name: UIApplication.willResignActiveNotification, object: nil)
    }

    private var hasRestored = false

    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
        flushSave()
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
        if isSheetOpen {
            layoutSheet()
        }
    }

    // MARK: - Room

    private func layoutRoom() {
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

    private static let backdropImageName = "bedroom"

    /// The room artwork, scaled to fill `rect`. The artwork's aspect ratio rarely
    /// matches the room's, and letterboxing would show the scene's dark backing
    /// through the room, so the overflowing side is cropped off the texture
    /// instead of being drawn outside the room.
    private func makeBackdrop(in rect: CGRect) -> SKSpriteNode? {
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
    private func addPlaceholderRoom() {
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

    /// Where the character's origin (their feet) goes when they use a piece.
    private func seatPosition(for piece: FurniturePiece) -> CGPoint {
        let rect = piece.rect
        switch piece.kind {
        case .bed:
            // Lying across the bed. Rotated 90°, so the body extends left from here.
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
        case characters = "Characters"
        case tidy = "Tidy Up"
        case mergeAll = "Merge All"
        case labels = "Labels"
        case trash = "Trash"

        /// A second line of small print, where the button needs one.
        var subtitle: String? {
            switch self {
            case .catalog: return "see everything"
            case .characters: return "pick who you are"
            case .trash: return "drop one, or tap to clear"
            default: return nil
            }
        }

        var color: SKColor {
            switch self {
            case .getStuff: return SKColor(red: 0.35, green: 0.55, blue: 0.92, alpha: 1)
            case .catalog: return SKColor(red: 0.45, green: 0.40, blue: 0.78, alpha: 1)
            case .characters: return SKColor(red: 0.78, green: 0.40, blue: 0.58, alpha: 1)
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
        stuffCountFontSize = count.fontSize

        layoutTools(inset: inset)
        // After the toolbar, which is what the readout has to stay clear of.
        refreshStuffCount()

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
        let carried = items.filter { $0.location.carryStyle != nil }.count
        let inRoom = items.count - onShelf - carried
        var text = onShelf == 1 ? "1 item" : "\(onShelf) items"
        if inRoom > 0 {
            text += " · \(inRoom) in the room"
        }
        if carried > 0 {
            text += " · \(carried) on \(character.name)"
        }

        guard let label = stuffCountLabel else { return }
        label.text = text
        // The readout runs rightwards into the toolbar, and "3 items · 1 in the
        // room · 3 on Girl" is long enough to disappear under it. Same bargain
        // the Catalog's filenames strike first — a small line that fits beats a
        // big one that is covered up — and then, where the toolbar starts almost
        // at the title and even the smallest legible size will not fit, no line
        // at all beats an unreadable smear under the buttons.
        label.fontSize = stuffCountFontSize
        let available = buttonColumnMinX - label.position.x - stuffCountFontSize * 0.5
        shrinkToFit(label, width: available)
        label.isHidden = label.frame.width > available
    }

    private func toolTapped(_ tool: StuffTool) {
        pressButton(button(for: tool)?.node)
        switch tool {
        case .getStuff: spawnItem()
        case .catalog: toggleSheet(.catalog)
        case .characters: toggleSheet(.characters)
        case .tidy: tidyStuff()
        case .mergeAll: mergeEverything()
        case .labels: toggleItemLabels()
        case .trash: clearStuffTapped()
        }
        setNeedsSave()
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
        highlightCharacter(false)

        for item in items {
            guard let node = itemNodes[item.id] else { continue }
            node.run(.sequence([.group([.scale(to: 0.4, duration: 0.12),
                                        .fadeOut(withDuration: 0.12)]),
                                .removeFromParent()]))
        }
        items.removeAll()
        itemNodes.removeAll()
        refreshStuffCount()
        setNeedsSave()
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
        setNeedsSave()
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

    /// Where an item currently lives. Items start in the Stuff area, can be
    /// carried into the Bedroom, where they become part of the dollhouse, and can
    /// end up on the character themselves — worn or held.
    ///
    /// The first two are places in the scene; the third is a place on a *body*,
    /// which is why it carries the style rather than a rect. Everything that
    /// asks "which area is this in" therefore has to answer for a third case
    /// that has no area at all.
    private enum ItemLocation: Equatable {
        case stuff
        case room
        case carried(CarryStyle)

        /// How this item is being carried, if it is. The common shorthand, since
        /// most of the scene only cares whether an item is on the character.
        var carryStyle: CarryStyle? {
            if case .carried(let style) = self { return style }
            return nil
        }
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
        setNeedsSave()
        return node
    }

    private func removeItem(id: Int) {
        itemNodes[id]?.removeFromParent()
        itemNodes[id] = nil
        if let index = itemIndex(id: id) {
            items.remove(at: index)
        }
        refreshStuffCount()
        setNeedsSave()
    }

    /// The size one item draws at. Items are dealt out small enough to fit the
    /// shelf and shown larger once they are in the room, which is the point of
    /// carrying one in there. On the character they are sized by the character
    /// instead: a hat is however big that character says a hat is.
    private func baseSize(in location: ItemLocation) -> CGSize {
        switch location {
        case .stuff: return itemBaseSize
        case .room: return roomItemBaseSize
        case .carried(let style):
            // Nearly square, unlike the shelf's wide box: a carry point says how
            // *tall* the thing is on the body, and a 3:2 box would have a Dress
            // placeholder half again as wide as the character wearing it.
            let height = characterHeight * character.carryPoint(for: style).size
            return CGSize(width: height * 1.2, height: height)
        }
    }

    /// How much bigger this item's merge level makes it, where it currently is.
    /// The three places an item can be have three different amounts of room, so
    /// they read the same range of levels at three different strengths.
    private func levelScale(for definition: ItemDefinition, in location: ItemLocation) -> CGFloat {
        switch location {
        case .room:
            // The room has the space to take a level at face value, and showing
            // one off at full size is the point of carrying it in there.
            return definition.scale
        case .stuff:
            // The shelf gives every item the same slot, so the full range does
            // not fit in one: a Crown drawn twice a Bow simply covers whatever is
            // next to it, and the fuller the shelf the worse that gets. Levels
            // are squeezed into the slot instead — still ordered, still legible,
            // never spilling over a neighbour.
            return sqrt(definition.scale / ItemCatalog.maxScale)
        case .carried:
            // The square root again, for the same reason but against a head
            // rather than a slot: a Crown should read as grander than a Bow
            // without being twice the size of the head it is sitting on.
            return sqrt(definition.scale)
        }
    }

    /// The size one item draws at — which is also its box: what a finger can
    /// grab, what the merge ring is drawn around, and what is kept inside the room.
    ///
    /// The nominal box is a fixed 3:2 that knows nothing about the drawing going
    /// in it. Fitting a drawing inside that box would leave its apparent size
    /// decided by its shape — a wide Tiara coming out shorter than a square Bear
    /// of the same level, with most of its box empty either side. So the box is
    /// reshaped to the drawing's own proportions at the same area instead: same
    /// level, same amount of item on screen, whatever shape the item is.
    private func itemSize(for definition: ItemDefinition, in location: ItemLocation) -> CGSize {
        let base = baseSize(in: location)
        let scale = levelScale(for: definition, in: location)
        var size = CGSize(width: base.width * scale, height: base.height * scale)

        // A square for anything not drawn yet, so a placeholder takes up as much
        // room as the drawing that will replace it and swapping one in changes
        // the picture rather than the layout.
        size = shaped(size, toAspect: Artwork.named(definition.imageName)?.aspect ?? 1)

        if location == .stuff {
            // A backstop for artwork far wider or taller than anything here now:
            // reshaping keeps the area right, and this keeps the shape in its slot.
            size = contained(size, in: CGSize(width: itemSlotSize.width * 0.94,
                                              height: itemSlotSize.height * 0.70))
        }
        return size
    }

    /// A box of the same area, reshaped to a drawing's proportions. Two items of
    /// the same level then put the same amount of ink on screen whether they are
    /// wide, tall or square — which fitting them into a shared box does not,
    /// since a wide drawing would only ever touch its sides.
    private func shaped(_ size: CGSize, toAspect aspect: CGFloat) -> CGSize {
        guard aspect > 0, size.width > 0, size.height > 0 else { return size }
        let height = sqrt(size.width * size.height / aspect)
        return CGSize(width: height * aspect, height: height)
    }

    /// The same box shrunk, if it has to be, to fit inside `limit`.
    private func contained(_ size: CGSize, in limit: CGSize) -> CGSize {
        guard limit.width > 0, limit.height > 0, size.width > 0, size.height > 0 else { return size }
        let fit = min(1, min(limit.width / size.width, limit.height / size.height))
        return CGSize(width: size.width * fit, height: size.height * fit)
    }

    private func layoutItems() {
        // Not `itemsNode.removeAllChildren()`: carried items are children of the
        // character, so the nodes have to be dropped by hand wherever they hang.
        for node in itemNodes.values {
            node.removeFromParent()
        }
        itemNodes = [:]
        for item in items {
            addItemNode(for: item)
        }
        refreshItemDepths()
    }

    /// Adds the node for one item under whatever it currently belongs to. A
    /// carried item goes under the character, which is what makes it walk, sit
    /// and lie down with them for free.
    @discardableResult
    private func addItemNode(for item: Item) -> SKNode {
        let node = makeItemNode(for: item)
        itemNodes[item.id] = node
        if item.location.carryStyle == nil {
            itemsNode.addChild(node)
        } else {
            characterNode.addChild(node)
        }
        return node
    }

    /// Draw order follows `items`, so moving an item to the end of the
    /// array is what brings it to the front. A carried item is not in that
    /// running order at all — it draws relative to the character it is on, and
    /// the only question is whether it sits in front of them or behind.
    private func refreshItemDepths() {
        for (index, item) in items.enumerated() {
            guard let node = itemNodes[item.id] else { continue }
            if let style = item.location.carryStyle {
                node.zPosition = character.carryPoint(for: style).inFront
                    ? style.depth : -style.depth
            } else {
                node.zPosition = CGFloat(index)
            }
        }
    }

    private func itemIndex(id: Int) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// An item's box in scene coordinates: where it is now, at the size its
    /// level says it should be. Measured rather than taken from the node so a
    /// name caption hanging below it does not count as part of the item.
    private func itemFrame(for item: Item) -> CGRect? {
        guard let node = itemNodes[item.id] else { return nil }
        // A carried item's position is in the character's space, not the scene's.
        let position = node.parent?.convert(node.position, to: self) ?? node.position
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

    // MARK: - Carrying

    /// The carry point a dropped item would take, if any.
    ///
    /// Two things have to be true: the item has to be a kind of thing that can go
    /// on a body at all, and it has to be dropped across enough of one. An item
    /// with no carry style is simply put down, so a Cake dropped on the character
    /// lands beside them rather than being worn as a hat.
    private func carryTarget(for item: Item) -> CarryStyle? {
        guard let style = item.definition.carry,
              let frame = itemFrame(for: item) else { return nil }

        let body = characterSceneFrame()
        let intersection = frame.intersection(body)
        guard !intersection.isNull else { return nil }

        let overlap = intersection.width * intersection.height
        let smaller = min(frame.width * frame.height, body.width * body.height)
        // The same "a quarter of the smaller of the two" bargain that furniture
        // and merging strike, nudged up: brushing past should not undress anyone.
        guard overlap >= smaller * 0.30 else { return nil }
        return style
    }

    /// What the character has on at this carry point, if anything.
    private func carriedItem(style: CarryStyle) -> Item? {
        items.first { $0.location == .carried(style) }
    }

    /// Puts an item on the character. It becomes a child of them, so it walks,
    /// sits and lies down with them — which is the whole reason carrying is worth
    /// having rather than just parking things nearby.
    private func attach(id: Int, style: CarryStyle) {
        // One thing per carry point: a second Bow replaces the first. The one
        // coming off is put down beside them rather than vanishing, so a swap
        // never loses anything.
        if let displaced = carriedItem(style: style), displaced.id != id {
            let aside = itemSize(for: displaced.definition, in: .room)
            putDown(id: displaced.id,
                    offset: CGPoint(x: -aside.width, y: -characterHeight * 0.25))
        }

        guard let index = itemIndex(id: id) else { return }
        itemNodes[id]?.removeFromParent()
        itemNodes[id] = nil
        items[index].location = .carried(style)
        addItemNode(for: items[index])
        refreshItemDepths()
        refreshStuffCount()
        // Taking an item off the shelf can let it re-split, which rebuilds every
        // node — so the one to animate is looked up after that, not held onto.
        refreshStuffDensity()

        setNeedsSave()

        guard let node = itemNodes[id] else { return }
        node.setScale(0.6)
        node.run(.sequence([.scale(to: 1.14, duration: 0.10),
                            .scale(to: 1.0, duration: 0.08)]))
    }

    /// Takes a carried item off and stands it on the floor of the room, where it
    /// was. `offset` shifts it clear of whatever is replacing it.
    @discardableResult
    private func putDown(id: Int, offset: CGPoint = .zero) -> SKNode? {
        guard let index = itemIndex(id: id),
              items[index].location.carryStyle != nil,
              let node = itemNodes[id] else { return itemNodes[id] }

        let scenePoint = node.parent?.convert(node.position, to: self) ?? node.position
        node.removeFromParent()
        itemNodes[id] = nil

        let size = itemSize(for: items[index].definition, in: .room)
        let resting = clampedItemPosition(CGPoint(x: scenePoint.x + offset.x,
                                                  y: scenePoint.y + offset.y),
                                          size: size, in: .room)
        items[index].location = .room
        items[index].anchor = itemAnchor(for: resting, in: .room)
        let fresh = addItemNode(for: items[index])
        refreshItemDepths()
        refreshStuffCount()
        setNeedsSave()
        return fresh
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
        highlightCharacter(false)
        guard let index = itemIndex(id: id), var node = itemNodes[id] else { return }
        node.removeAllActions()

        // Dropped on the Trash button: this one item goes, and nothing else.
        if isOverTrash(node.position) {
            discardItem(id: id)
            return
        }

        // Dropped on the character: they put it on. This is checked before the
        // room, because the character is standing in the room and dropping a Bow
        // on their head should not just leave it lying on the floor behind them.
        if let style = carryTarget(for: items[index]) {
            attach(id: id, style: style)
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
        // differ only in size. A caption is what makes a pile readable — but a
        // name tag hanging off a hat is clutter, not information.
        if showItemLabels, item.definition.artwork != nil, item.location.carryStyle == nil {
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
        if let artwork = Artwork.named(definition.imageName) {
            let sprite = SKSpriteNode(texture: artwork.texture)
            // `boxSize` was already shaped to this drawing's proportions, so the
            // drawing fills it exactly rather than being fitted somewhere inside it.
            sprite.size = boxSize
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

    /// A carried item has no area of its own — it is somewhere on a body, and
    /// the body is in the room. The room is the right answer for the one thing
    /// this is asked for a carried item: where it lands when it is put down.
    private func rect(for location: ItemLocation) -> CGRect {
        switch location {
        case .stuff: return stuffRect
        case .room, .carried: return roomRect
        }
    }

    private func itemPosition(for item: Item) -> CGPoint {
        // Carried items are children of the character, so their position is in
        // the character's own space: the origin is their feet.
        if let style = item.location.carryStyle {
            let point = character.carryPoint(for: style)
            return CGPoint(x: point.x * characterHeight, y: point.y * characterHeight)
        }

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

    /// Builds the character, sized relative to the room and to whoever you are
    /// currently playing as. The container's position is the character's feet.
    private func layoutCharacter() {
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
        label.text = characterUsing?.characterLabel ?? character.name
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

        if let kind = characterUsing, let piece = piece(for: kind) {
            characterNode.zRotation = kind.characterRotation
            characterNode.position = seatPosition(for: piece)
        } else {
            characterNode.position = clampedCharacterPosition(scenePosition(for: characterAnchor))
        }

        relayoutCarriedItems()
    }

    /// Redraws whatever the character is carrying. Their size and their carry
    /// points both belong to whoever they are, so a resize or a change of
    /// character moves the hat as well as the head.
    private func relayoutCarriedItems() {
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
    private func makeCharacterHighlight() -> SKNode {
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

    private static let characterHighlightName = "carry-highlight"

    private func highlightCharacter(_ on: Bool) {
        characterBodyNode.childNode(withName: Self.characterHighlightName)?.isHidden = !on
    }

    /// The character's own box in scene coordinates: their drawing and name tag,
    /// but not whatever they are carrying — a held Giant Teddy would otherwise
    /// count as part of them and drag the whole figure onto the bed with it.
    private func characterSceneFrame() -> CGRect {
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
    private func makeCharacterArtwork(for definition: CharacterDefinition,
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

        // A sheet covers the scene: while one is open it swallows every touch.
        if isSheetOpen {
            sheetTapped(at: location)
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

        if characterSceneFrame().contains(location) {
            beginCharacterDrag(touch: touch, at: location)
        }
    }

    private func beginCharacterDrag(touch: UITouch, at location: CGPoint) {
        if characterUsing != nil {
            // Stand them up where they are, then let the drag carry on from there.
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
        var node = node
        // Taking something off is just picking it up: it leaves the character,
        // is redrawn at room size and carries on under the finger as a loose item.
        if item.location.carryStyle != nil, let detached = putDown(id: item.id) {
            node = detached
        }

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
            let carry = carryTarget(for: items[index])
            highlightCharacter(carry != nil)
            highlightMergeTarget(carry == nil ? mergeTarget(for: items[index])?.id : nil)
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
        setNeedsSave()
    }

    /// Which usable piece the character is currently over, if any.
    ///
    /// This compares how much of them *overlaps* each piece rather than testing a
    /// single point. The origin is at the feet, so a point test only matched when
    /// grabbed low down — dragging the body onto the bed left the feet
    /// below it and nothing happened.
    private func dropTarget() -> FurnitureKind? {
        let characterFrame = characterSceneFrame()
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

    // MARK: - Sheets

    /// A full-screen sheet over the scene. Both of them answer a question the
    /// prototype keeps raising — what is in this game, and who can I be — so
    /// they share their chrome and differ only in what fills the body.
    private enum Sheet {
        case catalog
        case characters

        var title: String {
            switch self {
            case .catalog: return "Catalog"
            case .characters: return "Characters"
            }
        }

        var hint: String {
            switch self {
            case .catalog: return "every chain, bottom to top — tap an item to deal one out"
            case .characters: return "tap someone to be them — art still to come is named below"
            }
        }
    }

    private var openSheet: Sheet?
    private var isSheetOpen: Bool { openSheet != nil }

    /// Tapping a sheet's own button while it is up puts it away; tapping the
    /// other one swaps straight to it rather than closing first.
    private func toggleSheet(_ sheet: Sheet) {
        if openSheet == sheet {
            closeSheet()
        } else {
            openSheet = sheet
            layoutSheet()
        }
    }

    private func closeSheet() {
        openSheet = nil
        sheetNode.removeAllChildren()
        sheetCells = []
        sheetCloseRect = .zero
        sheetRect = .zero
    }

    /// The dimmed surround, the panel, its heading and its Close button. Whatever
    /// body rect is left over goes to the sheet that is open.
    private func layoutSheet() {
        guard let sheet = openSheet else { return }

        sheetNode.removeAllChildren()
        sheetCells = []

        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = SKColor(white: 0, alpha: 0.62)
        dim.strokeColor = .clear
        sheetNode.addChild(dim)

        sheetRect = CGRect(origin: .zero, size: size)
            .insetBy(dx: size.width * 0.05, dy: size.height * 0.05)
        let panel = SKShapeNode(rect: sheetRect, cornerRadius: sheetRect.height * 0.04)
        panel.fillColor = SKColor(red: 0.16, green: 0.15, blue: 0.20, alpha: 1)
        panel.strokeColor = SKColor(white: 0.42, alpha: 1)
        panel.lineWidth = 3
        sheetNode.addChild(panel)

        let inset = sheetRect.height * 0.05
        let titleSize = max(20, sheetRect.height * 0.065)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = sheet.title
        title.fontSize = titleSize
        title.fontColor = SKColor(white: 0.95, alpha: 1)
        title.verticalAlignmentMode = .top
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: sheetRect.minX + inset, y: sheetRect.maxY - inset)
        sheetNode.addChild(title)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = sheet.hint
        hint.fontSize = titleSize * 0.45
        hint.fontColor = SKColor(white: 0.68, alpha: 1)
        hint.verticalAlignmentMode = .top
        hint.horizontalAlignmentMode = .left
        hint.position = CGPoint(x: sheetRect.minX + inset,
                                y: sheetRect.maxY - inset - titleSize * 1.15)
        sheetNode.addChild(hint)

        sheetCloseRect = CGRect(x: sheetRect.maxX - inset - titleSize * 3.4,
                                y: sheetRect.maxY - inset - titleSize,
                                width: titleSize * 3.4, height: titleSize * 1.3)
        sheetNode.addChild(makeStuffButton(rect: sheetCloseRect, title: "Close", subtitle: nil,
                                           color: SKColor(red: 0.42, green: 0.40, blue: 0.48, alpha: 1)))

        let body = CGRect(x: sheetRect.minX + inset,
                          y: sheetRect.minY + inset,
                          width: sheetRect.width - inset * 2,
                          height: sheetRect.height - inset * 2 - titleSize * 2.1)

        switch sheet {
        case .catalog: layoutCatalogChains(in: body)
        case .characters: layoutCharacterCells(in: body)
        }
    }

    /// Taps while a sheet is up: an entry acts, Close or a tap on the dimmed
    /// surround puts it away, and anything else is swallowed.
    private func sheetTapped(at location: CGPoint) {
        if sheetCloseRect.contains(location) {
            closeSheet()
            return
        }

        if let id = sheetCells.first(where: { $0.rect.contains(location) })?.id {
            switch openSheet {
            case .catalog:
                guard let definition = ItemCatalog.definition(id: id) else { return }
                spawnItem(definition)
            case .characters:
                guard let definition = CharacterCatalog.definition(id: id) else { return }
                becomeCharacter(definition)
            case nil:
                return
            }
            // Rebuilt so the entry shows the tap landed — a count badge on the
            // Catalog, the selection ring on a character.
            layoutSheet()
            return
        }

        if !sheetRect.contains(location) {
            closeSheet()
        }
    }

    // MARK: - Catalog

    /// The Catalog is the answer to "what is actually in this game?": every chain
    /// laid out bottom to top, every drawing that exists, and the filename of every
    /// drawing that does not. Tapping an entry deals one out, so the top of a chain
    /// can be looked at without merging up to it.

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
                sheetNode.addChild(makeCatalogCell(for: definition, in: cell,
                                                     relativeScale: definition.scale / tallest))
                sheetCells.append((cell, definition.id))

                if column < chain.count - 1 {
                    let arrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
                    arrow.text = "\u{2192}"
                    arrow.fontSize = max(14, rowHeight * 0.22)
                    arrow.fontColor = SKColor(white: 0.60, alpha: 1)
                    arrow.verticalAlignmentMode = .center
                    arrow.horizontalAlignmentMode = .center
                    arrow.position = CGPoint(x: slot.maxX, y: cell.midY + rowHeight * 0.06)
                    sheetNode.addChild(arrow)
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

        if let artwork = Artwork.named(definition.imageName) {
            let sprite = SKSpriteNode(texture: artwork.texture)
            // Shaped to the drawing and then held inside the cell, the same
            // bargain the shelf strikes — so a row of a chain grows by its levels
            // rather than by how tightly each drawing happens to be cropped.
            sprite.size = contained(shaped(artBox, toAspect: artwork.aspect),
                                    in: CGSize(width: cell.width * 0.80,
                                               height: cell.height * 0.56))
            sprite.position = artCentre
            node.addChild(sprite)
        } else {
            let box = SKShapeNode(rect: CGRect(x: artCentre.x - artBox.width / 2,
                                               y: artCentre.y - artBox.height / 2,
                                               width: artBox.width, height: artBox.height),
                                  cornerRadius: artBox.height * 0.18)
            box.fillColor = definition.placeholderColor.withAlphaComponent(0.55)
            box.strokeColor = Self.sheetMissingArt
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
            note.fontColor = Self.sheetMissingArt
        } else {
            // Both halves of what an item is: where it goes on a character, and
            // where it goes in its chain.
            var parts: [String] = []
            if let carry = definition.carry { parts.append(carry.note) }
            parts.append(definition.mergesInto == nil ? "top of the chain" : "merges in pairs")
            note.text = parts.joined(separator: " · ")
            note.fontColor = SKColor(white: 0.55, alpha: 1)
        }
        shrinkToFit(note, width: cell.width * 0.92)
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

    private static let sheetMissingArt = SKColor(red: 1.0, green: 0.68, blue: 0.30, alpha: 1)

    /// Shrinks a label until it fits its cell. A filename like
    /// `Basic_human_drawing.png` is far longer than the name above it, and a note
    /// that runs into its neighbours is worse than a small one.
    private func shrinkToFit(_ label: SKLabelNode, width: CGFloat) {
        guard label.frame.width > width, label.frame.width > 0 else { return }
        label.fontSize = max(7, label.fontSize * width / label.frame.width)
    }

    // MARK: - Character picker

    /// Who you can be. The same bargain as the Catalog: everyone is listed
    /// whether or not they have been drawn yet, and picking one that has no
    /// artwork puts their stick figure in the room rather than nothing at all.

    /// A grid of everyone in the catalog, the current one ringed.
    private func layoutCharacterCells(in body: CGRect) {
        let everyone = CharacterCatalog.all
        guard !everyone.isEmpty else { return }

        let columns = min(3, everyone.count)
        let rows = Int(ceil(Double(everyone.count) / Double(columns)))
        let cellWidth = body.width / CGFloat(columns)
        let cellHeight = body.height / CGFloat(rows)
        let tallest = everyone.map { $0.scale }.max() ?? 1

        for (index, definition) in everyone.enumerated() {
            let slot = CGRect(x: body.minX + CGFloat(index % columns) * cellWidth,
                              y: body.maxY - CGFloat(index / columns + 1) * cellHeight,
                              width: cellWidth, height: cellHeight)
            let cell = slot.insetBy(dx: cellWidth * 0.07, dy: cellHeight * 0.08)
            sheetNode.addChild(makeCharacterCell(for: definition, in: cell,
                                                 relativeScale: definition.scale / tallest))
            sheetCells.append((cell, definition.id))
        }
    }

    /// One entry: the figure you would actually get, their name, and — when there
    /// is no drawing yet — the filename that would give them one.
    private func makeCharacterCell(for definition: CharacterDefinition, in cell: CGRect,
                                   relativeScale: CGFloat) -> SKNode {
        let node = SKNode()
        let isCurrent = definition.id == character.id

        let background = SKShapeNode(rect: cell, cornerRadius: cell.height * 0.10)
        background.fillColor = SKColor(white: 1, alpha: isCurrent ? 0.14 : 0.06)
        background.strokeColor = isCurrent
            ? Self.characterSelectedStroke
            : SKColor(white: 1, alpha: 0.14)
        background.lineWidth = isCurrent ? 5 : 2
        node.addChild(background)

        let nameSize = max(11, cell.height * 0.11)
        // Taller characters draw taller here too, so the sizes can be compared
        // before committing to one.
        let figure = makeCharacterArtwork(for: definition,
                                          height: cell.height * 0.52 * (0.55 + 0.45 * relativeScale))
        figure.position = CGPoint(x: cell.midX, y: cell.minY + cell.height * 0.34)
        node.addChild(figure)

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.text = definition.name
        name.fontSize = nameSize
        name.fontColor = SKColor(white: 0.95, alpha: 1)
        name.verticalAlignmentMode = .center
        name.horizontalAlignmentMode = .center
        name.position = CGPoint(x: cell.midX, y: cell.minY + cell.height * 0.20)
        shrinkToFit(name, width: cell.width * 0.92)
        node.addChild(name)

        // Only the missing art gets a caption. A drawn character needs no note:
        // the heading already says a tap picks one, and the ring says which is on.
        if definition.artwork == nil {
            let note = SKLabelNode(fontNamed: "AvenirNext-Medium")
            note.text = definition.missingArtworkNote
            note.fontSize = nameSize * 0.78
            note.fontColor = Self.sheetMissingArt
            note.verticalAlignmentMode = .center
            note.horizontalAlignmentMode = .center
            note.position = CGPoint(x: cell.midX, y: cell.minY + cell.height * 0.09)
            shrinkToFit(note, width: cell.width * 0.92)
            node.addChild(note)
        }

        if isCurrent {
            let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
            badge.text = "playing"
            badge.fontSize = nameSize * 0.8
            badge.fontColor = Self.characterSelectedStroke
            badge.verticalAlignmentMode = .top
            badge.horizontalAlignmentMode = .right
            badge.position = CGPoint(x: cell.maxX - cell.width * 0.06,
                                     y: cell.maxY - cell.height * 0.06)
            node.addChild(badge)
        }

        return node
    }

    private static let characterSelectedStroke =
        SKColor(red: 1.0, green: 0.86, blue: 0.42, alpha: 1)

    /// Switches who you are playing as, keeping where they were standing and
    /// whatever they were using — you are swapping the drawing, not restarting.
    private func becomeCharacter(_ definition: CharacterDefinition) {
        guard definition.id != character.id else { return }
        character = definition
        layoutCharacter()
        characterNode.removeAllActions()
        characterNode.setScale(1)
        characterNode.run(.sequence([.scale(to: 1.12, duration: 0.10),
                                     .scale(to: 1.0, duration: 0.12)]))
        setNeedsSave()
    }

    /// On release, snap the character onto whichever piece they were dropped on.
    /// Otherwise they simply stay where they were put.
    private func settleCharacter() {
        highlightFurniture(nil)
        guard let kind = dropTarget() else { return }
        characterUsing = kind
        layoutCharacter()
    }

    // MARK: - Saving

    /// Writing is deferred rather than done inline: dropping an item touches the
    /// model several times over, and a drag would otherwise write on every frame.
    /// Anything that changes what the child has made just says so, and `update`
    /// writes it out at most once a second.
    private var needsSave = false
    private var lastSaveTime: TimeInterval = 0

    private func setNeedsSave() {
        needsSave = true
    }

    override func update(_ currentTime: TimeInterval) {
        guard needsSave, currentTime - lastSaveTime >= 1 else { return }
        lastSaveTime = currentTime
        flushSave()
    }

    /// Writes immediately, whatever the timer says. Called when the app is about
    /// to go away, which is exactly the moment the deferred write cannot wait.
    @objc private func flushSave() {
        guard needsSave else { return }
        needsSave = false
        SaveStore.save(snapshot())
    }

    private func snapshot() -> SavedGame {
        let saved = items.map { item -> SavedItem in
            switch item.location {
            case .stuff:
                return SavedItem(item: item.definition.id, place: "stuff", carry: nil,
                                 x: Double(item.anchor.x), y: Double(item.anchor.y))
            case .room:
                return SavedItem(item: item.definition.id, place: "room", carry: nil,
                                 x: Double(item.anchor.x), y: Double(item.anchor.y))
            case .carried(let style):
                return SavedItem(item: item.definition.id, place: "carried",
                                 carry: style.rawValue, x: 0, y: 0)
            }
        }
        return SavedGame(version: SavedGame.currentVersion,
                         items: saved,
                         character: character.id,
                         characterX: Double(characterAnchor.x),
                         characterY: Double(characterAnchor.y),
                         characterUsing: characterUsing?.rawValue)
    }

    /// Rebuilds the model from the save, if there is one.
    ///
    /// Everything here is written to survive a catalog that has been edited since
    /// the file was written, because a catalog that can be edited freely is the
    /// whole point of this prototype. An item id that no longer exists is dropped
    /// and the rest is kept; a character or a piece of furniture that has gone
    /// falls back rather than throwing the save away.
    private func restoreSavedGame() {
        guard let saved = SaveStore.load() else { return }

        for entry in saved.items {
            guard let definition = ItemCatalog.definition(id: entry.item),
                  let restored = restored(entry, definition: definition) else { continue }
            items.append(Item(id: nextItemID, definition: definition,
                              location: restored.location, anchor: restored.anchor))
            nextItemID += 1
        }

        if let id = saved.character, let definition = CharacterCatalog.definition(id: id) {
            character = definition
        }
        characterAnchor = CGPoint(x: saved.characterX, y: saved.characterY)
        if let raw = saved.characterUsing, let kind = FurnitureKind(rawValue: raw),
           kind.characterLabel != nil {
            characterUsing = kind
        }
    }

    /// Where one saved entry goes now. A carried item stores no position of its
    /// own — its place comes from the character's carry point — so one that can
    /// no longer be carried needs an anchor inventing for it, and the middle of
    /// the floor is somewhere it will actually be seen.
    private func restored(_ entry: SavedItem,
                          definition: ItemDefinition) -> (location: ItemLocation, anchor: CGPoint)? {
        let anchor = CGPoint(x: entry.x, y: entry.y)
        switch entry.place {
        case "stuff": return (.stuff, anchor)
        case "room": return (.room, anchor)
        case "carried":
            // A carry style that no longer exists, or an item that is no longer
            // the kind of thing you can wear, is put down rather than dropped.
            guard let raw = entry.carry, let style = CarryStyle(rawValue: raw),
                  definition.carry == style else {
                return (.room, CGPoint(x: 0.5, y: 0.2))
            }
            return (.carried(style), anchor)
        default: return nil
        }
    }
}

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
