import SwiftUI

struct FlowChartCanvas: View {
    let nodes: [FlowchartNode]
    let edges: [FlowchartEdge]
    @Binding var selectedNodeId: String?
    var nodeRects: [String: CGRect]

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let contentSize = contentBounds()

            ZStack(alignment: .bottomTrailing) {
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        connectionLines
                        nodeViews
                    }
                    .frame(width: max(contentSize.width, geometry.size.width),
                           height: max(contentSize.height, geometry.size.height))
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                zoomControls
                    .padding(12)
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { scale = max(0.3, scale - 0.2) } }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
            }
            .help("Zoom out")

            Text(String(format: "%.0f", scale * 100) + "%")
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundColor(.secondary)
                .frame(width: 36)

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { scale = min(3.0, scale + 0.2) } }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
            }
            .help("Zoom in")

            Divider()
                .frame(height: 14)

            Button(action: { withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.0
                offset = .zero
                lastScale = 1.0
                lastOffset = .zero
            } }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .help("Reset zoom")
        }
        .padding(6)
        .background(.regularMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var nodeViews: some View {
        ForEach(nodes, id: \.id) { node in
            if let rect = nodeRects[node.id] {
                FlowChartNodeView(
                    node: node,
                    rect: rect,
                    isSelected: selectedNodeId == node.id
                )
                .onTapGesture {
                    selectedNodeId = node.id
                }
                .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private var connectionLines: some View {
        Path { path in
            for edge in edges {
                guard let fromRect = nodeRects[edge.from],
                      let toRect = nodeRects[edge.to] else {
                    continue
                }
                let fromPoint = CGPoint(x: fromRect.midX, y: fromRect.maxY)
                let toPoint = CGPoint(x: toRect.midX, y: toRect.minY)

                path.move(to: fromPoint)
                let controlY = (fromPoint.y + toPoint.y) / 2
                path.addCurve(
                    to: toPoint,
                    control1: CGPoint(x: fromPoint.x, y: controlY),
                    control2: CGPoint(x: toPoint.x, y: controlY)
                )
            }
        }
        .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func contentBounds() -> CGSize {
        guard !nodeRects.isEmpty else { return .zero }
        let maxX = nodeRects.values.map { $0.maxX }.max() ?? 0
        let maxY = nodeRects.values.map { $0.maxY }.max() ?? 0
        return CGSize(width: maxX + 60, height: maxY + 60)
    }
}

struct FlowChartNodeView: View {
    let node: FlowchartNode
    let rect: CGRect
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(iconTint)
            Text(node.label)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.tail)
                .foregroundColor(.primary)
        }
        .frame(width: rect.width - 10, height: rect.height - 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Color.accentColor : borderColor,
                            lineWidth: isSelected ? 2.5 : 1.2
                        )
                )
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.08),
                    radius: isSelected ? 8 : 3,
                    y: isSelected ? 0 : 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? LinearGradient(colors: [.accentColor.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var iconTint: Color {
        switch node.type {
        case "function": return .blue
        case "class": return .purple
        case "condition": return .orange
        case "loop": return .green
        case "trycatch": return .red
        case "catch": return .yellow
        case "return": return .teal
        case "import": return .gray
        default: return .secondary
        }
    }

    private var iconName: String {
        switch node.type {
        case "function": return "f.square"
        case "class": return "c.square"
        case "condition": return "diamond"
        case "loop": return "arrow.triangle.capsulepath"
        case "trycatch": return "exclamationmark.triangle"
        case "catch": return "arrow.triangle.branch"
        case "assign": return "equal.square"
        case "call": return "play.square"
        case "return": return "arrow.left.square"
        case "import": return "square.and.arrow.down"
        case "with": return "rectangle.and.pencil.and.ellipsis"
        case "module": return "rectangle.stack"
        case "comprehension": return "list.bullet.rectangle"
        case "raise": return "xmark.octagon"
        case "assert": return "checkmark.shield"
        case "break": return "forward.end"
        case "continue": return "forward"
        case "pass": return "minus"
        case "statement": return "doc.text"
        case "match": return "point.topleft.down.curvedto.point.bottomright.up"
        default: return "circle"
        }
    }

    private var backgroundColor: Color {
        switch node.type {
        case "function": return Color.blue.opacity(0.1)
        case "class": return Color.purple.opacity(0.1)
        case "condition": return Color.orange.opacity(0.1)
        case "loop": return Color.green.opacity(0.1)
        case "trycatch": return Color.red.opacity(0.08)
        case "catch": return Color.yellow.opacity(0.1)
        case "return": return Color.teal.opacity(0.1)
        case "import": return Color.gray.opacity(0.1)
        case "module": return Color.clear
        default: return Color(nsColor: .windowBackgroundColor)
        }
    }

    private var borderColor: Color {
        switch node.type {
        case "function": return .blue.opacity(0.5)
        case "class": return .purple.opacity(0.5)
        case "condition": return .orange.opacity(0.5)
        case "loop": return .green.opacity(0.5)
        case "trycatch": return .red.opacity(0.5)
        case "catch": return .yellow.opacity(0.5)
        case "return": return .teal.opacity(0.5)
        case "import": return .gray.opacity(0.5)
        case "module": return .clear
        default: return .secondary.opacity(0.25)
        }
    }
}
