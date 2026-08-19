# Merge House

Prototype built one milestone at a time — see `plan.md`.

**Current milestone: 6 — Character Uses Furniture.**

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
