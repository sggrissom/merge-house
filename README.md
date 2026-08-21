# Merge House

Prototype built one milestone at a time — see `plan.md`.

**Current milestone: 15 — Minimal Local Save.** Milestone 14 (several merge
chains) is done, plus a first pass at carrying: the character can wear and hold
what you merge, and what you made is still there next time you open the app.

## Explore tools

The Stuff panel's toolbar exists to poke at the prototype, not because a finished
game would have any of it:

| Button | What it does |
| --- | --- |
| **Get Stuff** | Deals one random level-one item onto the shelf. |
| **Catalog** | Every merge chain on one sheet: the artwork that exists, the filename of the artwork that does not, and how many of each are loose. Tap an entry to deal one out — no merging up to it first. |
| **Characters** | Everyone you can be, on the same kind of sheet. Tap one to switch to them; they keep where the character was standing and whatever it was using. |
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
already in the game. Only the second half genuinely varies: `girl.png` is a small
figure floating in a large square, so her hat sits at `0.80` of her height, while
the stick figure fills its frame and wants `0.93`. Anything a character leaves out
of `carryPoints` falls back to `CarryPoint.standard`, so you tune the one line that
looks wrong rather than teaching the hat about that character.

Still missing, and worth doing next: nothing is animated, a carry point is a
single fixed spot rather than a pose, and the character has no reaction to what
they are holding.

## Saving

What you made is written to `merge-house-save.json` in the app's Application
Support directory, and read back on launch: every loose item and where it is, what
the character is wearing and holding, who you are playing as, and what they are
sitting on.

Two decisions worth knowing about:

- **A file, not `UserDefaults`.** `UserDefaults` batches its disk writes, so a save
  made seconds before the app is killed is simply gone — which is exactly the case
  the save exists for. The file is written atomically, and it is pretty-printed
  JSON, so you can read it.
- **It survives you editing the catalogs.** That is the whole premise of this
  prototype, so the save stores item and character *ids* rather than positions in
  a list. An id that no longer exists is dropped and everything else is kept; a
  character or a piece of furniture that has gone falls back rather than throwing
  the save away; an item that is no longer something you can wear is put down on
  the floor rather than lost. There is no migration and there should not be one —
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

Anything with no artwork yet draws as a placeholder and captions itself with the
filename that would replace it. Drop `<imageName>.png` into the target's
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
