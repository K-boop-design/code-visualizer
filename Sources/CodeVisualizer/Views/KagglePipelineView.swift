import SwiftUI

struct KagglePipelineView: View {
    let stages: [PipelineStage]
    let summary: [PipelineStageSummary]
    let isMLPipeline: Bool
    @Binding var selectedStage: PipelineStage?
    let onShowOutput: ((Int) -> Void)?
    let onExplainLine: ((String, String) -> Void)?
    @State private var expandedStageIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Pipeline Visualization", systemImage: "square.stack.3d.up")
                    .font(.headline)
                Spacer()
                if isMLPipeline {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("ML Pipeline")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                Button(action: { expandedStageIDs.removeAll() }) {
                    Image(systemName: "arrow.up.left")
                        .font(.caption)
                }
                .help("Collapse all pipeline stages")
                .padding(.leading, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if stages.isEmpty {
                emptyState
            } else {
                HSplitView {
                    ScrollView {
                        VStack(spacing: 0) {
                            pipelineFlowView
                            stageListView
                        }
                    }
                    .frame(minWidth: 300)

                    if let stage = selectedStage {
                        StageCodeDetail(stage: stage, onShowOutput: onShowOutput, onExplainLine: onExplainLine)
                            .frame(minWidth: 250, idealWidth: 350)
                    }
                }
            }
        }
    }

    private var pipelineFlowView: some View {
        VStack(spacing: 0) {
            let uniqueStages = uniqueOrderedStages()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(uniqueStages.enumerated()), id: \.element.stage) { index, stage in
                        if index > 0 {
                            VStack(spacing: 0) {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                        PipelineStageCard(stage: stage, isSelected: selectedStage?.stage == stage.stage)
                            .onTapGesture {
                                selectedStage = stages.first { $0.stage == stage.stage }
                            }
                    }
                }
                .padding()
            }
        }
    }

    private func uniqueOrderedStages() -> [PipelineStageSummary] {
        var seen = Set<String>()
        return summary.filter { seen.insert($0.stage).inserted }
    }

    private var stageListView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Detected Stages")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.top, 12)

            ForEach(stages) { stage in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Button(action: {
                            if expandedStageIDs.contains(stage.id) {
                                expandedStageIDs.remove(stage.id)
                            } else {
                                expandedStageIDs.insert(stage.id)
                            }
                        }) {
                            Image(systemName: expandedStageIDs.contains(stage.id) ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 12)
                        }
                        .buttonStyle(.plain)

                        StageRow(stage: stage, isSelected: selectedStage?.id == stage.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStage = stage
                            }
                    }
                    if expandedStageIDs.contains(stage.id) {
                        if let snippet = stage.codeSnippet, !snippet.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(snippet) { line in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(line.lineNumber)")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, alignment: .trailing)
                                        Text(line.code)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .lineLimit(nil)
                                            .textSelection(.enabled)
                                    }
                                    Text(line.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 36)
                                }
                            }
                            .padding(.leading, 38)
                            .padding(.vertical, 6)
                            .padding(.trailing, 8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .padding(.leading, 18)
                            .padding(.bottom, 6)
                        } else {
                            Text("No code snippet available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 38)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(.bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Text("No pipeline detected")
                .font(.title3.weight(.semibold))
                .foregroundColor(.secondary)
            Text("Enter Python code with ML/Kaggle patterns")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PipelineStageCard: View {
    let stage: PipelineStageSummary
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName(for: stage.stage))
                .font(.title3)
                .foregroundColor(stageColor(for: stage.stage))
            Text(stage.description)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .frame(width: 100, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(stageColor(for: stage.stage).opacity(isSelected ? 0.18 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            stageColor(for: stage.stage).opacity(isSelected ? 0.7 : 0.2),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(
                    color: isSelected ? stageColor(for: stage.stage).opacity(0.3) : .clear,
                    radius: isSelected ? 6 : 0
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private func iconName(for stage: String) -> String {
        switch stage {
        case "data_loading": return "tray.and.arrow.down"
        case "eda": return "chart.bar"
        case "preprocessing": return "wand.and.stars"
        case "feature_engineering": return "gearshape.2"
        case "model_training": return "square.stack.3d.up"
        case "model_evaluation": return "checkmark.seal"
        case "prediction": return "forward"
        case "hyperparameter_tuning": return "slider.horizontal.3"
        case "data_augmentation": return "plus.rectangle.on.rectangle"
        default: return "circle"
        }
    }

    private func stageColor(for stage: String) -> Color {
        switch stage {
        case "data_loading": return .blue
        case "eda": return .green
        case "preprocessing": return .orange
        case "feature_engineering": return .purple
        case "model_training": return .red
        case "model_evaluation": return .yellow
        case "prediction": return .teal
        case "hyperparameter_tuning": return .pink
        case "data_augmentation": return .indigo
        default: return .gray
        }
    }
}

struct StageRow: View {
    let stage: PipelineStage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: stage.stageIcon)
                .foregroundColor(stageColor)
                .font(.caption)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(stage.description)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                Text(stage.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("Line \(stage.line)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var stageColor: Color {
        switch stage.stage {
        case "data_loading": return .blue
        case "eda": return .green
        case "preprocessing": return .orange
        case "feature_engineering": return .purple
        case "model_training": return .red
        case "model_evaluation": return .yellow
        case "prediction": return .teal
        case "hyperparameter_tuning": return .pink
        case "data_augmentation": return .indigo
        default: return .gray
        }
    }
}

struct StageCodeDetail: View {
    let stage: PipelineStage
    let onShowOutput: ((Int) -> Void)?
    let onExplainLine: ((String, String) -> Void)?
    @State private var hoveredLineId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(stageColor(stage.stage).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: stage.stageIcon)
                        .foregroundColor(stageColor(stage.stage))
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(stage.description)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Line \(stage.line)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            if let snippet = stage.codeSnippet, !snippet.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(snippet) { line in
                                CodeLineRow(
                                    line: line,
                                    stage: stage,
                                    isHovered: hoveredLineId == line.lineNumber,
                                    onShowOutput: onShowOutput,
                                    onExplainLine: onExplainLine,
                                    onHover: { hoveredLineId = $0 ? line.lineNumber : nil }
                                )
                                .id(line.id)
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .onAppear {
                        if let target = snippet.first(where: { $0.lineNumber == stage.line }) {
                            proxy.scrollTo(target.id, anchor: .center)
                        }
                    }
                    .onChange(of: stage.id) {
                        if let target = snippet.first(where: { $0.lineNumber == stage.line }) {
                            proxy.scrollTo(target.id, anchor: .center)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.secondary.opacity(0.06))
                            .frame(width: 48, height: 48)
                        Image(systemName: "text.alignleft")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    Text("No code snippet available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func stageColor(_ s: String) -> Color {
        switch s {
        case "data_loading": return .blue
        case "eda": return .green
        case "preprocessing": return .orange
        case "feature_engineering": return .purple
        case "model_training": return .red
        case "model_evaluation": return .yellow
        case "prediction": return .teal
        case "hyperparameter_tuning": return .pink
        case "data_augmentation": return .indigo
        default: return .gray
        }
    }
}

private struct CodeLineRow: View {
    let line: CodeLine
    let stage: PipelineStage
    let isHovered: Bool
    let onShowOutput: ((Int) -> Void)?
    let onExplainLine: ((String, String) -> Void)?
    let onHover: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(line.lineNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.accentColor)
                    .frame(width: 30, alignment: .trailing)
                    .padding(.top, 2)
                    .onTapGesture {
                        guard let onExplainLine, let snippet = stage.codeSnippet else { return }
                        let idx = snippet.firstIndex(where: { $0.id == line.id }) ?? 0
                        let startIdx = max(0, idx - 2)
                        let endIdx = min(snippet.count, idx + 3)
                        let neighborLines = snippet[startIdx..<endIdx]
                        let context = neighborLines.map { "\($0.lineNumber): \($0.code)" }.joined(separator: "\n")
                        let specificLine = "\(line.lineNumber): \(line.code)"
                        onExplainLine(specificLine, context)
                    }
                    .help("Explain this line with AI")
                Text(line.code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .textSelection(.enabled)
                if isFigureLine(line.code),
                   let cellIdx = stage.codeContext?.cellIndex {
                    Button(action: { onShowOutput?(cellIdx) }) {
                        Image(systemName: "eye")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help("Show output figure")
                    .padding(.leading, 2)
                }
            }
            Text(line.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 40)
        }
        .onHover { onHover($0) }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    line.lineNumber == stage.line ? Color.accentColor.opacity(0.1) :
                    isHovered ? Color.accentColor.opacity(0.05) :
                    Color.clear
                )
        )
        .overlay(alignment: .leading) {
            if line.lineNumber == stage.line {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
        }
    }

    private static let figureKeywords: Set<String> = [
        "plt.show", "plt.figure", "plt.subplots", "plt.imshow",
        "plt.tight_layout", "plt.savefig", "plt.plot", "plt.scatter",
        "plt.bar", "plt.hist", "plt.pie", "sns.",
    ]

    private func isFigureLine(_ code: String) -> Bool {
        let stripped = code.trimmingCharacters(in: .whitespaces)
        for kw in Self.figureKeywords {
            if stripped.hasPrefix(kw) { return true }
        }
        return false
    }
}
