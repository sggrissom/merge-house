import SwiftUI
import SpriteKit

struct GameView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var scene: GameScene = {
        GameScene(size: CGSize(width: 1024, height: 768))
    }()

    var body: some View {
        SpriteView(scene: scene)
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
        GameView()
    }
}
