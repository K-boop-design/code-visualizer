import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VisualizationViewModel()
    @State private var selectedTab: VisualizationTab = .flowchart
    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var settingsApiKey: String = ""
    @State private var settingsProvider: String = "groq"

    var body: some View {
        NavigationSplitView {
            CodeEditorView(
                code: $viewModel.code,
                isAnalyzing: viewModel.isAnalyzing,
                onAnalyze: viewModel.analyze,
                onClear: viewModel.clear,
                onOpenNotebook: { url in viewModel.analyzeNotebook(at: url) },
                notebookName: viewModel.isNotebook ? viewModel.notebookName : nil
            )
            .frame(minWidth: 250, idealWidth: 350)
        } content: {
            visualizationContent
                .frame(minWidth: 350, idealWidth: 350)
        } detail: {
            InspectorPanel(
                selectedNode: viewModel.selectedFlowchartNode,
                selectedNodeCode: viewModel.selectedNodeCode,
                selectedControlFlowNode: viewModel.selectedControlFlowNode,
                selectedControlFlowNodeCode: viewModel.selectedControlFlowNodeCode,
                selectedStage: viewModel.selectedPipelineStage,
                fullCode: viewModel.code,
                scriptResult: viewModel.scriptResult,
                viewModel: viewModel
            )
        }
        .navigationTitle("Code Visualizer")
        .navigationSubtitle(
            viewModel.isNotebook
                ? "\(viewModel.notebookName)  ·  \(viewModel.lines) lines  ·  \(viewModel.characters) chars"
                : viewModel.valid
                    ? "\(viewModel.lines) lines  ·  \(viewModel.characters) chars"
                    : ""
        )
        .toolbar {
            ToolbarItemGroup {
                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(VisualizationMode.allCases, id: \.self) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Visualization mode")
            }

            ToolbarItem {
                Button(action: { showSettings.toggle() }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .popover(isPresented: $showSettings) {
                    settingsView
                }
            }
        }
        .onChange(of: viewModel.mode) { _, _ in
            if viewModel.hasContent {
                viewModel.analyze()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case .structure:
                viewModel.selectedNodeId = nil
                viewModel.selectedPipelineStage = nil
            case .flowchart:
                viewModel.selectedControlFlowNodeId = nil
                viewModel.selectedPipelineStage = nil
            case .pipeline:
                viewModel.selectedNodeId = nil
                viewModel.selectedControlFlowNodeId = nil
            default:
                break
            }
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
                showOnboarding = true
            }
            if let samplesURL = Bundle.main.resourceURL?.appendingPathComponent("samples"),
               let files = try? FileManager.default.contentsOfDirectory(at: samplesURL, includingPropertiesForKeys: nil),
               let notebookFile = files.first(where: { $0.pathExtension == "ipynb" }) {
                viewModel.analyzeNotebook(at: notebookFile)
            }
        }
        .overlay(
            Group {
                if showOnboarding {
                    UITutorialOverlay(isPresented: $showOnboarding)
                        .transition(.opacity)
                }
            }
        )
    }

    @ViewBuilder
    private var visualizationContent: some View {
        if let error = viewModel.errorMessage {
            errorView(error)
        } else if viewModel.isAnalyzing {
            loadingView
        } else if viewModel.scriptResult != nil {
            tabView
        } else {
            welcomeView
        }
    }

    private var tabView: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Label("Flowchart", systemImage: "flowchart").tag(VisualizationTab.flowchart)
                Label("Pipeline", systemImage: "square.stack.3d.up").tag(VisualizationTab.pipeline)
                Label("Structure", systemImage: "list.tree").tag(VisualizationTab.structure)
                if !viewModel.outputImages.isEmpty {
                    Label("Outputs", systemImage: "photo.on.rectangle").tag(VisualizationTab.outputs)
                }
                if viewModel.learningData != nil {
                    Label("Learn", systemImage: "graduationcap").tag(VisualizationTab.learn)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case .flowchart:
                FlowChartView(
                    nodes: viewModel.flowchartNodes,
                    edges: viewModel.flowchartEdges,
                    selectedNodeId: $viewModel.selectedNodeId,
                    nodeRects: viewModel.nodeRects
                )
            case .pipeline:
                KagglePipelineView(
                    stages: viewModel.pipelineStages,
                    summary: viewModel.pipelineSummary,
                    isMLPipeline: viewModel.isMLPipeline,
                    selectedStage: $viewModel.selectedPipelineStage,
                    onShowOutput: { cellIdx in
                        viewModel.requestedOutputCellIndex = cellIdx
                        selectedTab = .outputs
                    },
                    onExplainLine: { specificLine, context in
                        viewModel.explainWithAI(
                            prompt: "Describe what this specific line of code does in the context of the ML pipeline:\n\n\(specificLine)\n\nSurrounding code:\n\(context)",
                            context: "Full code:\n\(viewModel.code)",
                            system: "You are an expert Python tutor. Explain the specific code line shown — what function call, variable, or operation it performs. Reference the surrounding lines for context. Be concise (2-4 sentences) and practical."
                        )
                    },
                    fullCode: viewModel.code
                )
            case .structure:
                structureView
            case .outputs:
                OutputsView(images: viewModel.outputImages, highlightedCellIndex: viewModel.requestedOutputCellIndex)
            case .learn:
                if let data = viewModel.learningData {
                    LearnView(learningData: data)
                }
            }
        }
    }

    private var structureView: some View {
        List(viewModel.controlFlowNodes, selection: $viewModel.selectedControlFlowNodeId) { node in
            HStack(spacing: 8) {
                Image(systemName: iconFor(node.icon))
                    .foregroundColor(colorFor(node.icon))
                    .font(.caption)
                    .frame(width: 16)
                Text(String(repeating: "  ", count: node.depth))
                    .font(.caption2) +
                Text(node.label)
                    .font(.subheadline)
                Spacer()
                if let lineno = node.lineno {
                    Text("L\(lineno)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 3)
            .padding(.leading, 4)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.8)
                .controlSize(.large)
            Text("Analyzing code...")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Parsing AST, detecting patterns, building visualizations")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flowchart")
                .font(.system(size: 64))
                .foregroundStyle(
                    .linearGradient(colors: [.accentColor, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("Code Visualizer")
                .font(.largeTitle.weight(.bold))
            Text("Paste Python code to visualize it\nas flowcharts and ML pipelines")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(
                    .linearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                )
            Text("Error")
                .font(.title2.weight(.semibold))
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                Text("AI Settings")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Provider")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Picker("Provider", selection: $settingsProvider) {
                    Text("OpenRouter (20+ free models)").tag("openrouter")
                    Text("GitHub Models (free GPT-4o)").tag("github")
                    Text("Groq (free Llama/Mixtral)").tag("groq")
                    Text("Google Gemini (free)").tag("gemini")
                    Text("Cerebras (free, 1M tok/day)").tag("cerebras")
                    Text("Mistral (free, 1B tok/mo)").tag("mistral")
                    Text("DeepSeek (free tier)").tag("deepseek")
                    Text("OpenAI (ChatGPT)").tag("openai")
                }
                .pickerStyle(.radioGroup)
            }

            VStack(alignment: .leading, spacing: 4) {
                let providerLabel: String = {
                    switch settingsProvider {
                    case "openrouter": return "OpenRouter API Key"
                    case "github": return "GitHub Personal Access Token"
                    case "groq": return "Groq API Key"
                    case "gemini": return "Gemini API Key"
                    case "cerebras": return "Cerebras API Key"
                    case "mistral": return "Mistral API Key"
                    case "deepseek": return "DeepSeek API Key"
                    default: return "OpenAI API Key"
                    }
                }()
                let providerHelp: String = {
                    switch settingsProvider {
                    case "openrouter": return "openrouter.ai/keys — 20+ free models, 50 req/day, no CC"
                    case "github": return "github.com/settings/tokens — free GPT-4o, no scopes needed"
                    case "groq": return "console.groq.com — free Llama 3.3 70B, 1000 req/day"
                    case "gemini": return "aistudio.google.com — free Gemini 2.0 Flash, 1500 req/day"
                    case "cerebras": return "cloud.cerebras.ai — ~1M tokens/day free, no CC, ultra-fast"
                    case "mistral": return "console.mistral.ai — ~1B tokens/month on Experiment plan"
                    case "deepseek": return "platform.deepseek.com — free deepseek-chat model"
                    default: return "platform.openai.com — paid (not recommended, use free providers)"
                    }
                }()
                Text(providerLabel)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                SecureField("Paste your API key", text: $settingsApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text(providerHelp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("Save") {
                    viewModel.saveProvider(settingsProvider)
                    viewModel.saveApiKey(settingsApiKey)
                    showSettings = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(settingsApiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 340)
        .onAppear {
            settingsApiKey = viewModel.aiApiKey
            settingsProvider = viewModel.aiProvider
        }
    }

    private func iconFor(_ icon: String) -> String {
        switch icon {
        case "function": return "f.square"
        case "class": return "c.square"
        case "condition": return "diamond"
        case "loop": return "arrow.triangle.capsulepath"
        case "trycatch": return "exclamationmark.triangle"
        case "assign": return "equal.square"
        case "call": return "play.square"
        case "return": return "arrow.left.square"
        case "import": return "square.and.arrow.down"
        case "module": return "rectangle.stack"
        default: return "circle"
        }
    }

    private func colorFor(_ icon: String) -> Color {
        switch icon {
        case "function": return .blue
        case "class": return .purple
        case "condition": return .orange
        case "loop": return .green
        case "trycatch": return .red
        case "return": return .teal
        case "import": return .gray
        default: return .primary
        }
    }
}

enum VisualizationTab: String, CaseIterable {
    case flowchart
    case pipeline
    case structure
    case learn
    case outputs
}
