# Cairo Clock roadmap

The roadmap features below are implemented in the macOS app. Existing click
behavior, Option-click hourly alerts, Control-click alarm testing, and clock
face alarm controls remain available.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#4CAF50', 'primaryTextColor': '#fff', 'primaryBorderColor': '#2E7D32', 'lineColor': '#333', 'secondBkgColor': '#E8F5E9', 'tertiaryColor': '#E8F5E9' } } }%%
graph LR
    A["1. Menu-bar<br/>Preferences"] --> B["2. Show & Hide<br/>Animations"]
    B --> C["3. Visual<br/>Effects"]
    C --> D["4. Liquid Glass<br/>Appearance"]
    D --> E["5. Menu-bar<br/>Improvements"]
    
    A -.->|✓ Implemented| A
    B -.->|✓ Implemented| B
    C -.->|✓ Implemented| C
    D -.->|✓ Implemented| D
    E -.->|✓ Implemented| E
    
    style A fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style B fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style C fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style D fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style E fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
```

## 1. Menu-bar preferences

Right-click the menu-bar item for a context menu with an Hourly Alert toggle
and Preferences. A normal left click still shows or hides the clock.

Preferences include:

- The clock appearance and three optional visual effects.
- A show/hide animation choice: Bounce, Fade, Zoom, Slide, or Spin.
- Restore Defaults, which returns to the Classic appearance and Bounce
  animation, and disables optional effects and hourly alerts.

Settings are stored with `UserDefaults` and persist between launches.

```mermaid
graph TD
    Prefs["Menu-bar Preferences"]
    
    Prefs --> Appearance["Appearance"]
    Prefs --> Animation["Animation"]
    Prefs --> Effects["Visual Effects"]
    Prefs --> Actions["Actions & Indicators"]
    Prefs --> Zones["Time Zones"]
    
    Appearance --> ClassicGlass["• Classic<br/>• Liquid Glass"]
    ClassicGlass --> Material["Material: Clear/<br/>Frosted/Tinted"]
    Material --> Tint["Tint: None/Blue/<br/>Teal/Purple/Amber"]
    
    Animation --> AnimTypes["• Bounce<br/>• Fade<br/>• Zoom<br/>• Slide<br/>• Spin"]
    
    Effects --> Pulse["• Minute Pulse"]
    Effects --> Glow["• Alarm Glow"]
    Effects --> Ripple["• Ripple"]
    
    Actions --> ClickMode["Click Action:<br/>Show/Hide or<br/>Open Popover"]
    Actions --> Density["Menu Density:<br/>Symbol/Analog/<br/>Analog+Time"]
    Actions --> Seconds["Optional<br/>Seconds Hand"]
    
    Zones --> Zone2["Secondary<br/>Time Zone"]
    
    style Prefs fill:#2C3E50,stroke:#1A252F,stroke-width:2px,color:#fff
    style Appearance fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Animation fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Effects fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Actions fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Zones fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
```

## 2. Show and hide animations

The selected animation is used in both directions when the clock view is shown
or hidden, including hiding with a right-click on the clock face:

1. **Bounce** — the existing bouncing scale-and-spin entrance and slide-away
   exit.
2. **Fade** — fade the clock in and out in place.
3. **Zoom** — scale the clock in and out around its centre.
4. **Slide** — slide the clock in from, and back toward, the right edge.
5. **Spin** — rotate the clock while scaling it in and out.

Bounce remains the default to preserve the existing transition.

```mermaid
graph LR
    Start["Start Animation"]
    
    Start --> Bounce["<b>Bounce</b><br/>Scale & Spin<br/>+ Slide Exit<br/>Default"]
    Start --> Fade["<b>Fade</b><br/>Opacity Change<br/>In Place"]
    Start --> Zoom["<b>Zoom</b><br/>Scale from<br/>Center"]
    Start --> Slide["<b>Slide</b><br/>From Right<br/>Edge"]
    Start --> Spin["<b>Spin</b><br/>Rotate +<br/>Scale"]
    
    Bounce --> Duration["1 Second<br/>Duration"]
    Fade --> Duration
    Zoom --> Duration
    Slide --> Duration
    Spin --> Duration
    
    Duration --> Easing["Easing:<br/>OutBounce or<br/>OutCubic"]
    
    style Bounce fill:#E91E63,stroke:#AD1457,stroke-width:2px,color:#fff
    style Fade fill:#00BCD4,stroke:#00838F,stroke-width:2px,color:#fff
    style Zoom fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style Slide fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
    style Spin fill:#9C27B0,stroke:#6A1B9A,stroke-width:2px,color:#fff
    style Start fill:#607D8B,stroke:#37474F,stroke-width:2px,color:#fff
    style Duration fill:#607D8B,stroke:#37474F,stroke-width:2px,color:#fff
    style Easing fill:#607D8B,stroke:#37474F,stroke-width:2px,color:#fff
```

## 3. Optional visual effects

The effects are independent preferences and off by default:

1. **Minute pulse** — a brief, subtle pulse of the clock face when the minute
   changes. It is suppressed when Reduce Motion is enabled.
2. **Alarm glow** — a short colored glow around the face when an alarm fires,
   complementing the existing swing.
3. **Ripple** — a restrained expanding ring when the clock appears or an alarm
   fires. It is suppressed when Reduce Motion is enabled.

Effects use short-lived timers and do not intercept input or replace the
existing appear/disappear animation.

```mermaid
%%{init: {'theme': 'default'} }%%
sequenceDiagram
    participant User
    participant Clock
    participant Effects
    
    Note over Effects: All Effects: 0.9s Duration<br/>Respect Reduce Motion
    
    rect rgb(76, 175, 80)
    Note over Clock,Effects: Minute Pulse
    User->>Clock: Minute Changes
    Clock->>Effects: Trigger Pulse
    Effects->>Clock: Subtle Scale Pulse
    end
    
    rect rgb(233, 30, 99)
    Note over Clock,Effects: Alarm Glow
    User->>Clock: Alarm Fires
    Clock->>Effects: Trigger Glow
    Effects->>Clock: Colored Glow Around Face
    end
    
    rect rgb(0, 188, 212)
    Note over Clock,Effects: Ripple
    User->>Clock: Clock Appears or Alarm
    Clock->>Effects: Trigger Ripple
    Effects->>Clock: Expanding Ring
    end
```

## 4. Liquid Glass appearance

The Preferences appearance selector offers **Classic** and **Liquid Glass**.
When Liquid Glass is selected, users can configure the glass material as Clear,
Frosted, or Tinted, and select None, Blue, Teal, Purple, or Amber tint. These
choices are saved with other preferences. The glass backdrop is drawn behind
the clock details so its hands, labels, hover indicator, and alarm display
stay legible.

```mermaid
graph TD
    LG["Liquid Glass Options"]
    
    LG --> Material["Glass Material"]
    Material --> Clear["Clear<br/>55% Opacity"]
    Material --> Frosted["Frosted<br/>82% Opacity"]
    Material --> Tinted["Tinted<br/>96% Opacity"]
    
    LG --> Tint["Tint Color"]
    Tint --> None["None"]
    Tint --> Blue["Blue"]
    Tint --> Teal["Teal"]
    Tint --> Purple["Purple"]
    Tint --> Amber["Amber"]
    
    style LG fill:#2C3E50,stroke:#1A252F,stroke-width:2px,color:#fff
    style Material fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Tint fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Clear fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style Frosted fill:#00BCD4,stroke:#00838F,stroke-width:2px,color:#fff
    style Tinted fill:#9C27B0,stroke:#6A1B9A,stroke-width:2px,color:#fff
    style None fill:#757575,stroke:#424242,stroke-width:2px,color:#fff
    style Blue fill:#2196F3,stroke:#1565C0,stroke-width:2px,color:#fff
    style Teal fill:#009688,stroke:#00695C,stroke-width:2px,color:#fff
    style Purple fill:#673AB7,stroke:#4527A0,stroke-width:2px,color:#fff
    style Amber fill:#FFA500,stroke:#E67E00,stroke-width:2px,color:#fff
```

### Glass Material & Tint Compatibility

| Material | Opacity | Tints Available | Use Case |
|----------|---------|-----------------|----------|
| **Clear** | 55% | All 5 options | Default, maximum transparency |
| **Frosted** | 82% | All 5 options | Balanced visibility & blur |
| **Tinted** | 96% | All 5 options | Enhanced color, less transparency |

On macOS 26 and later, the appearance uses SwiftUI's native Liquid Glass
effect. On macOS 13–25, it falls back to an AppKit HUD material while retaining
the translucent clock styling. The app's minimum deployment target remains
macOS 13.

```mermaid
graph TD
    Version["macOS Version"]
    
    Version -->|macOS 26+| Native["<b>Native Liquid Glass</b><br/>SwiftUI Effect<br/>Full Glass Materials<br/>All Tints Available"]
    Version -->|macOS 13-25| Fallback["<b>AppKit HUD Material</b><br/>Graceful Fallback<br/>Translucent Styling<br/>Same Tint Options"]
    
    Native --> Result1["<b>Result:</b> Modern,<br/>Native Experience"]
    Fallback --> Result2["<b>Result:</b> Consistent<br/>Look & Feel"]
    
    Result1 --> Support["✓ Supported on<br/>Minimum macOS 13"]
    Result2 --> Support
    
    style Version fill:#2C3E50,stroke:#1A252F,stroke-width:2px,color:#fff
    style Native fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style Fallback fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
    style Support fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style Result1 fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style Result2 fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
```

## 5. Native menu-bar improvements

The recommendations below are now implemented:

- **Analog indicator and density:** the status item defaults to a compact
  custom analog dial, with Compact Symbol and Analog + Time options. An
  optional seconds hand is off by default; without it, the dial redraws on
  minute changes. The hourly-alert highlight remains a separate rounded
  rectangle.
- **Quick clock popover:** shows a live analog preview, digital clock, date,
  local time, and optional second time zone. The click action can remain
  show/hide or open the popover.
- **Quick alarm actions:** the popover and right-click menu can open the clock
  face, enable or disable a selected alarm, and clear it.
- **Native preferences and materials:** grouped SwiftUI preferences configure
  menu-bar density, click action, second time zone, glass, effects, and
  animation. The popover uses Liquid Glass on macOS 26 and later, and a
  material fallback on earlier supported releases.
- **Accessibility and SF Symbols:** the status item has a spoken time and
  alert-state label, menu actions use system symbols and keyboard shortcuts,
  and the alarm state uses a subtle symbol bounce when Reduce Motion is off.

```mermaid
graph TD
    MenuBar["Menu-Bar Item"]
    
    MenuBar -->|Left Click| LeftAction["Show/Hide Clock<br/>or<br/>Open Popover<br/>Configurable"]
    
    MenuBar -->|Right Click| RightMenu["Context Menu:<br/>• Open Clock<br/>• Hourly Alert<br/>  Toggle<br/>• Preferences<br/>• Quick Alarm<br/>  Actions"]
    
    MenuBar -->|Option+Click| OptionClick["Toggle<br/>Hourly Alert<br/>Icon Highlights"]
    
    MenuBar -->|Control+Click| ControlClick["Test<br/>Alarm Effect"]
    
    Popover["Quick Popover<br/>Analog Preview<br/>Digital Time<br/>Date<br/>Time Zone<br/>Alarm Status"]
    
    LeftAction --> Popover
    RightMenu --> Popover
    
    MenuBar --> Density["Menu Density Options:<br/>• Compact Symbol<br/>• Analog Dial<br/>• Analog + Time"]
    
    style MenuBar fill:#2C3E50,stroke:#1A252F,stroke-width:2px,color:#fff
    style LeftAction fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style RightMenu fill:#3498DB,stroke:#2874A6,stroke-width:2px,color:#fff
    style OptionClick fill:#E91E63,stroke:#AD1457,stroke-width:2px,color:#fff
    style ControlClick fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
    style Popover fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style Density fill:#673AB7,stroke:#4527A0,stroke-width:2px,color:#fff
```

### User Interaction Model

| Input | Action | Result |
|-------|--------|--------|
| **Left Click** | Show/Hide or Open Popover | Toggle clock visibility or display quick preview |
| **Right Click** | Context Menu | Access hourly alerts, preferences, alarm actions |
| **Option + Click** | Toggle Hourly Alert | Icon highlights; alert fires each hour |
| **Control + Click** | Test Alarm | Play alarm effect for verification |
| **Clock Face Click** | Set/Toggle Alarm | Drag to set time, click center to enable/disable |

### MenuBarExtra migration assessment

The app deliberately retains `NSStatusItem`; it supports the established
Option-click hourly-alert and Control-click alarm-test shortcuts alongside
left- and right-click behavior. SwiftUI `MenuBarExtra` is not a drop-in
replacement for this interaction model. Reconsider a migration only after a
prototype proves parity for modifier clicks, the independent floating clock
panel, accessibility, and all three indicator densities. The current native
popover and SwiftUI preferences provide modern SwiftUI surfaces without
discarding the existing status-item behavior.

## Compatibility checks

Verify left-click show/hide, right-click menu behavior, right-click on the
clock face to hide it, alarm setting and firing, hourly alerts, saved
preferences, menu-bar indicator legibility at every density, VoiceOver and
keyboard access, optional seconds updates, popover time-zone display, and
operation on the minimum supported macOS version.

## Animation designer

Show and hide animations are a node graph edited from Preferences > Animations
tab. Each trigger (Show, Hide) is a left-to-right chain of
Fade, Scale, Spin, Slide, Flip, Wobble, Shake, Pop and Orbit nodes feeding the Clock. Nodes start together at the
trigger, so use Delay to stagger them; each has duration, easing (Linear, Ease
out, Ease in-out, Bounce), an amount and, for Slide, a direction. The graph is
stored as JSON in the `animationGraph` default (`AnimationGraph.swift`); the
ten transitions are available as presets. Possible follow-ups:
free-form branching wires, effect nodes (pulse, glow, ripple), and
import/export of designs.
