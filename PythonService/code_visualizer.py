#!/usr/bin/env python3
"""
Code Visualizer - Python Backend Service

Parses Python code into an AST, analyzes control flow, identifies Kaggle/ML pipelines,
and produces structured JSON for the Swift frontend to render as flowcharts and diagrams.

Supports both raw Python code and Jupyter Notebook (.ipynb) files.

Usage:
    python3 code_visualizer.py --mode flowchart --code "print('hello')"
    python3 code_visualizer.py --mode pipeline --file /path/to/script.py
    python3 code_visualizer.py --mode full --notebook /path/to/notebook.ipynb
"""

import ast
import json
import sys
import argparse
import os
import re
import uuid
import base64
import shutil
from pathlib import Path
from ast_parser import ASTParser
from pipeline_analyzer import PipelineAnalyzer
from notebook_explainer import generate_learning_plan
from ai_provider import query_ai


def strip_ipython_magics(code: str) -> str:
    lines = code.split("\n")
    cleaned = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(("%", "!", "?")):
            cleaned.append("# " + line)
        else:
            cleaned.append(line)
    return "\n".join(cleaned)


def extract_notebook_cells(notebook_path: str) -> dict:
    try:
        with open(notebook_path, "r", encoding="utf-8-sig") as f:
            nb = json.load(f)
    except json.JSONDecodeError as e:
        return {"valid": False, "error": f"Invalid notebook JSON: {e}"}
    except UnicodeDecodeError as e:
        return {"valid": False, "error": f"Cannot decode notebook file: {e}"}
    except Exception as e:
        return {"valid": False, "error": f"Failed to read notebook: {e}"}

    cells = nb.get("cells", [])
    code_cells = []
    markdown_cells = []
    all_code = []
    cell_boundaries = []

    for i, cell in enumerate(cells):
        cell_type = cell.get("cell_type", "code")
        raw_source = cell.get("source")
        if raw_source is None:
            raw_source = []
        elif isinstance(raw_source, str):
            raw_source = [raw_source]
        source = "".join(raw_source)
        lines = source.count("\n") + 1 if source else 0

        entry = {
            "index": i,
            "type": cell_type,
            "source": source,
            "lines": lines,
        }

        if cell_type == "code":
            code_cells.append(entry)
            start_line = "\n".join(all_code).count("\n") + 2 if all_code else 1
            all_code.append(source)
            cell_boundaries.append({"cell_index": i, "start_line": start_line, "end_line": start_line + lines})
        else:
            markdown_cells.append(entry)

    output_images = []
    images_dir = os.path.join("/tmp", f"code-visualizer-outputs-{uuid.uuid4().hex}")
    for i, cell in enumerate(cells):
        for j, out in enumerate(cell.get("outputs", [])):
            data = out.get("data", {})
            for mime, val in data.items():
                if mime == "image/png":
                    b64 = val
                    if isinstance(b64, list):
                        b64 = "".join(b64)
                    try:
                        img_data = base64.b64decode(b64)
                        os.makedirs(images_dir, exist_ok=True)
                        img_path = os.path.join(images_dir, f"cell_{i}_output_{j}.png")
                        with open(img_path, "wb") as f:
                            f.write(img_data)
                        output_images.append({
                            "cell_index": i,
                            "output_index": j,
                            "path": img_path,
                        })
                    except Exception:
                        pass

    raw_combined = "\n".join(all_code)
    combined = strip_ipython_magics(raw_combined)
    metadata = nb.get("metadata", {})
    kernelspec = metadata.get("kernelspec", {})
    language_info = metadata.get("language_info", {})

    return {
        "valid": True,
        "notebook_name": os.path.basename(notebook_path),
        "total_cells": len(cells),
        "code_cells": len(code_cells),
        "markdown_cells": len(markdown_cells),
        "code": combined,
        "raw_code": raw_combined,
        "code_cell_details": code_cells,
        "markdown_cell_details": markdown_cells,
        "cell_boundaries": cell_boundaries,
        "output_images": output_images,
        "kernelspec": {
            "name": kernelspec.get("name", ""),
            "display_name": kernelspec.get("display_name", ""),
        },
        "language": language_info.get("name", "python"),
    }


class CodeVisualizer:
    def __init__(self):
        self.ast_parser = ASTParser()
        self.pipeline_analyzer = PipelineAnalyzer()

    def visualize(self, code: str, mode: str = "full", cell_boundaries: list = None) -> dict:
        try:
            tree = ast.parse(code)
        except SyntaxError as e:
            return {"error": f"SyntaxError: {e}", "valid": False}

        result = {
            "valid": True,
            "lines": code.count("\n") + 1,
            "characters": len(code),
        }

        if mode in ("flowchart", "full"):
            ast_data = self.ast_parser.parse(code)
            result["ast"] = ast_data
            control_flow = self._extract_control_flow(ast_data)
            result["control_flow"] = control_flow
            result["flowchart"] = self._build_flowchart_nodes(control_flow)

        if mode in ("pipeline", "full", "learn"):
            pipeline_data = self.pipeline_analyzer.analyze(tree)
            self._enrich_stage_code(pipeline_data, code, cell_boundaries or [])
            result["pipeline"] = pipeline_data

        if mode in ("learn", "full"):
            if pipeline_data:
                summary = pipeline_data.get("pipeline_summary", [])
                result["learning"] = generate_learning_plan(summary)

        if mode == "full":
            result["suggested_mode"] = "pipeline" if result.get("pipeline", {}).get("is_ml_pipeline") else "flowchart"

        return result

    def _enrich_stage_code(self, pipeline_data: dict, code: str, cell_boundaries: list):
        code_lines = code.split("\n")

        def _make_snippet(cell, stage):
            if cell:
                cstart = cell["start_line"] - 1
                cend = cell["end_line"] - 1
                cindex = cell.get("cell_index")
            else:
                cstart = 0
                cend = len(code_lines)
                cindex = None
            lines_section = []
            for i in range(cstart, min(cend, len(code_lines))):
                raw = code_lines[i]
                lines_section.append({
                    "line_number": i + 1,
                    "code": raw,
                    "description": self._describe_line(raw, stage) if stage else "",
                })
            return lines_section, {"start_line": cstart + 1, "end_line": cend, "cell_index": cindex}

        for stage in pipeline_data.get("stages", []):
            line_no = stage.get("line")
            if not line_no:
                continue
            cell = None
            for cb in cell_boundaries:
                if cb["start_line"] <= line_no < cb["end_line"]:
                    cell = cb
                    break
            snippet, ctx = _make_snippet(cell, stage)
            stage["code_snippet"] = snippet
            stage["code_context"] = ctx

        # Add fallback stages for cells with no detected pipeline stages
        if cell_boundaries:
            covered_cells = set()
            for s in pipeline_data.get("stages", []):
                cc = s.get("code_context", {})
                if cc.get("cell_index") is not None:
                    covered_cells.add(cc["cell_index"])
            for cb in cell_boundaries:
                cidx = cb.get("cell_index")
                if cidx not in covered_cells:
                    snippet, ctx = _make_snippet(cb, None)
                    pipeline_data["stages"].append({
                        "stage": "code",
                        "name": f"Cell {cb['cell_index']}",
                        "line": cb["start_line"],
                        "description": "Code cell",
                        "code_snippet": snippet,
                        "code_context": ctx,
                    })
            pipeline_data["stages"].sort(key=lambda s: s.get("line", 0))

    def _describe_line(self, line: str, stage: dict) -> str:
        stripped = line.strip()
        if not stripped:
            return ""
        if stripped.startswith("#"):
            return f"Comment: {stripped.lstrip('#').strip()}"
        if stripped.startswith("import ") or stripped.startswith("from "):
            return "Import libraries and dependencies"
        for keyword, desc in [
            ("pd.read_csv", "Load CSV data into DataFrame"),
            ("pd.read_excel", "Load Excel data into DataFrame"),
            ("pd.read_parquet", "Load Parquet data into DataFrame"),
            ("pd.read_json", "Load JSON data into DataFrame"),
            ("train_test_split", "Split data into train/validation sets"),
            (".fit(", "Train/fit model on data"),
            (".predict(", "Generate predictions"),
            (".predict_proba(", "Generate probability predictions"),
            (".transform(", "Transform data"),
            (".fit_transform(", "Fit and transform data"),
            ("StandardScaler", "Scale features to standard distribution"),
            ("MinMaxScaler", "Scale features to [0,1] range"),
            ("LabelEncoder", "Encode categorical labels as integers"),
            ("OneHotEncoder", "One-hot encode categorical features"),
            ("SimpleImputer", "Impute missing values"),
            ("fillna", "Fill missing values"),
            ("dropna", "Drop rows with missing values"),
            (".describe()", "Generate summary statistics"),
            (".info()", "Display DataFrame info"),
            (".isnull()", "Check for missing values"),
            (".value_counts()", "Count unique values"),
            (".corr()", "Compute correlation matrix"),
            (".plot(", "Create plot/visualization"),
            ("plt.", "Create matplotlib plot"),
            ("sns.", "Create seaborn plot"),
            ("xgboost", "XGBoost model operation"),
            ("lightgbm", "LightGBM model operation"),
            ("catboost", "CatBoost model operation"),
            ("RandomForest", "Random Forest model operation"),
            ("LinearRegression", "Linear regression operation"),
            ("LogisticRegression", "Logistic regression operation"),
            ("accuracy_score", "Calculate accuracy metric"),
            ("precision_score", "Calculate precision metric"),
            ("recall_score", "Calculate recall metric"),
            ("f1_score", "Calculate F1 score"),
            ("confusion_matrix", "Generate confusion matrix"),
            ("classification_report", "Generate classification report"),
            ("mean_squared_error", "Calculate MSE"),
            ("r2_score", "Calculate R² score"),
            ("roc_auc_score", "Calculate ROC AUC"),
            ("cross_val_score", "Cross-validation scoring"),
            ("GridSearchCV", "Grid search hyperparameter tuning"),
            ("RandomizedSearchCV", "Random search hyperparameter tuning"),
        ]:
            if keyword in stripped:
                return desc
        if "=" in stripped and "==" not in stripped:
            var = stripped.split("=")[0].strip().split()[-1] if stripped.split("=")[0].strip() else "?"
            return f"Assign value to '{var}'"
        if stripped.startswith("def "):
            return f"Define function"
        if stripped.startswith("class "):
            return f"Define class"
        if stripped.startswith("if "):
            return "Conditional check"
        if stripped.startswith("for "):
            return "Loop iteration"
        if stripped.startswith("while "):
            return "While loop"
        if stripped.startswith("return "):
            return "Return value"
        if stripped.startswith("try:"):
            return "Begin try block"
        if stripped.startswith("except"):
            return "Handle exception"
        if stripped.startswith("print("):
            return "Print output"
        if stripped == "else:":
            return "Else branch"
        if stripped == "elif ":
            return "Else-if branch"
        return "Execute statement"

    def _extract_control_flow(self, ast_data: dict, parent_id: str = "0") -> list:
        nodes = []
        self._counter = 0
        self._extract_recursive(ast_data, parent_id, nodes)
        return nodes

    def _func_signature(self, node: dict) -> str:
        name = node.get("name", "")
        args_data = node.get("args", {})
        parts = []
        for a in args_data.get("args", []):
            if isinstance(a, dict):
                parts.append(a.get("arg", "?"))
        vararg = args_data.get("vararg")
        if vararg and isinstance(vararg, dict):
            parts.append(f"*{vararg.get('arg', '?')}")
        for a in args_data.get("kwonlyargs", []):
            if isinstance(a, dict):
                parts.append(f"{a.get('arg', '?')}=...")
        kwarg = args_data.get("kwarg")
        if kwarg and isinstance(kwarg, dict):
            parts.append(f"**{kwarg.get('arg', '?')}")
        sig = f"def {name}({', '.join(parts)})"
        returns = node.get("returns")
        if returns and isinstance(returns, dict):
            sig += f" -> {self._expr_summary(returns)}"
        return sig + ":"

    def _class_signature(self, node: dict) -> str:
        name = node.get("name", "")
        bases = node.get("bases", [])
        if bases:
            base_names = []
            for b in bases:
                if isinstance(b, dict):
                    base_names.append(b.get("id", "?"))
            return f"class {name}({', '.join(base_names)}):"
        return f"class {name}:"

    def _extract_recursive(self, node: dict, parent_id: str, nodes: list, depth: int = 0) -> str:
        node_type = node.get("type", "")
        node_id = f"n{self._counter}"
        self._counter += 1

        base = {
            "id": node_id,
            "parent_id": parent_id,
            "type": node_type,
            "depth": depth,
            "lineno": node.get("lineno"),
            "end_lineno": node.get("end_lineno"),
            "name": node.get("name") or "",
        }

        if node_type in ("FunctionDef", "AsyncFunctionDef"):
            prefix = "async " if node_type == "AsyncFunctionDef" else ""
            base["label"] = f"{prefix}Function: {node['name']}"
            base["brief"] = prefix + self._func_signature(node)
            base["icon"] = "function"
            base["children"] = []
            nodes.append(base)
            child_id = node_id
            for child in node.get("body", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            return node_id

        elif node_type == "ClassDef":
            base["label"] = f"Class: {node['name']}"
            base["brief"] = self._class_signature(node)
            base["icon"] = "class"
            base["children"] = []
            nodes.append(base)
            child_id = node_id
            for child in node.get("body", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            return node_id

        elif node_type == "If":
            test_str = self._expr_summary(node.get("test", {}))
            base["label"] = f"If: {test_str}"
            base["brief"] = f"if {test_str}:"
            base["icon"] = "condition"
            base["test"] = test_str
            base["children"] = []
            nodes.append(base)
            child_id = node_id
            for child in node.get("body", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            for child in node.get("orelse", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            return node_id

        elif node_type == "For":
            target_str = self._expr_summary(node.get("target", {}))
            iter_str = self._expr_summary(node.get("iter", {}))
            base["label"] = f"For: {target_str} in {iter_str}"
            base["brief"] = f"for {target_str} in {iter_str}:"
            base["icon"] = "loop"
            base["children"] = []
            nodes.append(base)
            child_id = node_id
            for child in node.get("body", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            return node_id

        elif node_type == "While":
            test_str = self._expr_summary(node.get("test", {}))
            base["label"] = f"While: {test_str}"
            base["brief"] = f"while {test_str}:"
            base["icon"] = "loop"
            base["children"] = []
            nodes.append(base)
            child_id = node_id
            for child in node.get("body", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            return node_id

        elif node_type == "Try":
            base["label"] = "Try"
            base["brief"] = "try:"
            base["icon"] = "trycatch"
            base["children"] = []
            nodes.append(base)
            child_id = node_id
            for child in node.get("body", []):
                self._extract_recursive(child, child_id, nodes, depth + 1)
            for handler in node.get("handlers", []):
                self._extract_recursive(handler, child_id, nodes, depth + 1)
            return node_id

        elif node_type == "ExceptHandler":
            exc_type = node.get("exception_type")
            name = node.get("name", "")
            label = "Except"
            brief = "except"
            if exc_type:
                exc_str = self._expr_summary(exc_type)
                label += f" {exc_str}"
                brief += f" {exc_str}"
            if name:
                label += f" as {name}"
                brief += f" as {name}"
            brief += ":"
            base["label"] = label
            base["brief"] = brief
            base["icon"] = "catch"
            base["children"] = []
            nodes.append(base)
            for child in node.get("body", []):
                self._extract_recursive(child, base["id"], nodes, depth + 1)
            return node_id

        elif node_type in ("Assign", "AugAssign", "AnnAssign"):
            label = self._assign_summary(node)
            base["label"] = label
            base["brief"] = label
            base["icon"] = "assign"
            nodes.append(base)
            return node_id

        elif node_type == "Expr":
            inner = node.get("value", {})
            inner_type = inner.get("type", "")
            if inner_type == "Call":
                func_str = self._expr_summary(inner.get("func", {}))
                base["label"] = func_str
                base["brief"] = f"{func_str}(...)"
                base["icon"] = "call"
            else:
                base["label"] = "Expression"
                base["brief"] = "Expression statement"
                base["icon"] = "expr"
            nodes.append(base)
            return node_id

        elif node_type == "Return":
            val = self._expr_summary(node.get("value", {}))
            base["label"] = f"Return {val}" if val else "Return"
            base["brief"] = f"return {val}" if val else "return"
            base["icon"] = "return"
            nodes.append(base)
            return node_id

        elif node_type == "Import":
            names = [n.get("name", "") for n in node.get("names", [])]
            base["label"] = f"import {', '.join(names)}"
            base["brief"] = f"import {', '.join(names)}"
            base["icon"] = "import"
            nodes.append(base)
            return node_id

        elif node_type == "ImportFrom":
            module = node.get("module", "")
            names = [n.get("name", "") for n in node.get("names", [])]
            base["label"] = f"from {module} import {', '.join(names)}"
            base["brief"] = f"from {module} import {', '.join(names)}"
            base["icon"] = "import"
            nodes.append(base)
            return node_id

        elif node_type == "With":
            base["label"] = "With"
            base["brief"] = "with ... :"
            base["icon"] = "with"
            base["children"] = []
            nodes.append(base)
            for child in node.get("body", []):
                self._extract_recursive(child, base["id"], nodes, depth + 1)
            return node_id

        elif node_type in ("ListComp", "SetComp", "DictComp", "GeneratorExp"):
            base["label"] = node_type
            base["brief"] = f"{node_type} expression"
            base["icon"] = "comprehension"
            nodes.append(base)
            return node_id

        elif node_type == "Module":
            base["label"] = "Module"
            base["brief"] = "Module (top-level code)"
            base["icon"] = "module"
            base["children"] = []
            base["is_root"] = True
            nodes.append(base)
            body = node.get("body", [])
            i = 0
            while i < len(body):
                child = body[i]
                ct = child.get("type", "")
                if ct in ("Import", "ImportFrom"):
                    group = []
                    while i < len(body) and body[i].get("type", "") in ("Import", "ImportFrom"):
                        group.append(body[i])
                        i += 1
                    self._emit_import_group(group, base["id"], nodes, depth)
                elif ct in ("FunctionDef", "AsyncFunctionDef", "ClassDef"):
                    group = []
                    current_kind = "func" if ct in ("FunctionDef", "AsyncFunctionDef") else "class"
                    while i < len(body):
                        t = body[i].get("type", "")
                        if t not in ("FunctionDef", "AsyncFunctionDef", "ClassDef"):
                            break
                        kind = "func" if t in ("FunctionDef", "AsyncFunctionDef") else "class"
                        if kind != current_kind:
                            break
                        group.append(body[i])
                        i += 1
                    if len(group) == 1:
                        self._extract_recursive(group[0], base["id"], nodes, depth + 1)
                    else:
                        self._emit_func_class_group(group, base["id"], nodes, depth)
                else:
                    if ct != "ImportGroup":
                        self._extract_recursive(child, base["id"], nodes, depth + 1)
                    i += 1
            return node_id

        elif node_type == "Raise":
            base["label"] = "Raise"
            base["brief"] = "raise"
            base["icon"] = "raise"
            nodes.append(base)
            return node_id

        elif node_type == "Assert":
            base["label"] = "Assert"
            base["brief"] = "assert"
            base["icon"] = "assert"
            nodes.append(base)
            return node_id

        elif node_type == "Delete":
            base["label"] = "Del"
            base["brief"] = "del"
            base["icon"] = "delete"
            nodes.append(base)
            return node_id

        elif node_type == "Break":
            base["label"] = "Break"
            base["brief"] = "break"
            base["icon"] = "break"
            nodes.append(base)
            return node_id

        elif node_type == "Continue":
            base["label"] = "Continue"
            base["brief"] = "continue"
            base["icon"] = "continue"
            nodes.append(base)
            return node_id

        elif node_type == "Match":
            subj = self._expr_summary(node.get('subject', {}))
            base["label"] = f"Match: {subj}"
            base["brief"] = f"match {subj}:"
            base["icon"] = "match"
            base["children"] = []
            nodes.append(base)
            return node_id

        elif node_type == "Pass":
            base["label"] = "Pass"
            base["brief"] = "pass"
            base["icon"] = "pass"
            nodes.append(base)
            return node_id

        elif node_type == "Global":
            base["label"] = "Global"
            base["brief"] = "global ..."
            base["icon"] = "global"
            nodes.append(base)
            return node_id

        elif node_type == "Nonlocal":
            base["label"] = "Nonlocal"
            base["brief"] = "nonlocal ..."
            base["icon"] = "nonlocal"
            nodes.append(base)
            return node_id

        else:
            base["label"] = node_type
            base["brief"] = node_type
            base["icon"] = "statement"
            nodes.append(base)
            return node_id

    @staticmethod
    def _split_name(name: str) -> list:
        if "_" in name:
            return [p for p in name.split("_") if p]
        parts = []
        current = ""
        for c in name:
            if c.isupper() and current:
                parts.append(current.lower())
                current = c.lower()
            else:
                current += c.lower()
        if current:
            parts.append(current)
        return parts

    def _common_prefix_segments(self, names: list) -> str:
        parts_list = [self._split_name(n) for n in names]
        prefix_parts = []
        for segments in zip(*parts_list):
            if len(set(segments)) == 1:
                prefix_parts.append(segments[0])
            else:
                break
        return "_".join(prefix_parts)

    def _derive_group_name(self, group: list) -> str:
        names = []
        has_func = False
        has_class = False
        for item in group:
            t = item.get("type", "")
            n = item.get("name", "")
            if n:
                names.append(n)
            if "Function" in t:
                has_func = True
            else:
                has_class = True

        kind = "Functions" if has_func and not has_class else ("Classes" if has_class and not has_func else "Functions & Classes")
        if not names:
            return kind

        if len(names) == 1:
            return names[0]

        prefix = self._common_prefix_segments(names)
        if prefix:
            readable = prefix.replace("_", " ").strip().title()
            if len(readable) >= 3:
                return f"{readable} {kind}"

        return kind

    def _emit_func_class_group(self, group: list, parent_id: str, nodes: list, depth: int):
        name = self._derive_group_name(group)
        has_func = any("Function" in item.get("type", "") for item in group)
        has_class = any(item.get("type") == "ClassDef" for item in group)
        icon = "class" if has_class and not has_func else "function"
        gid = f"n{self._counter}"
        self._counter += 1
        nodes.append({
            "id": gid,
            "parent_id": parent_id,
            "type": "Group",
            "depth": depth + 1,
            "lineno": group[0].get("lineno"),
            "name": name,
            "label": name,
            "brief": name,
            "icon": icon,
            "children": [],
        })
        for member in group:
            self._extract_recursive(member, gid, nodes, depth + 2)

    def _emit_import_group(self, group: list, parent_id: str, nodes: list, depth: int):
        parts = []
        lineno = group[0].get("lineno") if group else None
        for imp in group:
            if imp.get("type") == "Import":
                for n in imp.get("names", []):
                    name = n.get("name", "")
                    asname = n.get("asname")
                    parts.append(f"import {name}" + (f" as {asname}" if asname else ""))
            else:
                module = imp.get("module", "")
                for n in imp.get("names", []):
                    name = n.get("name", "")
                    asname = n.get("asname")
                    item = f"{name}" + (f" as {asname}" if asname else "")
                    parts.append(f"from {module} import {item}" if module else f"import {item}")
        brief = "; ".join(parts)
        if len(brief) > 150:
            brief = brief[:147] + "..."
        gid = f"n{self._counter}"
        self._counter += 1
        nodes.append({
            "id": gid,
            "parent_id": parent_id,
            "type": "ImportGroup",
            "depth": depth + 1,
            "lineno": lineno,
            "name": "",
            "label": "Imports",
            "brief": brief,
            "icon": "import",
        })

    def _build_flowchart_nodes(self, control_flow: list) -> dict:
        if not control_flow:
            return {"nodes": [], "edges": [], "root": ""}

        MAX_NODES = 200
        LEAF_TYPES = {"assign", "call", "expr", "statement", "pass", "break",
                      "continue", "comprehension", "global", "nonlocal", "delete", "assert"}

        CONTROL_FLOW_TYPES = {"function", "class", "condition", "loop", "trycatch",
                              "catch", "with", "match", "return", "raise", "import", "module"}

        significant = [n for n in control_flow if n.get("icon", "") not in LEAF_TYPES]
        significant.sort(key=lambda n: (0 if n.get("icon") == "module" else 1, n.get("lineno") or 0))
        kept = significant[:MAX_NODES]
        kept_ids = {n["id"] for n in kept}

        if not kept_ids:
            return {"nodes": [], "edges": [], "root": ""}

        nodes = []
        edges = []

        root_id = ""
        for node in kept:
            if node.get("is_root"):
                root_id = node["id"]
            nodes.append({
                "id": node["id"],
                "label": node.get("label", ""),
                "type": node.get("icon", "statement"),
                "lineno": node.get("lineno"),
                "depth": node.get("depth", 0),
            })

        for node in kept:
            pid = node.get("parent_id", "")
            nid = node["id"]
            if pid and pid != nid and pid in kept_ids:
                edges.append({"from": pid, "to": nid})

        if not root_id and nodes:
            root_id = nodes[0]["id"]

        return {"nodes": nodes, "edges": edges, "root": root_id}

    def _expr_summary(self, expr: dict) -> str:
        if not expr:
            return ""
        expr_type = expr.get("type", "")
        if expr_type == "Name":
            return expr.get("id", "?")
        elif expr_type == "Constant":
            val = expr.get("value", "")
            return str(val)[:60]
        elif expr_type == "Attribute":
            value = self._expr_summary(expr.get("value", {}))
            attr = expr.get("attr", "")
            return f"{value}.{attr}"
        elif expr_type == "Call":
            func = self._expr_summary(expr.get("func", {}))
            return f"{func}(...)"
        elif expr_type == "BinOp":
            left = self._expr_summary(expr.get("left", {}))
            op = expr.get("op", "")
            right = self._expr_summary(expr.get("right", {}))
            return f"{left} {op} {right}"
        elif expr_type == "Compare":
            left = self._expr_summary(expr.get("left", {}))
            ops = expr.get("ops", [])
            comps = expr.get("comparators", [])
            parts = [left]
            for i, op in enumerate(ops):
                c = self._expr_summary(comps[i]) if i < len(comps) else "?"
                parts.append(f"{op} {c}")
            return " ".join(parts)
        elif expr_type == "BoolOp":
            values = expr.get("values", [])
            op = expr.get("op", "")
            return f" {op} ".join(self._expr_summary(v) for v in values)
        elif expr_type == "UnaryOp":
            op = expr.get("op", "")
            operand = self._expr_summary(expr.get("operand", {}))
            return f"{op}({operand})"
        elif expr_type == "Subscript":
            value = self._expr_summary(expr.get("value", {}))
            slice_val = self._expr_summary(expr.get("slice", {}))
            return f"{value}[{slice_val}]"
        elif expr_type == "List":
            return "[...]"
        elif expr_type == "Dict":
            return "{...}"
        elif expr_type == "Tuple":
            return "(...)"
        elif expr_type == "Lambda":
            return "lambda ..."
        elif expr_type == "IfExp":
            return "... if ... else ..."
        elif expr_type == "ListComp":
            return "[... for ...]"
        elif expr_type == "DictComp":
            return "{...: ... for ...}"
        elif expr_type == "JoinedStr":
            return 'f"..."'
        elif expr_type == "Starred":
            return f"*{self._expr_summary(expr.get('value', {}))}"
        elif expr_type == "Slice":
            parts = []
            if expr.get("lower"):
                parts.append(self._expr_summary(expr.get("lower", {})))
            parts.append(":")
            if expr.get("upper"):
                parts.append(self._expr_summary(expr.get("upper", {})))
            return "".join(parts)
        elif expr_type == "NamedExpr":
            target = self._expr_summary(expr.get("target", {}))
            value = self._expr_summary(expr.get("value", {}))
            return f"{target} := {value}"
        return expr_type

    def _assign_summary(self, assign: dict) -> str:
        assign_type = assign.get("type", "")
        if assign_type == "Assign":
            targets = assign.get("targets", [])
            value = assign.get("value", {})
            target_str = ", ".join(self._expr_summary(t) for t in targets)
            val_str = self._expr_summary(value)
            return f"{target_str} = {val_str}"
        elif assign_type == "AugAssign":
            target = self._expr_summary(assign.get("target", {}))
            op = assign.get("op", "")
            value = self._expr_summary(assign.get("value", {}))
            return f"{target} {op}= {value}"
        elif assign_type == "AnnAssign":
            target = self._expr_summary(assign.get("target", {}))
            annotation = self._expr_summary(assign.get("annotation", {}))
            value = self._expr_summary(assign.get("value", {}))
            if value:
                return f"{target}: {annotation} = {value}"
            return f"{target}: {annotation}"
        return "= ..."


def main():
    try:
        _main()
    except Exception as e:
        import traceback
        tb = traceback.format_exc()
        print(json.dumps({"error": f"Internal error: {e}\n{tb}", "valid": False, "source_type": "error"}))


def _main():
    parser = argparse.ArgumentParser(description="Python Code Visualizer Backend")
    parser.add_argument("--mode", choices=["flowchart", "pipeline", "full", "learn", "ai"], default="full")
    parser.add_argument("--code", type=str, help="Python code string to analyze")
    parser.add_argument("--file", type=str, help="Python file to analyze")
    parser.add_argument("--notebook", type=str, help="Jupyter notebook (.ipynb) to analyze")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")

    args = parser.parse_args()

    if args.mode == "ai":
        try:
            payload = json.loads(sys.stdin.read())
        except json.JSONDecodeError as e:
            print(json.dumps({"response": None, "error": f"Invalid AI payload: {e}"}))
            sys.exit(1)
        result = query_ai(
            prompt=payload.get("prompt", ""),
            api_key=payload.get("api_key", ""),
            provider=payload.get("provider", "groq"),
            context=payload.get("context", ""),
            system_prompt=payload.get("system", ""),
        )
        print(json.dumps(result, default=str))
        return

    notebook_info = None

    if args.notebook:
        if not os.path.exists(args.notebook):
            print(json.dumps({"error": f"Notebook not found: {args.notebook}", "valid": False}))
            sys.exit(1)
        notebook_info = extract_notebook_cells(args.notebook)
        if not notebook_info.get("valid"):
            err = notebook_info.get("error", "Failed to parse notebook")
            print(json.dumps({"error": err, "valid": False}))
            sys.exit(1)
        code = notebook_info["code"]
    elif args.file:
        with open(args.file, "r") as f:
            code = f.read()
    elif args.code:
        code = args.code
    else:
        code = sys.stdin.read()

    if not code.strip():
        print(json.dumps({"error": "No code provided", "valid": False}))
        sys.exit(1)

    visualizer = CodeVisualizer()
    cb = notebook_info.get("cell_boundaries") if notebook_info else None
    result = visualizer.visualize(code, args.mode, cell_boundaries=cb)

    if notebook_info:
        result["notebook"] = notebook_info
        result["source_type"] = "notebook"
    elif args.file:
        result["source_type"] = "file"
        result["filename"] = os.path.basename(args.file)
    else:
        result["source_type"] = "code"

    indent = 2 if args.pretty else None
    print(json.dumps(result, indent=indent, default=str))


if __name__ == "__main__":
    main()
