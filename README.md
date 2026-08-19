# Merge House

Prototype built one milestone at a time — see `plan.md`.

**Current milestone: 13 — Data-Driven Item Definitions.**

## Build & run

```sh
open MergeHouse.xcodeproj
```

Select an iPad simulator and run. Or from the command line:

```sh
xcodebuild -scheme MergeHouse -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
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
