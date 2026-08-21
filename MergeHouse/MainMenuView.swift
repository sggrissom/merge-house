import SwiftUI

/// The way in: the saves there are, and a way to start another one.
///
/// The list is read from disk every time this view appears rather than held as
/// state, because the game you have just come back from has been written to disk
/// on its way out — reading is how the date and the newly made save get here.
struct MainMenuView: View {
    @State private var slots: [SaveSlot] = []
    @State private var path: [SaveSlot] = []

    @State private var isNaming = false
    @State private var newName = ""
    /// The save being renamed, if any. Held apart from `isNaming` so the same
    /// text field can do both jobs without either forgetting which it is doing.
    @State private var renaming: SaveSlot?

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 24) {
                Text("Merge House")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .padding(.top, 40)

                if slots.isEmpty {
                    Spacer()
                    Text("No games yet.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(slots) { slot in
                            Button {
                                path.append(slot)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(slot.name)
                                            .font(.title3)
                                        Text(slot.saved, format: .relative(presentation: .named))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    SaveStore.delete(slot.id)
                                    refresh()
                                }
                                Button("Rename") {
                                    renaming = slot
                                    newName = slot.name
                                    isNaming = true
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    // The list is the only thing on a mostly empty screen, so it
                    // is left as a set of cards on the menu's own background
                    // rather than a grey panel with three rows at the top of it.
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: 520)
                }

                Button {
                    renaming = nil
                    newName = suggestedName()
                    isNaming = true
                } label: {
                    Text(slots.isEmpty ? "New Game" : "New Save")
                        .font(.title)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(for: SaveSlot.self) { GameView(slot: $0) }
            .onAppear(perform: refresh)
            .alert(renaming == nil ? "Name this game" : "Rename this game",
                   isPresented: $isNaming) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button(renaming == nil ? "Start" : "Rename", action: commitName)
            }
        }
    }

    private func refresh() {
        slots = SaveStore.slots()
    }

    /// A name that is already filled in, so starting a game is one tap for
    /// somebody who has nothing to call it yet. Counting up from how many saves
    /// there are would repeat itself as soon as one is deleted, so it counts
    /// past whatever is already taken.
    private func suggestedName() -> String {
        var number = slots.count + 1
        let taken = Set(slots.map(\.name))
        while taken.contains("Game \(number)") { number += 1 }
        return "Game \(number)"
    }

    /// Names a new save and goes straight into it, or renames an existing one.
    /// An empty name is not refused with a message: the suggestion it came from
    /// is simply put back, which is what somebody who cleared the field and hit
    /// Start meant.
    private func commitName() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let slot = renaming {
            SaveStore.rename(slot.id, to: trimmed.isEmpty ? slot.name : trimmed)
            renaming = nil
            refresh()
            return
        }

        let slot = SaveStore.create(name: trimmed.isEmpty ? suggestedName() : trimmed)
        refresh()
        path.append(slot)
    }
}

#Preview {
    MainMenuView()
}
