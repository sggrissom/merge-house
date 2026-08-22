# Merge House — What To Build Next

The prototype loop works: get stuff, merge it, wear it, carry it into a room,
find it there tomorrow. What follows is a list of things worth adding *other than
more art* — features that make what already exists feel more alive, or make new
toys out of systems that are already here.

Everything below obeys the rule the prototype was built on, because it is the
reason the prototype is pleasant to edit:

> **A thing knows what kind of thing it is. Wherever it goes knows where that is.**

An item says `carry: .head`; the character says where a head is. A bed says you
lie on it; the room says which corner it is in. Any feature that would make a Bow
know about a Baby, or make gameplay code know what a kitchen is, has been
rewritten below until it does not.

The same goes for the second rule: **missing artwork is a normal state, not an
error.** Anything new that could have a file behind it — a sound, a wallpaper, a
face — draws or plays as a labeled placeholder until the file lands, and says the
filename it is waiting for.

Ideas are grouped by what they buy, not by size. Each says roughly what it
touches and how big it is: **S** is an afternoon, **M** is a weekend, **L** is a
real feature with a save change in it.

---

## Tier 1 — Make what exists feel alive

Nothing here adds a new toy. All of it makes the toys already in the box feel
like they are made of something. This is the tier with the best ratio of delight
to work, and I would do all five before anything in Tier 2.

### 1. Sound (S)

The whole game is silent, which for a toy aimed at a child is the single biggest
thing missing. Not music — noises:

| When | What |
| --- | --- |
| Two things merge | A rising pop, pitched up by merge level, so a Crown sounds grander than a Bow |
| An item is picked up / put down | A soft tick and a thud |
| Something is worn | A little sparkle |
| Walking into another room | A door |
| Trash | A crumple |
| Topping out a chain | A fanfare (see #5) |

Fits the catalogs the way art does: `sound: "pop-teddy"` on an `ItemDefinition`,
falling back to a shared default per event, falling back to silence if neither
file exists. `SKAction.playSoundFileNamed` is the whole implementation; the
missing-file check needs a `Bundle.main.url(forResource:)` guard first, because
that action traps on a missing file rather than shrugging like `UIImage(named:)`
does.

*Touches:* a new `Sounds.swift`, one line each in `merge`, `attach`, `putDown`,
`goToRoom`, `discardItem`.

**A mute button is not optional.** It goes in the toolbar (see #14), and it is
saved — the first thing a parent will want at bedtime.

### 2. The character is alive (S–M)

The README already names this as the gap: "nothing is animated, and the character
has no reaction to what they are holding."

- **Idle:** a slow breathing bob and a periodic blink-scale, running forever on
  `characterBodyNode`. Two `SKAction.repeatForever`s, and it transforms how the
  room reads.
- **Pick-up:** they lean toward whatever is being dragged near them.
- **Reaction:** a bubble pops above them when something is given — a heart for a
  teddy, a star for a crown, a crumb for a cake.

The reaction is the part that wants the catalog split, or it turns into a
switch statement that knows what a teddy is. So: `ItemDefinition` gains
`reaction: Reaction?` (`.love`, `.proud`, `.yum`, `.silly`), and the *bubble*
knows how to draw each one. An item with no reaction gets a generic sparkle. The
character never learns what a teddy is.

*Touches:* `GameScene+Character.swift`, `ItemCatalog.swift`, `attach`.

### 3. Tap to walk (S)

Right now the character is dragged, which is fine, but tapping the floor and
watching them walk over is what a child expects and it costs almost nothing:
`SKAction.move(to:duration:)` with the duration from the distance, plus a small
side-to-side rock while moving so it reads as walking rather than sliding.
Dragging keeps working exactly as it does — this is an additional way in, not a
replacement, and the drag is still what you use to put someone on the bed.

Two details that matter: the walk is cancelled the moment a drag starts, and
tapping a piece of furniture walks them to it *and* sits them on it, which is
currently a fairly fiddly drag.

*Touches:* `GameScene+Input.swift`, `GameScene+Character.swift`.

### 4. Things stand on the floor and on tables (M)

An item dropped in the room stays exactly where it was let go, including in
mid-air. A room full of floating teddies is the main reason the dollhouse reads
as a scrapbook rather than a room.

Two changes, and they are the same change twice:

- **A room has a floor line.** `RoomDefinition` already has `floorHeight` for its
  placeholder; promote it to the real thing, and an item let go over the room
  drops to the floor with a short ease-out and a small squash. Let go *above*
  the floor line, it falls to it; let go below, it stays where it is (that is the
  front of the room, and a child arranging a picnic in the foreground should be
  allowed to).
- **Furniture can have a top.** `FurnitureDefinition` gains
  `surface: CGFloat?` — how far up its own height its top is, `nil` for something
  with no top. A table gets `0.9`, a rug `0.05`, a stove `1.0`, a bed `0.6`. Drop
  an item over a piece with a top and it lands *on* the top rather than falling
  past it to the floor, and it draws in front of that piece.

Same bargain as everything else: the table says it has a top and how high;
nothing has to know that a cake goes on tables.

*Touches:* `RoomCatalog.swift`, `GameScene+Items.swift` (`settleItem`,
`clampedItemPosition`), `GameScene+Room.swift`.

### 5. Celebration when a chain tops out (S)

Merging into a Crown or a Wedding Cake is currently indistinguishable from
merging into a Fancy Bow. Since `ItemCatalog.chains` already knows the top of
every chain, `mergesInto == nil` is a free trigger: a burst of confetti particles
in the item's own `placeholderColor`, a fanfare, and the new item scaling up
bigger before settling. Ten lines, and it gives the merging a point.

*Touches:* `GameScene+Items.swift` (`merge`).

---

## Tier 2 — New toys out of systems that already exist

### 6. Mixing: two *different* things that go together (M)

The three frostings are currently the odd ones out — nothing merges into them,
they merge into nothing, and putting one on a cake does nothing. That is a hole
with an obvious floor under it.

Add one field to `ItemDefinition`:

```swift
/// What this becomes when it is dropped on something else.
/// The key is the other item's id. Merging is a pair of the same thing;
/// this is a pair of different things, and it is how a Cake meets Frosting.
let mixes: [String: String]   // other item id -> result id
```

Red Frosting + Cake → Red Cake. Bow + Teddy → Teddy With A Bow. Leaf + Cupcake →
something silly. This is the cheapest possible source of *discovery*, which is the
thing merge games actually run on, and it needs no new mechanic — `mergeTarget`
already finds what an item was dropped on; it just currently insists the two be
identical.

Worth allowing mixing **in the room as well as on the shelf**, unlike merging.
Merging in the room is banned for a good reason (things you arranged should not
vanish into each other when pushed together), but mixing is deliberate enough —
you have to bring a specific other thing to it — that a child doing it on the
kitchen table is exactly the point.

*Touches:* `ItemCatalog.swift`, `GameScene+Items.swift` (`mergeTarget`,
`settleItem`, `merge`).

### 7. Furniture that does something (M)

Furniture is currently either something you sit on or scenery. A third kind: put
an item *in* it and it does something.

```swift
enum FurnitureAction {
    /// Swallows what you give it and gives it back when tapped. The Toy Box.
    case keeps
    /// Turns what you give it into something else, after a moment. The Stove.
    case makes([String: String])
    /// Deals one random item of a kind. The Fridge, the Wardrobe.
    case gives([String])
}
```

The Stove baking a Cupcake into a Cake, the Toy Box you can actually put toys in
and get them out of, a Wardrobe that hands out a dress. Each is one entry in
`FurnitureCatalog` and no gameplay code that knows what a stove is.

`keeps` is the one worth doing first: children put things in boxes. It also
quietly solves a real problem — a room can only hold so many visible things
before it is a mess, and a box you can tip out is a better answer than a Tidy Up
button.

*Touches:* `RoomCatalog.swift`, `GameScene+Room.swift`, `GameScene+Items.swift`,
one new field in `SavedItem` (what it is inside).

### 8. Hang things on the wall (S–M)

There is a `lona-misa.png` in the art folder — a painting — and nowhere to hang
it. Rooms are currently all floor.

The split works the same way one step out: an item gains `hangs: true` (a
painting, a clock, a mirror), and a room gains a wall region — everything above
its floor line already is one. Drop a hangable item on the wall and it sticks
where it was put instead of falling to the floor per #4; drop a non-hangable one
there and it falls, as it should.

This is a small change that makes a room look decorated rather than strewn, and
it pairs with #4 so naturally that they should probably be built together.

*Touches:* `ItemCatalog.swift`, `GameScene+Items.swift`.

### 9. The family is in the room with you (L)

The single biggest change in how the game *feels*, and the one a child asks for
first: Mum, Dad and the Baby all exist, and you can only ever be one of them,
alone in the house.

Let a character be **in a room without being the one you are playing**. Everyone
in `CharacterCatalog` gets a place: which room they are in, where they stand,
what they are wearing, what they are sitting on. You are one of them. Tapping
another one swaps to them — which is what the Characters sheet does today, except
now they stay behind rather than being replaced.

The scene work is mostly generalising what is already there: `character`,
`characterAnchor`, `characterUsing` and `characterNode` become a small
`Resident` struct and a list of them, and `layoutCharacter` runs per resident.
Carried items already store a carry style; they now also store *whose*.

- **The Characters sheet** becomes "who is here and where they are" rather than a
  picker, with a tap to become them and a drag to bring them along.
- **The save** gains a residents list. This is the one idea here that needs a
  `SavedGame.currentVersion` bump, which the design explicitly allows — an
  unrecognised version starts fresh. Worth doing before there are saves anybody
  minds losing.

*Touches:* `GameScene.swift`, `GameScene+Character.swift`, `GameScene+Sheets.swift`,
`SaveGame.swift`. The biggest job on this list, and the most worth it.

### 10. The collection book (S–M)

The Catalog sheet already lists every chain and every count. Give it a memory:
things you have never made draw as a grey silhouette with a `?`, and the sheet
reads "17 of 26 found" across the top. Making something for the first time gets
its own small flourish.

A `Set<String>` of discovered ids in the save, and a handful of lines in
`makeCatalogCell`. It costs almost nothing and it turns the Catalog from a
developer readout into a reason to keep merging — the child now has something to
fill in.

Two caveats: `Get Stuff` and the Catalog's own tap-to-deal must not count as
discovery (only *making* a thing counts, or the book fills itself in), and there
should be no scolding about what is missing — the silhouettes are an invitation.

*Touches:* `GameScene+Sheets.swift`, `SaveGame.swift` (an optional field, so no
version bump).

---

## Tier 3 — Bigger swings, still not complicated

### 11. Your own drawings become the game (M–L)

The whole project already runs on "drop a PNG in and it takes over". Right now
that requires a Mac, Xcode and a parent. Let it happen from inside the app: pick
a photo, or take one of a drawing on the kitchen table, and it becomes the
artwork for a catalog entry.

The mechanism is nearly free, because `Artwork.named` is already the single door
every drawing comes through and it already caches and trims. Give it one more
place to look: a `drawings/` folder in Application Support, checked *before* the
bundle, keyed by the same `imageName`. Photograph a drawing of a crown, save it
as `crown`, and every Crown in the game is now that drawing — on the shelf, on
the head, in the Catalog — with no code change and no rebuild, exactly as if the
PNG had been dropped in.

Two things make it work rather than just exist:

- **Cut out the background.** The trimming in `Artwork` only strips transparent
  pixels, and a photo of paper has none. A rough white-ish-corner flood fill to
  transparency is enough for a felt-tip drawing on white paper, and it is the
  difference between "my crown" and "a photo of a table".
- **Put it back.** A long-press on any Catalog cell offers *use my drawing* and
  *use the original*, so an experiment is never destructive.

*Touches:* `Artwork.swift`, `GameScene+Sheets.swift`, `PhotosUI` for the picker.
Needs a camera/photo permission string in the target settings.

This is the idea I would pick if only one thing on this list could be built. It
is the one that makes it *her* game rather than a game with her drawings in it.

### 12. The doll house (M)

`Rooms` is a list, which is a strange way to describe a house. Replace it — or
better, add a second view of it — with the house seen from the front: every room
as a lit box in a grid, drawn with its own backdrop, the furniture in it, the
things left in it, and whoever is standing in it (see #9). Tap a room to walk
there.

Everything needed to draw it exists — a room can already be rendered at any rect,
and items already know which room they are in. It is mostly a layout, and it
makes the house feel like a place rather than three unrelated backdrops.

*Touches:* `GameScene+Sheets.swift`, `GameScene+Room.swift`.

### 13. Decorating the room (M)

Rooms are fixed. Let them be changed:

- **Paint.** A wall colour and floor colour per room, chosen from a small palette,
  saved. Trivial for the placeholder rooms; for a room with a backdrop PNG it
  becomes a colour wash over the drawing, which is good enough and reads as
  lighting.
- **Day and night.** One toggle that tints the room blue and dims it, and turns
  on any lamp in it. Pairs beautifully with the bed — putting the baby to bed and
  turning the light off is a whole game on its own for a four-year-old.

Both are per-room and saved. Neither needs new art.

*Touches:* `RoomCatalog.swift`, `GameScene+Room.swift`, `SaveGame.swift`.

### 14. Play mode, and a toolbar that has room to grow (S)

Eight buttons in two columns is full, and half of them — Tidy Up, Merge All,
Labels, the Catalog's tap-to-deal — exist to poke at the prototype rather than to
be played with. Adding a mute button, a night toggle and a house view to that
grid makes it worse.

Split it: a **Play** toolbar with the four things a child uses (Get Stuff,
Rooms, Characters, Trash) and a small toggle that reveals the **Explore** tools
behind it. The state is saved, so the game opens the way it was left. It costs an
afternoon, it makes room for everything above, and it is the difference between a
prototype with a debug menu and a toy.

*Touches:* `GameScene+Stuff.swift`.

### 15. Names (S)

Let the Girl be called by the name of the child playing. One tap on a character
in the Characters sheet, a text field, and it is saved. The house gets a name
too, on the menu. Nothing mechanical changes; it is the cheapest ownership on
this list.

*Touches:* `GameScene+Sheets.swift`, `SaveGame.swift`.

---

## What needs assets, and what does not

Worth reading the list on this axis too, because "more art" is the constraint
that actually binds here.

**Nothing below is blocked on an asset.** The placeholder rule covers everything
new the same way it covers drawings: a sound with no file behind it is silence, a
wallpaper with no file is a colour, a face with no file is the face you have. So
every idea can be built to completion, played, and judged before anybody draws or
records anything.

| Idea | Needs a new asset? |
| --- | --- |
| #2 alive, #3 walk, #4 floors, #5 confetti | **No.** All of it is `SKAction`s on the sprite already there — bob, lean, squash, rotate — plus shapes for bubbles and confetti. |
| #6 mixing | Only the *results*. A Red Cake with no drawing is a captioned box, which is playable but dull, so this one is best built alongside the art for whatever it makes. |
| #8 wall, #10 book, #12 doll house, #14 toolbar, #15 names | **No.** All of it is layout over drawings that exist. The book's silhouettes are the existing art, flattened to grey. |
| #13 decorating | **No.** Paint and night are colour washes over what is already drawn. |
| #7 furniture, #9 family | **No new art needed to build them** — every character and every piece of furniture in them already exists or already placeholders. |
| #11 own drawings | **No** — it is the feature that *makes* assets. |
| #1 sound | **Yes, this is the only one.** See below. |

### The one exception, and why it is cheaper than it looks

Sound is the only idea here that genuinely cannot be finished without new files.
But they are not files that compete with the drawing, and there are three ways to
get them:

1. **Synthesize them.** A merge pop is a sine blip with a fast envelope, pitched
   by merge level. `AVAudioEngine` with a source node, no files at all, and the
   "a Crown sounds grander than a Bow" behaviour comes free because pitch is a
   parameter rather than a recording. This is the one to do.
2. **Record them.** A child making the pop noise with her mouth is free, takes an
   afternoon, and is the most on-theme audio this game could possibly have.
3. **A CC0 pack.** Kenney's audio sets are public domain and about the right
   register.

### The one place #2 is not free

A character is a single flat PNG, so a *real* blink — or any change of
expression — is a second drawing, not a transform. What #2 describes is a
blink-scale: a quick squash of the whole figure, which reads as alive without
touching the face.

If expressions are wanted later, the shape is the one the catalogs already use:
`imageName` becomes a small optional set — `girl`, `girl-blink`, `girl-happy` —
each falling back to the base drawing when its file is missing, so a character
with one drawing keeps working and a character with four gets a face. Worth
leaving room for. Not worth building until somebody wants to draw the four.

---

## What I would build, in order

1. **Sound** (#1) and **the character being alive** (#2) — one weekend, and the
   game stops feeling like a diagram.
2. **Things stand on the floor** (#4) with **hanging things on the wall** (#8) —
   the rooms start looking arranged rather than strewn.
3. **Play mode** (#14) — a small job, but everything after this needs somewhere
   to put a button.
4. **Mixing** (#6) and **the collection book** (#10) — a reason to keep merging.
5. **The family in the room** (#9) — the big one.
6. **Your own drawings** (#11) — the one that makes it hers.

Tap-to-walk (#3), celebrations (#5), furniture that does something (#7), the
doll house (#12), decorating (#13) and names (#15) can be slotted in wherever
they are wanted; none of them blocks anything else.

---

## Deliberately not on this list

The original plan's list of things to refuse still stands, and it stands harder
now that the game is fun: no currencies, no energy, no timers you wait out, no
daily rewards, no quests, no store, no scores, no accounts, no networking, no
ads, no analytics. A merge game for a child should have nothing in it that is
trying to get her to come back tomorrow — she will or she will not, and either
is fine.

Two more, specific to where the code is now:

- **No save migration.** An unrecognised `version` starting fresh is a deliberate
  choice and a good one. If #9 needs a version bump, take it now while the saves
  are cheap, rather than growing a migration layer to avoid it.
- **No animation framework, no ECS, no scene graph abstraction.** Everything
  above is `SKAction`s and fields on a catalog struct. The reason this codebase is
  pleasant to add to is that there is nothing between an idea and the thing that
  draws it.
