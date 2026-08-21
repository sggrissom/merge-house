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
        }
    }

    func beginCharacterDrag(touch: UITouch, at location: CGPoint) {
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

    func endDrag(_ touches: Set<UITouch>) {
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
    func dropTarget() -> FurnitureKind? {
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
}
