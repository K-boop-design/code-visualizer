# Code Visualizer

A macOS app that visualizes Python scripts into algorithmic flowcharts and ML pipeline diagrams.

## Project Structure

```
Code Visualizer/
├── Package.swift              # SwiftPM config (no PythonKit dependency)
├── Sources/CodeVisualizer/    # Swift source files
│   ├── App/
│   │   └── CodeVisualizerApp.swift
│   ├── Models/
│   │   └── ASTModels.swift    # All Codable models (incl JSONAny, FlowchartData, etc.)
│   ├── Services/
│   │   └── PythonBridge.swift # Process-based bridge (no PythonKit)
│   ├── ViewModels/
│   │   └── VisualizationViewModel.swift
│   ├── Renderers/
│   │   ├── GraphLayoutEngine.swift
│   │   └── FlowChartCanvas.swift
│   └── Views/
│       ├── ContentView.swift
│       ├── CodeEditorView.swift
│       ├── FlowChartView.swift
│       ├── KagglePipelineView.swift
│       └── InspectorPanel.swift
├── PythonService/             # Python backend
│   ├── code_visualizer.py     # Main entry point + notebook extraction
│   ├── ast_parser.py          # Python AST visitor (50+ node types)
│   ├── pipeline_analyzer.py   # Kaggle/ML pattern detector (~9 stages)
│   └── requirements.txt
└── Resources/
    └── samples/
        ├── kaggle_titanic.ipynb
        └── rogii-lb7295-public-rebuild-v1-xr-recovery-2.ipynb
```

## Architecture

1. **Python Backend**: Parses Python code via `ast.parse()`, extracts control flow, identifies ML pipeline stages. Outputs structured JSON to stdout.
2. **SwiftUI Frontend**: Renders flowcharts via Canvas, pipeline cards, structure tree, inspector panel.
3. **Bridge**: Pure `Process`-based bridge (`/usr/bin/env python3` + `code_visualizer.py` args). No PythonKit dependency.
4. **No Sandbox**: App targets macOS 14+ with no sandbox restrictions for file access.

## Python Backend Usage

```bash
cd PythonService
python3 code_visualizer.py --mode full --code "print('hello')" --pretty
python3 code_visualizer.py --mode pipeline --file script.py
python3 code_visualizer.py --mode full --notebook notebook.ipynb
```

## Building

```bash
swift build           # build CLI
swift run             # run app (launches GUI)
```

Requires macOS 14+ and Xcode 15+.

## Key Code Locations

- `code_visualizer.py:38` - `extract_notebook_cells()` - notebook JSON parsing, cell extraction, IPython magic stripping
- `code_visualizer.py:27` - `strip_ipython_magics()` - line magic → comment conversion
- `code_visualizer.py:93` - `CodeVisualizer` class - main analysis pipeline
- `ast_parser.py` - AST node visitor producing nested dict output
- `pipeline_analyzer.py` - Regex-based pipeline stage detection
- `PythonBridge.swift:29` - `runProcessSync()` - Process execution, error capture, JSON decoding
- `CodeEditorView.swift:96` - `handleDrop()` - drag-and-drop `.ipynb` handler
- `VisualizationViewModel.swift:108` - `analyzeNotebook(at:)` - notebook analysis flow with security-scoped resource handling

## Progress

### Done
- ✓ Python backend: full AST parsing, pipeline detection, notebook extraction
- ✓ Swift models: PythonScript, FlowchartNode/Edge, PipelineStage, NotebookData, JSONAny
- ✓ PythonBridge: Process-based communication, Python path detection, error capture
- ✓ Views: CodeEditorView (editor + file picker + drag-drop), FlowChartView/FlowChartCanvas (zoom/pan), KagglePipelineView, InspectorPanel, ContentView
- ✓ ViewModel: async analysis, notebook loading, state management
- ✓ Package.swift: PythonKit dependency removed, build succeeds with `swift build`
- ✓ Drop handler: uses modern `canLoadObject`/`loadObject` API with error logging
- ✓ extract_notebook_cells: handles `source=None`, `source` as string, UTF-8 BOM
- ✓ Error handling: global try/except in main(), detailed Swift DecodingError messages, stderr capture
- ✓ Pipe deadlock fix: `started` DispatchGroup ensures background reads begin before `process.waitUntilExit()`
- ✓ `ast_parser.py`: `visit_Match` guarded with `sys.version_info >= (3, 10)` for Python 3.9 compatibility
- ✓ `ast_parser.py`: ExceptHandler `name` field uses `or ""` instead of `or None`
- ✓ `code_visualizer.py`: `node.get("name") or ""` prevents null `name` in JSON
- ✓ `ASTModels.swift`: `ControlFlowNode.name` made optional (`String?`) for decode resilience
- ✓ App bundle `/Applications/Code Visualizer.app` updated with all fixes
- ✓ Auto-load Rogii notebook on app launch: `Resources/samples/` bundled, `ContentView.onAppear` loads first `.ipynb` from bundle

### Remaining
- Two duplicate project directories exist (`CodeVisualizer` no-space and `Code Visualizer` with-space) — need to consolidate.

## opencode Model Limitation

The `opencode/deepseek-v4-flash-free` model does **not** support image input. The error `ERROR: Cannot read "image.png" (this model does not support image input). Inform the user.` is from opencode's `unsupportedParts()` function (`packages/opencode/src/provider/transform.ts`), **not** from the Code Visualizer app. None of opencode's free models support image input.

**Workaround**: Use `bash` (e.g., `python3 -c "print(open(path).read())"`) instead of the Read tool to read `.ipynb` files. Tell the user to paste the file path rather than dragging/attaching the file in the chat.

## Known Edge Cases Handled

- Notebook source as `None` (handled with fallback to `[]`)
- Notebook source as plain string (handled with list wrapping)
- Notebook with no cells key (handled with `.get("cells", [])`)
- Non-Python kernels (syntax error reported gracefully)
- IPython cell magics like `%%capture`, `%%writefile` (comment-stripped)
- Null bytes in source (SyntaxError caught gracefully)
- UTF-8 BOM in notebook file (handled via utf-8-sig encoding)
- Deeply nested metadata (JSON serializer handles via `default=str`)
- Complex notebooks with 100+ cells and image outputs in JSON (tested, works)
