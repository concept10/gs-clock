import AppKit

enum MenuBarClockDensity: String, CaseIterable {
	case symbol
	case analog
	case analogWithTime

	var title: String {
		switch self {
		case .symbol: "Compact Symbol"
		case .analog: "Analog"
		case .analogWithTime: "Analog + Time"
		}
	}

	var width: CGFloat {
		switch self {
		case .symbol: 30
		case .analog: 24
		case .analogWithTime: 68
		}
	}
}

enum MenuBarClockImage {
	static func make(date: Date, density: MenuBarClockDensity, showsSeconds: Bool) -> NSImage? {
		guard density != .symbol else { return nil }
		let size = NSSize(width: density.width, height: 22)
		return NSImage(size: size, flipped: false) { rect in
			guard let context = NSGraphicsContext.current?.cgContext else { return false }
			let dialSize: CGFloat = density == .analogWithTime ? 18 : 19
			let dialRect = NSRect(x: 1, y: (rect.height - dialSize) / 2, width: dialSize, height: dialSize)
			drawDial(in: dialRect, date: date, showsSeconds: showsSeconds, context: context)
			if density == .analogWithTime {
				let formatter = DateFormatter()
				formatter.locale = .current
				formatter.timeZone = .current
				formatter.timeStyle = .short
				formatter.dateStyle = .none
				let time = formatter.string(from: date)
				let attributes: [NSAttributedString.Key: Any] = [
					.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
					.foregroundColor: NSColor.labelColor,
				]
				NSAttributedString(string: time, attributes: attributes)
					.draw(at: NSPoint(x: 21, y: (rect.height - 11) / 2))
			}
			return true
		}
	}

	private static func drawDial(in rect: NSRect, date: Date, showsSeconds: Bool, context: CGContext) {
		let center = CGPoint(x: rect.midX, y: rect.midY)
		let radius = rect.width / 2 - 1
		context.setStrokeColor(NSColor.labelColor.cgColor)
		context.setLineWidth(1)
		context.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))

		context.saveGState()
		context.translateBy(x: center.x, y: center.y)
		for index in 0..<12 {
			let angle = CGFloat(index) * .pi / 6
			context.saveGState()
			context.rotate(by: angle)
			context.setLineWidth(index.isMultiple(of: 3) ? 1.1 : 0.65)
			context.move(to: CGPoint(x: 0, y: radius - 1))
			context.addLine(to: CGPoint(x: 0, y: radius - (index.isMultiple(of: 3) ? 3.5 : 2.5)))
			context.strokePath()
			context.restoreGState()
		}

		let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
		let hour = CGFloat((components.hour ?? 0) % 12) + CGFloat(components.minute ?? 0) / 60
		let minute = CGFloat(components.minute ?? 0) + CGFloat(components.second ?? 0) / 60
		drawHand(context, angle: -hour / 12 * 2 * .pi, length: radius * 0.48, width: 1.5)
		drawHand(context, angle: -minute / 60 * 2 * .pi, length: radius * 0.72, width: 1)
		if showsSeconds {
			drawHand(context, angle: -CGFloat(components.second ?? 0) / 60 * 2 * .pi,
				length: radius * 0.8, width: 0.55, color: .systemRed)
		}
		context.setFillColor(NSColor.labelColor.cgColor)
		context.fillEllipse(in: CGRect(x: -1.1, y: -1.1, width: 2.2, height: 2.2))
		context.restoreGState()
	}

	private static func drawHand(_ context: CGContext, angle: CGFloat, length: CGFloat,
			width: CGFloat, color: NSColor = .labelColor) {
		context.saveGState()
		context.rotate(by: angle)
		context.setStrokeColor(color.cgColor)
		context.setLineWidth(width)
		context.setLineCap(.round)
		context.move(to: .zero)
		context.addLine(to: CGPoint(x: 0, y: length))
		context.strokePath()
		context.restoreGState()
	}
}
