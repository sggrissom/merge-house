import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Items

    /// Where an item currently lives. Items start in the Stuff area, can be
    /// carried into whichever room you are in, where they become part of the
    /// dollhouse, and can end up on the character themselves — worn or held.
    ///
    /// The first two are places in the scene; the third is a place on a *body*,
    /// which is why it carries the style rather than a rect. Everything that
    /// asks "which area is this in" therefore has to answer for a third case
    /// that has no area at all.
    enum ItemLocation: Equatable {
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
    struct Item {
        let id: Int
        let definition: ItemDefinition
        var location: ItemLocation
        var anchor: CGPoint
        /// Which room it was left in, for an item that is in one. `.room` says an
        /// item is standing in a room; this says which room that was, so what you
        /// arranged in the Bedroom is still in the Bedroom after a trip to the
        /// Kitchen. `nil` for anything on the shelf or on the character — those
        /// come with you.
        var room: String?
    }

    /// Whether an item is somewhere you can see it from where you are standing.
    /// The shelf and the character are always with you; a room is only in front
    /// of you while you are in it.
    func isHere(_ item: Item) -> Bool {
        item.location != .room || item.room == room.id
    }

    /// Moves one item, remembering which room it landed in when it landed in one.
    /// Every move goes through here, so nothing can end up standing in a room
    /// that cannot say which room that is.
    func place(_ index: Int, in location: ItemLocation, anchor: CGPoint) {
        items[index].location = location
        items[index].anchor = anchor
        items[index].room = location == .room ? room.id : nil
    }

    /// Drops one item into the Stuff area. `Get Stuff` deals a random starter;
    /// the Catalog hands in whichever entry was tapped, so anything in the game
    /// can be looked at without merging up to it first.
    @discardableResult
    func spawnItem(_ definition: ItemDefinition = ItemCatalog.randomStarter()) -> SKNode {
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
    /// Anything put straight into a room lands in the one you are in.
    @discardableResult
    func addItem(definition: ItemDefinition, location: ItemLocation,
                         anchor: CGPoint) -> SKNode {
        let item = Item(id: nextItemID, definition: definition,
                        location: location, anchor: anchor,
                        room: location == .room ? room.id : nil)
        nextItemID += 1
        items.append(item)
        let node = addItemNode(for: item)
        refreshItemDepths()
        refreshStuffCount()
        setNeedsSave()
        return node
    }

    func removeItem(id: Int) {
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
    func baseSize(in location: ItemLocation) -> CGSize {
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
    func levelScale(for definition: ItemDefinition, in location: ItemLocation) -> CGFloat {
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
    func itemSize(for definition: ItemDefinition, in location: ItemLocation) -> CGSize {
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
    func shaped(_ size: CGSize, toAspect aspect: CGFloat) -> CGSize {
        guard aspect > 0, size.width > 0, size.height > 0 else { return size }
        let height = sqrt(size.width * size.height / aspect)
        return CGSize(width: height * aspect, height: height)
    }

    /// The same box shrunk, if it has to be, to fit inside `limit`.
    func contained(_ size: CGSize, in limit: CGSize) -> CGSize {
        guard limit.width > 0, limit.height > 0, size.width > 0, size.height > 0 else { return size }
        let fit = min(1, min(limit.width / size.width, limit.height / size.height))
        return CGSize(width: size.width * fit, height: size.height * fit)
    }

    func layoutItems() {
        // Not `itemsNode.removeAllChildren()`: carried items are children of the
        // character, so the nodes have to be dropped by hand wherever they hang.
        for node in itemNodes.values {
            node.removeFromParent()
        }
        itemNodes = [:]
        // What you left in another room is still in the model — it is simply not
        // drawn, because you are not standing in the room it is in.
        for item in items where isHere(item) {
            addItemNode(for: item)
        }
        refreshItemDepths()
    }

    /// Adds the node for one item under whatever it currently belongs to. A
    /// carried item goes under the character, which is what makes it walk, sit
    /// and lie down with them for free.
    @discardableResult
    func addItemNode(for item: Item) -> SKNode {
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
    func refreshItemDepths() {
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

    func itemIndex(id: Int) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// An item's box in scene coordinates: where it is now, at the size its
    /// level says it should be. Measured rather than taken from the node so a
    /// name caption hanging below it does not count as part of the item.
    func itemFrame(for item: Item) -> CGRect? {
        guard let node = itemNodes[item.id] else { return nil }
        // A carried item's position is in the character's space, not the scene's.
        let position = node.parent?.convert(node.position, to: self) ?? node.position
        let size = itemSize(for: item.definition, in: item.location)
        return CGRect(x: position.x - size.width / 2, y: position.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// The topmost item under a touch, if any. A little slop around the box
    /// makes small items easier to grab with a finger.
    func topItem(at location: CGPoint) -> Item? {
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
    func carryTarget(for item: Item) -> CarryStyle? {
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
    func carriedItem(style: CarryStyle) -> Item? {
        items.first { $0.location == .carried(style) }
    }

    /// Puts an item on the character. It becomes a child of them, so it walks,
    /// sits and lies down with them — which is the whole reason carrying is worth
    /// having rather than just parking things nearby.
    func attach(id: Int, style: CarryStyle) {
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
        place(index, in: .carried(style), anchor: items[index].anchor)
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
    func putDown(id: Int, offset: CGPoint = .zero) -> SKNode? {
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
        place(index, in: .room, anchor: itemAnchor(for: resting, in: .room))
        let fresh = addItemNode(for: items[index])
        refreshItemDepths()
        refreshStuffCount()
        setNeedsSave()
        return fresh
    }

    // MARK: - Merging

    static let itemHighlightName = "merge-highlight"
    static let itemStroke = SKColor(white: 0.15, alpha: 0.7)
    static let itemMergeStroke = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)

    /// The item `dragged` would merge with if it were released now, if any.
    ///
    /// Like the furniture test, this compares overlapping *area* rather than a
    /// single point, so an item dropped anywhere across its partner counts.
    func mergeTarget(for dragged: Item) -> Item? {
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
    func highlightMergeTarget(_ id: Int?) {
        for item in items {
            let highlight = itemNodes[item.id]?.childNode(withName: Self.itemHighlightName)
            highlight?.isHidden = item.id != id
        }
    }

    /// On release, merge the dragged item into whatever it was dropped on.
    /// Otherwise it simply stays where it was put.
    func settleItem(id: Int) {
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
        place(index, in: dropLocation, anchor: itemAnchor(for: resting, in: dropLocation))
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
    func merge(_ dragged: Item, _ target: Item, into result: ItemDefinition) {
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
    func makeItemNode(for item: Item) -> SKNode {
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
    func makeItemCaption(_ text: String, fontSize: CGFloat, topY: CGFloat) -> SKNode {
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
    func makeItemArtwork(for definition: ItemDefinition, size boxSize: CGSize) -> SKNode {
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
    func nextSpawnAnchor() -> CGPoint {
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
    func rect(for location: ItemLocation) -> CGRect {
        switch location {
        case .stuff: return stuffRect
        case .room, .carried: return roomRect
        }
    }

    func itemPosition(for item: Item) -> CGPoint {
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

    func itemAnchor(for position: CGPoint, in location: ItemLocation) -> CGPoint {
        let area = rect(for: location)
        guard area.width > 0, area.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: (position.x - area.minX) / area.width,
                       y: (position.y - area.minY) / area.height)
    }

    /// Which area an item dropped at this point belongs to. Anything not over the
    /// room — including the gap between the two — counts as Stuff.
    func location(forDropAt position: CGPoint) -> ItemLocation {
        roomRect.contains(position) ? .room : .stuff
    }

    /// Keeps a whole item inside its area. In the Stuff panel it also stays clear
    /// of the button column — an item parked on a button could not be picked up
    /// again, because the tap would hit the button instead.
    func clampedItemPosition(_ position: CGPoint, size boxSize: CGSize,
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
    func clampedDragPosition(_ position: CGPoint) -> CGPoint {
        let bounds = roomRect.union(stuffRect)
        return CGPoint(x: min(max(position.x, bounds.minX), bounds.maxX),
                       y: min(max(position.y, bounds.minY), bounds.maxY))
    }
}
