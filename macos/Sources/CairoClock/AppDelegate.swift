import AppKit
import SwiftUI

/// Port of extension.js: the menu-bar icon, the floating clock panel,
/// the appear/disappear animation and the alarm timer.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusItem: NSStatusItem!
	private var panel: NSPanel!
	private var panelView: ClockPanelView!
	private var clock: ClockView!
	private var preferencesWindow: NSWindow?
	private var clockPopover: NSPopover?
	private var popoverHost: NSHostingController<ClockPopoverView>?
	private var hourlyAlertMenuItem: NSMenuItem?
	private var hourlyAlertIndicator: CALayer?
	private var size: CGFloat = 400
	private var popPerHour = false	//   整点弹出报时`````` 。 
	private var alarmTimer: Timer?
	private var statusClockTimer: Timer?
	private var lastCheckedMinute: Date?
	private var transitionStyle = TransitionStyle.bounce
	private var menuBarDensity = MenuBarClockDensity.analog
	private var menuBarShowsSeconds = false
	private var secondaryTimeZone = ""
	private var clickAction = "clock"

	private enum PreferenceKey {
		static let hourlyAlert = "hourlyAlertEnabled"
		static let minutePulse = "minutePulseEnabled"
		static let alarmGlow = "alarmGlowEnabled"
		static let ripple = "rippleEnabled"
		static let appearance = "clockAppearance"
		static let transition = "clockTransition"
		static let glassStyle = "glassStyle"
		static let glassTint = "glassTint"
		static let menuBarDensity = "menuBarClockDensity"
		static let menuBarShowsSeconds = "menuBarShowsSeconds"
		static let secondaryTimeZone = "secondaryTimeZone"
		static let clickAction = "menuBarClickAction"
	}

	private enum TransitionStyle: String, CaseIterable {
		case bounce
		case fade
		case zoom
		case slide
		case spin

		var title: String {
			switch self {
			case .bounce: "Bounce"
			case .fade: "Fade"
			case .zoom: "Zoom"
			case .slide: "Slide"
			case .spin: "Spin"
			}
		}
	}

	private var animTimer: Timer?
	private var animStart = Date()
	private var animStep: ((CGFloat) -> Void)?
	private var animDone: (() -> Void)?
	private var usesBounce = false

	static func main() {
		let app = NSApplication.shared
		let delegate = AppDelegate()
		app.delegate = delegate
		app.setActivationPolicy(.accessory)	// menu-bar only, no Dock icon
		app.run()
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		size = floor((NSScreen.main?.frame.height ?? 1600) / 4)

		clock = ClockView(size: size)
		clock.onHide = { [weak self] in self?.hidePanel() }
		clock.onAlarmChange = { [weak self] in self?.refreshPopover() }
		panelView = ClockPanelView(clock: clock)

		panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
			styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = false
		panel.level = .floating
		panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
		panel.hidesOnDeactivate = false
		panel.acceptsMouseMovedEvents = true
		panel.contentView = panelView
		panel.center()
		loadPreferences()

		statusItem = NSStatusBar.system.statusItem(withLength: menuBarDensity.width)
		if let button = statusItem.button {
			button.wantsLayer = true
			button.imagePosition = .imageOnly
			button.target = self
			button.action = #selector(statusClicked(_:))
			button.sendAction(on: [.leftMouseDown, .rightMouseDown])
		}
		installHourlyAlertIndicator()
		updateMenuBarClock()
		updateStatusClockTimer()

		alarmTimer = Timer.scheduledTimer(timeInterval: 10, target: self,
			selector: #selector(checkAlarm), userInfo: nil, repeats: true)
	}

	@objc private func statusClicked(_ sender: NSStatusBarButton) {
		if NSApp.currentEvent?.type == .rightMouseDown {
			showStatusMenu(for: sender)
			return
		}
		let flags = NSApp.currentEvent?.modifierFlags ?? []
		if flags.contains(.option) {
			popPerHour.toggle()
			UserDefaults.standard.set(popPerHour, forKey: PreferenceKey.hourlyAlert)
			setHourlyAlertIndicator(popPerHour)
			hourlyAlertMenuItem?.state = popPerHour ? .on : .off
			return
		}
		if flags.contains(.control) {
			alarm()
			return
		}
		if clickAction == "popover" {
			togglePopover(for: sender)
		} else if panel.isVisible {
			hidePanel()
		} else {
			showPanel()
		}
	}

	// MARK: - Appear / disappear (port of ease_effect)

	private func showPanel() {
		let mouse = NSEvent.mouseLocation
		var origin = NSPoint(x: mouse.x - size / 2 + 10, y: mouse.y - 30 - size)
		if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
			let f = screen.visibleFrame
			origin.x = min(max(origin.x, f.minX), f.maxX - size)
			origin.y = min(max(origin.y, f.minY), f.maxY - size)
		}
		panel.setFrameOrigin(origin)
		panel.orderFrontRegardless()
		clock.clockAppeared()
		let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
			?? NSRect(origin: origin, size: panel.frame.size)
		let startX = slideOffsetX(from: origin.x, visibleFrame: visibleFrame)
		switch transitionStyle {
		case .bounce:
			panel.alphaValue = 10 / 255
			clock.introScale = 0.1
			clock.introRotation = 360
		case .fade:
			panel.alphaValue = 10 / 255
			clock.introScale = 1
			clock.introRotation = 0
		case .zoom:
			panel.alphaValue = 1
			clock.introScale = 0.1
			clock.introRotation = 0
		case .slide:
			panel.alphaValue = 1
			panel.setFrameOrigin(NSPoint(x: startX, y: origin.y))
			clock.introScale = 1
			clock.introRotation = 0
		case .spin:
			panel.alphaValue = 1
			clock.introScale = 0.75
			clock.introRotation = 360
		}
		animate({ t in
			switch self.transitionStyle {
			case .bounce:
				self.panel.alphaValue = 10 / 255 + (1 - 10 / 255) * t
				self.clock.introScale = 0.1 + 0.9 * t
				self.clock.introRotation = 360 * (1 - t)
			case .fade:
				self.panel.alphaValue = 10 / 255 + (1 - 10 / 255) * t
			case .zoom:
				self.clock.introScale = 0.1 + 0.9 * t
			case .slide:
				self.panel.setFrameOrigin(NSPoint(x: startX + (origin.x - startX) * t, y: origin.y))
			case .spin:
				self.clock.introScale = 0.75 + 0.25 * t
				self.clock.introRotation = 360 * (1 - t)
			}
		}, completion: {}, usesBounce: transitionStyle == .bounce)
	}

	private func hidePanel() {
		let start = panel.frame.origin
		let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
			?? NSRect(origin: start, size: panel.frame.size)
		let targetX = visibleFrame.maxX
		let slideX = slideOffsetX(from: start.x, visibleFrame: visibleFrame)
		clock.introScale = 1
		clock.introRotation = 0
		animate({ t in
			switch self.transitionStyle {
			case .bounce:
				self.panel.setFrameOrigin(NSPoint(x: start.x + (targetX - self.size * 0.4 - start.x) * t, y: start.y))
				self.panel.alphaValue = 1 - (1 - 10 / 255) * t
				self.clock.introScale = 1 - 0.6 * t
			case .fade:
				self.panel.alphaValue = 1 - (1 - 10 / 255) * t
			case .zoom:
				self.clock.introScale = 1 - 0.9 * t
			case .slide:
				self.panel.setFrameOrigin(NSPoint(x: start.x + (slideX - start.x) * t, y: start.y))
			case .spin:
				self.clock.introScale = 1 - 0.25 * t
				self.clock.introRotation = -360 * t
			}
		}, completion: {
			self.panel.orderOut(nil)
			self.panel.alphaValue = 1	// 及时恢复透明度。
			self.clock.introScale = 1	// 恢复比率，否则闹钟变小。
			self.clock.introRotation = 0
			self.panel.setFrameOrigin(start)	// 恢复位置，否则闹钟乱跑。
		}, usesBounce: transitionStyle == .bounce)
	}

	private func slideOffsetX(from x: CGFloat, visibleFrame: NSRect) -> CGFloat {
		let right = min(x + size * 0.8, visibleFrame.maxX - size)
		return right > x ? right : max(x - size * 0.8, visibleFrame.minX)
	}

	private func animate(_ step: @escaping (CGFloat) -> Void, completion: @escaping () -> Void,
			usesBounce: Bool = false) {
		finishAnimation()
		animStep = step
		animDone = completion
		animStart = Date()
		self.usesBounce = usesBounce
		step(0)
		animTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60, target: self,
			selector: #selector(animTick), userInfo: nil, repeats: true)
	}

	@objc private func animTick() {
		let p = CGFloat(min(Date().timeIntervalSince(animStart), 1))	// duration 1s
		animStep?(usesBounce ? Self.easeOutBounce(p) : Self.easeOutCubic(p))
		if p >= 1 { finishAnimation() }
	}

	private func finishAnimation() {
		guard let timer = animTimer else { return }
		timer.invalidate()
		animTimer = nil
		animStep?(1)
		usesBounce = false
		let done = animDone
		animStep = nil
		animDone = nil
		done?()
	}

	/// Same curve as Clutter.AnimationMode.EASE_OUT_BOUNCE.
	static func easeOutBounce(_ t: CGFloat) -> CGFloat {
		let n: CGFloat = 7.5625, d: CGFloat = 2.75
		if t < 1 / d { return n * t * t }
		if t < 2 / d { let t = t - 1.5 / d; return n * t * t + 0.75 }
		if t < 2.5 / d { let t = t - 2.25 / d; return n * t * t + 0.9375 }
		let t = t - 2.625 / d
		return n * t * t + 0.984375
	}

	private static func easeOutCubic(_ t: CGFloat) -> CGFloat {
		1 - pow(1 - t, 3)
	}

	// MARK: - Alarm

	private func alarm() {
		NSSound(named: "Glass")?.play()
		panel.orderFrontRegardless()
		clock.alarmEffectsStarted()
		clock.swing()
	}

	@objc private func checkAlarm() {
		let now = Date()
		let calendar = Calendar.current
		if let minute = calendar.dateInterval(of: .minute, for: now)?.start {
			if let lastCheckedMinute, minute != lastCheckedMinute {
				clock.minuteChanged()
				updateMenuBarClock()
				refreshPopover()
			}
			lastCheckedMinute = minute
		}
		let c = calendar.dateComponents([.hour, .minute, .second], from: now)
		let h0 = (c.hour ?? 0) % 12
		let m0 = c.minute ?? 0
		let s0 = c.second ?? 0
		if let a = clock.alarm, a.h % 12 == h0, a.m == m0 { alarm() }
		if popPerHour, m0 == 0, s0 < 10 { alarm() }	// 整点弹出报时
		clock.needsDisplay = true
	}
private func showStatusMenu(for button: NSStatusBarButton) {
	let menu = NSMenu()
let quickClock = NSMenuItem(title: "Quick Clock", action: #selector(openPopoverFromMenu), keyEquivalent: "")
quickClock.target = self
quickClock.keyEquivalent = "q"
quickClock.keyEquivalentModifierMask = [.command, .option]
quickClock.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
menu.addItem(quickClock)
let showClock = NSMenuItem(title: "Open Clock Face", action: #selector(openClockFromMenu), keyEquivalent: "")
showClock.target = self
showClock.keyEquivalent = "o"
showClock.keyEquivalentModifierMask = [.command, .shift]
showClock.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
menu.addItem(showClock)
let alarmItem = NSMenuItem(title: clock.isAlarmEnabled ? "Disable Alarm" : "Enable Alarm",
	action: #selector(toggleAlarmFromMenu), keyEquivalent: "")
alarmItem.target = self
alarmItem.isEnabled = clock.hasAlarmTime
alarmItem.image = NSImage(systemSymbolName: clock.isAlarmEnabled ? "alarm.waves.left.and.right" : "alarm",
	accessibilityDescription: nil)
menu.addItem(alarmItem)
let clearAlarmItem = NSMenuItem(title: "Clear Alarm", action: #selector(clearAlarmFromMenu), keyEquivalent: "")
clearAlarmItem.target = self
clearAlarmItem.isEnabled = clock.hasAlarmTime
clearAlarmItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
menu.addItem(clearAlarmItem)
menu.addItem(.separator())
hourlyAlertMenuItem = NSMenuItem(title: "Hourly Alert", action: #selector(toggleHourlyAlert), keyEquivalent: "")
	hourlyAlertMenuItem?.target = self
	hourlyAlertMenuItem?.state = popPerHour ? .on : .off
	if let hourlyAlertMenuItem { menu.addItem(hourlyAlertMenuItem) }
	menu.addItem(.separator())
	let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: "")
	preferencesItem.target = self
	preferencesItem.keyEquivalent = ","
	preferencesItem.keyEquivalentModifierMask = [.command]
	menu.addItem(preferencesItem)
	menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
}

@objc private func openPopoverFromMenu() {
	guard let button = statusItem.button else { return }
	showPopover(for: button)
}

@objc private func openClockFromMenu() {
	showPanel()
}

@objc private func toggleAlarmFromMenu() {
	clock.toggleAlarmEnabled()
}

@objc private func clearAlarmFromMenu() {
	clock.clearAlarm()
}

private func installHourlyAlertIndicator() {
	guard let button = statusItem.button else { return }
	let indicator = CALayer()
	indicator.cornerRadius = 6
	button.layer?.insertSublayer(indicator, at: 0)
	hourlyAlertIndicator = indicator
	setHourlyAlertIndicator(popPerHour)
}

private func setHourlyAlertIndicator(_ enabled: Bool) {
	guard let button = statusItem?.button else { return }
	hourlyAlertIndicator?.frame = button.bounds.insetBy(dx: 2, dy: 2)
	hourlyAlertIndicator?.backgroundColor = enabled ? NSColor(hex: 0xC98A38).cgColor : nil
	updateStatusAccessibility()
}

private func updateMenuBarClock() {
	guard let button = statusItem?.button else { return }
	statusItem.length = menuBarDensity.width
	if menuBarDensity == .symbol {
		let image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
		image?.isTemplate = true
		button.image = image
	} else {
		button.image = MenuBarClockImage.make(date: Date(), density: menuBarDensity,
			showsSeconds: menuBarShowsSeconds)
		button.image?.isTemplate = false
	}
	setHourlyAlertIndicator(popPerHour)
}

private func updateStatusAccessibility() {
	guard let button = statusItem?.button else { return }
	let formatter = DateFormatter()
	formatter.timeStyle = .short
	formatter.dateStyle = .none
	let alertState = popPerHour ? "hourly alert on" : "hourly alert off"
	button.setAccessibilityLabel("Cairo Clock, \(formatter.string(from: Date())), \(alertState)")
	button.setAccessibilityHelp("Click to \(clickAction == "popover" ? "open the quick clock" : "show or hide the clock"). Right-click for clock and alarm actions. Option-click toggles the hourly alert; Control-click tests the alarm.")
	button.toolTip = "Cairo Clock · \(formatter.string(from: Date())) · \(alertState)"
}

private func updateStatusClockTimer() {
	statusClockTimer?.invalidate()
	if menuBarShowsSeconds, menuBarDensity != .symbol {
		statusClockTimer = Timer.scheduledTimer(timeInterval: 1, target: self,
			selector: #selector(statusClockTick), userInfo: nil, repeats: true)
	} else if menuBarDensity != .symbol {
		scheduleMinuteIndicatorUpdate()
	} else {
		statusClockTimer = nil
	}
}

@objc private func statusClockTick() {
	updateMenuBarClock()
	refreshPopover()
	if !menuBarShowsSeconds { scheduleMinuteIndicatorUpdate() }
}

private func scheduleMinuteIndicatorUpdate() {
	statusClockTimer?.invalidate()
	let second = Calendar.current.component(.second, from: Date())
	let interval = TimeInterval(max(1, 60 - second))
	statusClockTimer = Timer.scheduledTimer(timeInterval: interval, target: self,
		selector: #selector(statusClockTick), userInfo: nil, repeats: false)
}

private func togglePopover(for button: NSStatusBarButton) {
	if clockPopover?.isShown == true {
		clockPopover?.performClose(nil)
	} else {
		showPopover(for: button)
	}
}

private func showPopover(for button: NSStatusBarButton) {
	if clockPopover == nil {
		let popover = NSPopover()
		popover.behavior = .transient
		let host = NSHostingController(rootView: makePopoverView())
		popoverHost = host
		popover.contentViewController = host
		clockPopover = popover
	} else {
		popoverHost?.rootView = makePopoverView()
	}
	clockPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
}

private func makePopoverView() -> ClockPopoverView {
	ClockPopoverView(
		alarmDescription: clock.alarmDescription,
		alarmEnabled: clock.isAlarmEnabled,
		secondaryTimeZoneIdentifier: secondaryTimeZone,
		onShowClock: { [weak self] in
			self?.clockPopover?.performClose(nil)
			if self?.panel.isVisible == true {
				self?.panel.orderFrontRegardless()
			} else {
				self?.showPanel()
			}
		},
		onToggleAlarm: { [weak self] in self?.clock.toggleAlarmEnabled() },
		onClearAlarm: { [weak self] in self?.clock.clearAlarm() },
		onPreferences: { [weak self] in
			self?.clockPopover?.performClose(nil)
			self?.showPreferences()
		}
	)
}

private func refreshPopover() {
	guard clockPopover?.isShown == true else { return }
	popoverHost?.rootView = makePopoverView()
}

@objc private func toggleHourlyAlert() {
	popPerHour.toggle()
	UserDefaults.standard.set(popPerHour, forKey: PreferenceKey.hourlyAlert)
	setHourlyAlertIndicator(popPerHour)
	hourlyAlertMenuItem?.state = popPerHour ? .on : .off
}

private func loadPreferences() {
	applyPreferences()
}

private func applyPreferences() {
	let defaults = UserDefaults.standard
	popPerHour = defaults.bool(forKey: PreferenceKey.hourlyAlert)
	clock.minutePulseEnabled = defaults.bool(forKey: PreferenceKey.minutePulse)
	clock.alarmGlowEnabled = defaults.bool(forKey: PreferenceKey.alarmGlow)
	clock.rippleEnabled = defaults.bool(forKey: PreferenceKey.ripple)
	transitionStyle = TransitionStyle(rawValue: defaults.string(forKey: PreferenceKey.transition) ?? "")
		?? .bounce
	let appearance = ClockView.Appearance(rawValue: defaults.string(forKey: PreferenceKey.appearance) ?? "")
		?? .classic
	let glassStyle = ClockPanelView.GlassStyle(rawValue: defaults.string(forKey: PreferenceKey.glassStyle) ?? "")
		?? .frosted
	let glassTint = ClockPanelView.GlassTint(rawValue: defaults.string(forKey: PreferenceKey.glassTint) ?? "")
		?? .none
	menuBarDensity = MenuBarClockDensity(rawValue: defaults.string(forKey: PreferenceKey.menuBarDensity) ?? "")
		?? .analog
	menuBarShowsSeconds = defaults.bool(forKey: PreferenceKey.menuBarShowsSeconds)
	secondaryTimeZone = defaults.string(forKey: PreferenceKey.secondaryTimeZone) ?? ""
	clickAction = defaults.string(forKey: PreferenceKey.clickAction) ?? "clock"
	panelView.setAppearance(appearance, glassStyle: glassStyle, glassTint: glassTint)
	updateMenuBarClock()
	updateStatusClockTimer()
	setHourlyAlertIndicator(popPerHour)
	updateStatusAccessibility()
	refreshPopover()
}

@objc private func showPreferences() {
	if preferencesWindow == nil { createPreferencesWindow() }
	preferencesWindow?.center()
	preferencesWindow?.makeKeyAndOrderFront(nil)
	NSApp.activate(ignoringOtherApps: true)
}

private func createPreferencesWindow() {
	let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
		styleMask: [.titled, .closable], backing: .buffered, defer: false)
	window.title = "Cairo Clock Preferences"
	window.isReleasedWhenClosed = false
	let host = NSHostingController(rootView: ClockPreferencesView { [weak self] in self?.applyPreferences() })
	window.contentViewController = host
	preferencesWindow = window
}
}
