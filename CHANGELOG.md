# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0] - 2026-09-21

First release of the fork. The extension did not load at all on GNOME Shell
45 and later; this release ports it to the current extension API.

### Changed

- Ported to the GNOME 45+ ESM extension API: `gi://` and `resource:///`
  imports, `export default class extends Extension`, no `init()` or
  `ExtensionUtils`. The legacy `imports.*` loader was removed in GNOME 45,
  so the old entry point was never executed.
- Drawing moved from `Clutter.Canvas` to `St.DrawingArea`
  (`invalidate()` -> `queue_repaint()`). `Clutter.Canvas` no longer exists
  in Clutter-18 (GNOME 48+).
- Colors are plain 0-1 RGB values instead of `Clutter.Color`, which was
  also removed in Clutter-18.
- Clicks go through `Clutter.ClickGesture` (see `compat.js`). GNOME 48+
  routes pointer buttons through the gesture framework and no longer emits
  `button-press-event` on actors; `Clutter.ClickAction` is gone as well.
  The old signal path is kept as a fallback for GNOME 45-47.
- The panel button is created with `dontCreateMenu` so its built-in click
  gesture stays disabled and no empty menu appears.
- The panel button's "popup per hour" highlight uses a CSS style instead of
  `background_color`.
- `String.prototype.format()` replaced with a template literal.
- `metadata.json`: `shell-version` is now 45-50.

### Fixed

- The clock's `size` field collided with the `Clutter.Actor:size`
  (`Graphene.Size`) property and threw on enable; renamed to `_size`.
- Alarms never fired at hour 0 or 12, or at minute 0: the check was
  `if (h && m)`. The hour is now compared modulo 12 and null is tested
  explicitly.
- A due alarm fired up to six times, because the 10 second tick matched for
  the whole minute. It now fires once per minute.
- Named colors rendered as white. `Clutter.Color` components are 0-255 and
  were passed straight to `setSourceRGBA()`, which clamps at 1, so
  "light gray" and "dimgray" both came out white. The clock face and the
  inactive alarm readout now render in their intended grays.
- Module-level mutable state moved onto the instances, and timeouts and the
  chrome actor are torn down in `disable()`, so the extension survives being
  disabled and re-enabled.

[2.0]: https://github.com/concept10/gs-clock/releases/tag/v2.0
