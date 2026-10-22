import SwiftUI

/// Node-style editor: Trigger -> Animation Nodes -> Clock, laid out left to right.
struct ClockAnimationDesignerView: View {
	@AppStorage(AnimationGraph.defaultsKey) private var graphJSON = ""
	@AppStorage("animationDesignerTrigger") private var triggerRaw = AnimationTrigger.show.rawValue

	private var trigger: AnimationTrigger { AnimationTrigger(rawValue: triggerRaw) ?? .show }

	let onPreview: (AnimationTrigger) -> Void

	private var graph: AnimationGraph { AnimationGraph.decode(graphJSON) ?? .default }

	private func update(_ change: (inout [AnimationNode]) -> Void) {
		var current = graph
		change(&current[trigger])
		graphJSON = current.json
	}

	private func binding(for id: UUID) -> Binding<AnimationNode> {
		Binding(
			get: { graph[trigger].first { $0.id == id } ?? AnimationNode(kind: .fade) },
			set: { newValue in
				update { nodes in
					if let index = nodes.firstIndex(where: { $0.id == id }) { nodes[index] = newValue }
				}
			})
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack {
				Picker("Trigger", selection: $triggerRaw) {
					ForEach(AnimationTrigger.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				.accessibilityLabel("Trigger")
				.frame(width: 160)
				Spacer()
				Menu("Load Preset") {
					ForEach(AnimationPreset.allCases, id: \.self) { preset in
						Button(preset.title) { graphJSON = preset.graph.json }
					}
				}
				.fixedSize()
				Button {
					onPreview(trigger)
				} label: {
					Label("Preview", systemImage: "play.fill")
				}
			}

			ScrollView(.horizontal) {
				HStack(spacing: 0) {
					endpointNode(title: trigger.title, subtitle: "Trigger", symbol: trigger.symbol, outputOnly: true)
					ForEach(graph[trigger]) { node in
						wire
						nodeCard(node)
					}
					wire
					addMenu
					wire
					endpointNode(title: "Clock", subtitle: "Output", symbol: "clock", outputOnly: false)
				}
				.padding(.vertical, 8)
			}

			Text("Nodes run together from the trigger; use Delay to stagger them. Total length: \(String(format: "%.2f", graph.totalDuration(for: trigger))) s.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.padding(16)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}

	private var wire: some View {
		HStack(spacing: 0) {
			Circle().frame(width: 7, height: 7)
			Rectangle().frame(width: 22, height: 2)
			Circle().frame(width: 7, height: 7)
		}
		.foregroundStyle(.secondary)
		.accessibilityHidden(true)
	}

	private func endpointNode(title: String, subtitle: String, symbol: String, outputOnly: Bool) -> some View {
		VStack(spacing: 6) {
			Image(systemName: symbol).font(.title2)
			Text(title).font(.headline)
			Text(subtitle).font(.caption).foregroundStyle(.secondary)
		}
		.frame(width: 90, height: 90)
		.background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
		.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
		.accessibilityElement(children: .combine)
	}

	private var addMenu: some View {
		Menu {
			ForEach(AnimationNodeKind.allCases, id: \.self) { kind in
				Button {
					update { $0.append(AnimationNode(kind: kind)) }
				} label: {
					Label(kind.title, systemImage: kind.symbol)
				}
			}
		} label: {
			Image(systemName: "plus").font(.title3)
		}
		.menuStyle(.borderlessButton)
		.menuIndicator(.hidden)
		.frame(width: 44, height: 44)
		.background(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4])))
		.foregroundStyle(.secondary)
		.accessibilityLabel("Add animation node")
	}

	private func nodeCard(_ node: AnimationNode) -> some View {
		let nodes = graph[trigger]
		let index = nodes.firstIndex { $0.id == node.id } ?? 0
		let item = binding(for: node.id)
		return VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 4) {
				Label(node.kind.title, systemImage: node.kind.symbol).font(.headline)
				Spacer()
				Button { update { $0.swapAt(index, index - 1) } } label: { Image(systemName: "chevron.left") }
					.disabled(index == 0)
					.accessibilityLabel("Move \(node.kind.title) earlier")
				Button { update { $0.swapAt(index, index + 1) } } label: { Image(systemName: "chevron.right") }
					.disabled(index >= nodes.count - 1)
					.accessibilityLabel("Move \(node.kind.title) later")
				Button(role: .destructive) { update { $0.removeAll { $0.id == node.id } } } label: {
					Image(systemName: "trash")
				}
				.accessibilityLabel("Remove \(node.kind.title)")
			}
			.buttonStyle(.borderless)

			slider("Duration", value: item.duration, range: 0.1...3, unit: "s")
			slider("Delay", value: item.delay, range: 0...2, unit: "s")
			slider(node.kind.amountLabel, value: item.amount, range: node.kind.amountRange,
				unit: [.spin, .flip, .wobble].contains(node.kind) ? "°" : "")
			Picker("Easing", selection: item.easing) {
				ForEach(AnimationEasing.allCases, id: \.self) { Text($0.title).tag($0) }
			}
			if node.kind == .slide {
				Picker("Direction", selection: item.direction) {
					ForEach(SlideDirection.allCases, id: \.self) { Text($0.title).tag($0) }
				}
			}
		}
		.padding(12)
		.frame(width: 230)
		.background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
		.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
	}

	private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			HStack {
				Text(title).font(.caption)
				Spacer()
				Text(String(format: "%.2f", value.wrappedValue) + unit)
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
			}
			Slider(value: value, in: range).accessibilityLabel(title)
		}
	}
}
