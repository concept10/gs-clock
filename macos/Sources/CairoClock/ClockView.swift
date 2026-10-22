import AppKit

/// Port of Clock.js: the clock face with the alarm hand, drawn with Core Graphics
/// instead of Cairo. The view is flipped so y grows downward, like Cairo, which
/// keeps the drawing code a line-by-line match of `on_draw`.
final class ClockView: NSView {
	enum Appearance: String {
		case classic
		case liquidGlass
	}

	let size: CGFloat
	private var maxR: CGFloat { size / 2 - size / 12 }
	private var minR: CGFloat { size / 10 }

	var clockAppearance: Appearance = .classic { didSet { needsDisplay = true } }
	static let systemFontFamily = "System"
	static let defaultFontFamily = "Georgia"
	var fontFamily = ClockView.defaultFontFamily { didSet { needsDisplay = true } }
	var minutePulseEnabled = false
	var alarmGlowEnabled = false
	var rippleEnabled = false

	private(set) var alarm: (h: Int, m: Int)?
	var isAlarmEnabled: Bool { alarmActive }
	var hasAlarmTime: Bool { hasSelectedAlarmTime }
	var alarmDescription: String {
		guard hasSelectedAlarmTime else { return "No alarm set" }
		let time = Self.degreeToTime(alarmDegree)
		return String(format: "%02d:%02d", time.h, time.m)
	}
	private var hoverDegree = 0
	private var alarmDegree = 0
	private var isCenter = false
	private var alarmActive = false
	private var hasSelectedAlarmTime = false

	private var rotateAngle: CGFloat = 0
	private var swingTimer: Timer?
	private var swingCnt = 6	// 查表循环计数
	private var swingDirect = 1	// 顺时钟为1
	private var swingMax: CGFloat = 10	// 每周期递减的最大角度，递减表现为阻尼。
	private static let cosTable: [CGFloat] = [0.2588, 0.5, 0.7071, 0.866, 0.966, 1, 1, 0.966, 0.866, 0.7071, 0.5, 0.2588]	// cos函数 0-75度,+15递增
	private var pulseStarted: Date?
	private var glowStarted: Date?
	private var rippleStarted: Date?
	private var effectTimer: Timer?
	private static let effectDuration: TimeInterval = 0.9

	/// Appear/disappear animation, applied around the centre (Clutter pivot 0.5, 0.5).
	var introScale: CGFloat = 1 { didSet { needsDisplay = true } }
	var introRotation: CGFloat = 0 { didSet { needsDisplay = true } }
	var introFlip: CGFloat = 1 { didSet { needsDisplay = true } }

	/// Called on right click (右键隐藏).
	var onHide: (() -> Void)?
	var onAlarmChange: (() -> Void)?

	init(size: CGFloat) {
		self.size = size
		super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

	override var isFlipped: Bool { true }

	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		for area in trackingAreas { removeTrackingArea(area) }
		addTrackingArea(NSTrackingArea(rect: bounds,
			options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
			owner: self))
	}

	// MARK: - Mouse

	/// Port of get_coords(): pointer position relative to the clock centre.
	private func updateCoords(_ event: NSEvent) -> Bool {
		let p = convert(event.locationInWindow, from: nil)
		let x = p.x - size / 2
		let y = p.y - size / 2
		let distance = hypot(x, y)
		if distance > maxR {
			isCenter = false
			hoverDegree = 0
			needsDisplay = true
			return false
		}
		isCenter = distance <= minR
		if !isCenter { hoverDegree = Int((atan2(y, x) * 180 / .pi).rounded(.up)) + 90 }
		if hoverDegree == 0 { return false }
		if hoverDegree < 0 { hoverDegree += 360 }
		return true
	}

	override func mouseMoved(with event: NSEvent) {
		if !updateCoords(event) || alarmActive { return }
		needsDisplay = true
	}

	override func mouseExited(with event: NSEvent) {
		hoverDegree = 0
		needsDisplay = true
	}

	override func mouseDown(with event: NSEvent) {
		_ = updateCoords(event)
		if !isCenter {
			if !alarmActive {
				alarmDegree = hoverDegree
				hasSelectedAlarmTime = true
			}
		} else {
			alarmActive.toggle()
			if alarmActive { hasSelectedAlarmTime = true }
		}
		if alarmActive {
			alarm = Self.degreeToTime(alarmDegree)
			hoverDegree = 0
		} else {
			alarm = nil
		}
		needsDisplay = true
		onAlarmChange?()
	}

	override func rightMouseDown(with event: NSEvent) {
		hoverDegree = 0
		needsDisplay = true
		onHide?()
	}

	func toggleAlarmEnabled() {
		guard hasSelectedAlarmTime else { return }
		if alarmActive {
			alarmActive = false
			alarm = nil
		} else {
			alarmActive = true
			alarm = Self.degreeToTime(alarmDegree)
		}
		needsDisplay = true
		onAlarmChange?()
	}

	func clearAlarm() {
		alarmActive = false
		alarm = nil
		alarmDegree = 0
		hasSelectedAlarmTime = false
		needsDisplay = true
		onAlarmChange?()
	}

	// MARK: - Drawing

	override func draw(_ dirtyRect: NSRect) {
		guard let ctx = NSGraphicsContext.current?.cgContext else { return }
		let backColor = NSColor(hex: 0xD3D3D3)	// "light gray"
		let handColor = clockAppearance == .liquidGlass ? NSColor.labelColor : NSColor.black

		ctx.clear(bounds)
		ctx.translateBy(x: size / 2, y: size / 2)	// 窗口中心为坐标原点。
		let pulseProgress = effectProgress(since: pulseStarted)
		let pulseScale = pulseProgress.map { 1 + 0.035 * sin(.pi * $0) } ?? 1
		ctx.scaleBy(x: introScale * pulseScale, y: introScale * pulseScale)
		ctx.rotate(by: introRotation * .pi / 180)
		ctx.scaleBy(x: introFlip, y: 1)
		ctx.setLineCap(.round)
		if swingTimer != nil { ctx.rotate(by: rotateAngle * .pi / 180) }

		let faceOpacity: CGFloat = clockAppearance == .liquidGlass ? 0.12 : 0.8
		ctx.setFillColor(backColor.withAlphaComponent(faceOpacity).cgColor)	// 底色
		addCircle(ctx, radius: size / 2 - size / 20)
		ctx.fillPath()
		ctx.setLineWidth(size / 100)
		ctx.setStrokeColor(handColor.withAlphaComponent(clockAppearance == .liquidGlass ? 0.65 : 1).cgColor)
		addCircle(ctx, radius: size / 2 - size / 20)
		ctx.strokePath()
		ctx.setLineWidth(size / 200)
		ctx.setStrokeColor(NSColor.white.withAlphaComponent(clockAppearance == .liquidGlass ? 0.8 : 1).cgColor)
		addCircle(ctx, radius: size / 2 - size / 7.5)
		ctx.strokePath()
		drawTransientEffects(ctx, now: Date())

		ctx.saveGState()	// 刻度
		for i in 0..<60 {
			if i % 5 == 0 {
				if i % 15 == 0 {
					drawText(String(i / 5), at: CGPoint(x: 0, y: -maxR), color: handColor)
					ctx.setStrokeColor(handColor.cgColor)
					ctx.setLineWidth(size / 30)
				} else {
					ctx.setStrokeColor(backColor.cgColor)
					ctx.setLineWidth(size / 50)
				}
				ctx.move(to: CGPoint(x: 0, y: -maxR - size / 35))
				ctx.addLine(to: CGPoint(x: 0, y: -maxR - size / 70))
				ctx.strokePath()
			}
			ctx.rotate(by: 6 * .pi / 180)	// 6度一个刻度
		}
		ctx.restoreGState()

		let now = Calendar.current.dateComponents([.hour, .minute], from: Date())	// 时间
		let h24 = now.hour ?? 0
		let h0 = h24 % 12
		let m0 = now.minute ?? 0
		let hovering = hoverDegree != 0 && !alarmActive

		if hovering {
			ctx.setFillColor(NSColor.red.cgColor)	// hover 指示
			ctx.saveGState()
			ctx.rotate(by: -.pi / 2)
			ctx.move(to: .zero)
			ctx.addArc(center: .zero, radius: size / 4, startAngle: 0,
				endAngle: CGFloat(hoverDegree) * .pi / 180, clockwise: false)
			ctx.fillPath()
			ctx.restoreGState()
			let t = Self.degreeToTime(hoverDegree)
			drawText(Self.format(t.h, t.m), at: CGPoint(x: 0, y: size / 4), color: .red)
		} else {
			drawText(Self.format(h0, m0), at: CGPoint(x: 0, y: size / 6), color: handColor)
			drawText(h24 >= 12 ? "PM" : "AM", at: CGPoint(x: 0, y: size / 12), color: handColor)
		}

		let at = Self.degreeToTime(alarmDegree)
		drawText(Self.format(at.h, at.m), at: CGPoint(x: 0, y: -size / 5),
			color: alarmActive ? .blue : NSColor(hex: 0x696969))

		drawHand(ctx, .white, width: size / 25, degrees: CGFloat(alarmDegree),
			length: -floor(size / 4), dimmed: hovering, isAlarm: true)	// 闹铃，30度1小时
		drawHand(ctx, handColor, width: size / 20, degrees: CGFloat(h0 * 30) + CGFloat(m0) * 0.5,
			length: -floor(size / 3.7), dimmed: hovering, isAlarm: false)	// 时针，30度1小时
		drawHand(ctx, handColor, width: size / 33, degrees: CGFloat(m0 * 6),
			length: -floor(size / 2.7), dimmed: hovering, isAlarm: false)	// 分针，6度1分钟
		ctx.setFillColor(handColor.cgColor)
		addCircle(ctx, radius: size / 20)
		ctx.fillPath()
		ctx.setFillColor((alarmActive ? NSColor.blue : .red).cgColor)
		addCircle(ctx, radius: size / 33)
		ctx.fillPath()
	}

	func minuteChanged() {
		guard minutePulseEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
		pulseStarted = Date()
		startEffectTimer()
	}

	func clockAppeared() {
		guard rippleEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
		rippleStarted = Date()
		startEffectTimer()
	}

	func alarmEffectsStarted() {
		if alarmGlowEnabled { glowStarted = Date() }
		if rippleEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { rippleStarted = Date() }
		startEffectTimer()
	}

	private func effectProgress(since start: Date?) -> CGFloat? {
		guard let start else { return nil }
		let progress = Date().timeIntervalSince(start) / Self.effectDuration
		return progress < 1 ? CGFloat(max(0, progress)) : nil
	}

	private func drawTransientEffects(_ ctx: CGContext, now: Date) {
		if let start = rippleStarted {
			let progress = CGFloat(max(0, now.timeIntervalSince(start) / Self.effectDuration))
			if progress < 1 {
				let radius = size * (0.43 + 0.12 * progress)
				ctx.setLineWidth(size / 90)
				ctx.setStrokeColor(NSColor.systemTeal.withAlphaComponent(0.55 * (1 - progress)).cgColor)
				addCircle(ctx, radius: radius)
				ctx.strokePath()
			} else {
				rippleStarted = nil
			}
		}
		if let start = glowStarted {
			let progress = CGFloat(max(0, now.timeIntervalSince(start) / Self.effectDuration))
			if progress < 1 {
				ctx.saveGState()
				ctx.setShadow(offset: .zero, blur: size / 18,
					color: NSColor.systemOrange.withAlphaComponent(0.75 * (1 - progress)).cgColor)
				ctx.setLineWidth(size / 55)
				ctx.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.8 * (1 - progress)).cgColor)
				addCircle(ctx, radius: size / 2 - size / 24)
				ctx.strokePath()
				ctx.restoreGState()
			} else {
				glowStarted = nil
			}
		}
		if let start = pulseStarted, now.timeIntervalSince(start) / Self.effectDuration >= 1 {
			pulseStarted = nil
		}
	}

	private func startEffectTimer() {
		needsDisplay = true
		guard effectTimer == nil else { return }
		effectTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60, target: self,
			selector: #selector(effectTick), userInfo: nil, repeats: true)
	}

	@objc private func effectTick() {
		if effectProgress(since: pulseStarted) == nil { pulseStarted = nil }
		if effectProgress(since: glowStarted) == nil { glowStarted = nil }
		if effectProgress(since: rippleStarted) == nil { rippleStarted = nil }
		needsDisplay = true
		if pulseStarted == nil, glowStarted == nil, rippleStarted == nil {
			effectTimer?.invalidate()
			effectTimer = nil
		}
	}

	private func addCircle(_ ctx: CGContext, center: CGPoint = .zero, radius: CGFloat) {
		ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
	}

	private func drawHand(_ ctx: CGContext, _ color: NSColor, width: CGFloat, degrees: CGFloat,
			length: CGFloat, dimmed: Bool, isAlarm: Bool) {
		ctx.saveGState()
		ctx.rotate(by: degrees * .pi / 180)
		ctx.setStrokeColor(color.withAlphaComponent(dimmed ? 0.4 : 1).cgColor)	// 指针颜色
		ctx.setLineWidth(width)
		ctx.move(to: .zero)
		ctx.addLine(to: CGPoint(x: 0, y: length))
		ctx.strokePath()
		if isAlarm {
			ctx.setFillColor((alarmActive ? NSColor.blue : .red).cgColor)
			addCircle(ctx, center: CGPoint(x: 0, y: length), radius: width / 2 * 0.6)
			ctx.fillPath()
		}
		ctx.restoreGState()	// 消除旋转的角度
	}

	/// Port of align_show(): text centred horizontally, top edge at `p`.
	private func drawText(_ text: String, at p: CGPoint, color: NSColor) {
		let pointSize = size / 25
		let font: NSFont
		if fontFamily == ClockView.systemFontFamily {
			font = .systemFont(ofSize: pointSize, weight: .bold)
		} else {
			font = NSFontManager.shared.font(withFamily: fontFamily, traits: .boldFontMask, weight: 9, size: pointSize)
				?? NSFont(name: fontFamily, size: pointSize)
				?? .boldSystemFont(ofSize: pointSize)
		}
		let s = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
		s.draw(at: CGPoint(x: p.x - s.size().width / 2, y: p.y))
	}

	static func degreeToTime(_ degree: Int) -> (h: Int, m: Int) {
		let at = degree * 2
		let h = at / 60
		return (h, (at - h * 60) / 5 * 5)
	}

	private static func format(_ h: Int, _ m: Int) -> String {
		String(format: "%02d : %02d", h, m)
	}

	// MARK: - Swing

	func swing() {
		if swingTimer != nil { return }	// 不能重入。
		swingCnt = 6
		swingDirect = 1
		swingMax = 10
		swingTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self,
			selector: #selector(swingTick), userInfo: nil, repeats: true)
	}

	@objc private func swingTick() {
		if swingMax == 0 {	// 停止条件
			swingTimer?.invalidate()
			swingTimer = nil
			needsDisplay = true
			return
		}
		rotateAngle += CGFloat(swingDirect) * swingMax * Self.cosTable[swingCnt]
		if (swingCnt == Self.cosTable.count - 1 && swingDirect == 1) || (swingCnt == 0 && swingDirect == -1) {
			swingDirect = -swingDirect
			swingMax -= 1
		} else {
			swingCnt += swingDirect	// 转向时，停止一次变动，更加柔和。
		}
		needsDisplay = true
	}
}

extension NSColor {
	convenience init(hex: UInt32) {
		self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
			green: CGFloat((hex >> 8) & 0xFF) / 255,
			blue: CGFloat(hex & 0xFF) / 255,
			alpha: 1)
	}
}
