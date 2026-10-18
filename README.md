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

Same as the extension, with optional appearance and effect settings:

- Click the menu-bar clock to show or hide the clock.
- Click the clock face to set the alarm, click the centre circle to enable it. Right-click hides the clock.
- Option + click the menu-bar icon: icon turns orange, popup every hour.
- Control + click the menu-bar icon: test the alarm.
- Right-click the menu-bar icon to toggle the hourly alert or open Preferences.
- The menu-bar clock is an analog dial by default. In Preferences, choose a
  compact symbol or an analog dial with digital time; optionally show a
  seconds hand.
- Set the menu-bar click action to open the floating clock or a quick-clock
  popover with a larger analog preview, date, local time, optional second time
  zone, and alarm controls. Right-click also provides quick alarm actions.
- Preferences lets you enable the minute pulse, alarm glow, and ripple effects,
  or choose the Classic and Liquid Glass clock appearances. Choices are saved
  between launches; Restore Defaults returns to the original appearance and
  disables optional effects and hourly alerts.
- For Liquid Glass, choose Clear, Frosted, or Tinted glass and an optional
  None, Blue, Teal, Purple, or Amber tint. Choose Bounce, Fade, Zoom, Slide,
  or Spin for the clock's show and hide animation.
- Menu items and the status icon include VoiceOver labels and keyboard
  shortcuts where applicable.

## Roadmap

See the [clock roadmap](docs/CLOCK-ROADMAP.md) for implementation details
and compatibility notes.
