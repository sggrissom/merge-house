# Merge House

Prototype built one milestone at a time — see `plan.md`.

**Current milestone: 15 — Minimal Local Save.** Milestone 14 (several merge
chains) is done, plus a first pass at carrying: the character can wear and hold
what you merge, and what you made is still there next time you open the app.

There is now more than one room, which `plan.md` lists as out of scope for the
prototype "unless requested" — it was requested. Everything else on that list is
still out.

## Explore tools

The Stuff panel's toolbar exists to poke at the prototype, not because a finished
game would have any of it:

| Button | What it does |
| --- | --- |
| **Get Stuff** | Deals one random level-one item onto the shelf. |
| **Catalog** | Every merge chain on one sheet: the artwork that exists, the filename of the artwork that does not, and how many of each are loose. Tap an entry to deal one out — no merging up to it first. |
| **Characters** | Everyone you can be, on the same kind of sheet. Tap one to switch to them; they keep where the character was standing and whatever it was using. |
| **Rooms** | Everywhere you can go, on the same kind of sheet: the backdrop that exists, the filename of the one that does not, what furniture is in each and how much you have left there. Tap one to go there. |
| **Tidy Up** | Re-lays the shelf out in catalog order, so a shoved-around pile becomes readable again. |
| **Merge All** | Merges every pair it can, repeatedly, until nothing else combines. The quick way to see the top of a chain. |
| **Labels** | Toggles the name tag under each item. |
| **Trash** | Drag one item onto it to bin that item; tap it to clear everything. |

The shelf deals items into slots rather than scattering them, and splits itself
into more rows as it fills, so `Get Stuff` never buries anything.

## Carrying things

Drag an item onto the character and they put it on: a Bow or a Crown goes on the
head, a Teddy or a Cake into a hand, a Dress onto the body. A carried item becomes
a child of the character, so it walks with them, sits with them, and lies down
with them on the bed. Drag it off again to take it off. Only one thing fits each
carry point — a second Bow replaces the first, and the one coming off is set down
beside them rather than lost.

The awkward part of this is that *how* a thing is worn varies, so it is split in
two halves that never have to know about each other:

- **The item says what kind of thing it is.** `carry: .head` in `ItemCatalog` means
  "worn on a head", and nothing more. An item with `carry: nil` is one you only
  ever put down.
- **The character says where that is on them.** `carryPoints` in
  `CharacterCatalog` maps a carry style to a `CarryPoint`: how far up, how far
  across, how big, and in front or behind — all as fractions of that character's
  drawn height.

That is what makes a fully customizable set of objects tractable. A new item works
on every character the day it is added, and a new character wears everything
already in the game. Only the second half genuinely varies — a Baby is mostly
head, so a hat sits lower on one than on a grown-up. Anything a character leaves
out of `carryPoints` falls back to `CarryPoint.standard`, so you tune the one line
that looks wrong rather than teaching the hat about that character. Most
characters need no entries at all, because a carry point is measured against the
figure rather than against the empty space around it — see below.

Still missing, and worth doing next: nothing is animated, a carry point is a
single fixed spot rather than a pose, and the character has no reaction to what
they are holding.

## Rooms

There is a house rather than a bedroom, and `Rooms` is how you walk around it.
The split is the same one carrying uses, one step out:

- **The furniture says what kind of thing it is.** `FurnitureCatalog` has a Bed
  that you lie on and are said to be `Sleeping`, a Rug you sit on and are
  `Playing`, a Table you cannot get on at all. That is the whole of what a Bed
  knows.
- **The room says where that is in it.** `RoomCatalog` lists a `FurniturePlacement`
  per piece — how far across, how far up, how big — all fractions of the room, so
  one line means the same corner on a phone, on an iPad and after a rotation.

So a new piece of furniture works in every room that lists it, and a new room
furnishes itself out of pieces that already know how they are used. A room with
two chairs gets two seats, told apart as `chair` and `chair-2`.

What travels and what stays is worth being exact about, because it is the only
thing about rooms a child will actually notice:

| | Going next door |
| --- | --- |
| The shelf of loose stuff | Comes with you — it is your pocket, not a piece of furniture. |
| What you are wearing and holding | Comes with you. |
| What you put down in a room | Stays in that room, exactly where you left it. |
| What you were sitting on | You stand up on the way out. The chair is still there when you come back. |

A room you are not in is still in the save and still counted — the Stuff readout
says "3 in other rooms" rather than quietly losing them — it simply is not drawn,
because you are not in it.

## How big things are

Two rules, and between them they are the whole answer to why something looks the
wrong size.

**Nothing is ever sized by its file.** Every PNG here is a canvas with the subject
floating somewhere inside it, and how much of the canvas the subject covers has
nothing to do with the thing it shows: `bear.png` fills 97% of its height,
`tiara.png` 42%, `sapling.png` 30%. Size a sprite by its file and you have sized
it by that accident — which is why a Tiara used to draw *smaller* than the Fancy
Bow it merges up from, and why the Girl stood a third shorter than she was asked
to, floating above the floor with a hit box twice as wide as she was. So `Artwork`
crops every drawing to its opaque pixels first, once, and it is the crop that gets
a size. New art still needs no preparation: drop the PNG in and it is trimmed for
you.

**An item's box is shaped to its drawing, at a fixed area.** A wide thing and a
tall thing of the same merge level should read as the same amount of item, which
fitting both into one shared box does not do — the wide one only ever touches the
sides. Sizing by area instead means the box is also honest about what it holds, so
what you can grab, what the merge ring is drawn around and what is kept inside the
room are all the drawing itself. An item with no artwork yet draws square at that
same area, so swapping the real one in changes the picture and not the layout.

The three places an item can be have three amounts of room, so each reads the same
range of merge levels at its own strength:

| Where | How levels read |
| --- | --- |
| In the room | `scale` at face value — full range, because showing one off is the point of carrying it in there. |
| On the shelf | Squeezed to fit one slot. Every slot is the same size, so at face value a Crown would simply cover its neighbours, and the fuller the shelf the worse it got. |
| On a character | Square root of `scale`, against the character's height. A Crown should read as grander than a Bow without being twice the size of the head it sits on. |

## Saving

What you made is written to `merge-house-save.json` in the app's Application
Support directory, and read back on launch: every loose item, where it is and
which room that was, what the character is wearing and holding, who you are
playing as, which room you are in, and what they are sitting on.

Two decisions worth knowing about:

- **A file, not `UserDefaults`.** `UserDefaults` batches its disk writes, so a save
  made seconds before the app is killed is simply gone — which is exactly the case
  the save exists for. The file is written atomically, and it is pretty-printed
  JSON, so you can read it.
- **It survives you editing the catalogs.** That is the whole premise of this
  prototype, so the save stores item and character *ids* rather than positions in
  a list. An id that no longer exists is dropped and everything else is kept; a
  character, a room or a piece of furniture that has gone falls back rather than
  throwing the save away; an item that is no longer something you can wear is put
  down on the floor rather than lost, and one left in a room that has since been
  deleted turns up in the room you load into rather than going with it. There is no migration and there should not be one —
  an unrecognised `version` starts fresh.

The save is written at most once a second while anything has changed, and
immediately when the app is about to go into the background. `Trash` clears
everything, which saves too — that is the way to start over.

## Adding content

Both catalogs work the same way, and neither needs the artwork to exist first.

- **A merge chain** is entries in `ItemCatalog.all`, linked by `mergesInto`. The
  bottom of a chain — whatever nothing else merges into — is dealt by `Get Stuff`
  automatically. `carry` says where on a character it goes, if anywhere.
- **A character** is one entry in `CharacterCatalog.all`: a name, the `imageName`
  the drawing will use, a `scale` relative to the default, the two colours their
  stick figure is drawn in until then, and any `carryPoints` the defaults get
  wrong for them.
- **A room** is one entry in `RoomCatalog.all`: a name, the `imageName` its
  backdrop will use, the wall and floor colours it stands in until then, and the
  furniture in it. Nothing else knows what a Kitchen is.
- **A piece of furniture** is one entry in `FurnitureCatalog.all`: a name, an
  `imageName`, a colour for the box it draws as until that exists, and a
  `FurnitureUse` — the pose it puts a character in and what they are said to be
  doing — or `nil` for something you only walk past.

Anything with no artwork yet draws as a placeholder and captions itself with the
filename that would replace it — a room without a backdrop is its own two colours
with `needs kitchen.png` under its name. The one exception is furniture standing
in a room that *has* been drawn: the backdrop has already drawn its own bed, and
the box on top of it is only there to be sat on, so it does not ask for artwork
that is on the screen already. Drop `<imageName>.png` into the target's
resources and it takes over — no code change.

## Build & run

```sh
open MergeHouse.xcodeproj
```

Select an iPad simulator and run. Or from the command line:

```sh
xcodebuild -scheme MergeHouse -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
```

Set your signing team in Xcode (target → Signing & Capabilities) before running on a device.
The bundle identifier is `com.grissom.MergeHouse` — change it if you'd rather use something else.

## Checking the landscape lock

Orientation is set two ways: `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`
plus `INFOPLIST_KEY_UIRequiresFullScreen` in the target's build settings, and
`AppDelegate.application(_:supportedInterfaceOrientationsFor:)` at runtime.

If the iPad build still rotates, check what actually landed in the built Info.plist:

```sh
plutil -p ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug-iphonesimulator/"Merge House.app"/Info.plist \
  | grep -iE 'orientation|fullscreen' -A4
```

If `UIRequiresFullScreen` is missing or is the string `"YES"` rather than a
boolean, set it from Xcode instead: target → General → "Requires full screen".
