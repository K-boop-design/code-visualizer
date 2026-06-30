import SwiftUI

struct InspectorPanel: View {
    let selectedNode: FlowchartNode?
    let selectedNodeCode: String?
    let selectedControlFlowNode: ControlFlowNode?
    let selectedControlFlowNodeCode: String?
    let selectedStage: PipelineStage?
    let fullCode: String
    let scriptResult: PythonScript?
    @ObservedObject var viewModel: VisualizationViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Inspector", systemImage: "info.circle")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let node = selectedNode {
                nodeInspector(node)
            } else if let cfNode = selectedControlFlowNode {
                controlFlowInspector(cfNode)
            } else if let stage = selectedStage {
                stageInspector(stage)
            } else if let result = scriptResult {
                overviewInspector(result)
            } else {
                emptyInspector
            }
        }
        .frame(minWidth: 250, idealWidth: 350)
    }

    private func inspectorSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3, height: 14)
                    .cornerRadius(1.5)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            content()
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            Spacer()
        }
    }

    @ViewBuilder
    private func codeBlock(_ code: String, highlightLine: Int?) -> some View {
        let lines = code.components(separatedBy: "\n")
        let base = highlightLine ?? 1
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, lineContent in
                let actualLine = base + idx
                let isHighlighted = highlightLine.map { actualLine == $0 } ?? false
                HStack(alignment: .top, spacing: 8) {
                    Text("\(actualLine)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(isHighlighted ? .accentColor : .secondary.opacity(0.6))
                        .frame(width: 28, alignment: .trailing)
                    Text(lineContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(alignment: .leading) {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: 3)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private func nodeInspector(_ node: FlowchartNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inspectorSection("Node Details") {
                    detailRow("Type", node.type)
                    detailRow("Label", node.label)
                    detailRow("Depth", "\(node.depth)")
                    if let lineno = node.lineno {
                        detailRow("Line", "\(lineno)")
                    }
                    if let endLineno = node.endLineno {
                        detailRow("End Line", "\(endLineno)")
                    }
                }

                inspectorSection("Description") {
                    Text(descriptionForNode(node))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    aiButton("Explain with AI") {
                        viewModel.explainWithAI(
                            prompt: "Explain this \(node.type) node '\(node.label)' in the context of a Python code flowchart. What does it do and why is it important?",
                            context: "Full code:\n\(fullCode)\n\nNode details: type=\(node.type), label=\(node.label), line=\(node.lineno ?? 0)",
                            system: "You are an expert Python tutor explaining code structure. Be concise (3-5 sentences) and educational."
                        )
                    }
                }

                aiResultSection

                if let code = selectedNodeCode, !code.isEmpty {
                    inspectorSection("Source Code") {
                        codeBlock(code, highlightLine: node.lineno)
                    }
                }
            }
            .padding()
        }
    }

    private func controlFlowInspector(_ node: ControlFlowNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inspectorSection("Structure Node") {
                    detailRow("Type", node.type)
                    detailRow("Label", node.label)
                    if let lineno = node.lineno {
                        detailRow("Line", "\(lineno)")
                    }
                    if let endLineno = node.endLineno {
                        detailRow("End Line", "\(endLineno)")
                    }
                }

                inspectorSection("Description") {
                    Text(node.brief ?? node.label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    aiButton("Explain with AI") {
                        viewModel.explainWithAI(
                            prompt: "Describe what this specific code does, line by line. Node: '\(node.label)' (type: \(node.type)).",
                            context: "Full code:\n\(fullCode)",
                            system: "You are an expert Python tutor. Explain what the specific code at this control flow node does — focus on the actual operations, function calls, and logic. Be concrete, not generic."
                        )
                    }
                }

                aiResultSection

                if let code = selectedControlFlowNodeCode, !code.isEmpty {
                    inspectorSection("Source Code") {
                        codeBlock(code, highlightLine: node.lineno)
                    }
                }
            }
            .padding()
        }
    }

    private func stageInspector(_ stage: PipelineStage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inspectorSection("Pipeline Stage") {
                    HStack(spacing: 6) {
                        Image(systemName: stage.stageIcon)
                            .foregroundColor(stageColor(stage.stage))
                        Text(stage.description)
                            .font(.headline)
                    }
                    detailRow("Code Pattern", stage.name)
                    detailRow("Line", "\(stage.line)")
                    if let target = stage.target {
                        detailRow("Target Variable", target)
                    }
                }

                inspectorSection("Description") {
                    Text(stageDescription(stage.stage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    aiButton("Explain with AI") {
                        let codeLines = stage.codeSnippet?.map { $0.code }.joined(separator: "\n") ?? ""
                        viewModel.explainWithAI(
                            prompt: "Describe exactly what the code below does, line by line. Then briefly mention which ML pipeline stage ('\(stage.description)') this belongs to.",
                            context: "STAGE: \(stage.description)\nCODE:\n\(codeLines)\n\nFull code:\n\(fullCode)",
                            system: "You are an expert Python tutor. Explain the specific code lines shown — what each function call, variable, and operation does. Keep explanations practical and concrete, not generic."
                        )
                    }
                }

                aiResultSection
            }
            .padding()
        }
    }

    private func overviewInspector(_ result: PythonScript) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inspectorSection("Script Overview") {
                    HStack {
                        Circle()
                            .fill(result.valid ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(result.valid ? "Valid" : "Error")
                            .font(.subheadline)
                    }
                    detailRow("Lines", "\(result.lines ?? 0)")
                    detailRow("Characters", "\(result.characters ?? 0)")
                }

                if let fc = result.flowchart {
                    inspectorSection("Flowchart") {
                        detailRow("Nodes", "\(fc.nodes.count)")
                        detailRow("Edges", "\(fc.edges.count)")
                    }
                }

                if let pipeline = result.pipeline {
                    inspectorSection("Pipeline") {
                        detailRow("Stages", "\(pipeline.stageCount)")
                        HStack {
                            Text("ML Pipeline:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: pipeline.isMLPipeline ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(pipeline.isMLPipeline ? .green : .secondary)
                                .font(.caption)
                            Text(pipeline.isMLPipeline ? "Yes" : "No")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        if pipeline.hasDataLoading {
                            Label("Data Loading", systemImage: "tray.and.arrow.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        if pipeline.hasModelTraining {
                            Label("Model Training", systemImage: "square.stack.3d.up")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                aiButton("Explain entire script with AI") {
                    viewModel.explainWithAI(
                        prompt: "Provide a concise analysis of this Python script. Describe its structure, purpose, and key components.",
                        context: "Full code:\n\(fullCode)",
                        system: "You are an expert code reviewer. Be concise (3-5 sentences). Focus on the overall architecture and purpose."
                    )
                }

                aiResultSection
            }
            .padding()
        }
    }

    private var emptyInspector: some View {
        VStack(spacing: 14) {
            Image(systemName: "info.circle")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No selection")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Click on a node or pipeline stage for details")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func descriptionForNode(_ node: FlowchartNode) -> String {
        switch node.type {
        case "function": return "Defines a reusable function. Functions help organize code into logical blocks."
        case "class": return "Defines a class, the foundation of object-oriented programming in Python."
        case "condition": return "Conditional branch (if/elif/else). The program flow splits based on a boolean condition."
        case "loop": return "Loop construct (for/while). Repeats a block of code multiple times."
        case "trycatch": return "Try-Except block for handling exceptions and errors gracefully."
        case "catch": return "Exception handler that catches and processes specific error types."
        case "assign": return "Variable assignment. Stores a value in memory for later use."
        case "call": return "Function or method call. Executes a named block of code."
        case "return": return "Return statement. Exits a function and optionally returns a value."
        case "import": return "Import statement. Loads external modules or libraries."
        case "module": return "Top-level module container representing the entire Python file."
        default: return "A generic statement in the Python code."
        }
    }

    private func stageDescription(_ stage: String) -> String {
        switch stage {
        case "data_loading": return "Data loading is the first step in any ML pipeline. Data is read from files (CSV, Excel, etc.) or APIs into memory for processing."
        case "eda": return "Exploratory Data Analysis involves understanding the dataset through statistics and visualizations to find patterns, anomalies, and relationships."
        case "preprocessing": return "Data preprocessing cleans and transforms raw data into a format suitable for machine learning models."
        case "feature_engineering": return "Feature engineering creates new features or transforms existing ones to improve model performance."
        case "model_training": return "Model training is the core ML step where an algorithm learns patterns from the training data."
        case "model_evaluation": return "Model evaluation assesses how well the trained model performs on unseen data using various metrics."
        case "prediction": return "Prediction uses a trained model to make forecasts or classifications on new data."
        case "hyperparameter_tuning": return "Hyperparameter tuning searches for the optimal configuration of model parameters to maximize performance."
        case "data_augmentation": return "Data augmentation increases dataset diversity by creating modified versions of existing data samples."
        default: return "A stage in the ML/Kaggle pipeline."
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

    @ViewBuilder
    private func aiButton(_ label: String, action: @escaping () -> Void) -> some View {
        if viewModel.isAIThinking {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("AI thinking...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 6)
        } else {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.caption)
                    Text(label)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var aiResultSection: some View {
        if !viewModel.aiConversation.isEmpty {
            inspectorSection("AI Chat") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button(action: { viewModel.clearAI() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                Text("Clear")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear conversation")
                    }
                    ForEach(viewModel.aiConversation) { msg in
                        HStack(alignment: .top, spacing: 6) {
                            Text(msg.role == "user" ? "You:" : "AI:")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(msg.role == "user" ? .accentColor : .green)
                                .frame(width: 28, alignment: .trailing)
                            Text(msg.content)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    if viewModel.isAIThinking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Cancel") {
                                viewModel.aiCancelled = true
                                viewModel.isAIThinking = false
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.leading, 34)
                    }
                    HStack(spacing: 6) {
                        TextField("Ask a follow-up question...", text: $viewModel.aiFollowUpText)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .onSubmit {
                                viewModel.sendFollowUp()
                            }
                        Button(action: { viewModel.sendFollowUp() }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .disabled(viewModel.aiFollowUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        } else if let error = viewModel.aiError {
            inspectorSection("AI Error") {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if viewModel.aiNeedsKey {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Set an API key in Settings (gear icon) to use AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .transition(.opacity)
        } else if viewModel.aiInvalidKey {
            let providerName: String = {
                switch viewModel.aiProvider {
                case "github": return "GitHub"
                case "deepseek": return "DeepSeek"
                case "groq": return "Groq"
                case "openrouter": return "OpenRouter"
                case "cerebras": return "Cerebras"
                case "mistral": return "Mistral"
                default: return "Gemini"
                }
            }()
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Invalid API key. Check your \(providerName) API key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .transition(.opacity)
        } else if viewModel.aiRateLimited {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Rate limited. Please wait a moment and try again")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .transition(.opacity)
        } else if viewModel.aiUnavailable {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
                Text("AI assistant unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.top, 4)
            .transition(.opacity)
        }
    }
}
