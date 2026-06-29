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

## Distribution

For a paid app, the recommended setup is:

- Keep the source repository private.
- Publish a separate public GitHub release repository with this README, screenshots, and downloadable app builds.
- Upload signed and notarized `.dmg` or `.zip` builds under GitHub Releases.
- Use a payment provider such as Gumroad, Lemon Squeezy, Stripe Payment Links, or Ko-fi for purchases.
- Put the paid download or license key delivery behind the payment provider.

This keeps hosting costs near zero while still giving the app a public landing page and release history.

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

Copyright (c) 2026. All rights reserved.

This repository is not open-source unless a separate open-source license is added.

