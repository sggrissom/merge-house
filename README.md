# Merge House

Prototype built one milestone at a time — see `plan.md`.

**Current milestone: 14 — Several Merge Chains.**

## Explore tools

The Stuff panel's toolbar exists to poke at the prototype, not because a finished
game would have any of it:

| Button | What it does |
| --- | --- |
| **Get Stuff** | Deals one random level-one item onto the shelf. |
| **Catalog** | Every merge chain on one sheet: the artwork that exists, the filename of the artwork that does not, and how many of each are loose. Tap an entry to deal one out — no merging up to it first. |
| **Characters** | Everyone you can be, on the same kind of sheet. Tap one to become her; she keeps where she was standing and whatever she was using. |
| **Tidy Up** | Re-lays the shelf out in catalog order, so a shoved-around pile becomes readable again. |
| **Merge All** | Merges every pair it can, repeatedly, until nothing else combines. The quick way to see the top of a chain. |
| **Labels** | Toggles the name tag under each item. |
| **Trash** | Drag one item onto it to bin that item; tap it to clear everything. |

The shelf deals items into slots rather than scattering them, and splits itself
into more rows as it fills, so `Get Stuff` never buries anything.

## Adding content

Both catalogs work the same way, and neither needs the artwork to exist first.

- **A merge chain** is entries in `ItemCatalog.all`, linked by `mergesInto`. The
  bottom of a chain — whatever nothing else merges into — is dealt by `Get Stuff`
  automatically.
- **A character** is one entry in `CharacterCatalog.all`: a name, the `imageName`
  the drawing will use, a `scale` relative to the default, and the two colours her
  stick figure is drawn in until then.

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
