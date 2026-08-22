import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Sheets

    /// A full-screen sheet over the scene. All of them answer a question the
    /// prototype keeps raising — what is in this game, who can I be, where can I
    /// go — so they share their chrome and differ only in what fills the body.
    enum Sheet {
        case catalog
        case characters
        case rooms

        var title: String {
            switch self {
            case .catalog: return "Catalog"
            case .characters: return "Characters"
            case .rooms: return "Rooms"
            }
        }

        var hint: String {
            switch self {
            case .catalog: return "every chain, bottom to top — tap an item to deal one out"
            case .characters: return "tap someone to be them — art still to come is named below"
            case .rooms: return "tap a room to go there — what you left in one stays there"
            }
        }
    }

    var isSheetOpen: Bool { openSheet != nil }

    /// Tapping a sheet's own button while it is up puts it away; tapping the
    /// other one swaps straight to it rather than closing first.
    func toggleSheet(_ sheet: Sheet) {
        if openSheet == sheet {
            closeSheet()
        } else {
            openSheet = sheet
            layoutSheet()
        }
    }

    func closeSheet() {
        openSheet = nil
        sheetNode.removeAllChildren()
        sheetCells = []
        sheetCloseRect = .zero
        sheetRect = .zero
    }

    /// The dimmed surround, the panel, its heading and its Close button. Whatever
    /// body rect is left over goes to the sheet that is open.
    func layoutSheet() {
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
        case .rooms: layoutRoomCells(in: body)
        }
    }

    /// Taps while a sheet is up: an entry acts, Close or a tap on the dimmed
    /// surround puts it away, and anything else is swallowed.
    func sheetTapped(at location: CGPoint) {
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
            case .rooms:
                guard let definition = RoomCatalog.definition(id: id) else { return }
                goToRoom(definition)
            case nil:
                return
            }
            // Rebuilt so the entry shows the tap landed — a count badge on the
            // Catalog, the selection ring on a character or a room.
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
    func layoutCatalogChains(in body: CGRect) {
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
    func makeCatalogCell(for definition: ItemDefinition, in cell: CGRect,
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

    static let sheetMissingArt = SKColor(red: 1.0, green: 0.68, blue: 0.30, alpha: 1)

    /// Shrinks a label until it fits its cell. A filename like
    /// `Basic_human_drawing.png` is far longer than the name above it, and a note
    /// that runs into its neighbours is worse than a small one.
    func shrinkToFit(_ label: SKLabelNode, width: CGFloat) {
        guard label.frame.width > width, label.frame.width > 0 else { return }
        label.fontSize = max(7, label.fontSize * width / label.frame.width)
    }

    // MARK: - Character picker

    /// Who you can be. The same bargain as the Catalog: everyone is listed
    /// whether or not they have been drawn yet, and picking one that has no
    /// artwork puts their stick figure in the room rather than nothing at all.

    /// A grid of everyone in the catalog, the current one ringed.
    func layoutCharacterCells(in body: CGRect) {
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
    func makeCharacterCell(for definition: CharacterDefinition, in cell: CGRect,
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

    static let characterSelectedStroke =
        SKColor(red: 1.0, green: 0.86, blue: 0.42, alpha: 1)

    // MARK: - Room picker

    /// Where you can go. The same bargain again: every room is listed whether or
    /// not it has been drawn, and going to one that has not puts you in its flat
    /// wall and floor rather than nowhere at all.

    /// A grid of every room, the one you are in ringed.
    func layoutRoomCells(in body: CGRect) {
        let rooms = RoomCatalog.all
        guard !rooms.isEmpty else { return }

        let columns = min(3, rooms.count)
        let rows = Int(ceil(Double(rooms.count) / Double(columns)))
        let cellWidth = body.width / CGFloat(columns)
        let cellHeight = body.height / CGFloat(rows)

        for (index, definition) in rooms.enumerated() {
            let slot = CGRect(x: body.minX + CGFloat(index % columns) * cellWidth,
                              y: body.maxY - CGFloat(index / columns + 1) * cellHeight,
                              width: cellWidth, height: cellHeight)
            let cell = slot.insetBy(dx: cellWidth * 0.07, dy: cellHeight * 0.08)
            sheetNode.addChild(makeRoomCell(for: definition, in: cell))
            sheetCells.append((cell, definition.id))
        }
    }

    /// One entry: the room as you would actually find it — its backdrop or the
    /// colours standing in for one — what is in it, and how much you have left
    /// there.
    func makeRoomCell(for definition: RoomDefinition, in cell: CGRect) -> SKNode {
        let node = SKNode()
        let isCurrent = definition.id == room.id

        let background = SKShapeNode(rect: cell, cornerRadius: cell.height * 0.10)
        background.fillColor = SKColor(white: 1, alpha: isCurrent ? 0.14 : 0.06)
        background.strokeColor = isCurrent
            ? Self.characterSelectedStroke
            : SKColor(white: 1, alpha: 0.14)
        background.lineWidth = isCurrent ? 5 : 2
        node.addChild(background)

        let nameSize = max(11, cell.height * 0.11)
        let preview = CGRect(x: cell.minX + cell.width * 0.08,
                             y: cell.minY + cell.height * 0.30,
                             width: cell.width * 0.84,
                             height: cell.height * 0.56)
        // The room's own backdrop, cropped to the preview exactly the way it is
        // cropped to the room — so what is shown here is what you will walk into.
        if let backdrop = makeBackdrop(named: definition.imageName, in: preview) {
            node.addChild(backdrop)
        } else {
            node.addChild(makePlaceholderRoom(for: definition, in: preview))
        }

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.text = definition.name
        name.fontSize = nameSize
        name.fontColor = SKColor(white: 0.95, alpha: 1)
        name.verticalAlignmentMode = .center
        name.horizontalAlignmentMode = .center
        name.position = CGPoint(x: cell.midX, y: cell.minY + cell.height * 0.20)
        shrinkToFit(name, width: cell.width * 0.92)
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
            // What is in there, which is the other half of what makes one room
            // different from the next.
            note.text = definition.pieces.map { $0.definition.name.lowercased() }
                .joined(separator: " · ")
            note.fontColor = SKColor(white: 0.55, alpha: 1)
        }
        shrinkToFit(note, width: cell.width * 0.92)
        node.addChild(note)

        let left = items.filter { $0.location == .room && $0.room == definition.id }.count
        if left > 0 {
            let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
            badge.text = "\u{00D7}\(left)"
            badge.fontSize = nameSize
            badge.fontColor = SKColor(red: 1.0, green: 0.86, blue: 0.42, alpha: 1)
            badge.verticalAlignmentMode = .top
            badge.horizontalAlignmentMode = .left
            badge.position = CGPoint(x: cell.minX + cell.width * 0.06,
                                     y: cell.maxY - cell.height * 0.06)
            node.addChild(badge)
        }

        if isCurrent {
            let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
            badge.text = "here"
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

    // MARK: - Becoming someone

    /// Switches who you are playing as, keeping where they were standing and
    /// whatever they were using — you are swapping the drawing, not restarting.
    func becomeCharacter(_ definition: CharacterDefinition) {
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
    func settleCharacter() {
        highlightFurniture(nil)
        guard let id = dropTarget() else { return }
        characterUsing = id
        layoutCharacter()
    }
}
