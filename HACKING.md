# Hacking on Cairo Clock

Notes for whoever maintains this next — including future you.

## Layout

| File | What it is |
| --- | --- |
| `extension.js` | Entry point: panel button, show/hide animation, alarm timer |
| `Clock.js` | The clock actor: an `St.DrawingArea` that draws itself with Cairo |
| `compat.js` | Click handling across GNOME versions (see below) |
| `pack.bash` | `gnome-extensions pack` + install into `~/.local/share` |
| `tools/test-shell.sh` | Run the extension in a throwaway headless shell |
| `extension-git_DrawingArea-version.js` | Upstream's older, unused variant. Not loaded. |

## The one thing that makes this awkward

GNOME Shell imports each extension's module **exactly once per session**
(`await import(uri)` in `ui/extensionSystem.js`, with no cache busting).
Disabling and re-enabling an extension re-runs `enable()` on the *already
imported* module, so it will not pick up edited source.

On X11 you could restart the shell with `Alt+F2` `r`. On Wayland you cannot.
So after editing, your options are:

1. `tools/test-shell.sh start` — a separate headless shell, ~30s round trip.
2. Log out and back in — needed only to run the change in your real session.

Use (1) while developing and (2) once at the end.

## Testing in the headless shell

```bash
tools/test-shell.sh start        # packs, installs, launches, prints errors
tools/test-shell.sh log cairo    # grep its log
tools/test-shell.sh stop
```

It runs on its own D-Bus session. To drive `gnome-extensions` against it:

```bash
export DBUS_SESSION_BUS_ADDRESS=$(cat "${TMPDIR:-/tmp}/gs-clock-test-shell/busaddr")
gnome-extensions info cairo@eexpss.gmail.com
gnome-extensions disable cairo@eexpss.gmail.com   # check disable() cleans up
gnome-extensions enable  cairo@eexpss.gmail.com
```

Anything the extension `console.log()`s lands in that log, which is the only
practical way to inspect state: `org.gnome.Shell.Eval` is disabled outside
Looking Glass's unsafe mode, and `org.gnome.Shell.Screenshot` refuses callers
it doesn't recognise.

### Simulating input

There is no user in a headless shell, so drive it with a virtual device from a
temporary hook inside `enable()`:

```js
const seat = Clutter.get_default_backend().get_default_seat();
const vd = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
const now = () => GLib.get_monotonic_time();   // NOT global.get_current_time()
vd.notify_absolute_motion(now(), x, y);
vd.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
vd.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
```

Timestamps must be monotonic microseconds. `global.get_current_time()` returns
the last *event* time, which is 0 in a fresh headless shell, and events stamped
with it are silently dropped.

### Checking what the clock draws

`Clock.on_draw()` only needs something with a `get_context()`, so it can be
rendered straight to a PNG from a temporary hook:

```js
const surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, size, size);
const cr = new Cairo.Context(surface);
clock.on_draw({get_context: () => cr});
surface.writeToPNG('/tmp/clock.png');
```

That is how `screenshot-gnome50.png` was produced.

## Porting to a new GNOME release

The two things that have broken here before, and will again:

- **Removed Clutter API.** Check what actually exists rather than guessing:
  ```bash
  strings /usr/lib/x86_64-linux-gnu/mutter-*/Clutter-*.typelib | grep -x ClickGesture
  ```
  That is how `Clutter.Canvas`, `Clutter.Color` and `Clutter.ClickAction` were
  each found to be gone.
- **Input.** GNOME 48+ routes pointer buttons through the gesture framework;
  actors no longer get `button-press-event`. `compat.js` wraps this, and is the
  first place to look if clicks stop working. Note it fails *silently* — the
  extension loads and draws fine, it just never responds.

Also bump `shell-version` in `metadata.json`, add a `CHANGELOG.md` entry, and
re-check `disable()` still removes every timeout and chrome actor: GNOME's
review process cares, and leaks survive across enable/disable cycles.

## Style

Upstream's code uses tabs, aligned `=`, and Chinese comments. Changes so far
have kept that rather than reformatting, to keep diffs against upstream
readable. If you ever reformat, do it in one commit that changes nothing else.
