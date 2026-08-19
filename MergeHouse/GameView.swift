import SwiftUI

/// Placeholder game screen. The real room arrives in a later milestone.
struct GameView: View {
    var body: some View {
        Text("Game")
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Game")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GameView()
    }
}
