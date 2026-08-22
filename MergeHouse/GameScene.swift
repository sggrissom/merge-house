import SpriteKit
import UIKit

/// The whole play area: whichever room you are in on top, the Stuff area below.
/// Drawn from shapes and labels, with artwork swapped in wherever it exists.
final class GameScene: SKScene {

    // MARK: - Furniture in this room

    /// One piece of furniture, placed. The catalog says what it is and the room
    /// says whereabouts in itself it stands; this is that worked out against the
    /// room's actual rect, which is the only form the scene ever needs.
    struct FurniturePiece {
        /// Unique within the room, so two chairs are two different seats.
        let id: String
        let definition: FurnitureDefinition
        let rect: CGRect
    }

    // MARK: - Nodes and state

    /// Room chrome (backdrop, outline, title). Rebuilt whenever the scene resizes
    /// and whenever you go to another room.
    let roomNode = SKNode()
    /// This room's furniture. Rebuilt whenever the scene resizes and whenever you
    /// go to another room.
    let furnitureNode = SKNode()
    /// The character. A persistent container so it keeps its own state across
    /// resizes — and so carried items have something to be children of.
    let characterNode = SKNode()
    /// The character's own drawing and name tag, rebuilt on every layout.
    /// Held apart from `characterNode` so that whatever they are carrying — which
    /// lives alongside it — is not wiped out every time they are redrawn.
    let characterBodyNode = SKNode()
    /// The Stuff area panel and its button. Rebuilt whenever the scene resizes.
    let stuffNode = SKNode()
    /// The loose items, in the Stuff area or placed in the room. They draw above
    /// the Stuff panel, so this layer sits on top of everything else.
    let itemsNode = SKNode()

    /// The playable area of the room in scene coordinates.
    var roomRect: CGRect = .zero
    /// The Stuff area below the room, where mergeable items will live.
    var stuffRect: CGRect = .zero
    var furniturePieces: [FurniturePiece] = []
    var furnitureBoxes: [String: SKNode] = [:]

    /// Every tool button in the Stuff panel, with the rect it answers taps in.
    var toolButtons: [(tool: StuffTool, node: SKNode, rect: CGRect)] = []
    /// Whether loose items caption themselves. On by default: while the art is
    /// still going in, telling a Bow from a Fancy Bow by shape alone is a guess.
    var showItemLabels = true
    /// Reads out how much is loose, so a shelf with more on it than fits still
    /// says how much that is.
    var stuffCountLabel: SKLabelNode?
    /// The size that readout wants to be. Held so it can be shrunk to fit a long
    /// tally and then grow back again, rather than only ever getting smaller.
    var stuffCountFontSize: CGFloat = 0
    /// Number of rows currently used by the Stuff shelf.
    var stuffRows = GameScene.minStuffRows
    /// The open sheet — the Catalog, the character picker or the room picker.
    /// Empty while closed.
    let sheetNode = SKNode()
    var openSheet: Sheet?
    /// Where each entry in the open sheet sits, so a tap can act on it. What the
    /// id means is the open sheet's business: an item to deal out, a character to
    /// become, or a room to go to.
    var sheetCells: [(rect: CGRect, id: String)] = []
    var sheetRect: CGRect = .zero
    var sheetCloseRect: CGRect = .zero

    /// Every item that exists, back to front: the last one draws on top and is
    /// the first to be picked up.
    var items: [Item] = []
    /// The node showing each item, keyed by item id.
    var itemNodes: [Int: SKNode] = [:]
    var nextItemID = 0
    /// The part of the Stuff area new items are dealt into: clear of the title and button.
    var stuffSpawnRect: CGRect = .zero
    /// Placeholder size for one item, scaled to the current Stuff area.
    var itemBaseSize: CGSize = .zero
    /// One cell of the Stuff shelf: an item plus the room its name tag needs.
    var itemSlotSize: CGSize = .zero
    /// Base size for an item on display in the room. Held apart from the shelf's
    /// size so that filling the shelf up does not shrink the dollhouse.
    var roomItemBaseSize: CGSize = .zero

    /// Where the character stands, as a fraction of `roomRect`, so a resize or
    /// rotation keeps it in the same relative spot instead of resetting it.
    var characterAnchor = CGPoint(x: 0.5, y: 0.10)
    /// The id of the piece the character is currently using, if any. While it
    /// names a piece of the room you are in, their position comes from that
    /// piece rather than from `characterAnchor`.
    var characterUsing: String?

    /// The piece that id actually refers to, if the room you are in has one. A
    /// piece that is not in this room simply leaves the character standing —
    /// which is what makes walking out of a room you were sitting down in safe.
    var usingPiece: FurniturePiece? {
        guard let id = characterUsing else { return nil }
        return piece(for: id)
    }

    /// The character's bounds relative to its own origin (its feet), used for clamping.
    var characterLocalFrame: CGRect = .zero
    /// Who you are playing as. Everything about how the character draws comes
    /// from here, so switching is this one assignment plus a relayout.
    var character = CharacterCatalog.starting
    /// Which room you are in. Everything about how the room draws and what is in
    /// it comes from here, so going next door is this one assignment plus a
    /// relayout — the same bargain switching character strikes.
    var room = RoomCatalog.starting
    /// How tall the character currently draws. Carry points are fractions of
    /// this, so it is the one number that turns a `CarryPoint` into a position.
    var characterHeight: CGFloat = 0

    /// What the current drag is moving.
    enum DragSubject {
        case character
        case item(id: Int)
    }

    var dragTouch: UITouch?
    var dragSubject: DragSubject?
    var dragOffset: CGPoint = .zero

    /// Save writes are coalesced by the frame update loop.
    var needsSave = false
    var lastSaveTime: TimeInterval = 0

    // MARK: - Setup

    /// Which save this is. Held for the whole life of the scene: it is both the
    /// file that was read on the way in and the one every write on the way out
    /// goes to, so there is no moment where the game being played and the game
    /// being written are different games.
    let slot: SaveSlot

    init(size: CGSize, slot: SaveSlot) {
        self.slot = slot
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

    var hasRestored = false

    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
        flushSave()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    /// Rebuilds everything for the current scene size. Called again on rotation/resize.
    func layoutScene() {
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
}
