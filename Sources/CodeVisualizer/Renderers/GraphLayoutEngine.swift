import Foundation

struct LayoutNode {
    let id: String
    let label: String
    let type: String
    let depth: Int
    var position: CGPoint
    var size: CGSize
}

struct LayoutEdge {
    let from: String
    let to: String
    var controlPoints: [CGPoint]
}

final class GraphLayoutEngine {
    let nodeWidth: CGFloat = 180
    let nodeHeight: CGFloat = 50
    let horizontalSpacing: CGFloat = 60
    let verticalSpacing: CGFloat = 80
    let padding: CGFloat = 40

    func layout(nodes: [FlowchartNode], edges: [FlowchartEdge]) -> [String: CGRect] {
        guard !nodes.isEmpty else { return [:] }

        let byDepth = Dictionary(grouping: nodes, by: { $0.depth })
        let sortedDepths = byDepth.keys.sorted()

        var rects: [String: CGRect] = [:]

        for depth in sortedDepths {
            let nodesAtDepth = byDepth[depth] ?? []
            let depthWidth = CGFloat(nodesAtDepth.count) * nodeWidth + CGFloat(max(0, nodesAtDepth.count - 1)) * horizontalSpacing
            let startX = (depthWidth / -2.0) + padding

            for (index, node) in nodesAtDepth.sorted(by: { $0.id < $1.id }).enumerated() {
                let x = startX + CGFloat(index) * (nodeWidth + horizontalSpacing)
                let y = padding + CGFloat(depth) * (nodeHeight + verticalSpacing)
                rects[node.id] = CGRect(x: x, y: y, width: nodeWidth, height: nodeHeight)
            }
        }

        if rects.isEmpty, let node = nodes.first {
            rects[node.id] = CGRect(x: padding, y: padding, width: nodeWidth, height: nodeHeight)
        }

        return rects
    }

    func layoutTree(nodes: [FlowchartNode], edges: [FlowchartEdge]) -> [String: CGRect] {
        guard !nodes.isEmpty else { return [:] }

        let childrenMap = Dictionary(grouping: edges, by: { $0.from })
            .mapValues { $0.map { $0.to } }

        var rootNode: FlowchartNode? = nil
        for node in nodes {
            if node.type == "module" || node.depth == 0 {
                rootNode = node
                break
            }
        }
        if rootNode == nil { rootNode = nodes.first }
        let rootId = rootNode?.id ?? ""

        var rects: [String: CGRect] = [:]
        var usedWidth: CGFloat = 0

        func assignPosition(nodeId: String, depth: Int) {
            let children = childrenMap[nodeId] ?? []
            if children.isEmpty {
                let x = padding + usedWidth * (nodeWidth + horizontalSpacing)
                let y = padding + CGFloat(depth) * (nodeHeight + verticalSpacing)
                rects[nodeId] = CGRect(x: x, y: y, width: nodeWidth, height: nodeHeight)
                usedWidth += 1
            } else {
                for child in children {
                    assignPosition(nodeId: child, depth: depth + 1)
                }
                let childRects = children.compactMap { rects[$0] }
                if !childRects.isEmpty {
                    let minX = childRects.map { $0.midX }.min()!
                    let maxX = childRects.map { $0.midX }.max()!
                    let parentX = (minX + maxX) / 2 - nodeWidth / 2
                    let parentY = padding + CGFloat(depth) * (nodeHeight + verticalSpacing)
                    rects[nodeId] = CGRect(x: parentX, y: parentY, width: nodeWidth, height: nodeHeight)
                } else {
                    let x = padding + usedWidth * (nodeWidth + horizontalSpacing)
                    let y = padding + CGFloat(depth) * (nodeHeight + verticalSpacing)
                    rects[nodeId] = CGRect(x: x, y: y, width: nodeWidth, height: nodeHeight)
                    usedWidth += 1
                }
            }
        }

        assignPosition(nodeId: rootId, depth: 0)

        if rects.isEmpty, let node = nodes.first {
            rects[node.id] = CGRect(x: padding, y: padding, width: nodeWidth, height: nodeHeight)
        }

        return rects
    }
}
