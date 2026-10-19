import AppKit
import SwiftUI

final class ClockPanelView: NSView {
	enum GlassStyle: String, CaseIterable {
		case clear
		case frosted
		case tinted

		var title: String {
			switch self {
			case .clear: "Clear"
			case .frosted: "Frosted"
			case .tinted: "Tinted"
			}
		}

		var opacity: CGFloat {
			switch self {
			case .clear: 0.55
			case .frosted: 0.82
			case .tinted: 0.96
			}
		}
	}

	enum GlassTint: String, CaseIterable {
		case none
		case blue
		case teal
		case purple
		case amber

		var title: String {
			switch self {
			case .none: "None"
			case .blue: "Blue"
			case .teal: "Teal"
			case .purple: "Purple"
			case .amber: "Amber"
			}
		}

		var color: NSColor? {
			switch self {
			case .none: nil
			case .blue: .systemBlue
			case .teal: .systemTeal
			case .purple: .systemPurple
			case .amber: NSColor(hex: 0xC98A38)
			}
		}
	}

	private let glassBackdrop: NSView
	let clock: ClockView
	private var glassStyle = GlassStyle.frosted
	private var glassTint = GlassTint.none

	init(clock: ClockView) {
		self.clock = clock
		glassBackdrop = Self.makeGlassBackdrop(size: clock.size)
		super.init(frame: NSRect(x: 0, y: 0, width: clock.size, height: clock.size))

		glassBackdrop.frame = bounds.insetBy(dx: clock.size / 20, dy: clock.size / 20)
		addSubview(glassBackdrop)

		clock.frame = bounds
		addSubview(clock)
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

	func setAppearance(_ appearance: ClockView.Appearance, glassStyle: GlassStyle, glassTint: GlassTint) {
		self.glassStyle = glassStyle
		self.glassTint = glassTint
		glassBackdrop.isHidden = appearance != .liquidGlass
		clock.clockAppearance = appearance
		if #available(macOS 26.0, *), let glassView = glassBackdrop as? PassthroughHostingView<GlassBackdrop> {
			glassView.rootView = GlassBackdrop(style: glassStyle, tint: glassTint)
		} else if let effectView = glassBackdrop as? PassthroughVisualEffectView {
			effectView.configure(style: glassStyle, tint: glassTint, size: clock.size)
		}
	}

	private static func makeGlassBackdrop(size: CGFloat) -> NSView {
		if #available(macOS 26.0, *) {
			return PassthroughHostingView(rootView: GlassBackdrop(style: .frosted, tint: .none))
		}

		let backdrop = PassthroughVisualEffectView(frame: .zero)
		backdrop.configure(style: .frosted, tint: .none, size: size)
		return backdrop
	}
}

@available(macOS 26.0, *)
private struct GlassBackdrop: View {
	let style: ClockPanelView.GlassStyle
	let tint: ClockPanelView.GlassTint

	var body: some View {
		let base = Circle().fill(.clear)
		let glass = style == .clear
			? base.glassEffect(.clear.tint(tint.color.map { Color(nsColor: $0) }))
			: base.glassEffect(.regular.tint(tint.color.map { Color(nsColor: $0) }))
		if style == .tinted, let color = tint.color {
			glass.overlay(Circle().fill(Color(nsColor: color).opacity(0.18)))
		} else {
			glass
		}
	}
}

private final class PassthroughVisualEffectView: NSVisualEffectView {
	private let tintOverlay = CALayer()

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		wantsLayer = true
		layer?.cornerRadius = 0
		layer?.masksToBounds = true
		tintOverlay.frame = bounds
		tintOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
		layer?.addSublayer(tintOverlay)
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

	func configure(style: ClockPanelView.GlassStyle, tint: ClockPanelView.GlassTint, size: CGFloat) {
		material = style == .clear ? .popover : .hudWindow
		blendingMode = .behindWindow
		state = .active
		alphaValue = style.opacity
		layer?.cornerRadius = size * 0.45
		tintOverlay.backgroundColor = tint.color?.withAlphaComponent(style == .tinted ? 0.28 : 0.12).cgColor
	}

	override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@available(macOS 26.0, *)
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
	override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
