import SpriteKit
import UIKit

extension GameScene {
    // MARK: - Saving

    /// Writing is deferred rather than done inline: dropping an item touches the
    /// model several times over, and a drag would otherwise write on every frame.
    /// Anything that changes what the child has made just says so, and `update`
    /// writes it out at most once a second.
    func setNeedsSave() {
        needsSave = true
    }

    override func update(_ currentTime: TimeInterval) {
        // A walk moves the drawing; this is what moves the character. Kept here
        // rather than at the end of the walk so that stopping one halfway needs
        // no unwinding.
        trackWalk()

        guard needsSave, currentTime - lastSaveTime >= 1 else { return }
        lastSaveTime = currentTime
        flushSave()
    }

    /// Writes immediately, whatever the timer says. Called when the app is about
    /// to go away, which is exactly the moment the deferred write cannot wait.
    @objc func flushSave() {
        guard needsSave else { return }
        needsSave = false
        SaveStore.save(snapshot(), id: slot.id)
    }

    func snapshot() -> SavedGame {
        let saved = items.map { item -> SavedItem in
            switch item.location {
            case .stuff:
                return SavedItem(item: item.definition.id, place: "stuff", room: nil, carry: nil,
                                 x: Double(item.anchor.x), y: Double(item.anchor.y))
            case .room:
                // The room it is standing in, not the one you happen to be in:
                // saving from the Kitchen must not move the Bedroom's things.
                return SavedItem(item: item.definition.id, place: "room",
                                 room: item.room ?? room.id, carry: nil,
                                 x: Double(item.anchor.x), y: Double(item.anchor.y))
            case .carried(let style):
                return SavedItem(item: item.definition.id, place: "carried", room: nil,
                                 carry: style.rawValue, x: 0, y: 0)
            }
        }
        return SavedGame(version: SavedGame.currentVersion,
                         name: slot.name,
                         saved: Date(),
                         items: saved,
                         character: character.id,
                         room: room.id,
                         characterX: Double(characterAnchor.x),
                         characterY: Double(characterAnchor.y),
                         characterUsing: characterUsing)
    }

    /// Rebuilds the model from the save, if there is one.
    ///
    /// Everything here is written to survive a catalog that has been edited since
    /// the file was written, because a catalog that can be edited freely is the
    /// whole point of this prototype. An item id that no longer exists is dropped
    /// and the rest is kept; a character, a room or a piece of furniture that has
    /// gone falls back rather than throwing the save away.
    func restoreSavedGame() {
        guard let saved = SaveStore.load(slot.id) else { return }

        // Before the items, which need to know which room to fall back to.
        if let id = saved.room, let definition = RoomCatalog.definition(id: id) {
            room = definition
        }

        for entry in saved.items {
            guard let definition = ItemCatalog.definition(id: entry.item),
                  let restored = restored(entry, definition: definition) else { continue }
            items.append(Item(id: nextItemID, definition: definition,
                              location: restored.location, anchor: restored.anchor,
                              room: restored.room))
            nextItemID += 1
        }

        if let id = saved.character, let definition = CharacterCatalog.definition(id: id) {
            character = definition
        }
        characterAnchor = CGPoint(x: saved.characterX, y: saved.characterY)
        // Only if this room still has that piece and it is still something you
        // can get on. Anything else and they are simply standing up.
        //
        // Matched without case, because the saves written before furniture had a
        // catalog of its own wrote `Bed` where this one says `bed`, and standing
        // somebody up out of their bed is a poor reward for having a save.
        if let id = saved.characterUsing,
           let piece = room.pieces.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }),
           piece.definition.use != nil {
            characterUsing = piece.id
        }
    }

    /// Where one saved entry goes now. A carried item stores no position of its
    /// own — its place comes from the character's carry point — so one that can
    /// no longer be carried needs an anchor inventing for it, and the middle of
    /// the floor is somewhere it will actually be seen.
    ///
    /// An item left in a room that has since been taken out of the catalog is
    /// moved to the room being restored into rather than being thrown away —
    /// a room that no longer exists should not take the teddy in it with it.
    func restored(_ entry: SavedItem, definition: ItemDefinition)
        -> (location: ItemLocation, anchor: CGPoint, room: String?)? {
        let anchor = CGPoint(x: entry.x, y: entry.y)
        let inRoom = entry.room.flatMap { RoomCatalog.definition(id: $0) }?.id ?? room.id
        switch entry.place {
        case "stuff": return (.stuff, anchor, nil)
        case "room": return (.room, anchor, inRoom)
        case "carried":
            // A carry style that no longer exists, or an item that is no longer
            // the kind of thing you can wear, is put down rather than dropped.
            guard let raw = entry.carry, let style = CarryStyle(rawValue: raw),
                  definition.carry == style else {
                return (.room, CGPoint(x: 0.5, y: 0.2), room.id)
            }
            return (.carried(style), anchor, nil)
        default: return nil
        }
    }
}
