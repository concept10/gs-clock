import AppKit

enum AnimationTrigger: String, CaseIterable, Codable {
	case show, hide

	var title: String { self == .show ? "Show" : "Hide" }
	var symbol: String { self == .show ? "eye" : "eye.slash" }
}

enum AnimationNodeKind: String, CaseIterable, Codable {
	case fade, scale, spin, slide, flip, wobble, shake, pop, orbit

	var title: String {
		switch self {
		case .fade: "Fade"
		case .scale: "Scale"
		case .spin: "Spin"
		case .slide: "Slide"
		case .flip: "Flip"
		case .wobble: "Wobble"
		case .shake: "Shake"
		case .pop: "Pop"
		case .orbit: "Orbit"
		}
	}

	var symbol: String {
		switch self {
		case .fade: "circle.lefthalf.filled"
		case .scale: "arrow.up.left.and.arrow.down.right"
		case .spin: "arrow.triangle.2.circlepath"
		case .slide: "arrow.left.and.right"
		case .flip: "rectangle.landscape.rotate"
		case .wobble: "metronome"
		case .shake: "waveform.path"
		case .pop: "sparkle"
		case .orbit: "tornado"
		}
	}

	var amountLabel: String {
		switch self {
		case .fade: "Hidden opacity"
		case .scale: "Hidden scale"
		case .spin: "Rotation (°)"
		case .slide: "Distance (clock widths)"
		case .flip: "Flip angle (°)"
		case .wobble: "Swing angle (°)"
		case .shake: "Shake distance (clock widths)"
		case .pop: "Overshoot"
		case .orbit: "Orbit radius (clock widths)"
		}
	}

	var amountRange: ClosedRange<Double> {
		switch self {
		case .fade: 0...1
		case .scale: 0.05...1
		case .spin: 0...720
		case .slide: 0...2
		case .flip: 0...180
		case .wobble: 0...90
		case .shake: 0...0.3
		case .pop: 0...0.5
		case .orbit: 0...2
		}
	}

	var defaultAmount: Double {
		switch self {
		case .fade: 0.04
		case .scale: 0.1
		case .spin: 360
		case .slide: 0.8
		case .flip: 90
		case .wobble: 25
		case .shake: 0.06
		case .pop: 0.2
		case .orbit: 0.6
		}
	}
}

enum AnimationEasing: String, CaseIterable, Codable {
	case linear, easeOut, easeInOut, bounce

	var title: String {
		switch self {
		case .linear: "Linear"
		case .easeOut: "Ease out"
		case .easeInOut: "Ease in-out"
		case .bounce: "Bounce"
		}
	}

	func apply(_ t: Double) -> Double {
		switch self {
		case .linear:
			return t
		case .easeOut:
			return 1 - pow(1 - t, 3)
		case .easeInOut:
			return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
		case .bounce:
			// Same curve as Clutter.AnimationMode.EASE_OUT_BOUNCE.
			let n = 7.5625, d = 2.75
			if t < 1 / d { return n * t * t }
			if t < 2 / d { let u = t - 1.5 / d; return n * u * u + 0.75 }
			if t < 2.5 / d { let u = t - 2.25 / d; return n * u * u + 0.9375 }
			let u = t - 2.625 / d
			return n * u * u + 0.984375
		}
	}
}

enum SlideDirection: String, CaseIterable, Codable {
	case auto, left, right, up, down

	var title: String { self == .auto ? "Auto" : rawValue.capitalized }
}

struct AnimationNode: Codable, Identifiable, Equatable {
	var id = UUID()
	var kind: AnimationNodeKind
	var duration = 1.0
	var delay = 0.0
	var easing = AnimationEasing.easeOut
	var amount: Double
	var direction = SlideDirection.auto

	init(kind: AnimationNodeKind, duration: Double = 1, delay: Double = 0,
			easing: AnimationEasing = .easeOut, amount: Double? = nil, direction: SlideDirection = .auto) {
		self.kind = kind
		self.duration = duration
		self.delay = delay
		self.easing = easing
		self.amount = amount ?? kind.defaultAmount
		self.direction = direction
	}
}

/// What the panel and clock should look like at one instant of an animation.
struct AnimationPose {
	var alpha: CGFloat = 1
	var scale: CGFloat = 1
	var rotation: CGFloat = 0
	var offsetX: CGFloat = 0
	var offsetY: CGFloat = 0
	var flipX: CGFloat = 1
}

enum AnimationPreset: String, CaseIterable {
	case bounce, fade, zoom, slide, spin, flip, wobble, shake, pop, orbit

	var title: String { rawValue.capitalized }

	var graph: AnimationGraph {
		switch self {
		case .bounce:
			AnimationGraph(
				show: [.init(kind: .fade, easing: .bounce), .init(kind: .scale, easing: .bounce),
					.init(kind: .spin, easing: .bounce)],
				hide: [.init(kind: .fade, easing: .bounce), .init(kind: .scale, easing: .bounce, amount: 0.6),
					.init(kind: .slide, easing: .bounce, amount: 0.8, direction: .right)])
		case .fade:
			AnimationGraph(show: [.init(kind: .fade)], hide: [.init(kind: .fade)])
		case .zoom:
			AnimationGraph(show: [.init(kind: .scale)], hide: [.init(kind: .scale)])
		case .slide:
			AnimationGraph(show: [.init(kind: .slide)], hide: [.init(kind: .slide)])
		case .spin:
			AnimationGraph(show: [.init(kind: .scale, amount: 0.75), .init(kind: .spin)],
				hide: [.init(kind: .scale, amount: 0.75), .init(kind: .spin)])
		case .flip:
			AnimationGraph(show: [.init(kind: .fade, duration: 0.6), .init(kind: .flip, amount: 90)],
				hide: [.init(kind: .fade, duration: 0.6), .init(kind: .flip, amount: 90)])
		case .wobble:
			AnimationGraph(
				show: [.init(kind: .fade, duration: 0.4), .init(kind: .scale, amount: 0.5),
					.init(kind: .wobble, duration: 1.2, easing: .linear)],
				hide: [.init(kind: .wobble, duration: 0.6, easing: .linear),
					.init(kind: .fade, duration: 0.5, delay: 0.3)])
		case .shake:
			AnimationGraph(
				show: [.init(kind: .fade, duration: 0.3), .init(kind: .shake, duration: 0.6, easing: .linear)],
				hide: [.init(kind: .shake, duration: 0.5, easing: .linear),
					.init(kind: .fade, duration: 0.4, delay: 0.3)])
		case .pop:
			AnimationGraph(
				show: [.init(kind: .fade, duration: 0.4), .init(kind: .scale, duration: 0.7, amount: 0.2),
					.init(kind: .pop, duration: 0.7, easing: .linear)],
				hide: [.init(kind: .pop, duration: 0.5, easing: .linear),
					.init(kind: .scale, duration: 0.5, amount: 0.2), .init(kind: .fade, duration: 0.5)])
		case .orbit:
			AnimationGraph(
				show: [.init(kind: .fade, duration: 0.8), .init(kind: .scale, duration: 1.2, amount: 0.3),
					.init(kind: .orbit, duration: 1.2)],
				hide: [.init(kind: .fade, duration: 0.8, delay: 0.3), .init(kind: .scale, duration: 1.2, amount: 0.3),
					.init(kind: .orbit, duration: 1.2)])
		}
	}
}

/// One left-to-right chain of animation nodes per trigger. All nodes run from the
/// trigger moment, each after its own delay, and combine into one pose.
struct AnimationGraph: Codable, Equatable {
	static let defaultsKey = "animationGraph"
	static let minimumAlpha: CGFloat = 10 / 255

	var show: [AnimationNode]
	var hide: [AnimationNode]

	static var `default`: AnimationGraph { AnimationPreset.bounce.graph }

	static func load(from defaults: UserDefaults = .standard) -> AnimationGraph {
		guard let json = defaults.string(forKey: defaultsKey), let graph = decode(json) else { return .default }
		return graph
	}

	static func decode(_ json: String) -> AnimationGraph? {
		try? JSONDecoder().decode(AnimationGraph.self, from: Data(json.utf8))
	}

	var json: String {
		guard let data = try? JSONEncoder().encode(self) else { return "" }
		return String(decoding: data, as: UTF8.self)
	}

	subscript(trigger: AnimationTrigger) -> [AnimationNode] {
		get { trigger == .show ? show : hide }
		set { if trigger == .show { show = newValue } else { hide = newValue } }
	}

	func totalDuration(for trigger: AnimationTrigger) -> Double {
		self[trigger].map { $0.delay + $0.duration }.max() ?? 0
	}

	/// `slideSign` resolves `.auto` slides to +1 (right) or -1 (left).
	func pose(for trigger: AnimationTrigger, at time: Double, slideSign: CGFloat, size: CGFloat) -> AnimationPose {
		var pose = AnimationPose()
		for node in self[trigger] {
			let raw = node.duration > 0 ? min(max((time - node.delay) / node.duration, 0), 1) : 1
			let eased = node.easing.apply(raw)
			// 1 = fully hidden, 0 = fully shown.
			let hidden = CGFloat(trigger == .show ? 1 - eased : eased)
			let amount = CGFloat(node.amount)
			switch node.kind {
			case .fade:
				pose.alpha *= 1 - (1 - amount) * hidden
			case .scale:
				pose.scale *= 1 - (1 - amount) * hidden
			case .spin:
				pose.rotation += amount * hidden * (trigger == .show ? 1 : -1)
			case .flip:
				let angle = amount * hidden * .pi / 180
				pose.flipX *= max(abs(cos(angle)), 0.001) * (cos(angle) < 0 ? -1 : 1)
			case .wobble:
				// Damped swing around upright, independent of show/hide direction.
				pose.rotation += amount * CGFloat(sin(raw * 4 * .pi) * (1 - raw))
			case .shake:
				pose.offsetX += amount * size * CGFloat(sin(raw * 10 * .pi) * (1 - raw))
			case .pop:
				// Brief scale overshoot that settles back to the pose from the other nodes.
				pose.scale *= 1 + amount * CGFloat(sin(raw * .pi))
			case .orbit:
				let radius = amount * size * hidden
				let angle = Double(hidden) * 2 * .pi * (trigger == .show ? 1 : -1)
				pose.offsetX += radius * CGFloat(cos(angle))
				pose.offsetY += radius * CGFloat(sin(angle))
			case .slide:
				let distance = amount * size * hidden
				switch node.direction {
				case .auto: pose.offsetX += distance * slideSign
				case .left: pose.offsetX -= distance
				case .right: pose.offsetX += distance
				case .up: pose.offsetY += distance
				case .down: pose.offsetY -= distance
				}
			}
		}
		pose.alpha = max(pose.alpha, Self.minimumAlpha)
		return pose
	}
}
