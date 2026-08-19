import SwiftUI

struct MainMenuView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text("Merge House")
                    .font(.system(size: 64, weight: .bold, design: .rounded))

                NavigationLink {
                    GameView()
                } label: {
                    Text("Play")
                        .font(.title)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    MainMenuView()
}
