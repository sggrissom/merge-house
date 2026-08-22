import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Stuff area

    /// The explore-mode toolbar. These exist to make the prototype easy to poke
    /// at — spawn things, see what merges into what, and clear the decks again —
    /// not because a finished game would have any of them.
    enum StuffTool: String, CaseIterable {
        case getStuff = "Get Stuff"
        case catalog = "Catalog"
        case characters = "Characters"
        case rooms = "Rooms"
        case tidy = "Tidy Up"
        case mergeAll = "Merge All"
        case labels = "Labels"
        case trash = "Trash"
        /// The one button here a child's parent uses rather than a developer,
        /// which is why it is the odd one out in a toolbar of explore tools. It
        /// stays put when the rest of them are eventually folded away.
        case sound = "Sound"

        /// A second line of small print, where the button needs one.
        var subtitle: String? {
            switch self {
            case .catalog: return "see everything"
            case .characters: return "pick who you are"
            case .rooms: return "go somewhere else"
            case .trash: return "drop one, or tap to clear"
            case .sound: return "quiet at bedtime"
            default: return nil
            }
        }

        var color: SKColor {
            switch self {
            case .getStuff: return SKColor(red: 0.35, green: 0.55, blue: 0.92, alpha: 1)
            case .catalog: return SKColor(red: 0.45, green: 0.40, blue: 0.78, alpha: 1)
            case .characters: return SKColor(red: 0.78, green: 0.40, blue: 0.58, alpha: 1)
            case .rooms: return SKColor(red: 0.34, green: 0.52, blue: 0.72, alpha: 1)
            case .tidy: return SKColor(red: 0.28, green: 0.60, blue: 0.55, alpha: 1)
            case .mergeAll: return SKColor(red: 0.80, green: 0.58, blue: 0.24, alpha: 1)
            case .labels: return SKColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1)
            case .trash: return SKColor(red: 0.72, green: 0.32, blue: 0.34, alpha: 1)
            case .sound: return SKColor(red: 0.36, green: 0.64, blue: 0.42, alpha: 1)
            }
        }
    }

    static let toolColumns = 2

    func layoutStuff() {
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
    static let minStuffRows = 2
    static let maxStuffRows = 3

    func slotSize(rows: Int) -> CGSize {
        let slotHeight = stuffSpawnRect.height / CGFloat(max(1, rows))
        let itemHeight = slotHeight * 0.62
        return CGSize(width: itemHeight * 1.5 * 1.18, height: slotHeight)
    }

    /// How many items fit on a shelf of this many rows.
    func shelfCapacity(rows: Int) -> Int {
        let slot = slotSize(rows: rows)
        guard slot.width > 0 else { return 0 }
        return max(1, Int(stuffSpawnRect.width / slot.width)) * rows
    }

    /// Re-splits the shelf if what is on it no longer fits the current rows.
    /// Called whenever the loose items change, which is what keeps Get Stuff from
    /// ever burying anything.
    func refreshStuffDensity() {
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
    func stuffSlots() -> [CGPoint] {
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
    func layoutTools(inset: CGFloat) {
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
        refreshSoundButton()
    }

    /// The left edge of the toolbar, which items keep clear of.
    var buttonColumnMinX: CGFloat {
        toolButtons.reduce(stuffRect.maxX) { min($0, $1.rect.minX) }
    }

    func button(for tool: StuffTool) -> (node: SKNode, rect: CGRect)? {
        guard let match = toolButtons.first(where: { $0.tool == tool }) else { return nil }
        return (match.node, match.rect)
    }

    static let buttonBackgroundName = "button-background"
    /// Named because one button's title is its state: Sound reads "Muted" when
    /// it is, which beats a dimmed rectangle you have to remember the meaning of.
    static let buttonTitleName = "button-title"

    /// Built around its own centre so it can scale when pressed.
    func makeStuffButton(rect: CGRect, title: String,
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

        let titleSize = max(13, rect.height * 0.34)
        let captionSize = max(8, rect.height * 0.19)
        // Two lines only where two lines fit. Both sizes have a floor they will
        // not go below, so on a short button they stop shrinking with it and
        // start printing through each other instead. The small print is the half
        // worth losing: the name of the button is the part you need. Nine tools
        // in two columns is what brought this within reach, and splitting the
        // toolbar in two is the real answer to that — see plan #14.
        let smallPrint = rect.height >= (titleSize + captionSize) * 1.3 ? subtitle : nil

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = Self.buttonTitleName
        label.text = title
        label.fontSize = titleSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: smallPrint == nil ? 0 : rect.height * 0.12)
        node.addChild(label)

        if let smallPrint = smallPrint {
            let caption = SKLabelNode(fontNamed: "AvenirNext-Medium")
            caption.text = smallPrint
            caption.fontSize = captionSize
            caption.fontColor = SKColor(white: 1, alpha: 0.75)
            caption.verticalAlignmentMode = .center
            caption.horizontalAlignmentMode = .center
            caption.position = CGPoint(x: 0, y: -rect.height * 0.20)
            node.addChild(caption)
        }

        return node
    }

    func pressButton(_ button: SKNode?) {
        guard let button = button else { return }
        button.removeAllActions()
        button.setScale(1)
        button.run(.sequence([.scale(to: 0.92, duration: 0.06),
                              .scale(to: 1.0, duration: 0.09)]))
    }

    func refreshStuffCount() {
        let onShelf = items.filter { $0.location == .stuff }.count
        let carried = items.filter { $0.location.carryStyle != nil }.count
        let inRoom = items.filter { $0.location == .room && $0.room == room.id }.count
        // What is in the rooms you are not in has to be counted too, or the tally
        // would say things had gone missing every time you walked out of one.
        let elsewhere = items.count - onShelf - carried - inRoom
        var text = onShelf == 1 ? "1 item" : "\(onShelf) items"
        if inRoom > 0 {
            text += " · \(inRoom) in the \(room.name.lowercased())"
        }
        if elsewhere > 0 {
            text += " · \(elsewhere) in other rooms"
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

    func toolTapped(_ tool: StuffTool) {
        pressButton(button(for: tool)?.node)
        switch tool {
        case .getStuff: spawnItem()
        case .catalog: toggleSheet(.catalog)
        case .characters: toggleSheet(.characters)
        case .rooms: toggleSheet(.rooms)
        case .tidy: tidyStuff()
        case .mergeAll: mergeEverything()
        case .labels: toggleItemLabels()
        case .trash: clearStuffTapped()
        case .sound: toggleSound()
        }
        setNeedsSave()
    }

    /// The Labels button says what it will do next, so its state is readable
    /// without hunting for a caption somewhere else.
    func refreshLabelsButton() {
        guard let node = button(for: .labels)?.node,
              let background = node.childNode(withName: Self.buttonBackgroundName) as? SKShapeNode
        else { return }
        background.fillColor = showItemLabels
            ? StuffTool.labels.color
            : SKColor(white: 0.24, alpha: 1)
    }

    func toggleItemLabels() {
        showItemLabels.toggle()
        refreshLabelsButton()
        layoutItems()
    }

    /// Says what it is rather than what it will do, unlike Labels: a button
    /// reading "Muted" is a state a parent can read across a dark bedroom.
    func refreshSoundButton() {
        guard let node = button(for: .sound)?.node else { return }
        let background = node.childNode(withName: Self.buttonBackgroundName) as? SKShapeNode
        background?.fillColor = Sounds.isMuted
            ? SKColor(white: 0.24, alpha: 1)
            : StuffTool.sound.color
        let title = node.childNode(withName: Self.buttonTitleName) as? SKLabelNode
        title?.text = Sounds.isMuted ? "Muted" : "Sound"
    }

    /// Muting is not part of the save. It belongs to the device and the hour of
    /// the evening rather than to the game being played — see `Sounds.isMuted`.
    func toggleSound() {
        Sounds.isMuted.toggle()
        refreshSoundButton()
        // Turning it back on says so out loud. A silent button is exactly what
        // the muted one is supposed to look like, so the unmuted one has to be
        // audibly different — and while there are no files yet, this is the one
        // place the silence is deliberate rather than merely missing.
        playSound(.pickUp)
    }

    /// Wipes every loose item, in the Stuff area and in the room alike.
    /// Any drag in progress is dropped with it, since its item is gone.
    func clearStuffTapped() {
        guard !items.isEmpty else { return }

        if case .item = dragSubject {
            dragTouch = nil
            dragSubject = nil
        }
        highlightMergeTarget(nil)
        highlightTrash(false)
        highlightCharacter(false)
        // One crumple for the lot: emptying a shelf of twenty is one action, and
        // twenty of them at once is a noise rather than twenty noises.
        playSound(.trash)

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
    func refreshStuffDensityAfterPoof() {
        run(.sequence([.wait(forDuration: 0.16),
                       .run { [weak self] in self?.refreshStuffDensity() }]))
    }

    // MARK: - Explore tools

    /// Lays every loose item in the Stuff area out on a grid, in catalog order,
    /// so a pile that has been shoved around becomes a readable shelf again.
    /// Items carried into the room are left where they are; they are on display.
    func tidyStuff() {
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
    func mergeEverything() {
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
    func nextMergeablePair() -> (Item, Item)? {
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
    func discardItem(id: Int) {
        guard let node = itemNodes[id] else { return }
        playSound(.trash, voice: itemIndex(id: id).flatMap { items[$0].definition.sound })
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
    func isOverTrash(_ position: CGPoint) -> Bool {
        guard let trash = button(for: .trash) else { return false }
        return trash.rect.contains(position)
    }

    func highlightTrash(_ on: Bool) {
        guard let trash = button(for: .trash),
              let background = trash.node.childNode(withName: Self.buttonBackgroundName)
                as? SKShapeNode else { return }
        background.strokeColor = on ? Self.itemMergeStroke : SKColor(white: 0.9, alpha: 0.8)
        background.lineWidth = on ? 5 : 2
    }
}
