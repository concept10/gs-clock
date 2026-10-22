# Restructuring Cairo Clock like Dinky

Action plan for aligning the macOS clock with the layout and conventions of
`~/Developer/dinky-main` (Dinky). Nothing here is implemented yet.

## 1. Evaluation

### How Dinky is structured

| Area | Dinky |
|---|---|
| Build system | `Dinky.xcodeproj` (Xcode project, scheme, entitlements, `Info.plist`, asset catalog) |
| Reusable logic | Local SwiftPM package `DinkyCoreImage` (several library targets + tests) kept separate from the app target |
| App target folders | `Models/`, `Views/`, `Services/`, `Extensions/`, `Intents/`, `Resources/` (localized `.lproj`, `Help.md`) |
| Entry point | SwiftUI `@main App` with `@NSApplicationDelegateAdaptor(AppDelegate)` |
| Preferences | One `DinkyPreferences` observable model injected via environment; `PreferencesView` uses tabs and grouped forms |
| Strings | `Localizable.xcstrings`, `InfoPlist.xcstrings`, central `Strings.swift` |
| Tests | `DinkyTests` target plus SwiftPM tests, run in CI with `xcodebuild test` and `swift test` |
| Release | `release.sh` (version bump, build, DMG + zip, Homebrew cask, GitHub release), `Casks/`, `.github/workflows/ci.yml` and `homebrew-cask.yml` |
| Distribution extras | `LSMultipleInstancesProhibited`, update checker, launch-at-login manager, App Intents / Shortcuts, global hotkey manager |
| Docs and agent rules | `README.md`, `CLAUDE.md` (size and dependency rules), `agents.md` (UI conventions), `docs/`, `site/` |
| Targets | macOS 26, Apple Silicon, no third-party Swift dependencies |

### Where Cairo Clock is today

- SwiftPM-only executable (`macos/Package.swift`, deployment target macOS 13).
- Six flat files in `Sources/CairoClock/`; `AppDelegate.swift` (about 540 lines)
  mixes status item, panel, transitions, menus, preferences window, popover and
  alarm wiring.
- Preferences live as loose `UserDefaults` keys plus `@AppStorage` strings,
  duplicated between `AppDelegate` and `ClockPreferencesView`.
- `bundle.sh` writes an inline `Info.plist`; no asset catalog, no signing, DMG,
  tests, CI, localization or release automation.
- Legacy GNOME code is in `legacy/`; the repo root holds macOS docs.

### Gaps worth closing (ordered by value)

1. No single preferences model, so every new setting touches three places.
2. `AppDelegate` is too large; no separation of models, views and services.
3. No tests, so rendering and alarm logic are unverified.
4. No real app bundle project (icon, entitlements, Info.plist, signing).
5. No release pipeline or CI.
6. No localization, Launch at Login, single-instance guard or Shortcuts support.

### Deliberate differences

- **Menu-bar app, not a window app.** Dinky is a `WindowGroup` app; the clock stays an
  `LSUIElement` agent using `NSStatusItem` (Option and Control clicks need it).
  Keep the `NSApplicationDelegateAdaptor` pattern but not the main window scene.
- **Deployment target.** Dinky requires macOS 26. Decide whether the clock follows
  (simplifies Liquid Glass code by removing availability gates) or keeps macOS 13.
- **Xcode project vs SwiftPM.** An `.xcodeproj` is needed for asset catalogs, signing and
  `.icon` files. Keep SwiftPM for the core package.
- Adopt Dinky's rule of **no third-party dependencies**; the clock already complies.

## 2. Target layout

```
gs-clock/
├── CairoClock.xcodeproj
├── CairoClock/                    # app target
│   ├── CairoClockApp.swift        # @main, @NSApplicationDelegateAdaptor
│   ├── AppDelegate.swift          # lifecycle only
│   ├── Models/
│   │   ├── ClockPreferences.swift # single ObservableObject over UserDefaults
│   │   ├── Enums.swift            # Appearance, TransitionStyle, GlassStyle, GlassTint, Density
│   │   └── AlarmState.swift
│   ├── Views/
│   │   ├── ClockView.swift        # AppKit drawing
│   │   ├── ClockPanelView.swift
│   │   ├── ClockPopoverView.swift
│   │   ├── PreferencesView.swift  # tabbed: General, Appearance, Alarm, Menu Bar
│   │   └── MenuBarClockImage.swift
│   ├── Services/
│   │   ├── StatusItemController.swift
│   │   ├── PanelController.swift  # show/hide + transitions
│   │   ├── AlarmService.swift
│   │   ├── LaunchAtLoginManager.swift
│   │   └── UpdateChecker.swift    # optional
│   ├── Extensions/                # NSColor+Hex, View+AdaptiveGlass
│   ├── Intents/                   # optional App Shortcuts
│   ├── Resources/                 # en.lproj etc., Help.md
│   ├── Assets.xcassets, AppIcon.icon
│   ├── Info.plist, CairoClock.entitlements
│   ├── Localizable.xcstrings, InfoPlist.xcstrings
├── CairoClockCore/                # local SwiftPM package (optional)
│   ├── Package.swift
│   ├── Sources/CairoClockCore/    # clock math, drawing helpers, preferences model
│   └── Tests/CairoClockCoreTests/
├── CairoClockTests/
├── Casks/ , release.sh, .github/workflows/
├── docs/ , CLAUDE.md , agents.md
└── legacy/                        # GNOME extension, untouched
```

Move the macOS sources out of `macos/` once the Xcode project exists, or keep the
`macos/` folder and place the project inside it. Pick one in phase 4.

## 3. Phased action plan

Each phase leaves the app building and shippable.

### Phase 1: Internal refactor (no behaviour change)
- Create `ClockPreferences` (ObservableObject, `UserDefaults`-backed, one key enum);
  replace `PreferenceKey`, `applyPreferences()` field copying and per-view `@AppStorage`.
- Split `AppDelegate` into `StatusItemController`, `PanelController` (transitions),
  `AlarmService` and a thin `AppDelegate`.
- Group files into `Models/`, `Views/`, `Services/`, `Extensions/` inside the SwiftPM target.
- Move enums out of view files; extract `NSColor(hex:)` to `Extensions/`.
- Exit check: `swift build`, manual smoke test of every right-click item and effect.

### Phase 2: Tests and conventions
- Extract pure logic (hand angles, alarm matching, time zone formatting, hourly alert)
  into a core target; add XCTest coverage.
- Add `CLAUDE.md` (no dependencies, small footprint, Apple frameworks only) and
  `agents.md` (Settings-style UI rules: tabbed prefs, grouped forms, accessibility labels).
- Restructure `PreferencesView` into tabs: General, Appearance, Alarm, Menu Bar.

### Phase 3: Xcode project and app packaging
- Create `CairoClock.xcodeproj` with the app target and test target; add `Info.plist`
  (`LSUIElement`, `LSMultipleInstancesProhibited`), entitlements, asset catalog,
  `MenuBarIcon` template image and an `AppIcon.icon`.
- Replace `bundle.sh` with the Xcode Release scheme; keep it only as a fallback.
- Decide the macOS deployment target (see differences above).

### Phase 4: Platform features borrowed from Dinky
- `LaunchAtLoginManager` using `SMAppService`, exposed as a General preference.
- Optional global hotkey to toggle the clock (Dinky's `GlobalHotkeyManager` pattern).
- App Intents / Shortcuts: Show Clock, Set Alarm, Toggle Hourly Alert.
- Localization via `Localizable.xcstrings` and a central `Strings.swift`; ship English first.
- Optional lightweight `UpdateChecker` against GitHub releases.

### Phase 5: Release and CI
- Add `release.sh` adapted from Dinky: bump version, build Release, create DMG and zip,
  publish a GitHub release.
- Add `.github/workflows/ci.yml` (`xcodebuild test` plus `swift test`) and, if
  Homebrew distribution is wanted, `Casks/cairo-clock.rb` plus the cask workflow.
- Add notarization and signing notes to `docs/`.

### Phase 6: Docs and site
- Update `README.md` with the Dinky-style sections: system requirements, releases,
  features, install via Homebrew.
- Optional `site/` landing page; keep screenshots in `Screenshots/`.

## 4. Decisions needed

1. Raise the deployment target to macOS 26 (as Dinky does) or stay on 13?
2. Move to an Xcode project now, or finish phases 1 and 2 under SwiftPM first
   (recommended: yes, finish them first)?
3. Ship via DMG and Homebrew, or just build from source?
4. Which Dinky extras are wanted: Launch at Login, hotkey, Shortcuts, updater, localization?

## 5. Risks

- The Xcode project file is merge-hostile; make the structural moves in one commit.
- Raising the deployment target drops macOS 13 to 25 users.
- Splitting `AppDelegate` touches the click, transition and popover paths; test
  Option-click, Control-click and right-click after each step.
- Signing and notarization require an Apple Developer account.
