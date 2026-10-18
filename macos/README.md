# Cairo Clock for macOS

Native Swift port of the GNOME Shell extension, as a menu-bar app (macOS 13 or later).

| GNOME Shell extension | macOS port |
|---|---|
| `PanelMenu.Button` in the top bar | `NSStatusItem` in the menu bar |
| `Main.layoutManager.addChrome` actor | borderless floating `NSPanel` |
| `Clutter.Canvas` + Cairo + Pango | `NSView` + Core Graphics + `NSAttributedString` |
| `ease()` with `EASE_OUT_BOUNCE` | same bounce curve, driven by a timer |
| `global.display.get_sound_player()` | `NSSound` |

## Build and run

```bash
cd macos
swift run              # run directly
./bundle.sh            # or build build/CairoClock.app, then copy it to /Applications
```

## Usage

Same as the extension:

- Click the menu-bar clock to show or hide the clock.
- Click the clock face to set the alarm, click the centre circle to enable it. Right-click hides the clock.
- Option + click the menu-bar icon: icon turns orange, popup every hour.
- Control + click the menu-bar icon: test the alarm.
