import SpriteKit
import UIKit

extension GameScene {
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
            return
        }

        // Nothing under the finger. It might yet be a tap on the room, which is
        // a walk — but only if the finger comes up near where it went down.
        if roomRect.contains(location) {
            tapTouch = touch
            tapStart = location
        }
    }

    /// How far a finger can travel and still have been a tap.
    var tapSlop: CGFloat {
        max(10, min(size.width, size.height) * 0.02)
    }

    /// A tap on the room: they walk there.
    ///
    /// A tap on something they can get on walks them to it *and* puts them on
    /// it, which is the fiddliest drag in the game — lining a body up with a bed
    /// — done with one finger in one go.
    func floorTapped(at location: CGPoint) {
        guard roomRect.contains(location) else { return }
        if let piece = usablePiece(at: location) {
            // Already on it: tapping the bed you are lying on is not a reason to
            // get up and lie down again.
            guard piece.id != characterUsing else { return }
            walkCharacter(to: seatPosition(for: piece), sittingOn: piece.id)
        } else {
            walkCharacter(to: location, sittingOn: nil)
        }
    }

    /// The frontmost piece under a point that a character can actually get on.
    /// Room order is draw order, so the last match is the one on top — and a
    /// Table, which is furniture you only walk past, is not a match at all.
    func usablePiece(at location: CGPoint) -> FurniturePiece? {
        furniturePieces.last { $0.definition.use != nil && $0.rect.contains(location) }
    }

    func beginCharacterDrag(touch: UITouch, at location: CGPoint) {
        // A drag beats a walk: whatever they were told to do, this is what they
        // are doing now.
        stopWalking()
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

    func beginItemDrag(_ item: Item, node: SKNode,
                                    touch: UITouch, at location: CGPoint) {
        // Picking anything up stops a walk, so that what is being carried
        // towards them is not also walking away.
        stopWalking()
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

        playSound(.pickUp, voice: item.definition.sound)

        node.removeAllActions()
        node.run(.scale(to: 1.08, duration: 0.08))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tap = tapTouch, touches.contains(tap) {
            let moved = tap.location(in: self)
            if hypot(moved.x - tapStart.x, moved.y - tapStart.y) > tapSlop {
                tapTouch = nil
            }
        }

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
            place(index, in: carriedTo, anchor: itemAnchor(for: node.position, in: carriedTo))
            let carry = carryTarget(for: items[index])
            highlightCharacter(carry != nil)
            // They tip toward whatever is being held out to them, whether or not
            // it is a thing they could actually take: a Cake carried past is
            // still worth turning your head for.
            leanCharacter(toward: node.position)
            highlightMergeTarget(carry == nil ? mergeTarget(for: items[index])?.id : nil)
            highlightTrash(isOverTrash(node.position))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tap = tapTouch, touches.contains(tap) {
            tapTouch = nil
            floorTapped(at: tap.location(in: self))
        }
        endDrag(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tap = tapTouch, touches.contains(tap) {
            tapTouch = nil
        }
        endDrag(touches)
    }

    func endDrag(_ touches: Set<UITouch>) {
        guard let touch = dragTouch, touches.contains(touch) else { return }
        let subject = dragSubject
        dragTouch = nil
        dragSubject = nil
        leanCharacter(toward: nil)
        guard let subject = subject else { return }

        switch subject {
        case .character:
            settleCharacter()
        case .item(let id):
            settleItem(id: id)
        }
        setNeedsSave()
    }

    /// The id of the usable piece the character is currently over, if any.
    ///
    /// This compares how much of them *overlaps* each piece rather than testing a
    /// single point. The origin is at the feet, so a point test only matched when
    /// grabbed low down — dragging the body onto the bed left the feet
    /// below it and nothing happened.
    func dropTarget() -> String? {
        let characterFrame = characterSceneFrame()
        let characterArea = characterFrame.width * characterFrame.height
        var best: (id: String, overlap: CGFloat)?

        for piece in furniturePieces where piece.definition.use != nil {
            let intersection = characterFrame.intersection(piece.rect)
            guard !intersection.isNull else { continue }

            let overlap = intersection.width * intersection.height
            let pieceArea = piece.rect.width * piece.rect.height
            // A quarter of the smaller of the two, so brushing past does not count.
            guard overlap >= min(characterArea, pieceArea) * 0.25 else { continue }
            if let current = best, overlap <= current.overlap { continue }

            best = (piece.id, overlap)
        }

        return best?.id
    }
}
