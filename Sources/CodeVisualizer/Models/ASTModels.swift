import Foundation

struct JSONAny: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { value = str }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let dbl = try? container.decode(Double.self) { value = dbl }
        else if let bol = try? container.decode(Bool.self) { value = bol }
        else if let arr = try? container.decode([JSONAny].self) { value = arr.map { $0.value } }
        else if let dict = try? container.decode([String: JSONAny].self) { value = dict.mapValues { $0.value } }
        else { value = "?" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String { try container.encode(str) }
        else if let int = value as? Int { try container.encode(int) }
        else if let dbl = value as? Double { try container.encode(dbl) }
        else if let bol = value as? Bool { try container.encode(bol) }
        else if let arr = value as? [Any] { try container.encode(arr.map { JSONAny($0) }) }
        else if let dict = value as? [String: Any] { try container.encode(dict.mapValues { JSONAny($0) }) }
    }
}

struct PythonScript: Codable {
    let valid: Bool
    let lines: Int?
    let characters: Int?
    let ast: [String: JSONAny]?
    let controlFlow: [ControlFlowNode]?
    let flowchart: FlowchartData?
    let pipeline: PipelineData?
    let learning: LearnData?
    let suggestedMode: String?
    let error: String?
    let notebook: NotebookData?
    let sourceType: String?

    enum CodingKeys: String, CodingKey {
        case valid, lines, characters, ast, error
        case controlFlow = "control_flow"
        case flowchart, pipeline, learning
        case suggestedMode = "suggested_mode"
        case notebook
        case sourceType = "source_type"
    }

    init(valid: Bool, lines: Int? = nil, characters: Int? = nil, ast: [String: JSONAny]? = nil, controlFlow: [ControlFlowNode]? = nil, flowchart: FlowchartData? = nil, pipeline: PipelineData? = nil, learning: LearnData? = nil, suggestedMode: String? = nil, error: String? = nil, notebook: NotebookData? = nil, sourceType: String? = nil) {
        self.valid = valid
        self.lines = lines
        self.characters = characters
        self.ast = ast
        self.controlFlow = controlFlow
        self.flowchart = flowchart
        self.pipeline = pipeline
        self.learning = learning
        self.suggestedMode = suggestedMode
        self.error = error
        self.notebook = notebook
        self.sourceType = sourceType
    }
}

struct ControlFlowNode: Codable, Identifiable {
    let id: String
    let parentId: String
    let type: String
    let depth: Int
    let lineno: Int?
    let endLineno: Int?
    let name: String?
    let label: String
    let brief: String?
    let icon: String
    let isRoot: Bool?
    let children: [String]?

    enum CodingKeys: String, CodingKey {
        case id, type, depth, lineno, name, label, brief, icon, children
        case parentId = "parent_id"
        case isRoot = "is_root"
        case endLineno = "end_lineno"
    }
}

struct FlowchartData: Codable {
    let nodes: [FlowchartNode]
    let edges: [FlowchartEdge]
    let root: String
}

struct FlowchartNode: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let type: String
    let lineno: Int?
    let endLineno: Int?
    let depth: Int

    enum CodingKeys: String, CodingKey {
        case id, label, type, lineno, depth
        case endLineno = "end_lineno"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FlowchartNode, rhs: FlowchartNode) -> Bool {
        lhs.id == rhs.id
    }
}

struct FlowchartEdge: Codable, Identifiable {
    let from: String
    let to: String

    var id: String { "\(from)->\(to)" }
}

struct PipelineData: Codable {
    let stages: [PipelineStage]
    let pipelineSummary: [PipelineStageSummary]
    let stageCount: Int
    let hasDataLoading: Bool
    let hasModelTraining: Bool
    let hasEvaluation: Bool
    let isMLPipeline: Bool

    enum CodingKeys: String, CodingKey {
        case stages
        case pipelineSummary = "pipeline_summary"
        case stageCount = "stage_count"
        case hasDataLoading = "has_data_loading"
        case hasModelTraining = "has_model_training"
        case hasEvaluation = "has_evaluation"
        case isMLPipeline = "is_ml_pipeline"
    }
}

struct CodeLine: Codable, Identifiable {
    let lineNumber: Int
    let code: String
    let description: String

    var id: Int { lineNumber }

    enum CodingKeys: String, CodingKey {
        case lineNumber = "line_number"
        case code
        case desc = "description"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lineNumber = try c.decode(Int.self, forKey: .lineNumber)
        code = try c.decode(String.self, forKey: .code)
        description = try c.decode(String.self, forKey: .desc)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lineNumber, forKey: .lineNumber)
        try c.encode(code, forKey: .code)
        try c.encode(description, forKey: .desc)
    }
}

struct CodeContext: Codable {
    let startLine: Int
    let endLine: Int
    let cellIndex: Int?

    enum CodingKeys: String, CodingKey {
        case startLine = "start_line"
        case endLine = "end_line"
        case cellIndex = "cell_index"
    }
}

struct PipelineStage: Codable, Identifiable {
    let stage: String
    let name: String
    let line: Int
    let description: String
    let target: String?
    let codeSnippet: [CodeLine]?
    let codeContext: CodeContext?

    var id: String { "\(stage)-\(line)-\(name)" }

    enum CodingKeys: String, CodingKey {
        case stage, name, line, target
        case desc = "description"
        case codeSnippet = "code_snippet"
        case codeContext = "code_context"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decode(String.self, forKey: .stage)
        name = try c.decode(String.self, forKey: .name)
        line = try c.decode(Int.self, forKey: .line)
        description = try c.decode(String.self, forKey: .desc)
        target = try c.decodeIfPresent(String.self, forKey: .target)
        codeSnippet = try c.decodeIfPresent([CodeLine].self, forKey: .codeSnippet)
        codeContext = try c.decodeIfPresent(CodeContext.self, forKey: .codeContext)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stage, forKey: .stage)
        try c.encode(name, forKey: .name)
        try c.encode(line, forKey: .line)
        try c.encode(description, forKey: .desc)
        try c.encodeIfPresent(target, forKey: .target)
        try c.encodeIfPresent(codeSnippet, forKey: .codeSnippet)
        try c.encodeIfPresent(codeContext, forKey: .codeContext)
    }

    var stageColor: String {
        switch stage {
        case "data_loading": return "blue"
        case "eda": return "green"
        case "preprocessing": return "orange"
        case "feature_engineering": return "purple"
        case "model_training": return "red"
        case "model_evaluation": return "yellow"
        case "prediction": return "teal"
        case "hyperparameter_tuning": return "pink"
        case "data_augmentation": return "indigo"
        default: return "gray"
        }
    }

    var stageIcon: String {
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
}

struct PipelineStageSummary: Codable, Identifiable {
    let stage: String
    let description: String
    let line: Int

    var id: String { stage }
}

struct NotebookData: Codable {
    let valid: Bool
    let notebookName: String?
    let totalCells: Int?
    let codeCells: Int?
    let markdownCells: Int?
    let code: String?
    let codeCellDetails: [NotebookCell]?
    let markdownCellDetails: [NotebookCell]?
    let cellBoundaries: [CellBoundary]?
    let outputImages: [NotebookOutputImage]?
    let kernelspec: KernelSpec?
    let language: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case notebookName = "notebook_name"
        case totalCells = "total_cells"
        case codeCells = "code_cells"
        case markdownCells = "markdown_cells"
        case code
        case codeCellDetails = "code_cell_details"
        case markdownCellDetails = "markdown_cell_details"
        case cellBoundaries = "cell_boundaries"
        case outputImages = "output_images"
        case kernelspec
        case language
    }
}

struct NotebookOutputImage: Codable, Identifiable {
    let cellIndex: Int
    let outputIndex: Int
    let path: String

    var id: String { "cell_\(cellIndex)_output_\(outputIndex)" }

    enum CodingKeys: String, CodingKey {
        case cellIndex = "cell_index"
        case outputIndex = "output_index"
        case path
    }
}

struct NotebookCell: Codable, Identifiable {
    let index: Int
    let type: String
    let source: String
    let lines: Int

    var id: Int { index }
}

struct LearnData: Codable {
    let lessons: [LearnLesson]
    let competitionStrategy: String
    let skillProgress: [SkillProgress]
    let recommendedNext: [String]?
    let totalStages: Int
    let masteryLevel: String

    enum CodingKeys: String, CodingKey {
        case lessons
        case competitionStrategy = "competition_strategy"
        case skillProgress = "skill_progress"
        case recommendedNext = "recommended_next"
        case totalStages = "total_stages"
        case masteryLevel = "mastery_level"
    }
}

struct LearnLesson: Codable, Identifiable {
    let stage: String
    let title: String
    let explanation: String
    let kaggleSkill: String
    let tips: [String]
    let difficulty: String
    let learningOutcome: String

    var id: String { stage }

    enum CodingKeys: String, CodingKey {
        case stage, title, explanation, tips, difficulty
        case kaggleSkill = "kaggle_skill"
        case learningOutcome = "learning_outcome"
    }

    var color: String {
        switch difficulty {
        case "Beginner": return "green"
        case "Intermediate": return "blue"
        case "Advanced": return "orange"
        default: return "gray"
        }
    }
}

struct SkillProgress: Codable, Identifiable {
    let skill: String
    let difficulty: String
    let stage: String

    var id: String { stage }
}

struct AIChatMessage: Encodable, Identifiable {
    let id: String
    let role: String
    let content: String

    init(id: String = UUID().uuidString, role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}

struct CellBoundary: Codable {
    let cellIndex: Int
    let startLine: Int
    let endLine: Int

    enum CodingKeys: String, CodingKey {
        case cellIndex = "cell_index"
        case startLine = "start_line"
        case endLine = "end_line"
    }
}

struct KernelSpec: Codable {
    let name: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
    }
}
