import SwiftUI

/// Preferences window content: general settings plus the animation node designer.
struct ClockPreferencesRootView: View {
	let onChange: () -> Void
	let onPreview: (AnimationTrigger) -> Void

	var body: some View {
		TabView {
			ClockPreferencesView(onChange: onChange)
				.tabItem { Label("General", systemImage: "gearshape") }
			ClockAnimationDesignerView(onPreview: onPreview)
				.tabItem { Label("Animations", systemImage: "point.3.connected.trianglepath.dotted") }
		}
		.frame(width: 780, height: 640)
	}
}

struct ClockPreferencesView: View {
	@AppStorage("clockAppearance") private var appearance = "classic"
	@AppStorage("glassStyle") private var glassStyle = "frosted"
	@AppStorage("glassTint") private var glassTint = "none"
	@AppStorage("minutePulseEnabled") private var minutePulse = false
	@AppStorage("alarmGlowEnabled") private var alarmGlow = false
	@AppStorage("rippleEnabled") private var ripple = false
	@AppStorage("menuBarClockDensity") private var density = "analog"
	@AppStorage("menuBarShowsSeconds") private var showsSeconds = false
	@AppStorage("secondaryTimeZone") private var secondaryTimeZone = ""
	@AppStorage("menuBarClickAction") private var clickAction = "clock"
	@AppStorage("clockFontFamily") private var fontFamily = ClockView.defaultFontFamily

	private var fontFamilies: [String] {
		var families = NSFontManager.shared.availableFontFamilies
		if !families.contains(fontFamily) && fontFamily != ClockView.systemFontFamily { families.insert(fontFamily, at: 0) }
		return families
	}

	let onChange: () -> Void

	private let timeZones = [
		("", "None"),
		("America/Los_Angeles", "Los Angeles"),
		("America/New_York", "New York"),
		("Europe/London", "London"),
		("Europe/Paris", "Paris"),
		("Asia/Tokyo", "Tokyo"),
		("Australia/Sydney", "Sydney"),
	]

	var body: some View {
		Form {
			Section("Menu Bar") {
				Picker("Indicator", selection: $density) {
					ForEach(MenuBarClockDensity.allCases, id: \.rawValue) { option in
						Text(option.title).tag(option.rawValue)
					}
				}
				Picker("Click action", selection: $clickAction) {
					Text("Show or hide clock").tag("clock")
					Text("Open quick clock").tag("popover")
				}
				Toggle("Show seconds hand", isOn: $showsSeconds)
					.disabled(density == MenuBarClockDensity.symbol.rawValue)
			}

			Section("Time Zones") {
				Picker("Second time zone", selection: $secondaryTimeZone) {
					ForEach(timeZones, id: \.0) { identifier, name in
						Text(name).tag(identifier)
					}
				}
			}

			Section("Clock Appearance") {
				Picker("Appearance", selection: $appearance) {
					Text("Classic").tag("classic")
					Text("Liquid Glass").tag("liquidGlass")
				}
				Picker("Font", selection: $fontFamily) {
					Text("System").tag(ClockView.systemFontFamily)
					Divider()
					ForEach(fontFamilies, id: \.self) { family in
						Text(family).tag(family)
					}
				}
				Picker("Glass material", selection: $glassStyle) {
					ForEach(ClockPanelView.GlassStyle.allCases, id: \.rawValue) { option in
						Text(option.title).tag(option.rawValue)
					}
				}
				.disabled(appearance != "liquidGlass")
				Picker("Glass tint", selection: $glassTint) {
					ForEach(ClockPanelView.GlassTint.allCases, id: \.rawValue) { option in
						Text(option.title).tag(option.rawValue)
					}
				}
				.disabled(appearance != "liquidGlass")
			}

			Section("Effects and Animation") {
				Toggle("Minute pulse", isOn: $minutePulse)
				Toggle("Alarm glow", isOn: $alarmGlow)
				Toggle("Ripple on show and alarm", isOn: $ripple)
			}

			Section {
				Button("Restore Defaults", role: .destructive) {
					appearance = "classic"
					UserDefaults.standard.removeObject(forKey: AnimationGraph.defaultsKey)
					glassStyle = "frosted"
					glassTint = "none"
					minutePulse = false
					alarmGlow = false
					ripple = false
					density = "analog"
					showsSeconds = false
					secondaryTimeZone = ""
					clickAction = "clock"
					fontFamily = ClockView.defaultFontFamily
					UserDefaults.standard.set(false, forKey: "hourlyAlertEnabled")
					onChange()
				}
			}
		}
		.formStyle(.grouped)
		.padding(16)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onChange(of: appearance) { _ in onChange() }
		.onChange(of: glassStyle) { _ in onChange() }
		.onChange(of: glassTint) { _ in onChange() }
		.onChange(of: minutePulse) { _ in onChange() }
		.onChange(of: alarmGlow) { _ in onChange() }
		.onChange(of: ripple) { _ in onChange() }
		.onChange(of: density) { _ in onChange() }
		.onChange(of: showsSeconds) { _ in onChange() }
		.onChange(of: secondaryTimeZone) { _ in onChange() }
		.onChange(of: clickAction) { _ in onChange() }
		.onChange(of: fontFamily) { _ in onChange() }
	}
}
