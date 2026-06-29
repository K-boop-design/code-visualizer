import SwiftUI

struct FlowChartView: View {
    let nodes: [FlowchartNode]
    let edges: [FlowchartEdge]
    @Binding var selectedNodeId: String?
    let nodeRects: [String: CGRect]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Control Flow Diagram", systemImage: "flowchart")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text("\(nodes.count) nodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text("\(edges.count) connections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if nodes.isEmpty {
                emptyState
            } else {
                FlowChartCanvas(
                    nodes: nodes,
                    edges: edges,
                    selectedNodeId: $selectedNodeId,
                    nodeRects: nodeRects
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "flowchart")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Text("No flowchart generated")
                .font(.title3.weight(.semibold))
                .foregroundColor(.secondary)
            Text("Enter Python code and click Visualize")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
