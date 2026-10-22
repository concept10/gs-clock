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
		static let glassStyle = "glassStyle"
		static let glassTint = "glassTint"
		static let menuBarDensity = "menuBarClockDensity"
		static let menuBarShowsSeconds = "menuBarShowsSeconds"
		static let secondaryTimeZone = "secondaryTimeZone"
		static let clickAction = "menuBarClickAction"
	}

	private var animTimer: Timer?
	private var animStart = Date()
	private var animStep: ((Double) -> Void)?
	private var animDone: (() -> Void)?
	private var animDuration = 0.0

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
		let sign: CGFloat = slideOffsetX(from: origin.x, visibleFrame: visibleFrame) > origin.x ? 1 : -1
		let graph = AnimationGraph.load()
		animate(duration: graph.totalDuration(for: .show), step: { time in
			let pose = graph.pose(for: .show, at: time, slideSign: sign, size: self.size)
			self.apply(pose, origin: origin)
		}, completion: {})
	}

	private func hidePanel() {
		let start = panel.frame.origin
		let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
			?? NSRect(origin: start, size: panel.frame.size)
		let sign: CGFloat = slideOffsetX(from: start.x, visibleFrame: visibleFrame) > start.x ? 1 : -1
		let graph = AnimationGraph.load()
		animate(duration: graph.totalDuration(for: .hide), step: { time in
			let pose = graph.pose(for: .hide, at: time, slideSign: sign, size: self.size)
			self.apply(pose, origin: start)
		}, completion: {
			self.panel.orderOut(nil)
			self.panel.alphaValue = 1	// 及时恢复透明度。
			self.clock.introScale = 1	// 恢复比率，否则闹钟变小。
			self.clock.introRotation = 0
			self.clock.introFlip = 1
			self.panel.setFrameOrigin(start)	// 恢复位置，否则闹钟乱跑。
		})
	}

	private func apply(_ pose: AnimationPose, origin: NSPoint) {
		panel.alphaValue = pose.alpha
		clock.introScale = pose.scale
		clock.introRotation = pose.rotation
		clock.introFlip = pose.flipX
		panel.setFrameOrigin(NSPoint(x: origin.x + pose.offsetX, y: origin.y + pose.offsetY))
	}

	private func slideOffsetX(from x: CGFloat, visibleFrame: NSRect) -> CGFloat {
		let right = min(x + size * 0.8, visibleFrame.maxX - size)
		return right > x ? right : max(x - size * 0.8, visibleFrame.minX)
	}

	private func animate(duration: Double, step: @escaping (Double) -> Void, completion: @escaping () -> Void) {
		finishAnimation()
		step(0)
		guard duration > 0 else {
			step(0)
			completion()
			return
		}
		animStep = step
		animDone = completion
		animDuration = duration
		animStart = Date()
		animTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60, target: self,
			selector: #selector(animTick), userInfo: nil, repeats: true)
	}

	@objc private func animTick() {
		let elapsed = Date().timeIntervalSince(animStart)
		animStep?(min(elapsed, animDuration))
		if elapsed >= animDuration { finishAnimation() }
	}

	private func finishAnimation() {
		guard let timer = animTimer else { return }
		timer.invalidate()
		animTimer = nil
		animStep?(animDuration)
		let done = animDone
		animStep = nil
		animDone = nil
		done?()
	}

	private func previewAnimation(_ trigger: AnimationTrigger) {
		switch trigger {
		case .show:
			if panel.isVisible { finishAnimation(); panel.orderOut(nil) }
			showPanel()
		case .hide:
			if panel.isVisible {
				hidePanel()
			} else {
				showPanel()
				let wait = AnimationGraph.load().totalDuration(for: .show) + 0.6
				DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
					guard let self, self.panel.isVisible else { return }
					self.hidePanel()
				}
			}
		}
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
	menu.addItem(.separator())
	let quitItem = NSMenuItem(title: "Quit Cairo Clock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
	quitItem.target = NSApp
	menu.addItem(quitItem)
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
	clock.fontFamily = defaults.string(forKey: "clockFontFamily") ?? ClockView.defaultFontFamily
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
	let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 640),
		styleMask: [.titled, .closable], backing: .buffered, defer: false)
	window.title = "Cairo Clock Preferences"
	window.isReleasedWhenClosed = false
	let host = NSHostingController(rootView: ClockPreferencesRootView(
		onChange: { [weak self] in self?.applyPreferences() },
		onPreview: { [weak self] in self?.previewAnimation($0) }))
	window.contentViewController = host
	preferencesWindow = window
}
}
