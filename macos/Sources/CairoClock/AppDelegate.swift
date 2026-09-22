import AppKit

/// Port of extension.js: the menu-bar icon, the floating clock panel,
/// the appear/disappear animation and the alarm timer.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusItem: NSStatusItem!
	private var panel: NSPanel!
	private var clock: ClockView!
	private var size: CGFloat = 400
	private var popPerHour = false	// 整点弹出报时。
	private var alarmTimer: Timer?

	private var animTimer: Timer?
	private var animStart = Date()
	private var animStep: ((CGFloat) -> Void)?
	private var animDone: (() -> Void)?

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
		clock.onHide = { [weak self] in self?.panel.orderOut(nil) }

		panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
			styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = false
		panel.level = .floating
		panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
		panel.hidesOnDeactivate = false
		panel.acceptsMouseMovedEvents = true
		panel.contentView = clock
		panel.center()

		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		if let button = statusItem.button {
			button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Cairo Clock")
			button.image?.isTemplate = true
			button.wantsLayer = true
			button.layer?.cornerRadius = 4
			button.target = self
			button.action = #selector(statusClicked(_:))
			button.sendAction(on: [.leftMouseDown])
		}

		alarmTimer = Timer.scheduledTimer(timeInterval: 10, target: self,
			selector: #selector(checkAlarm), userInfo: nil, repeats: true)
	}

	@objc private func statusClicked(_ sender: NSStatusBarButton) {
		let flags = NSApp.currentEvent?.modifierFlags ?? []
		if flags.contains(.option) {
			popPerHour.toggle()
			sender.layer?.backgroundColor = popPerHour ? NSColor(hex: 0xC98A38).cgColor : nil
			return
		}
		if flags.contains(.control) {
			alarm()
			return
		}
		if panel.isVisible { hidePanel() } else { showPanel() }
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
		animate({ t in	// 出现。
			self.panel.alphaValue = 10 / 255 + (1 - 10 / 255) * t
			self.clock.introScale = 0.1 + 0.9 * t
			self.clock.introRotation = 360 * (1 - t)
		}, completion: {})
	}

	private func hidePanel() {
		let start = panel.frame.origin
		let targetX = (panel.screen ?? NSScreen.main)?.frame.maxX ?? start.x
		animate({ t in	// 消失。
			self.panel.setFrameOrigin(NSPoint(x: start.x + (targetX - self.size * 0.4 - start.x) * t, y: start.y))
			self.panel.alphaValue = 1 - (1 - 10 / 255) * t
			self.clock.introScale = 1 - 0.6 * t
		}, completion: {
			self.panel.orderOut(nil)
			self.panel.alphaValue = 1	// 及时恢复透明度。
			self.clock.introScale = 1	// 恢复比率，否则闹钟变小。
			self.panel.setFrameOrigin(start)	// 恢复位置，否则闹钟乱跑。
		})
	}

	private func animate(_ step: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
		finishAnimation()
		animStep = step
		animDone = completion
		animStart = Date()
		step(0)
		animTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60, target: self,
			selector: #selector(animTick), userInfo: nil, repeats: true)
	}

	@objc private func animTick() {
		let p = CGFloat(min(Date().timeIntervalSince(animStart), 1))	// duration 1s
		animStep?(Self.easeOutBounce(p))
		if p >= 1 { finishAnimation() }
	}

	private func finishAnimation() {
		guard let timer = animTimer else { return }
		timer.invalidate()
		animTimer = nil
		animStep?(1)
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

	// MARK: - Alarm

	private func alarm() {
		NSSound(named: "Glass")?.play()
		panel.orderFrontRegardless()
		clock.swing()
	}

	@objc private func checkAlarm() {
		let c = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
		let h0 = (c.hour ?? 0) % 12
		let m0 = c.minute ?? 0
		let s0 = c.second ?? 0
		if let a = clock.alarm, a.h % 12 == h0, a.m == m0 { alarm() }
		if popPerHour, m0 == 0, s0 < 10 { alarm() }	// 整点弹出报时
		clock.needsDisplay = true
	}
}
