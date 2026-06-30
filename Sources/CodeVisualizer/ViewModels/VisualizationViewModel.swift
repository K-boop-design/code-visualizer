import SwiftUI
import Combine

@MainActor
final class VisualizationViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var mode: VisualizationMode = .full
    @Published var isAnalyzing = false
    @Published var scriptResult: PythonScript?
    @Published var errorMessage: String?
    @Published var selectedNodeId: String?
    @Published var selectedControlFlowNodeId: String?
    @Published var selectedPipelineStage: PipelineStage?
    @Published var nodeRects: [String: CGRect] = [:]
    @Published var showInspector = false
    @Published var requestedOutputCellIndex: Int?

    @Published var aiExplanation: String?
    @Published var isAIThinking = false
    @Published var aiError: String?
    @Published var aiUnavailable = false
    @Published var aiDownloading = false
    @Published var aiNeedsKey = false
    @Published var aiInvalidKey = false
    @Published var aiRateLimited = false
    @Published var aiDebugInfo: String?
    @Published var aiApiKey: String = ""
    @Published var aiProvider: String = "openai"
    @Published var aiConversation: [AIChatMessage] = []
    @Published var aiFollowUpText: String = ""
    @Published var aiSystemPrompt: String = ""
    @Published var aiContext: String = ""

    private let bridge = PythonBridge.shared
    private let layoutEngine = GraphLayoutEngine()

    init() {
        aiApiKey = UserDefaults.standard.string(forKey: "ai_api_key") ?? ""
        aiProvider = UserDefaults.standard.string(forKey: "ai_provider") ?? "openai"
    }

    func saveApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        aiApiKey = trimmed
        UserDefaults.standard.set(trimmed, forKey: "ai_api_key")
    }

    func saveProvider(_ provider: String) {
        aiProvider = provider
        UserDefaults.standard.set(provider, forKey: "ai_provider")
    }

    var flowchartNodes: [FlowchartNode] {
        scriptResult?.flowchart?.nodes ?? []
    }

    var flowchartEdges: [FlowchartEdge] {
        scriptResult?.flowchart?.edges ?? []
    }

    var pipelineStages: [PipelineStage] {
        scriptResult?.pipeline?.stages ?? []
    }

    var pipelineSummary: [PipelineStageSummary] {
        scriptResult?.pipeline?.pipelineSummary ?? []
    }

    var isMLPipeline: Bool {
        scriptResult?.pipeline?.isMLPipeline ?? false
    }

    var learningData: LearnData? {
        scriptResult?.learning
    }

    var controlFlowNodes: [ControlFlowNode] {
        scriptResult?.controlFlow ?? []
    }

    var valid: Bool {
        scriptResult?.valid ?? false
    }

    var lines: Int {
        scriptResult?.lines ?? 0
    }

    var characters: Int {
        scriptResult?.characters ?? 0
    }

    var suggestedMode: String {
        scriptResult?.suggestedMode ?? "flowchart"
    }

    var selectedFlowchartNode: FlowchartNode? {
        guard let id = selectedNodeId else { return nil }
        return flowchartNodes.first { $0.id == id }
    }

    var selectedNodeCode: String? {
        guard let node = selectedFlowchartNode, let lineno = node.lineno else { return nil }
        return extractCode(from: lineno, end: node.endLineno)
    }

    var selectedControlFlowNode: ControlFlowNode? {
        guard let id = selectedControlFlowNodeId else { return nil }
        return controlFlowNodes.first { $0.id == id }
    }

    var selectedControlFlowNodeCode: String? {
        guard let node = selectedControlFlowNode, let lineno = node.lineno else { return nil }
        return extractCode(from: lineno, end: node.endLineno)
    }

    private func extractCode(from lineno: Int, end endLineno: Int? = nil) -> String? {
        let lines = code.components(separatedBy: "\n")
        let startIdx = max(0, lineno - 1)
        let endIdx: Int
        if let endLineno = endLineno {
            endIdx = min(endLineno, lines.count)
        } else {
            endIdx = min(startIdx + 20, lines.count)
        }
        guard startIdx < endIdx else { return nil }
        return lines[startIdx..<endIdx].joined(separator: "\n")
    }

    @Published var notebookInfo: NotebookData?
    @Published var loadedFilePath: String?

    var hasContent: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isNotebook: Bool {
        scriptResult?.sourceType == "notebook"
    }

    var notebookName: String {
        notebookInfo?.notebookName ?? loadedFilePath ?? ""
    }

    var outputImages: [NotebookOutputImage] {
        notebookInfo?.outputImages ?? []
    }

    func analyze() {
        guard hasContent else {
            errorMessage = "Please enter Python code"
            return
        }

        isAnalyzing = true
        errorMessage = nil
        selectedNodeId = nil
        selectedControlFlowNodeId = nil
        selectedPipelineStage = nil
        requestedOutputCellIndex = nil

        Task {
            let result = await bridge.analyze(code: code, mode: mode.rawValue)

            if !result.valid {
                errorMessage = result.error ?? "Analysis failed"
            }

            scriptResult = result
            notebookInfo = result.notebook

            if result.valid, let flowchart = result.flowchart {
                layoutNodes(flowchart.nodes, flowchart.edges)
            }

            isAnalyzing = false
        }
    }

    func analyzeNotebook(at url: URL) {
        let t0 = CFAbsoluteTimeGetCurrent()
        let isBundleResource = url.path.hasPrefix(Bundle.main.bundlePath)
        let needsStop = isBundleResource || url.startAccessingSecurityScopedResource()
        if !needsStop {
            errorMessage = "Cannot access file: \(url.lastPathComponent)"
            return
        }
        let t1 = CFAbsoluteTimeGetCurrent()
        print("[Timing] security scope: \(t1-t0)s")

        loadedFilePath = url.path
        isAnalyzing = true
        errorMessage = nil
        selectedNodeId = nil
        selectedControlFlowNodeId = nil
        selectedPipelineStage = nil
        requestedOutputCellIndex = nil

        Task {
            let t2 = CFAbsoluteTimeGetCurrent()
            let result = await bridge.analyze(notebookPath: url.path, mode: mode.rawValue)
            let t3 = CFAbsoluteTimeGetCurrent()
            print("[Timing] Python bridge: \(t3-t2)s")
            if !isBundleResource {
                url.stopAccessingSecurityScopedResource()
            }

            if !result.valid {
                errorMessage = result.error ?? "Failed to analyze notebook"
            }

            let t4 = CFAbsoluteTimeGetCurrent()
            scriptResult = result
            notebookInfo = result.notebook

            if let notebook = result.notebook, let nbCode = notebook.code {
                code = nbCode
            }

            if result.valid, let flowchart = result.flowchart {
                layoutNodes(flowchart.nodes, flowchart.edges)
            }
            let t5 = CFAbsoluteTimeGetCurrent()
            print("[Timing] Swift state update + layout: \(t5-t4)s")
            print("[Timing] Total analyzeNotebook: \(t5-t0)s")

            isAnalyzing = false
        }
    }

    func analyzeSample(_ sampleCode: String) {
        code = sampleCode
        notebookInfo = nil
        loadedFilePath = nil
        analyze()
    }

    private func layoutNodes(_ nodes: [FlowchartNode], _ edges: [FlowchartEdge]) {
        let rects = layoutEngine.layoutTree(nodes: nodes, edges: edges)
        withAnimation(.easeOut(duration: 0.3)) {
            nodeRects = rects
        }
    }

    func explainWithAI(prompt: String, context: String = "", system: String = "") {
        guard !aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[AI Debug] No API key set")
            aiNeedsKey = true
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { aiNeedsKey = false }
            }
            return
        }

        aiSystemPrompt = system
        aiContext = context

        let maxContextLen = 3000
        let truncatedContext = context.count > maxContextLen
            ? String(context.prefix(maxContextLen)) + "\n... (truncated)"
            : context

        isAIThinking = true
        aiError = nil
        aiExplanation = nil
        aiUnavailable = false
        aiDownloading = false
        aiNeedsKey = false
        aiInvalidKey = false
        aiRateLimited = false
        aiConversation = []

        Task {
            let result = await bridge.queryAI(prompt: prompt, apiKey: aiApiKey, provider: aiProvider, context: truncatedContext, system: system)
            isAIThinking = false
            aiDebugInfo = "provider=\(aiProvider) status=\(result.status ?? "nil") error=\(result.error ?? "nil")"
            if let response = result.response {
                aiExplanation = response
                aiConversation.append(AIChatMessage(role: "assistant", content: response))
            } else if let error = result.error {
                aiError = error
                aiConversation = []
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    withAnimation { aiError = nil }
                }
            } else {
                aiConversation = []
                switch result.status {
                case "no_key":
                    aiNeedsKey = true
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation { aiNeedsKey = false }
                    }
                case "invalid_key":
                    aiInvalidKey = true
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation { aiInvalidKey = false }
                    }
                case "rate_limited":
                    aiRateLimited = true
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation { aiRateLimited = false }
                    }
                default:
                    aiUnavailable = true
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation { aiUnavailable = false }
                    }
                }
            }
        }
    }

    func sendFollowUp() {
        let text = aiFollowUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        aiFollowUpText = ""

        let userMsg = AIChatMessage(role: "user", content: text)
        aiConversation.append(userMsg)
        isAIThinking = true
        aiError = nil

        var messagesToSend: [AIChatMessage] = []
        if !aiContext.isEmpty {
            messagesToSend.append(AIChatMessage(role: "system", content: "Here is the relevant code context:\n\n\(aiContext)"))
        }
        if !aiSystemPrompt.isEmpty {
            messagesToSend.append(AIChatMessage(role: "system", content: aiSystemPrompt))
        }
        messagesToSend += aiConversation.map { AIChatMessage(role: $0.role, content: $0.content) }

        Task {
            let result = await bridge.queryAIConversation(messages: messagesToSend, apiKey: aiApiKey, provider: aiProvider)
            isAIThinking = false
            if let response = result.response {
                aiExplanation = response
                aiConversation.append(AIChatMessage(role: "assistant", content: response))
            } else if let error = result.error {
                aiError = error
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    withAnimation { aiError = nil }
                }
            } else {
                switch result.status {
                case "no_key": aiNeedsKey = true
                case "invalid_key": aiInvalidKey = true
                case "rate_limited": aiRateLimited = true
                default: aiUnavailable = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    withAnimation { [weak self] in
                        self?.aiNeedsKey = false
                        self?.aiInvalidKey = false
                        self?.aiRateLimited = false
                        self?.aiUnavailable = false
                    }
                }
            }
        }
    }

    func clearAI() {
        aiConversation = []
        aiFollowUpText = ""
        aiSystemPrompt = ""
        aiContext = ""
        aiExplanation = nil
        aiError = nil
        isAIThinking = false
        aiUnavailable = false
        aiNeedsKey = false
        aiInvalidKey = false
        aiRateLimited = false
        aiDebugInfo = nil
    }

    func clear() {
        code = ""
        scriptResult = nil
        errorMessage = nil
        selectedNodeId = nil
        selectedControlFlowNodeId = nil
        selectedPipelineStage = nil
        requestedOutputCellIndex = nil
        nodeRects = [:]
        notebookInfo = nil
        loadedFilePath = nil
        aiExplanation = nil
        aiError = nil
        isAIThinking = false
        aiUnavailable = false
        aiDownloading = false
        aiNeedsKey = false
        aiInvalidKey = false
        aiRateLimited = false
        aiDebugInfo = nil
        aiConversation = []
        aiFollowUpText = ""
        aiSystemPrompt = ""
        aiContext = ""
    }
}

enum VisualizationMode: String, CaseIterable {
    case flowchart = "flowchart"
    case pipeline = "pipeline"
    case full = "full"

    var label: String {
        switch self {
        case .flowchart: return "Flowchart"
        case .pipeline: return "Pipeline"
        case .full: return "Full"
        }
    }

    var icon: String {
        switch self {
        case .flowchart: return "flowchart"
        case .pipeline: return "square.stack.3d.up"
        case .full: return "square.on.square"
        }
    }
}
