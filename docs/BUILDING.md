# Building and running

All commands run from the `macos/` directory. Build output (`.build/`, `build/`)
is git-ignored.

## Which artifact to use

| Goal | Command | Artifact | Use it for |
|---|---|---|---|
| Release app | `./bundle.sh` | `macos/build/CairoClock.app` | Daily use, copying to `/Applications`, sharing |
| Debug app | `./bundle.sh debug` | `macos/build/CairoClock-debug.app` | Testing a development build as a real app (menu-bar agent, Preferences, popover) |
| Quick debug run | `swift run` | `macos/.build/debug/CairoClock` (bare executable) | Fast edit-run loops with console output |
| Release executable | `swift build -c release` | `macos/.build/release/CairoClock` | CI or scripting only |

Use the `.app` bundles for anything user-facing. The bare executables have no
`Info.plist`, so they lack the `LSUIElement` setting (a Dock icon may appear) and
a bundle identifier, which makes them behave differently from the shipped app.

Both bundles are ad-hoc signed (`codesign --sign -`) by `bundle.sh`. They run on the
machine that built them; distributing to other Macs needs a Developer ID
signature and notarization (see `DINKY-STRUCTURE-PLAN.md`, phase 5).

## Notes

- Quit a running clock (right-click the menu-bar icon > Quit Cairo Clock) before
  launching a new build; otherwise you may be looking at the old one.
- The release and debug bundles share the same bundle identifier, so they also share
  saved preferences (`UserDefaults`). Avoid running both at once.
- Debug builds are unoptimized and animate less smoothly than release builds.
- Install: `cp -R build/CairoClock.app /Applications/`.
