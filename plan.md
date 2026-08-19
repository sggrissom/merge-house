# Merge House — Initial Prototype Plan

## Purpose

Build the smallest possible playable prototype of **Merge House**, one visible step at a time.

The primary target is **iPad**, with **landscape orientation** as the reference experience. The app should also remain compatible with iPhone where practical, using the same codebase and adaptive layout rather than separate implementations.

This prototype intentionally uses **zero final art**. Everything should be represented with simple shapes, text labels, and system styling until the core interaction loop works. The end goal of this plan is to reach a point where the game can be handed to the kids as a concrete template for creating the real artwork.

---

## Product Idea

Merge House is a simple digital dollhouse with a merge mechanic.

The intended loop is:

1. Enter a room.
2. Move a character around.
3. Interact with simple furniture.
4. Generate loose objects in a "stuff" area.
5. Drag matching objects together to merge them.
6. Place the resulting objects into the house.
7. Play with the character and objects.

The prototype does **not** need to resemble a commercial merge game beyond that basic idea.

---

## Technical Direction

Use Apple's native frameworks:

- **Swift**
- **SwiftUI** for app-level UI such as the main menu and screen structure.
- **SpriteKit** for the interactive room, draggable character, objects, placement, and merging.

Prefer standard Apple frameworks only. Do not add third-party dependencies unless there is a clear need that cannot reasonably be handled natively.

### Platform

- Primary: iPad
- Reference layout: landscape iPad
- Secondary: iPhone
- Use one universal app target if practical.
- Layout should adapt to available screen size.
- Do not create separate iPad and iPhone game implementations.

### Prototype Art Rules

Until the art handoff phase:

- Do not download or integrate art packs.
- Do not generate production artwork.
- Use `SKShapeNode`, simple colors, SF Symbols where useful, and text labels.
- Every game object must still work if its real image asset is missing.
- Missing artwork should be a supported normal state, not an error.

Example placeholder:

```text
┌─────────────┐
│ Little Teddy│
└─────────────┘
```

Later, a real image should be able to replace that placeholder without changing gameplay code.

---

# Agent Working Rules

The most important rule is:

> **Implement only the current milestone. Do not anticipate later milestones.**

For every milestone:

1. Make the smallest reasonable implementation.
2. Keep the project compiling.
3. Run/build the app after the change.
4. Verify the milestone's acceptance criteria.
5. Briefly report:
   - what changed,
   - important files changed,
   - any decision that could affect later work.
6. Stop unless explicitly asked to continue.

Do not add speculative systems such as:

- accounts,
- networking,
- backend services,
- currencies,
- energy,
- timers,
- quests,
- stores,
- achievements,
- analytics,
- elaborate navigation,
- generalized ECS architecture,
- elaborate inventory systems,
- animation frameworks,
- complex save migrations.

Hardcoded prototype data is acceptable when it keeps a milestone simple.

Refactor only when the next concrete feature makes the existing implementation meaningfully awkward.

---

# Milestone 0 — Project Exists

## Goal

Create an Xcode project that launches successfully.

## Requirements

- App name: **Merge House**
- Swift
- SwiftUI app lifecycle
- Universal iOS/iPadOS target where practical.
- Prefer landscape on iPad for the game experience.
- Initial screen may be plain.

## Visible Result

Opening the app shows:

```text
Merge House
Prototype
```

## Acceptance Criteria

- Builds successfully.
- Runs in an iPad simulator.
- App launches without errors.
- The words `Merge House` are visible.
- No game architecture is required yet.

---

# Milestone 1 — Main Menu

## Goal

Create the first real screen.

## Requirements

Show:

- `Merge House`
- one `Play` button

Do not add settings, profiles, credits, saves, or other menu options.

## Interaction

Tap `Play` to navigate to a placeholder game screen.

## Acceptance Criteria

- App launches to the menu.
- Play button works.
- Back navigation from the game screen is possible.

---

# Milestone 2 — Empty Room

## Goal

Make the user feel like they have entered the dollhouse.

## Requirements

Create the gameplay view.

Use SpriteKit for the interactive game area.

Show:

- a large placeholder rectangle representing the room,
- label: `Bedroom`,
- a visually distinct floor/wall area if easy,
- a way to return to the main menu.

No character yet.

## Layout

iPad landscape is the reference layout.

The room should occupy most of the screen.

## Acceptance Criteria

- Play opens the room.
- The room fills the expected game area on iPad.
- Rotation/layout does not visibly break the scene.
- Returning to the menu works.

---

# Milestone 3 — Character Appears

## Goal

Put the first "person" in the dollhouse.

## Requirements

Add one placeholder character.

Representation can be:

- rounded rectangle,
- circle,
- simple body made of shapes.

Label it:

`Girl`

No animation.

No movement yet.

## Acceptance Criteria

- Character is visible in the room.
- Character cannot accidentally render underneath the background.
- Character size is reasonable for future furniture interactions.

---

# Milestone 4 — Drag the Character

## Goal

Make the room interactive for the first time.

## Requirements

The character can be:

- touched,
- dragged,
- released.

After release, it stays at the dropped position.

The character must remain within the room's playable bounds.

Do not add walking animation.

## Acceptance Criteria

- Drag feels responsive with a finger.
- Character follows the drag.
- Character stays where dropped.
- Character cannot be lost outside the room.

## First Kid Demo

This is an important demo checkpoint.

The child should now be able to:

1. Open Merge House.
2. Tap Play.
3. See a bedroom.
4. Move the character around.

---

# Milestone 5 — Placeholder Furniture

## Goal

Give the room recognizable dollhouse objects.

## Requirements

Add three non-interactive placeholder objects:

- Bed
- Chair
- Table

Represent each with labeled rectangles/shapes.

Position them in sensible locations in the room.

Do not make the furniture movable yet unless required by a later milestone.

## Acceptance Criteria

- All three pieces are visible.
- Their positions make the room understandable.
- Character can still be dragged freely.

---

# Milestone 6 — Character Uses Furniture

## Goal

Introduce the first dollhouse-specific interaction.

## Requirements

### Bed

Dragging the character onto the bed should snap the character to a defined bed position.

The character may:

- rotate 90 degrees,
- change its label to `Sleeping`,
- or otherwise visibly indicate the state.

### Chair

Dragging the character onto the chair should snap it to a defined chair position.

The character may change its label to `Sitting`.

Do not create animation frames.

Do not require furniture artwork.

## Acceptance Criteria

- Bed interaction is obvious.
- Chair interaction is obvious.
- Character can be picked up again afterward.
- Character can return to normal free placement.

---

# Milestone 7 — Add the Stuff Area

## Goal

Create the second major part of the screen: where mergeable items live.

## Layout

Split the gameplay screen conceptually into:

```text
┌────────────────────────────────────┐
│                                    │
│              BEDROOM               │
│                                    │
│   Bed       Girl        Chair      │
│                         Table      │
│                                    │
├────────────────────────────────────┤
│ Stuff                              │
│                                    │
│                 [ Get Stuff ]      │
└────────────────────────────────────┘
```

The room should still get the majority of screen space.

## Requirements

- A clearly distinct bottom area labeled `Stuff`.
- A `Get Stuff` button.
- Button does not need to do anything yet.

## iPhone

Adapt this layout rather than creating a separate implementation.

If space is limited, the Stuff area may become proportionally smaller or scrollable later.

## Acceptance Criteria

- Bedroom and Stuff area are visually distinct.
- Existing character/furniture interaction still works.
- Get Stuff button is visible and tappable.

---

# Milestone 8 — Spawn the First Item

## Goal

Make `Get Stuff` produce something.

## Requirements

Each tap creates a placeholder:

`Little Teddy`

For now, always create the same item.

Spawn it somewhere sensible within the Stuff area.

Do not merge yet.

## Acceptance Criteria

- Tapping Get Stuff creates a teddy.
- Multiple teddies can exist.
- New objects remain inside the Stuff area.

---

# Milestone 9 — Drag Items

## Goal

Allow loose objects to behave like physical game pieces.

## Requirements

Teddies can be dragged within the Stuff area.

They should stay inside valid game bounds.

If easy, allow a teddy to be dragged into the Bedroom as well, but this is optional until later.

## Acceptance Criteria

- Individual teddy objects can be selected reliably.
- Multiple objects can coexist.
- Dragging one does not accidentally move another.

---

# Milestone 10 — First Merge

## Goal

Implement the defining mechanic of Merge House.

## Requirements

Two identical `Little Teddy` objects can be merged.

Interaction:

```text
Little Teddy + Little Teddy
            ↓
         Big Teddy
```

The user should drag one teddy onto the other.

On a valid merge:

1. Remove both source objects.
2. Create one `Big Teddy`.
3. Place the result near the merge location.

Add one very small visual feedback effect if easy, such as:

- quick scale up/down,
- brief bounce,
- simple particle pop.

Do not build an elaborate effects system.

## Acceptance Criteria

- Only two compatible objects merge.
- Invalid overlaps do nothing destructive.
- Two Little Teddies reliably produce one Big Teddy.
- Merge result is draggable.

## Second Kid Demo

At this point, demonstrate:

1. Enter house.
2. Move character.
3. Put character in bed/chair.
4. Tap Get Stuff twice.
5. Drag the two teddies together.
6. Show the new teddy.

---

# Milestone 11 — Complete One Merge Chain

## Goal

Prove merging can have progression.

## Chain

```text
Little Teddy
    ↓
Big Teddy
    ↓
Giant Teddy
```

Rules:

```text
Little Teddy + Little Teddy → Big Teddy
Big Teddy + Big Teddy       → Giant Teddy
```

`Giant Teddy + Giant Teddy` does nothing for now.

## Acceptance Criteria

- Full three-level chain works.
- Each level is visually distinguishable by:
  - size,
  - label,
  - or both.
- No generic content editor is required yet.

---

# Milestone 12 — Put Merge Objects in the House

## Goal

Connect the merge game to the dollhouse.

## Requirements

Allow merge items to cross from the Stuff area into the Bedroom.

Once placed in the room:

- they stay where dropped,
- they remain draggable,
- they are treated as dollhouse objects.

Do not implement advanced inventory behavior.

## Acceptance Criteria

- A Giant Teddy can be created.
- It can be dragged into the Bedroom.
- It can be positioned near the character/furniture.
- It remains there while the current game session runs.

At this point the complete conceptual loop exists:

```text
Get Stuff
   ↓
Merge
   ↓
Create Better Object
   ↓
Bring It Into House
   ↓
Play
```

---

# Milestone 13 — Make Item Definitions Data-Driven

## Goal

Only now introduce a small reusable model for content.

## Requirements

Create a simple item definition model.

Conceptually:

```swift
struct ItemDefinition {
    let id: String
    let name: String
    let imageName: String?
    let mergesInto: String?
}
```

The exact design may differ if the existing implementation suggests something cleaner.

The important behavior:

- `imageName == nil` renders a placeholder.
- Providing an image later should replace the placeholder.
- Merge behavior comes from item definitions rather than teddy-specific conditional logic.

Do not build a general-purpose content management system.

## Acceptance Criteria

- Existing teddy chain still works.
- Teddy-specific merge logic is no longer scattered through interaction code.
- Missing images render cleanly as placeholders.

---

# Milestone 14 — Add Several Kid-Designed Merge Chains

## Goal

Test whether the system is fun with a small amount of content.

Ask the kids what they want.

Possible examples:

```text
Bow → Fancy Bow → Tiara

Chair → Nice Chair → Princess Chair

Cupcake → Cake → Giant Cake
```

Use placeholders only.

## Requirements

Add approximately 2–3 additional chains.

`Get Stuff` may now spawn a random level-one item.

Avoid balancing systems.

## Acceptance Criteria

- Multiple chains coexist.
- Only matching compatible levels merge.
- It is easy to add another item definition.
- The screen remains usable with several loose objects.

---

# Milestone 15 — Minimal Local Save

## Goal

Avoid losing the child's creations every time the app closes.

## Requirements

Save only what is useful for the prototype.

Suggested state:

- unlocked/created item instances,
- item type,
- whether an item is in the Stuff area or Bedroom,
- approximate placed position.

Character position may be saved if trivial, but it is not important.

Use simple local persistence.

Do not add:

- accounts,
- iCloud,
- CloudKit,
- backend storage,
- login.

## Acceptance Criteria

- Place several objects.
- Close the app.
- Reopen it.
- Important objects are restored.

---

# Milestone 16 — Art Handoff Preparation

## Goal

Freeze feature development and turn the working prototype into a concrete art assignment for the kids.

Do not add new gameplay during this milestone.

## Required Art Slots

Create a clear list of every asset currently needed.

Example:

### Characters

- `girl`

### Room

- `bedroom-background`

### Furniture

- `bed`
- `chair`
- `table`

### Teddy Chain

- `teddy-small`
- `teddy-big`
- `teddy-giant`

### Bow Chain

- `bow`
- `fancy-bow`
- `tiara`

Continue for all prototype items.

---

## Asset Contract

Define a simple asset contract for the kids and for later integration.

Prefer:

- PNG
- transparent background for characters, furniture, and loose items
- consistent canvas dimensions within an asset category
- artwork centered with reasonable transparent padding
- avoid text inside the artwork
- filenames matching the asset list

The room background may be an opaque full-frame image.

Exact pixel dimensions should be chosen based on the implemented scene rather than guessed early.

Create an `ART_ASSETS.md` file at this milestone containing:

1. every required image,
2. target canvas dimensions,
3. example screenshot showing where each category appears,
4. filename for each asset,
5. whether transparency is required.

---

# Milestone 17 — First Real Kid Art

## Goal

Replace exactly one placeholder with a real drawing.

Start with something simple, for example:

`teddy-small.png`

## Requirements

- Import the PNG into the asset catalog.
- Associate it with the existing item definition.
- Do not change merge logic.
- Placeholder fallback must continue to work for every asset that has not yet been drawn.

## Acceptance Criteria

The game may now contain:

```text
real teddy art
placeholder Big Teddy
placeholder Giant Teddy
placeholder furniture
placeholder character
```

That mixed state is expected and supported.

---

# Prototype Complete

The initial prototype is complete when all of the following are true:

- Merge House launches on iPad.
- Main menu works.
- One bedroom exists.
- One character can be dragged.
- Character can use at least the bed and chair.
- A Stuff area exists.
- Items can spawn.
- Items can be dragged.
- Matching items merge.
- At least several three-level merge chains exist.
- Merged objects can be brought into the room.
- Basic game state persists locally.
- Every drawable object has a documented art slot.
- Missing art automatically falls back to placeholders.
- One real kid-created PNG can replace one placeholder without gameplay changes.

At that point, stop adding systems and let the kids make art.

---

# Explicitly Out of Scope for This Prototype

Do not implement these unless requested after the initial prototype is validated:

- multiple rooms,
- character customization,
- multiple characters,
- clothing system,
- pets,
- character animation,
- complex furniture animation,
- quests,
- story,
- currency,
- energy,
- timers,
- purchases,
- ads,
- Game Center,
- achievements,
- online multiplayer,
- cloud saves,
- accounts,
- backend services,
- procedural content,
- complex sound system,
- production-quality visual effects.

These are possible future features, not prototype requirements.

---

# Guiding Principle

At every point, prefer:

> **Something the child can see and touch today**

over:

> **Infrastructure that might be useful later.**

The purpose of the prototype is not to prove that the architecture can support a large game.

The purpose is to find out what **Merge House** actually wants to become.
