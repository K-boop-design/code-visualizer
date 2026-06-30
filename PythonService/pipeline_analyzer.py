import ast
import re
from typing import Any, Optional


class PipelineAnalyzer:
    KAGGLE_PATTERNS = {
        "data_loading": {
            "triggers": [
                "pd.read_csv", "pd.read_excel", "pd.read_json", "pd.read_parquet",
                "pd.read_sql", "load_dotenv", "train_test_split", "datasets.load",
                "tensorflow.keras.datasets", "torchvision.datasets",
            ],
            "keywords": ["load", "read", "import", "ingest", "fetch"],
            "libraries": ["pandas", "datasets", "tensorflow", "torch", "numpy"],
        },
        "eda": {
            "triggers": [
                ".describe()", ".info()", ".head()", ".tail()", ".shape", ".columns",
                ".dtypes", ".isnull()", ".value_counts()", ".corr()", ".plot",
                "sns.", "plt.", "matplotlib",
            ],
            "keywords": ["explore", "analyze", "visualize", "plot", "chart", "distribution"],
            "libraries": ["seaborn", "matplotlib", "plotly", "pandas"],
        },
        "preprocessing": {
            "triggers": [
                "sklearn.preprocessing", "StandardScaler", "MinMaxScaler", "LabelEncoder",
                "OneHotEncoder", "SimpleImputer", "train_test_split", "fillna", "dropna",
                "get_dummies", ".transform(", ".fit_transform(",
            ],
            "keywords": ["clean", "preprocess", "scale", "normalize", "encode", "impute"],
            "libraries": ["sklearn", "scikit-learn", "feature_engine"],
        },
        "feature_engineering": {
            "triggers": [
                "PolynomialFeatures", "SelectKBest", "PCA", "TSNE", "CountVectorizer",
                "TfidfVectorizer", "FeatureUnion", "ColumnTransformer",
            ],
            "keywords": ["feature", "extract", "select", "reduce", "engineer"],
            "libraries": ["sklearn", "featuretools"],
        },
        "model_training": {
            "triggers": [
                ".fit(", "model.fit", "trainer.train", "xgboost", "lightgbm", "catboost",
                "RandomForest", "GradientBoosting", "LinearRegression", "LogisticRegression",
                "SVC", "KNeighbors", "NeuralNetwork", "Sequential", "compile(",
                "model.compile", "pytorch_lightning", "transformers.Trainer",
            ],
            "keywords": ["train", "learn", "fit", "optimize"],
            "libraries": ["sklearn", "xgboost", "lightgbm", "catboost", "tensorflow",
                          "keras", "torch", "pytorch", "transformers"],
        },
        "model_evaluation": {
            "triggers": [
                ".score(", "accuracy_score", "precision_score", "recall_score", "f1_score",
                "confusion_matrix", "classification_report", "mean_squared_error",
                "r2_score", "cross_val_score", "GridSearchCV", "RandomizedSearchCV",
                "roc_auc_score", "roc_curve",
            ],
            "keywords": ["evaluate", "validate", "test", "score", "accuracy", "metric"],
            "libraries": ["sklearn.metrics", "sklearn.model_selection"],
        },
        "prediction": {
            "triggers": [
                ".predict(", ".predict_proba(", ".transform(", "model.predict",
            ],
            "keywords": ["predict", "forecast", "infer", "classify"],
            "libraries": [],
        },
        "hyperparameter_tuning": {
            "triggers": [
                "GridSearchCV", "RandomizedSearchCV", "Optuna", "Hyperopt",
                "BayesianOptimization", "KerasTuner",
            ],
            "keywords": ["tune", "search", "optimize", "hyperparameter"],
            "libraries": ["sklearn.model_selection", "optuna", "hyperopt"],
        },
        "data_augmentation": {
            "triggers": [
                "ImageDataGenerator", "transforms.Compose", "albumentations",
                ".augment", "RandomFlip", "RandomRotation", "RandomCrop",
            ],
            "keywords": ["augment", "transform", "generate"],
            "libraries": ["tensorflow.keras.preprocessing", "torchvision", "albumentations"],
        },
    }

    def analyze(self, tree: ast.AST) -> dict:
        stages = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
                stage = self._classify_call(node.value)
                if stage:
                    stages.append(stage)
            elif isinstance(node, ast.Assign):
                if isinstance(node.value, ast.Call):
                    targets = []
                    for target in node.targets:
                        if isinstance(target, ast.Name):
                            targets.append(target.id)
                        elif isinstance(target, ast.Tuple):
                            for elt in target.elts:
                                if isinstance(elt, ast.Name):
                                    targets.append(elt.id)
                    if targets:
                        stage = self._classify_call(node.value)
                        if stage:
                            stage["target"] = ", ".join(targets)
                            stages.append(stage)
            elif isinstance(node, ast.AugAssign) and isinstance(node.value, ast.Call):
                stage = self._classify_call(node.value)
                if stage:
                    stages.append(stage)
            elif isinstance(node, ast.Import) or isinstance(node, ast.ImportFrom):
                self._check_import_for_stage(node, stages)

        # Deduplicate and order stages
        seen = set()
        ordered = []
        for s in stages:
            key = (s["stage"], s.get("name", ""), s.get("line", 0))
            if key not in seen:
                seen.add(key)
                ordered.append(s)
        ordered.sort(key=lambda x: x.get("line", 0))

        # Build pipeline summary
        pipeline = self._build_pipeline_summary(ordered)
        return {
            "stages": ordered,
            "pipeline_summary": pipeline,
            "stage_count": len(pipeline),
            "has_data_loading": any(s["stage"] == "data_loading" for s in ordered),
            "has_model_training": any(s["stage"] == "model_training" for s in ordered),
            "has_evaluation": any(s["stage"] == "model_evaluation" for s in ordered),
            "is_ml_pipeline": len(pipeline) >= 3,
        }

    def _classify_call(self, call_node: ast.Call) -> Optional[dict]:
        call_str = self._call_to_string(call_node)
        if not call_str:
            return None

        for stage_name, pattern in self.KAGGLE_PATTERNS.items():
            for trigger in pattern["triggers"]:
                if trigger in call_str:
                    return {
                        "stage": stage_name,
                        "name": call_str,
                        "line": call_node.lineno,
                        "description": self._stage_description(stage_name),
                    }
        return None

    def _call_to_string(self, call_node: ast.Call) -> str:
        parts = []
        func = call_node.func

        if isinstance(func, ast.Attribute):
            parts.append(self._expr_to_string(func.value))
            parts.append(func.attr)
        elif isinstance(func, ast.Name):
            parts.append(func.id)
        else:
            parts.append(self._expr_to_string(func))

        result = ".".join(p for p in parts if p)
        args = []
        for arg in call_node.args:
            args.append(self._expr_to_string(arg))
        for kw in call_node.keywords:
            args.append(f"{kw.arg}={self._expr_to_string(kw.value)}")

        if args:
            result += f"({', '.join(args[:3])})"
        else:
            result += "()"
        return result

    def _expr_to_string(self, node: ast.AST) -> str:
        if isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Attribute):
            return f"{self._expr_to_string(node.value)}.{node.attr}"
        elif isinstance(node, ast.Constant):
            return repr(node.value)
        elif isinstance(node, ast.Call):
            return self._call_to_string(node)
        elif isinstance(node, ast.Subscript):
            return f"{self._expr_to_string(node.value)}[{self._expr_to_string(node.slice)}]"
        elif isinstance(node, ast.List):
            return f"[{', '.join(self._expr_to_string(e) for e in node.elts)}]"
        elif isinstance(node, ast.Dict):
            return "{...}"
        elif isinstance(node, ast.Tuple):
            return f"({', '.join(self._expr_to_string(e) for e in node.elts)})"
        elif isinstance(node, ast.BinOp):
            return f"{self._expr_to_string(node.left)} {type(node.op).__name__} {self._expr_to_string(node.right)}"
        elif isinstance(node, ast.UnaryOp):
            return f"{type(node.op).__name__}({self._expr_to_string(node.operand)})"
        elif isinstance(node, ast.Lambda):
            return "<lambda>"
        elif isinstance(node, ast.Slice):
            parts = []
            if node.lower:
                parts.append(self._expr_to_string(node.lower))
            parts.append(":")
            if node.upper:
                parts.append(self._expr_to_string(node.upper))
            return "".join(parts)
        return "?"

    def _stage_description(self, stage: str) -> str:
        descriptions = {
            "data_loading": "Loading data from file or API",
            "eda": "Exploratory Data Analysis & Visualization",
            "preprocessing": "Data cleaning & preprocessing",
            "feature_engineering": "Feature engineering & extraction",
            "model_training": "Model training",
            "model_evaluation": "Model evaluation & validation",
            "prediction": "Making predictions",
            "hyperparameter_tuning": "Hyperparameter optimization",
            "data_augmentation": "Data augmentation",
        }
        return descriptions.get(stage, stage.replace("_", " ").title())

    def _check_import_for_stage(self, node, stages):
        if isinstance(node, ast.Import):
            for alias in node.names:
                for stage_name, pattern in self.KAGGLE_PATTERNS.items():
                    if alias.name in pattern.get("libraries", []):
                        stages.append({
                            "stage": stage_name,
                            "name": f"import {alias.name}",
                            "line": node.lineno,
                            "description": self._stage_description(stage_name),
                        })
        elif isinstance(node, ast.ImportFrom):
            for stage_name, pattern in self.KAGGLE_PATTERNS.items():
                if node.module in pattern.get("libraries", []):
                    stages.append({
                        "stage": stage_name,
                        "name": f"from {node.module} import ...",
                        "line": node.lineno,
                        "description": self._stage_description(stage_name),
                    })

    def _build_pipeline_summary(self, stages: list) -> list:
        seen_stages = set()
        summary = []
        for s in stages:
            stage_type = s["stage"]
            if stage_type not in seen_stages:
                seen_stages.add(stage_type)
                summary.append({
                    "stage": stage_type,
                    "description": s["description"],
                    "line": s["line"],
                })
        return summary
