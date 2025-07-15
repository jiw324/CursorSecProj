#!/usr/bin/env python3

import asyncio
import logging
import pickle
import sqlite3
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Protocol, Tuple, Union
import warnings

import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.metrics import (
    accuracy_score, classification_report, confusion_matrix,
    mean_squared_error, r2_score, roc_auc_score
)
from sklearn.model_selection import (
    GridSearchCV, cross_val_score, train_test_split, StratifiedKFold
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import (
    StandardScaler, MinMaxScaler, LabelEncoder, OneHotEncoder
)
import joblib

warnings.filterwarnings('ignore', category=UserWarning)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ml_pipeline.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

@dataclass
class ModelConfig:
    model_type: str
    hyperparameters: Dict[str, Any] = field(default_factory=dict)
    cross_validation_folds: int = 5
    test_size: float = 0.2
    random_state: int = 42
    feature_selection: bool = True
    max_features: Optional[int] = None

@dataclass
class ModelMetrics:
    accuracy: Optional[float] = None
    precision: Optional[float] = None
    recall: Optional[float] = None
    f1_score: Optional[float] = None
    roc_auc: Optional[float] = None
    mse: Optional[float] = None
    rmse: Optional[float] = None
    r2: Optional[float] = None
    cross_val_scores: Optional[List[float]] = None

@dataclass
class DataQualityReport:
    total_rows: int
    missing_values: Dict[str, int]
    duplicate_rows: int
    outliers: Dict[str, int]
    data_types: Dict[str, str]
    quality_score: float

class MLModel(Protocol):
    def fit(self, X: np.ndarray, y: np.ndarray) -> None:
        ...
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        ...
    
    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        ...

class OutlierRemover(BaseEstimator, TransformerMixin):
    def __init__(self, factor: float = 1.5):
        self.factor = factor
        self.lower_bounds_ = None
        self.upper_bounds_ = None
    
    def fit(self, X: np.ndarray, y: Optional[np.ndarray] = None) -> 'OutlierRemover':
        X = np.array(X)
        
        Q1 = np.percentile(X, 25, axis=0)
        Q3 = np.percentile(X, 75, axis=0)
        IQR = Q3 - Q1
        
        self.lower_bounds_ = Q1 - (self.factor * IQR)
        self.upper_bounds_ = Q3 + (self.factor * IQR)
        
        return self
    
    def transform(self, X: np.ndarray) -> np.ndarray:
        X = np.array(X)
        mask = np.all(
            (X >= self.lower_bounds_) & (X <= self.upper_bounds_),
            axis=1
        )
        return X[mask]
    
    def fit_transform(self, X: np.ndarray, y: Optional[np.ndarray] = None) -> np.ndarray:
        return self.fit(X, y).transform(X)

class FeatureEngineer(BaseEstimator, TransformerMixin):
    def __init__(self, create_interactions: bool = True, polynomial_degree: int = 2):
        self.create_interactions = create_interactions
        self.polynomial_degree = polynomial_degree
        self.feature_names_ = None
    
    def fit(self, X: pd.DataFrame, y: Optional[np.ndarray] = None) -> 'FeatureEngineer':
        self.feature_names_ = X.columns.tolist()
        return self
    
    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X_new = X.copy()
        numeric_columns = X.select_dtypes(include=[np.number]).columns
        
        if len(numeric_columns) > 1 and self.create_interactions:
            for i, col1 in enumerate(numeric_columns):
                for col2 in numeric_columns[i+1:]:
                    X_new[f'{col1}_x_{col2}'] = X[col1] * X[col2]
        
        if self.polynomial_degree >= 2:
            for col in numeric_columns:
                X_new[f'{col}_squared'] = X[col] ** 2
        
        if len(numeric_columns) > 1:
            for i, col1 in enumerate(numeric_columns):
                for col2 in numeric_columns[i+1:]:
                    with np.errstate(divide='ignore', invalid='ignore'):
                        ratio = X[col1] / (X[col2] + 1e-8)
                        X_new[f'{col1}_div_{col2}'] = np.where(
                            np.isfinite(ratio), ratio, 0
                        )
        
        return X_new

class DataQualityAnalyzer:
    @staticmethod
    def analyze(df: pd.DataFrame) -> DataQualityReport:
        logger.info("Starting data quality analysis...")
        
        total_rows = len(df)
        missing_values = df.isnull().sum().to_dict()
        duplicate_rows = df.duplicated().sum()
        data_types = df.dtypes.astype(str).to_dict()
        
        outliers = {}
        numeric_columns = df.select_dtypes(include=[np.number]).columns
        
        for col in numeric_columns:
            Q1 = df[col].quantile(0.25)
            Q3 = df[col].quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - 1.5 * IQR
            upper_bound = Q3 + 1.5 * IQR
            
            outlier_count = len(df[(df[col] < lower_bound) | (df[col] > upper_bound)])
            outliers[col] = outlier_count
        
        missing_ratio = sum(missing_values.values()) / (total_rows * len(df.columns))
        duplicate_ratio = duplicate_rows / total_rows
        outlier_ratio = sum(outliers.values()) / (total_rows * len(numeric_columns)) if numeric_columns.any() else 0
        
        quality_score = 1.0 - (missing_ratio + duplicate_ratio + outlier_ratio) / 3
        quality_score = max(0.0, min(1.0, quality_score))
        
        logger.info(f"Data quality score: {quality_score:.3f}")
        
        return DataQualityReport(
            total_rows=total_rows,
            missing_values=missing_values,
            duplicate_rows=duplicate_rows,
            outliers=outliers,
            data_types=data_types,
            quality_score=quality_score
        )
    
    @staticmethod
    def clean_data(df: pd.DataFrame, strategy: str = 'auto') -> pd.DataFrame:
        logger.info(f"Cleaning data using strategy: {strategy}")
        
        df_clean = df.copy()
        
        df_clean = df_clean.drop_duplicates()
        
        if strategy == 'auto':
            numeric_columns = df_clean.select_dtypes(include=[np.number]).columns
            for col in numeric_columns:
                df_clean[col].fillna(df_clean[col].median(), inplace=True)
            
            categorical_columns = df_clean.select_dtypes(include=['object']).columns
            for col in categorical_columns:
                mode_value = df_clean[col].mode()
                if not mode_value.empty:
                    df_clean[col].fillna(mode_value[0], inplace=True)
        
        elif strategy == 'drop':
            df_clean = df_clean.dropna()
        
        logger.info(f"Data cleaned: {len(df)} -> {len(df_clean)} rows")
        return df_clean

class ModelFactory:
    _models = {
        'logistic_regression': LogisticRegression,
        'random_forest_classifier': RandomForestClassifier,
        'linear_regression': LinearRegression,
        'gradient_boosting_regressor': GradientBoostingRegressor
    }
    
    @classmethod
    def create_model(cls, model_type: str, **kwargs) -> Any:
        if model_type not in cls._models:
            raise ValueError(f"Unknown model type: {model_type}")
        
        model_class = cls._models[model_type]
        return model_class(**kwargs)
    
    @classmethod
    def get_default_hyperparameters(cls, model_type: str) -> Dict[str, List[Any]]:
        defaults = {
            'logistic_regression': {
                'C': [0.1, 1.0, 10.0],
                'solver': ['liblinear', 'lbfgs'],
                'max_iter': [1000]
            },
            'random_forest_classifier': {
                'n_estimators': [100, 200, 300],
                'max_depth': [None, 10, 20, 30],
                'min_samples_split': [2, 5, 10]
            },
            'linear_regression': {
                'fit_intercept': [True, False]
            },
            'gradient_boosting_regressor': {
                'n_estimators': [100, 200],
                'learning_rate': [0.1, 0.05, 0.01],
                'max_depth': [3, 5, 7]
            }
        }
        
        return defaults.get(model_type, {})

class ModelEvaluator:
    @staticmethod
    def evaluate_classifier(model: Any, X_test: np.ndarray, y_test: np.ndarray) -> ModelMetrics:
        logger.info("Evaluating classification model...")
        
        y_pred = model.predict(X_test)
        y_pred_proba = None
        
        try:
            y_pred_proba = model.predict_proba(X_test)[:, 1]
        except (AttributeError, IndexError):
            logger.warning("Model doesn't support probability prediction")
        
        accuracy = accuracy_score(y_test, y_pred)
        
        report = classification_report(y_test, y_pred, output_dict=True)
        weighted_avg = report['weighted avg']
        
        roc_auc = None
        if y_pred_proba is not None:
            try:
                roc_auc = roc_auc_score(y_test, y_pred_proba)
            except ValueError:
                logger.warning("ROC AUC calculation failed")
        
        return ModelMetrics(
            accuracy=accuracy,
            precision=weighted_avg['precision'],
            recall=weighted_avg['recall'],
            f1_score=weighted_avg['f1-score'],
            roc_auc=roc_auc
        )
    
    @staticmethod
    def evaluate_regressor(model: Any, X_test: np.ndarray, y_test: np.ndarray) -> ModelMetrics:
        logger.info("Evaluating regression model...")
        
        y_pred = model.predict(X_test)
        
        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)
        r2 = r2_score(y_test, y_pred)
        
        return ModelMetrics(
            mse=mse,
            rmse=rmse,
            r2=r2
        )
    
    @staticmethod
    def cross_validate(model: Any, X: np.ndarray, y: np.ndarray, cv: int = 5) -> List[float]:
        logger.info(f"Performing {cv}-fold cross-validation...")
        
        scores = cross_val_score(model, X, y, cv=cv, scoring='accuracy')
        return scores.tolist()

class MLPipeline:
    def __init__(self, config: ModelConfig):
        self.config = config
        self.preprocessor = None
        self.model = None
        self.is_trained = False
        self.feature_names = None
        self.target_encoder = None
        self.metrics = None
    
    def create_preprocessor(self, X: pd.DataFrame) -> ColumnTransformer:
        logger.info("Creating preprocessing pipeline...")
        
        numeric_features = X.select_dtypes(include=[np.number]).columns.tolist()
        categorical_features = X.select_dtypes(include=['object']).columns.tolist()
        
        transformers = []
        
        if numeric_features:
            numeric_transformer = Pipeline([
                ('scaler', StandardScaler()),
                ('outlier_remover', OutlierRemover())
            ])
            transformers.append(('num', numeric_transformer, numeric_features))
        
        if categorical_features:
            categorical_transformer = Pipeline([
                ('encoder', OneHotEncoder(drop='first', sparse_output=False, handle_unknown='ignore'))
            ])
            transformers.append(('cat', categorical_transformer, categorical_features))
        
        return ColumnTransformer(transformers=transformers, remainder='passthrough')
    
    def prepare_data(self, X: pd.DataFrame, y: pd.Series, 
                    test_size: Optional[float] = None) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        logger.info("Preparing data for training...")
        
        quality_report = DataQualityAnalyzer.analyze(X)
        logger.info(f"Data quality score: {quality_report.quality_score:.3f}")
        
        if quality_report.quality_score < 0.8:
            logger.warning("Poor data quality detected, applying automatic cleaning...")
            X_clean = DataQualityAnalyzer.clean_data(X)
            y = y.loc[X_clean.index]
            X = X_clean
        
        feature_engineer = FeatureEngineer()
        X_engineered = feature_engineer.fit_transform(X)
        
        self.feature_names = X_engineered.columns.tolist()
        
        test_size = test_size or self.config.test_size
        X_train, X_test, y_train, y_test = train_test_split(
            X_engineered, y, 
            test_size=test_size, 
            random_state=self.config.random_state,
            stratify=y if self._is_classification() else None
        )
        
        return X_train, X_test, y_train, y_test
    
    def train(self, X: pd.DataFrame, y: pd.Series) -> ModelMetrics:
        logger.info(f"Training {self.config.model_type} model...")
        
        X_train, X_test, y_train, y_test = self.prepare_data(X, y)
        
        self.preprocessor = self.create_preprocessor(X_train)
        
        base_model = ModelFactory.create_model(
            self.config.model_type, 
            random_state=self.config.random_state,
            **self.config.hyperparameters
        )
        
        pipeline_steps = [('preprocessor', self.preprocessor)]
        
        if self.config.feature_selection:
            max_features = self.config.max_features or min(50, X_train.shape[1])
            selector = SelectKBest(f_classif, k=max_features)
            pipeline_steps.append(('selector', selector))
        
        pipeline_steps.append(('model', base_model))
        
        self.model = Pipeline(pipeline_steps)
        
        if not self.config.hyperparameters:
            self.model = self._tune_hyperparameters(X_train, y_train)
        else:
            self.model.fit(X_train, y_train)
        
        if self._is_classification():
            self.metrics = ModelEvaluator.evaluate_classifier(self.model, X_test, y_test)
        else:
            self.metrics = ModelEvaluator.evaluate_regressor(self.model, X_test, y_test)
        
        cv_scores = ModelEvaluator.cross_validate(
            self.model, X_train, y_train, cv=self.config.cross_validation_folds
        )
        self.metrics.cross_val_scores = cv_scores
        
        self.is_trained = True
        logger.info("Model training completed successfully")
        
        return self.metrics
    
    def predict(self, X: pd.DataFrame) -> np.ndarray:
        if not self.is_trained:
            raise ValueError("Model must be trained before making predictions")
        
        feature_engineer = FeatureEngineer()
        X_engineered = feature_engineer.fit_transform(X)
        
        return self.model.predict(X_engineered)
    
    def predict_proba(self, X: pd.DataFrame) -> np.ndarray:
        if not self.is_trained:
            raise ValueError("Model must be trained before making predictions")
        
        if not self._is_classification():
            raise ValueError("predict_proba only available for classification models")
        
        feature_engineer = FeatureEngineer()
        X_engineered = feature_engineer.fit_transform(X)
        
        return self.model.predict_proba(X_engineered)
    
    def save_model(self, filepath: str) -> None:
        if not self.is_trained:
            raise ValueError("Cannot save untrained model")
        
        model_data = {
            'model': self.model,
            'config': self.config,
            'feature_names': self.feature_names,
            'metrics': self.metrics,
            'is_trained': self.is_trained
        }
        
        joblib.dump(model_data, filepath)
        logger.info(f"Model saved to {filepath}")
    
    @classmethod
    def load_model(cls, filepath: str) -> 'MLPipeline':
        model_data = joblib.load(filepath)
        
        pipeline = cls(model_data['config'])
        pipeline.model = model_data['model']
        pipeline.feature_names = model_data['feature_names']
        pipeline.metrics = model_data['metrics']
        pipeline.is_trained = model_data['is_trained']
        
        logger.info(f"Model loaded from {filepath}")
        return pipeline
    
    def _is_classification(self) -> bool:
        classification_models = ['logistic_regression', 'random_forest_classifier']
        return self.config.model_type in classification_models
    
    def _tune_hyperparameters(self, X_train: np.ndarray, y_train: np.ndarray) -> Pipeline:
        logger.info("Performing hyperparameter tuning...")
        
        param_grid = {}
        default_params = ModelFactory.get_default_hyperparameters(self.config.model_type)
        
        for param, values in default_params.items():
            param_grid[f'model__{param}'] = values
        
        if param_grid:
            cv_strategy = StratifiedKFold(n_splits=3) if self._is_classification() else 3
            
            grid_search = GridSearchCV(
                self.model,
                param_grid,
                cv=cv_strategy,
                scoring='accuracy' if self._is_classification() else 'neg_mean_squared_error',
                n_jobs=-1
            )
            
            grid_search.fit(X_train, y_train)
            logger.info(f"Best parameters: {grid_search.best_params_}")
            
            return grid_search.best_estimator_
        else:
            self.model.fit(X_train, y_train)
            return self.model

class DataGenerator:
    @staticmethod
    def generate_classification_dataset(n_samples: int = 1000, n_features: int = 20, 
                                       n_classes: int = 2, noise: float = 0.1) -> Tuple[pd.DataFrame, pd.Series]:
        from sklearn.datasets import make_classification
        
        X, y = make_classification(
            n_samples=n_samples,
            n_features=n_features,
            n_classes=n_classes,
            n_redundant=n_features // 4,
            n_informative=n_features // 2,
            flip_y=noise,
            random_state=42
        )
        
        feature_names = [f'feature_{i:02d}' for i in range(n_features)]
        X_df = pd.DataFrame(X, columns=feature_names)
        y_series = pd.Series(y, name='target')
        
        n_categorical = min(3, n_features // 4)
        for i in range(n_categorical):
            col_name = f'category_{i}'
            X_df[col_name] = np.random.choice(['A', 'B', 'C'], size=n_samples)
        
        missing_mask = np.random.random(X_df.shape) < 0.05
        X_df = X_df.mask(missing_mask)
        
        return X_df, y_series
    
    @staticmethod
    def generate_regression_dataset(n_samples: int = 1000, n_features: int = 20, 
                                   noise: float = 0.1) -> Tuple[pd.DataFrame, pd.Series]:
        from sklearn.datasets import make_regression
        
        X, y = make_regression(
            n_samples=n_samples,
            n_features=n_features,
            n_informative=n_features // 2,
            noise=noise,
            random_state=42
        )
        
        feature_names = [f'feature_{i:02d}' for i in range(n_features)]
        X_df = pd.DataFrame(X, columns=feature_names)
        y_series = pd.Series(y, name='target')
        
        return X_df, y_series

class ModelMonitor:
    def __init__(self, reference_data: pd.DataFrame):
        self.reference_data = reference_data
        self.reference_stats = self._compute_stats(reference_data)
    
    def _compute_stats(self, data: pd.DataFrame) -> Dict[str, Dict[str, float]]:
        stats = {}
        
        for column in data.select_dtypes(include=[np.number]).columns:
            stats[column] = {
                'mean': data[column].mean(),
                'std': data[column].std(),
                'min': data[column].min(),
                'max': data[column].max(),
                'q25': data[column].quantile(0.25),
                'q75': data[column].quantile(0.75)
            }
        
        return stats
    
    def detect_drift(self, new_data: pd.DataFrame, threshold: float = 0.1) -> Dict[str, bool]:
        new_stats = self._compute_stats(new_data)
        drift_detected = {}
        
        for column in self.reference_stats:
            if column in new_stats:
                ref_mean = self.reference_stats[column]['mean']
                new_mean = new_stats[column]['mean']
                
                relative_change = abs(new_mean - ref_mean) / (abs(ref_mean) + 1e-8)
                drift_detected[column] = relative_change > threshold
            else:
                drift_detected[column] = True
        
        return drift_detected

class AsyncMLPipeline:
    def __init__(self, config: ModelConfig):
        self.config = config
        self.pipeline = MLPipeline(config)
    
    async def train_async(self, X: pd.DataFrame, y: pd.Series, 
                         batch_size: int = 10000) -> ModelMetrics:
        logger.info("Starting asynchronous training...")
        
        if len(X) <= batch_size:
            return self.pipeline.train(X, y)
        
        total_batches = len(X) // batch_size + (1 if len(X) % batch_size > 0 else 0)
        
        for i in range(total_batches):
            start_idx = i * batch_size
            end_idx = min((i + 1) * batch_size, len(X))
            
            X_batch = X.iloc[start_idx:end_idx]
            y_batch = y.iloc[start_idx:end_idx]
            
            logger.info(f"Processing batch {i + 1}/{total_batches}")
            
            await asyncio.sleep(0.1)
            
            if i == 0:
                self.pipeline.train(X_batch, y_batch)
            else:
                logger.info(f"Batch {i + 1} processed (incremental learning not shown)")
        
        return self.pipeline.metrics

class ModelRegistry:
    def __init__(self, registry_path: str = "model_registry.db"):
        self.registry_path = registry_path
        self._init_database()
    
    def _init_database(self) -> None:
        with sqlite3.connect(self.registry_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS models (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    version TEXT NOT NULL,
                    model_type TEXT NOT NULL,
                    file_path TEXT NOT NULL,
                    metrics TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    is_active BOOLEAN DEFAULT FALSE,
                    UNIQUE(name, version)
                )
            """)
    
    def register_model(self, name: str, version: str, pipeline: MLPipeline, 
                      file_path: str, is_active: bool = False) -> None:
        pipeline.save_model(file_path)
        
        with sqlite3.connect(self.registry_path) as conn:
            metrics_json = pickle.dumps(pipeline.metrics) if pipeline.metrics else None
            
            conn.execute("""
                INSERT OR REPLACE INTO models 
                (name, version, model_type, file_path, metrics, is_active)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (name, version, pipeline.config.model_type, file_path, metrics_json, is_active))
        
        logger.info(f"Model {name} v{version} registered successfully")
    
    def get_model(self, name: str, version: str = None) -> Optional[MLPipeline]:
        with sqlite3.connect(self.registry_path) as conn:
            if version:
                cursor = conn.execute(
                    "SELECT file_path FROM models WHERE name = ? AND version = ?",
                    (name, version)
                )
            else:
                cursor = conn.execute(
                    "SELECT file_path FROM models WHERE name = ? AND is_active = TRUE",
                    (name,)
                )
            
            result = cursor.fetchone()
            if result:
                return MLPipeline.load_model(result[0])
        
        return None
    
    def list_models(self) -> List[Dict[str, Any]]:
        with sqlite3.connect(self.registry_path) as conn:
            cursor = conn.execute("""
                SELECT name, version, model_type, created_at, is_active 
                FROM models ORDER BY created_at DESC
            """)
            
            columns = [desc[0] for desc in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]

def demonstrate_ml_pipeline():
    logger.info("Starting ML Pipeline demonstration...")
    
    print("=== Generating Sample Data ===")
    X, y = DataGenerator.generate_classification_dataset(n_samples=5000, n_features=15)
    print(f"Generated dataset with {len(X)} samples and {len(X.columns)} features")
    
    print("\n=== Data Quality Analysis ===")
    quality_report = DataQualityAnalyzer.analyze(X)
    print(f"Data quality score: {quality_report.quality_score:.3f}")
    print(f"Missing values: {sum(quality_report.missing_values.values())}")
    print(f"Duplicate rows: {quality_report.duplicate_rows}")
    
    print("\n=== Model Training ===")
    config = ModelConfig(
        model_type='random_forest_classifier',
        cross_validation_folds=5,
        feature_selection=True,
        max_features=10
    )
    
    pipeline = MLPipeline(config)
    metrics = pipeline.train(X, y)
    
    print(f"Model Accuracy: {metrics.accuracy:.3f}")
    print(f"F1 Score: {metrics.f1_score:.3f}")
    print(f"Cross-validation scores: {metrics.cross_val_scores}")
    
    print("\n=== Making Predictions ===")
    sample_data = X.head(10)
    predictions = pipeline.predict(sample_data)
    probabilities = pipeline.predict_proba(sample_data)
    
    print(f"Sample predictions: {predictions[:5]}")
    print(f"Sample probabilities: {probabilities[:5, 1]}")
    
    print("\n=== Model Registry ===")
    registry = ModelRegistry()
    registry.register_model(
        name="customer_classifier",
        version="1.0.0",
        pipeline=pipeline,
        file_path="customer_classifier_v1.joblib",
        is_active=True
    )
    
    registered_models = registry.list_models()
    print(f"Registered models: {len(registered_models)}")
    
    print("\n=== Model Monitoring ===")
    monitor = ModelMonitor(X)
    
    X_new = X.copy()
    X_new['feature_00'] *= 1.5
    
    drift_results = monitor.detect_drift(X_new, threshold=0.1)
    drifted_features = [col for col, has_drift in drift_results.items() if has_drift]
    print(f"Features with detected drift: {drifted_features}")
    
    print("\nML Pipeline demonstration completed successfully!")

if __name__ == "__main__":
    demonstrate_ml_pipeline() 