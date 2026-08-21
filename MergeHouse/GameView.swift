import SwiftUI
import SpriteKit

struct GameView: View {
    let slot: SaveSlot

    @Environment(\.dismiss) private var dismiss

    /// Built once, from the slot, and kept: the scene reads its save on the way
    /// in, so a scene rebuilt mid-play would read the file back over the game
    /// you are in the middle of.
    @State private var scene: GameScene

    init(slot: SaveSlot) {
        self.slot = slot
        _scene = State(initialValue: GameScene(size: CGSize(width: 1024, height: 768),
                                               slot: slot))
    }

    var body: some View {
        SpriteView(scene: scene)
            .navigationTitle(slot.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Menu") { dismiss() }
                }
            }
    }
}

#Preview {
    NavigationStack {
        GameView(slot: SaveSlot(id: "preview", name: "Preview", saved: Date()))
    }
}
