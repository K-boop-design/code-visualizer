"""Educational explainer for Kaggle competition notebooks."""

STAGE_LESSONS = {
    "data_loading": {
        "title": "Data Loading & Understanding",
        "explanation": (
            "You loaded the competition dataset. In Kaggle, data comes in various formats "
            "(CSV, Parquet, JSON). Knowing how to efficiently load large datasets is "
            "critical — many competitions have millions of rows."
        ),
        "kaggle_skill": "Data ingestion & memory optimization",
        "tips": [
            "Use dtypes='category' for string columns to save memory",
            "Load only needed columns with pd.read_csv(usecols=...)",
            "Use nrows=N to preview large datasets before full load",
            "Parquet format loads 10x faster than CSV for large data",
        ],
        "difficulty": "Beginner",
        "learning_outcome": "Load and inspect competition data efficiently",
    },
    "eda": {
        "title": "Exploratory Data Analysis (EDA)",
        "explanation": (
            "EDA is where you uncover patterns, missing values, distributions, and "
            "relationships between features. Strong EDA is what separates top Kagglers "
            "from the rest — it directly informs your feature engineering strategy."
        ),
        "kaggle_skill": "Data visualization & pattern discovery",
        "tips": [
            "Always check target distribution — class imbalance affects metric choice",
            "Plot correlations to find redundant features early",
            "Use pairplots to spot non-linear relationships",
            "Check for time-based leakage if data has timestamps",
            "Visualize missing values with a heatmap to plan imputation",
        ],
        "difficulty": "Beginner",
        "learning_outcome": "Discover data patterns and plan feature strategy",
    },
    "preprocessing": {
        "title": "Data Preprocessing & Cleaning",
        "explanation": (
            "Cleaning turns raw data into a model-ready format. This includes handling "
            "missing values, encoding categories, scaling features, and splitting data. "
            "The choices you make here dramatically impact model performance."
        ),
        "kaggle_skill": "Data cleaning & transformation pipelines",
        "tips": [
            "Use ColumnTransformer for clean, reusable preprocessing pipelines",
            "Fit scalers/encoders on TRAIN only, then transform validation/test",
            "Consider KFold target encoding for high-cardinality categories",
            "Missing not at random? The absence itself may be a signal — flag it",
            "Use SimpleImputer(strategy='median') for robust handling of outliers",
        ],
        "difficulty": "Beginner",
        "learning_outcome": "Build robust preprocessing pipelines",
    },
    "feature_engineering": {
        "title": "Feature Engineering",
        "explanation": (
            "Feature engineering is the #1 differentiator in Kaggle competitions. "
            "Creating meaningful features from raw data — interactions, aggregations, "
            "polynomial transforms — often matters more than model choice."
        ),
        "kaggle_skill": "Creative feature construction & domain expertise",
        "tips": [
            "Create interaction features between top-important features",
            "Aggregate group statistics (mean, std, count) for categorical groups",
            "Use PCA or t-SNE for dimensionality reduction on high-dim data",
            "Binning continuous features can capture non-linearities",
            "Date features: extract day-of-week, month, quarter, is_weekend",
            "Text data: TF-IDF n-grams often beat simple bag-of-words",
        ],
        "difficulty": "Intermediate",
        "learning_outcome": "Engineer predictive features from raw data",
    },
    "model_training": {
        "title": "Model Training",
        "explanation": (
            "You trained a model. In Kaggle, ensemble methods (XGBoost, LightGBM, "
            "CatBoost) dominate tabular data. For deep learning, architecture choice "
            "and transfer learning are key. A single model rarely wins — ensembles do."
        ),
        "kaggle_skill": "Model selection & training techniques",
        "tips": [
            "XGBoost/LightGBM/CatBoost are the Holy Trinity for tabular Kaggle",
            "Always use early_stopping_rounds to prevent overfitting",
            "Set a seed for reproducibility",
            "Try stratified K-Fold cross-validation for imbalanced targets",
            "Log-transform skewed targets before training",
            "For CNNs/NLP: start with a pretrained model and fine-tune",
        ],
        "difficulty": "Intermediate",
        "learning_outcome": "Train and optimize ML models",
    },
    "model_evaluation": {
        "title": "Model Evaluation & Validation",
        "explanation": (
            "Evaluation tells you if your model actually generalizes. Kaggle uses "
            "specific metrics (RMSE, LogLoss, AUC, F1). Proper cross-validation "
            "is essential — public leaderboard scores can be misleading."
        ),
        "kaggle_skill": "Cross-validation & metric optimization",
        "tips": [
            "Match your CV strategy to the competition metric",
            "Use stratified K-Fold for classification, K-Fold for regression",
            "Track train vs validation score to detect overfitting",
            "Public LB is not your friend — trust your CV score",
            "Create a local holdout set that mirrors the test distribution",
        ],
        "difficulty": "Intermediate",
        "learning_outcome": "Validate models with competition-appropriate metrics",
    },
    "prediction": {
        "title": "Prediction & Submission",
        "explanation": (
            "Generating predictions for the test set and creating a submission file. "
            "Kaggle competitions require a specific format. Ensembling multiple models "
            "at this stage often boosts your leaderboard position."
        ),
        "kaggle_skill": "Inference & submission pipeline",
        "tips": [
            "Average predictions from 5+ CV folds for more stable results",
            "Blend models with different strengths (tree + linear + NN)",
            "Ensure your submission format matches the sample_submission.csv exactly",
            "Use .predict_proba() and calibrate for probabilistic metrics",
            "Save intermediate predictions to disk to avoid recomputation",
        ],
        "difficulty": "Beginner",
        "learning_outcome": "Generate competition-ready submissions",
    },
    "hyperparameter_tuning": {
        "title": "Hyperparameter Tuning",
        "explanation": (
            "You optimized hyperparameters. Grid search is exhaustive but slow; "
            "random search and Bayesian methods (Optuna) are more efficient. "
            "The biggest gains often come from a few key parameters."
        ),
        "kaggle_skill": "Efficient hyperparameter optimization",
        "tips": [
            "Start with Optuna — it's faster and smarter than GridSearchCV",
            "Tune learning_rate, max_depth, and subsample first for tree models",
            "Use pruning in Optuna to kill bad trials early",
            "Narrow your search space after each round of tuning",
            "Log your experiments — what worked and what didn't",
        ],
        "difficulty": "Advanced",
        "learning_outcome": "Optimize hyperparameters efficiently",
    },
    "data_augmentation": {
        "title": "Data Augmentation",
        "explanation": (
            "Data augmentation creates synthetic training examples. For images, this "
            "means rotations/flips/crops. For tabular data, it's SMOTE or adding noise. "
            "This reduces overfitting and improves generalization."
        ),
        "kaggle_skill": "Synthetic data generation",
        "tips": [
            "For images: use Albumentations — it's faster than torchvision",
            "Apply augmentation in real-time during training, not before",
            "Mixup and CutMix are strong augmentation strategies for vision",
            "For tabular: add Gaussian noise to features (small sigma)",
            "Don't augment validation/test data — only training data",
        ],
        "difficulty": "Intermediate",
        "learning_outcome": "Generate synthetic data to improve model robustness",
    },
}


def generate_learning_plan(pipeline_summary: list) -> dict:
    """Generate educational content from detected pipeline stages."""
    if not pipeline_summary:
        return {
            "lessons": [],
            "competition_strategy": "No ML pipeline detected. Try loading a Kaggle competition notebook to get started.",
            "skill_progress": [],
        }

    lessons = []
    skills = []

    for stage in pipeline_summary:
        stage_type = stage["stage"]
        lesson = STAGE_LESSONS.get(stage_type)
        if lesson:
            lessons.append({
                "stage": stage_type,
                "title": lesson["title"],
                "explanation": lesson["explanation"],
                "kaggle_skill": lesson["kaggle_skill"],
                "tips": lesson["tips"],
                "difficulty": lesson["difficulty"],
                "learning_outcome": lesson["learning_outcome"],
            })
            skills.append({
                "skill": lesson["kaggle_skill"],
                "difficulty": lesson["difficulty"],
                "stage": stage_type,
            })

    # Build competition strategy from detected stages
    strategy_parts = []
    has_data = any(s["stage"] in ("data_loading", "eda", "preprocessing") for s in pipeline_summary)
    has_model = any(s["stage"] in ("model_training", "hyperparameter_tuning") for s in pipeline_summary)
    has_eval = any(s["stage"] in ("model_evaluation", "prediction") for s in pipeline_summary)
    has_feat = any(s["stage"] == "feature_engineering" for s in pipeline_summary)

    if has_data:
        strategy_parts.append("Understand your data before modeling")
    if has_feat:
        strategy_parts.append("Engineer features that capture domain signals")
    if has_model:
        strategy_parts.append("Train strong baselines, then iterate")
    if has_eval:
        strategy_parts.append("Validate thoroughly — don't trust the leaderboard alone")

    strategy = (
        "Your notebook covers the standard Kaggle workflow. "
        + " → ".join(strategy_parts)
        + ". To improve: add cross-validation, ensemble multiple models, "
        "and study the competition-specific data distributions."
    )

    # Recommend next skills to learn
    all_stages = {s["stage"] for s in pipeline_summary}
    recommendations = []
    if "feature_engineering" not in all_stages:
        recommendations.append("Feature engineering — the highest-leverage skill in Kaggle")
    if "hyperparameter_tuning" not in all_stages:
        recommendations.append("Hyperparameter tuning with Optuna")
    if "data_augmentation" not in all_stages:
        recommendations.append("Data augmentation for better generalization")

    return {
        "lessons": lessons,
        "competition_strategy": strategy,
        "skill_progress": skills,
        "recommended_next": recommendations,
        "total_stages": len(pipeline_summary),
        "mastery_level": _mastery_level(pipeline_summary),
    }


def _mastery_level(pipeline_summary: list) -> str:
    stages = {s["stage"] for s in pipeline_summary}
    count = len(stages)
    has_advanced = "hyperparameter_tuning" in stages or "data_augmentation" in stages
    has_feat = "feature_engineering" in stages

    if count >= 6 and has_advanced and has_feat:
        return "Advanced"
    elif count >= 4 and has_feat:
        return "Intermediate"
    elif count >= 2:
        return "Beginner"
    return "Explorer"
