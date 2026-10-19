import SwiftUI

struct ClockPopoverView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let alarmDescription: String
	let alarmEnabled: Bool
	let secondaryTimeZoneIdentifier: String
	let onShowClock: () -> Void
	let onToggleAlarm: () -> Void
	let onClearAlarm: () -> Void
	let onPreferences: () -> Void

	private var secondaryTimeZone: TimeZone? {
		guard !secondaryTimeZoneIdentifier.isEmpty else { return nil }
		return TimeZone(identifier: secondaryTimeZoneIdentifier)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			TimelineView(.periodic(from: .now, by: 1)) { context in
				HStack(alignment: .center, spacing: 14) {
					AnalogClockPreview(date: context.date)
						.frame(width: 82, height: 82)
						.accessibilityLabel("Analog clock showing \(context.date.formatted(date: .omitted, time: .shortened))")
					VStack(alignment: .leading, spacing: 4) {
						Text(context.date, format: .dateTime.hour().minute().second())
							.font(.system(size: 28, weight: .medium, design: .rounded).monospacedDigit())
							.accessibilityAddTraits(.updatesFrequently)
						Text(context.date.formatted(date: .complete, time: .omitted))
							.font(.callout)
							.foregroundStyle(.secondary)
						Text("Local time · \(TimeZone.current.localizedName(for: .generic, locale: .current) ?? "Local")")
							.font(.caption)
							.foregroundStyle(.secondary)
						if let secondaryTimeZone {
							Text(secondaryTimeText(context.date, timeZone: secondaryTimeZone))
								.font(.callout.monospacedDigit())
						}
					}
				}
				.accessibilityElement(children: .combine)
			}

			Divider()

			HStack(spacing: 8) {
				alarmSymbol
				VStack(alignment: .leading, spacing: 2) {
					Text(alarmEnabled ? "Alarm enabled" : "Alarm")
						.font(.headline)
					Text(alarmDescription)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.accessibilityElement(children: .combine)

			HStack {
				Button(action: onShowClock) {
					Label("Open Clock", systemImage: "clock")
				}
				.buttonStyle(.borderedProminent)
				Button(alarmEnabled ? "Disable" : "Enable", action: onToggleAlarm)
					.disabled(alarmDescription == "No alarm set")
					.accessibilityLabel(alarmEnabled ? "Disable alarm" : "Enable alarm")
				Button {
					onClearAlarm()
				} label: {
					Image(systemName: "xmark.circle")
				}
				.help("Clear alarm")
				.accessibilityLabel("Clear alarm")
				.disabled(alarmDescription == "No alarm set")
			}

			Button(action: onPreferences) {
				Label("Preferences…", systemImage: "slider.horizontal.3")
			}
			.buttonStyle(.plain)
			.foregroundStyle(.secondary)
		}
		.padding(18)
		.frame(width: 360, alignment: .leading)
		.background {
			if #available(macOS 26.0, *) {
				RoundedRectangle(cornerRadius: 18)
					.fill(.clear)
					.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
			} else {
				RoundedRectangle(cornerRadius: 18)
					.fill(.ultraThinMaterial)
			}
		}
	}

	private func secondaryTimeText(_ date: Date, timeZone: TimeZone) -> String {
		let formatter = DateFormatter()
		formatter.locale = .current
		formatter.timeZone = timeZone
		formatter.timeStyle = .short
		formatter.dateStyle = .none
		let name = timeZone.localizedName(for: .generic, locale: .current) ?? timeZone.identifier
		return "\(formatter.string(from: date)) · \(name)"
	}

	@ViewBuilder
	private var alarmSymbol: some View {
		if #available(macOS 14.0, *), !reduceMotion {
			Image(systemName: alarmEnabled ? "alarm.waves.left.and.right" : "alarm")
				.symbolEffect(.bounce, value: alarmEnabled)
				.font(.title2)
				.foregroundStyle(alarmEnabled ? Color.accentColor : Color.secondary)
				.accessibilityHidden(true)
		} else {
			Image(systemName: alarmEnabled ? "alarm.waves.left.and.right" : "alarm")
				.font(.title2)
				.foregroundStyle(alarmEnabled ? Color.accentColor : Color.secondary)
				.accessibilityHidden(true)
		}
	}
}

private struct AnalogClockPreview: View {
	let date: Date

	var body: some View {
		Canvas { context, size in
			let center = CGPoint(x: size.width / 2, y: size.height / 2)
			let radius = min(size.width, size.height) / 2 - 3
			let faceRect = CGRect(x: center.x - radius, y: center.y - radius,
				width: radius * 2, height: radius * 2)
			context.stroke(Path(ellipseIn: faceRect), with: .foreground, lineWidth: 1.5)

			for index in 0..<12 {
				let angle = Double(index) * .pi / 6
				let outer = point(center: center, length: radius - 4, angle: angle)
				let tickLength: CGFloat = index.isMultiple(of: 3) ? 11 : 8
				let inner = point(center: center, length: radius - tickLength, angle: angle)
				var tick = Path()
				tick.move(to: outer)
				tick.addLine(to: inner)
				context.stroke(tick, with: .foreground, style: StrokeStyle(
					lineWidth: index.isMultiple(of: 3) ? 1.5 : 0.8, lineCap: .round
				))
			}

			let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
			let hours = Double((components.hour ?? 0) % 12) + Double(components.minute ?? 0) / 60
			let minutes = Double(components.minute ?? 0) + Double(components.second ?? 0) / 60
			strokeHand(&context, center: center, length: radius * 0.48,
				angle: hours / 12 * 2 * .pi, width: 3)
			strokeHand(&context, center: center, length: radius * 0.72,
				angle: minutes / 60 * 2 * .pi, width: 2)
			context.fill(Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
				with: .foreground)
		}
		.accessibilityElement(children: .ignore)
	}

	private func point(center: CGPoint, length: CGFloat, angle: Double) -> CGPoint {
		CGPoint(x: center.x + length * CGFloat(sin(angle)),
			y: center.y - length * CGFloat(cos(angle)))
	}

	private func strokeHand(_ context: inout GraphicsContext, center: CGPoint,
			length: CGFloat, angle: Double, width: CGFloat) {
		var hand = Path()
		hand.move(to: center)
		hand.addLine(to: point(center: center, length: length, angle: angle))
		context.stroke(hand, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
	}
}
