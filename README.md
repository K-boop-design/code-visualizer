# Code Visualizer

Turn Python scripts and Jupyter notebooks into interactive flowcharts, structure maps, and machine-learning pipeline diagrams on macOS.

Code Visualizer is a native macOS app for understanding unfamiliar Python code faster. Paste a script, open a `.py` file, or drag in a `.ipynb` notebook and the app analyzes the code locally, then shows the control flow, detected ML stages, notebook outputs, and learning-oriented explanations in one workspace.

![Code Visualizer app icon](Resources/AppIcon.icns)

## What It Does

- Builds interactive flowcharts from Python control flow.
- Detects common Kaggle and machine-learning pipeline stages.
- Opens Jupyter notebooks and extracts Python cells.
- Shows notebook output images when available.
- Lets you inspect generated nodes and jump back to source code.
- Includes a structure tree for functions, classes, branches, loops, and expressions.
- Provides a learning view for Kaggle-style workflows and ML concepts.
- Runs the Python parser through a process bridge, without PythonKit.

## Who It Is For

- Students learning Python, data science, or algorithms.
- Kaggle users who want to understand competition notebooks.
- ML engineers reviewing pipeline-heavy scripts.
- Teachers who need visual material for explaining code.
- Developers onboarding into unfamiliar Python projects.

## Why It Helps

Python notebooks can hide important logic across many cells. Code Visualizer makes the shape of the program visible: where data is loaded, how it is transformed, where models are trained, and which lines belong to each stage.

Instead of reading a notebook from top to bottom and hoping the structure becomes clear, you get a visual map first and inspect the code from there.

## Screenshots

Add product screenshots here before publishing a release:

- `docs/assets/flowchart.png` - Python code rendered as a flowchart.
- `docs/assets/pipeline.png` - detected ML pipeline stages.
- `docs/assets/inspector.png` - selected node with source details.
- `docs/assets/learn.png` - Kaggle learning plan.

## Quick Start

### Requirements

- macOS 14 or newer
- Xcode 15 or newer
- Python 3 available through `/usr/bin/env python3`

### Build From Source

```bash
swift build
swift run
```

### Python Backend

```bash
cd PythonService
python3 code_visualizer.py --mode full --code "print('hello')" --pretty
python3 code_visualizer.py --mode pipeline --file script.py
python3 code_visualizer.py --mode full --notebook notebook.ipynb
```

## Download

Grab the latest DMG from the [Releases](https://github.com/K-boop-design/code-visualizer/releases) page.

## Support

If you find this tool useful, consider supporting development:

- [GitHub Sponsors](https://github.com/sponsors/K-boop-design)
- [Buy Me a Coffee](https://buymeacoffee.com/kboop)

Your support helps keep the project alive and growing!

## Current Status

Code Visualizer currently includes:

- Python AST parsing.
- Notebook extraction and IPython magic stripping.
- ML pipeline stage detection.
- Native SwiftUI layout with flowchart, pipeline, structure, outputs, and learning tabs.
- Process-based Swift-to-Python bridge.
- Sample notebook auto-load on app launch.

## Privacy

Code analysis runs locally. If AI explanation features are enabled, the app uses the API provider configured by the user and only sends the prompt/context needed for that explanation.

## License

MIT License — see [LICENSE.txt](LICENSE.txt) for details.

