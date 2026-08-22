import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Character

    /// Builds the character, sized relative to the room and to whoever you are
    /// currently playing as. The container's position is the character's feet.
    func layoutCharacter() {
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
        // Being alive is stopped and wound back to a standing figure before
        // anything is measured, so a breath half taken never ends up baked into
        // the frame everything else is clamped and hit-tested against.
        stopBeingAlive()

        characterBodyNode.addChild(makeCharacterArtwork(for: character, height: height))

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = usingPiece?.definition.use?.label ?? character.name
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

        if let piece = usingPiece {
            characterNode.zRotation = piece.definition.use?.pose.rotation ?? 0
            characterNode.position = seatPosition(for: piece)
        } else {
            characterNode.position = clampedCharacterPosition(scenePosition(for: characterAnchor))
        }

        relayoutCarriedItems()
        startBeingAlive()
    }

    // MARK: - Being alive

    static let characterBreathKey = "breathe"
    static let characterBlinkKey = "blink"
    static let characterLeanKey = "lean"

    /// How far the figure tips toward something held out to them.
    static let characterLeanAngle: CGFloat = 0.10

    /// The two things a standing figure does forever: breathe, and now and then
    /// blink.
    ///
    /// A character is a single flat drawing, so neither of these can be a change
    /// of face — they are both a squash, which is the one thing a drawing can do
    /// without a second drawing behind it. Both scale about the node's origin,
    /// which is the character's feet, so they stay standing on the floor rather
    /// than growing out of it.
    ///
    /// The breath is on the body and the blink is on the whole figure, because
    /// two actions on one node both writing `scale` would fight over it. The
    /// lean shares the figure with the blink quite happily: it writes rotation,
    /// and they never touch the same property.
    func startBeingAlive() {
        let breatheIn = SKAction.scaleX(to: 0.995, y: 1.02, duration: 1.6)
        breatheIn.timingMode = .easeInEaseOut
        let breatheOut = SKAction.scaleX(to: 1.0, y: 1.0, duration: 1.8)
        breatheOut.timingMode = .easeInEaseOut
        characterBodyNode.run(.repeatForever(.sequence([breatheIn, breatheOut])),
                              withKey: Self.characterBreathKey)

        let blinkDown = SKAction.scaleX(to: 1.04, y: 0.94, duration: 0.09)
        blinkDown.timingMode = .easeOut
        let blinkUp = SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.13)
        blinkUp.timingMode = .easeOut
        // A fresh random wait every time round, so it reads as a person rather
        // than a metronome.
        characterLeanNode.run(.repeatForever(.sequence([
            .wait(forDuration: 3.0, withRange: 3.5),
            blinkDown,
            blinkUp,
        ])), withKey: Self.characterBlinkKey)
    }

    /// Stands the figure back up, still and unsquashed.
    func stopBeingAlive() {
        characterLean = 0
        for node in [characterLeanNode, characterBodyNode] {
            node.removeAction(forKey: Self.characterBreathKey)
            node.removeAction(forKey: Self.characterBlinkKey)
            node.removeAction(forKey: Self.characterLeanKey)
            node.setScale(1)
            node.zRotation = 0
        }
    }

    /// Tips the figure toward something being held out to them, and stands them
    /// back up when it goes away. `nil` is nothing being offered.
    ///
    /// The lean is a pose rather than a dial: near enough on one side or the
    /// other, or upright. That keeps it from twitching as a finger crosses the
    /// middle, and it means the action is only restarted when the answer
    /// actually changes rather than on every frame of a drag.
    func leanCharacter(toward point: CGPoint?) {
        var angle: CGFloat = 0
        if let point = point, characterHeight > 0 {
            let dx = point.x - characterNode.position.x
            let dy = point.y - characterNode.position.y
            let reach = characterHeight * 1.1
            // Within arm's length, and roughly alongside them: something down on
            // the shelf is not being held out to anybody.
            if abs(dx) <= reach, dy > -characterHeight * 0.4, dy < characterHeight * 1.7 {
                let deadzone = characterHeight * 0.12
                if dx > deadzone {
                    angle = -Self.characterLeanAngle
                } else if dx < -deadzone {
                    angle = Self.characterLeanAngle
                }
            }
        }

        guard angle != characterLean else { return }
        characterLean = angle
        let tip = SKAction.rotate(toAngle: angle, duration: 0.18, shortestUnitArc: true)
        tip.timingMode = .easeOut
        characterLeanNode.run(tip, withKey: Self.characterLeanKey)
    }

    // MARK: - Reacting

    static let characterReactionName = "reaction-bubble"

    /// A bubble popping over the character's shoulder when they are given
    /// something.
    ///
    /// Which reaction it is belongs to the item — a Teddy is loved and a Cake is
    /// eaten — and drawing it belongs here. The character never learns what a
    /// teddy is, and an item that has not said anything about itself still gets
    /// a sparkle, because being handed something is worth *something*.
    func showReaction(_ reaction: Reaction?) {
        guard characterHeight > 0 else { return }
        // One at a time: handing over three things quickly is three bubbles in a
        // row, not three bubbles on top of each other.
        characterNode.childNode(withName: Self.characterReactionName)?.removeFromParent()

        let size = characterHeight * 0.26
        let bubble = SKNode()
        bubble.name = Self.characterReactionName
        // Over their shoulder, clear of the name tag above their head, and on
        // whichever side has more room — a bubble is not worth pushing off the
        // edge of the room over. Upright even when they are lying on the bed,
        // which is the one place the character themselves is not.
        let side: CGFloat = characterNode.position.x > roomRect.midX ? -1 : 1
        bubble.position = CGPoint(x: side * characterHeight * 0.36, y: characterHeight * 0.95)
        bubble.zRotation = -characterNode.zRotation
        bubble.zPosition = 5
        bubble.setScale(0.2)
        bubble.alpha = 0

        let disc = SKShapeNode(circleOfRadius: size * 0.68)
        disc.fillColor = SKColor(white: 1, alpha: 0.94)
        disc.strokeColor = SKColor(white: 0.15, alpha: 0.35)
        disc.lineWidth = 2
        bubble.addChild(disc)
        bubble.addChild(makeReactionMark(reaction, size: size))

        characterNode.addChild(bubble)

        let pop = SKAction.scale(to: 1.12, duration: 0.16)
        pop.timingMode = .easeOut
        bubble.run(.sequence([
            .group([pop, .fadeIn(withDuration: 0.10)]),
            .scale(to: 1.0, duration: 0.10),
            .wait(forDuration: 0.8),
            .group([.moveBy(x: 0, y: size * 0.6, duration: 0.30),
                    .fadeOut(withDuration: 0.30)]),
            .removeFromParent(),
        ]))
    }

    /// What goes inside the bubble. Shapes rather than artwork, so this is one
    /// more thing that is finished before anybody draws anything.
    func makeReactionMark(_ reaction: Reaction?, size: CGFloat) -> SKNode {
        // Nothing said about it is still worth a sparkle.
        guard let reaction = reaction else {
            return makeFilledMark(starPath(points: 4, radius: size * 0.44, innerRatio: 0.26),
                                  color: SKColor(red: 0.99, green: 0.86, blue: 0.40, alpha: 1))
        }

        switch reaction {
        case .love:
            return makeFilledMark(heartPath(size: size * 0.9),
                                  color: SKColor(red: 0.93, green: 0.30, blue: 0.42, alpha: 1))
        case .proud:
            return makeFilledMark(starPath(points: 5, radius: size * 0.42, innerRatio: 0.46),
                                  color: SKColor(red: 0.98, green: 0.78, blue: 0.24, alpha: 1))
        case .yum:
            return makeCrumbsMark(size: size)
        case .silly:
            return makeSquiggleMark(size: size)
        }
    }

    private func makeFilledMark(_ path: CGPath, color: SKColor) -> SKShapeNode {
        let mark = SKShapeNode(path: path)
        mark.fillColor = color
        mark.strokeColor = color
        mark.lineWidth = 1
        return mark
    }

    /// Crumbs: what is left of a cake once somebody has been given it.
    private func makeCrumbsMark(size: CGFloat) -> SKNode {
        let node = SKNode()
        let crumb = SKColor(red: 0.60, green: 0.38, blue: 0.22, alpha: 1)
        let scatter: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (-0.22, 0.14, 0.13), (0.18, 0.20, 0.10),
            (0.05, -0.08, 0.15), (-0.10, -0.26, 0.09), (0.26, -0.20, 0.11),
        ]
        for spot in scatter {
            let dot = SKShapeNode(circleOfRadius: size * spot.r)
            dot.position = CGPoint(x: size * spot.x, y: size * spot.y)
            dot.fillColor = crumb
            dot.strokeColor = crumb
            dot.lineWidth = 1
            node.addChild(dot)
        }
        return node
    }

    /// A squiggle, for the things that are simply funny to be handed.
    private func makeSquiggleMark(size: CGFloat) -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size * 0.34, y: -size * 0.18))
        path.addCurve(to: CGPoint(x: 0, y: -size * 0.18),
                      control1: CGPoint(x: -size * 0.22, y: size * 0.34),
                      control2: CGPoint(x: -size * 0.12, y: -size * 0.40))
        path.addCurve(to: CGPoint(x: size * 0.34, y: size * 0.10),
                      control1: CGPoint(x: size * 0.12, y: size * 0.02),
                      control2: CGPoint(x: size * 0.16, y: size * 0.40))
        let mark = SKShapeNode(path: path)
        mark.fillColor = .clear
        mark.strokeColor = SKColor(red: 0.55, green: 0.40, blue: 0.86, alpha: 1)
        mark.lineWidth = max(2, size * 0.14)
        mark.lineCap = .round
        return mark
    }

    private func heartPath(size: CGFloat) -> CGPath {
        let w = size * 0.46
        let h = size * 0.42
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -h))
        path.addCurve(to: CGPoint(x: -w, y: h * 0.35),
                      control1: CGPoint(x: -w * 0.55, y: -h * 0.50),
                      control2: CGPoint(x: -w, y: -h * 0.15))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.30),
                      control1: CGPoint(x: -w, y: h * 0.90),
                      control2: CGPoint(x: -w * 0.28, y: h * 0.90))
        path.addCurve(to: CGPoint(x: w, y: h * 0.35),
                      control1: CGPoint(x: w * 0.28, y: h * 0.90),
                      control2: CGPoint(x: w, y: h * 0.90))
        path.addCurve(to: CGPoint(x: 0, y: -h),
                      control1: CGPoint(x: w, y: -h * 0.15),
                      control2: CGPoint(x: w * 0.55, y: -h * 0.50))
        path.closeSubpath()
        return path
    }

    private func starPath(points: Int, radius: CGFloat, innerRatio: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let step = CGFloat.pi / CGFloat(points)
        for index in 0..<(points * 2) {
            let reach = index.isMultiple(of: 2) ? radius : radius * innerRatio
            let angle = CGFloat(index) * step + .pi / 2
            let point = CGPoint(x: cos(angle) * reach, y: sin(angle) * reach)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    /// Redraws whatever the character is carrying. Their size and their carry
    /// points both belong to whoever they are, so a resize or a change of
    /// character moves the hat as well as the head.
    func relayoutCarriedItems() {
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
    func makeCharacterHighlight() -> SKNode {
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

    static let characterHighlightName = "carry-highlight"

    func highlightCharacter(_ on: Bool) {
        characterBodyNode.childNode(withName: Self.characterHighlightName)?.isHidden = !on
    }

    /// The character's own box in scene coordinates: their drawing and name tag,
    /// but not whatever they are carrying — a held Giant Teddy would otherwise
    /// count as part of them and drag the whole figure onto the bed with it.
    ///
    /// Measured through `characterNode`, which means a figure mid-breath or
    /// mid-lean has the same box as one standing still. That is deliberate: this
    /// is what a finger has to hit and what decides whether a dropped item is
    /// being handed over, and neither should wobble in time with a breath.
    func characterSceneFrame() -> CGRect {
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
    func makeCharacterArtwork(for definition: CharacterDefinition,
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

    func scenePosition(for anchor: CGPoint) -> CGPoint {
        CGPoint(x: roomRect.minX + anchor.x * roomRect.width,
                y: roomRect.minY + anchor.y * roomRect.height)
    }

    func characterAnchor(for position: CGPoint) -> CGPoint {
        guard roomRect.width > 0, roomRect.height > 0 else { return characterAnchor }
        return CGPoint(x: (position.x - roomRect.minX) / roomRect.width,
                       y: (position.y - roomRect.minY) / roomRect.height)
    }

    /// Keeps the whole character — label included — inside the room.
    func clampedCharacterPosition(_ position: CGPoint) -> CGPoint {
        let minX = roomRect.minX - characterLocalFrame.minX
        let maxX = roomRect.maxX - characterLocalFrame.maxX
        let minY = roomRect.minY - characterLocalFrame.minY
        let maxY = roomRect.maxY - characterLocalFrame.maxY
        return CGPoint(x: min(max(position.x, minX), max(minX, maxX)),
                       y: min(max(position.y, minY), max(minY, maxY)))
    }
}
