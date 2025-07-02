#!/usr/bin/env python3
"""
Machine Learning Pipeline for E-commerce Product Recommendation System
Demonstrates modern ML practices with scikit-learn, pandas, and MLflow
"""

import os
import logging
import warnings
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from datetime import datetime, timedelta

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.preprocessing import StandardScaler, LabelEncoder, OneHotEncoder
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
import joblib
import mlflow
import mlflow.sklearn
from scipy import stats
from imblearn.over_sampling import SMOTE
import optuna

warnings.filterwarnings('ignore')
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DataProcessor:
    """Handle data loading, cleaning, and preprocessing"""
    
    def __init__(self, data_path: str):
        self.data_path = Path(data_path)
        self.scaler = StandardScaler()
        self.label_encoders = {}
        self.preprocessor = None
        
    def load_data(self) -> pd.DataFrame:
        """Load data from various sources"""
        logger.info(f"Loading data from {self.data_path}")
        
        if self.data_path.suffix == '.csv':
            df = pd.read_csv(self.data_path)
        elif self.data_path.suffix in ['.xlsx', '.xls']:
            df = pd.read_excel(self.data_path)
        else:
            raise ValueError(f"Unsupported file format: {self.data_path.suffix}")
            
        logger.info(f"Loaded {len(df)} rows and {len(df.columns)} columns")
        return df
    
    def explore_data(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Perform exploratory data analysis"""
        logger.info("Performing exploratory data analysis...")
        
        analysis = {
            'shape': df.shape,
            'info': df.info(),
            'describe': df.describe(),
            'missing_values': df.isnull().sum(),
            'duplicates': df.duplicated().sum(),
            'dtypes': df.dtypes
        }
        
        # Plot distributions for numeric columns
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        if len(numeric_cols) > 0:
            fig, axes = plt.subplots(2, 2, figsize=(12, 10))
            axes = axes.ravel()
            
            for i, col in enumerate(numeric_cols[:4]):
                df[col].hist(bins=30, ax=axes[i])
                axes[i].set_title(f'Distribution of {col}')
                axes[i].set_xlabel(col)
                axes[i].set_ylabel('Frequency')
            
            plt.tight_layout()
            plt.savefig('data_distributions.png')
            plt.close()
            
        return analysis
    
    def clean_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean and preprocess the data"""
        logger.info("Cleaning data...")
        
        # Remove duplicates
        df = df.drop_duplicates()
        
        # Handle missing values
        for col in df.columns:
            if df[col].dtype in ['int64', 'float64']:
                # Fill numeric missing values with median
                df[col].fillna(df[col].median(), inplace=True)
            else:
                # Fill categorical missing values with mode
                df[col].fillna(df[col].mode()[0] if not df[col].mode().empty else 'Unknown', inplace=True)
        
        # Remove outliers using IQR method for numeric columns
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        for col in numeric_cols:
            Q1 = df[col].quantile(0.25)
            Q3 = df[col].quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - 1.5 * IQR
            upper_bound = Q3 + 1.5 * IQR
            df = df[(df[col] >= lower_bound) & (df[col] <= upper_bound)]
        
        logger.info(f"Data cleaned. New shape: {df.shape}")
        return df
    
    def feature_engineering(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create new features from existing data"""
        logger.info("Performing feature engineering...")
        
        # Example: Create price range categories
        if 'price' in df.columns:
            df['price_range'] = pd.cut(df['price'], 
                                     bins=[0, 50, 100, 200, float('inf')], 
                                     labels=['Low', 'Medium', 'High', 'Premium'])
        
        # Example: Create interaction features
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        if len(numeric_cols) >= 2:
            for i in range(len(numeric_cols)-1):
                col1, col2 = numeric_cols[i], numeric_cols[i+1]
                df[f'{col1}_{col2}_interaction'] = df[col1] * df[col2]
        
        # Example: Create time-based features if datetime column exists
        datetime_cols = df.select_dtypes(include=['datetime64']).columns
        for col in datetime_cols:
            df[f'{col}_year'] = df[col].dt.year
            df[f'{col}_month'] = df[col].dt.month
            df[f'{col}_day_of_week'] = df[col].dt.dayofweek
            df[f'{col}_is_weekend'] = df[col].dt.dayofweek >= 5
        
        return df
    
    def prepare_features(self, df: pd.DataFrame, target_col: str) -> Tuple[np.ndarray, np.ndarray]:
        """Prepare features and target for model training"""
        logger.info("Preparing features and target...")
        
        # Separate features and target
        X = df.drop(columns=[target_col])
        y = df[target_col]
        
        # Identify numeric and categorical columns
        numeric_features = X.select_dtypes(include=['int64', 'float64']).columns
        categorical_features = X.select_dtypes(include=['object', 'category']).columns
        
        # Create preprocessing pipeline
        numeric_transformer = Pipeline(steps=[
            ('scaler', StandardScaler())
        ])
        
        categorical_transformer = Pipeline(steps=[
            ('onehot', OneHotEncoder(handle_unknown='ignore'))
        ])
        
        self.preprocessor = ColumnTransformer(
            transformers=[
                ('num', numeric_transformer, numeric_features),
                ('cat', categorical_transformer, categorical_features)
            ]
        )
        
        # Transform features
        X_processed = self.preprocessor.fit_transform(X)
        
        # Encode target if categorical
        if y.dtype == 'object':
            le = LabelEncoder()
            y_processed = le.fit_transform(y)
            self.target_encoder = le
        else:
            y_processed = y.values
            self.target_encoder = None
        
        logger.info(f"Features shape: {X_processed.shape}, Target shape: {y_processed.shape}")
        return X_processed, y_processed

class ModelTrainer:
    """Handle model training, evaluation, and hyperparameter tuning"""
    
    def __init__(self):
        self.models = {}
        self.best_model = None
        self.best_score = 0
        
    def define_models(self) -> Dict[str, Any]:
        """Define candidate models"""
        models = {
            'logistic_regression': LogisticRegression(random_state=42),
            'random_forest': RandomForestClassifier(random_state=42),
            'gradient_boosting': GradientBoostingClassifier(random_state=42)
        }
        return models
    
    def train_baseline_models(self, X_train: np.ndarray, X_test: np.ndarray, 
                            y_train: np.ndarray, y_test: np.ndarray) -> Dict[str, Dict]:
        """Train baseline models and evaluate performance"""
        logger.info("Training baseline models...")
        
        models = self.define_models()
        results = {}
        
        for name, model in models.items():
            logger.info(f"Training {name}...")
            
            # Train model
            model.fit(X_train, y_train)
            
            # Make predictions
            train_pred = model.predict(X_train)
            test_pred = model.predict(X_test)
            test_proba = model.predict_proba(X_test)[:, 1] if hasattr(model, 'predict_proba') else None
            
            # Calculate metrics
            train_accuracy = accuracy_score(y_train, train_pred)
            test_accuracy = accuracy_score(y_test, test_pred)
            test_f1 = f1_score(y_test, test_pred, average='weighted')
            test_precision = precision_score(y_test, test_pred, average='weighted')
            test_recall = recall_score(y_test, test_pred, average='weighted')
            
            if test_proba is not None and len(np.unique(y_test)) == 2:
                test_auc = roc_auc_score(y_test, test_proba)
            else:
                test_auc = None
            
            results[name] = {
                'model': model,
                'train_accuracy': train_accuracy,
                'test_accuracy': test_accuracy,
                'test_f1': test_f1,
                'test_precision': test_precision,
                'test_recall': test_recall,
                'test_auc': test_auc
            }
            
            # Cross-validation
            cv_scores = cross_val_score(model, X_train, y_train, cv=5, scoring='accuracy')
            results[name]['cv_mean'] = cv_scores.mean()
            results[name]['cv_std'] = cv_scores.std()
            
            logger.info(f"{name} - Test Accuracy: {test_accuracy:.4f}, CV Score: {cv_scores.mean():.4f} ± {cv_scores.std():.4f}")
        
        self.models = results
        return results
    
    def hyperparameter_tuning(self, X_train: np.ndarray, y_train: np.ndarray, 
                            model_name: str = 'random_forest') -> Dict[str, Any]:
        """Perform hyperparameter tuning using Optuna"""
        logger.info(f"Performing hyperparameter tuning for {model_name}...")
        
        def objective(trial):
            if model_name == 'random_forest':
                params = {
                    'n_estimators': trial.suggest_int('n_estimators', 50, 300),
                    'max_depth': trial.suggest_int('max_depth', 3, 20),
                    'min_samples_split': trial.suggest_int('min_samples_split', 2, 20),
                    'min_samples_leaf': trial.suggest_int('min_samples_leaf', 1, 10),
                    'random_state': 42
                }
                model = RandomForestClassifier(**params)
            elif model_name == 'gradient_boosting':
                params = {
                    'n_estimators': trial.suggest_int('n_estimators', 50, 200),
                    'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3),
                    'max_depth': trial.suggest_int('max_depth', 3, 10),
                    'random_state': 42
                }
                model = GradientBoostingClassifier(**params)
            else:
                raise ValueError(f"Hyperparameter tuning not implemented for {model_name}")
            
            # Cross-validation score
            scores = cross_val_score(model, X_train, y_train, cv=3, scoring='accuracy')
            return scores.mean()
        
        study = optuna.create_study(direction='maximize')
        study.optimize(objective, n_trials=50)
        
        best_params = study.best_params
        logger.info(f"Best parameters: {best_params}")
        logger.info(f"Best CV score: {study.best_value:.4f}")
        
        return best_params
    
    def train_final_model(self, X_train: np.ndarray, y_train: np.ndarray, 
                         model_name: str, best_params: Dict[str, Any]) -> Any:
        """Train final model with best parameters"""
        logger.info("Training final model with best parameters...")
        
        if model_name == 'random_forest':
            model = RandomForestClassifier(**best_params)
        elif model_name == 'gradient_boosting':
            model = GradientBoostingClassifier(**best_params)
        else:
            raise ValueError(f"Final model training not implemented for {model_name}")
        
        # Handle class imbalance with SMOTE
        smote = SMOTE(random_state=42)
        X_train_balanced, y_train_balanced = smote.fit_resample(X_train, y_train)
        
        model.fit(X_train_balanced, y_train_balanced)
        self.best_model = model
        
        return model

class ModelEvaluator:
    """Handle model evaluation and visualization"""
    
    def __init__(self):
        pass
    
    def evaluate_model(self, model: Any, X_test: np.ndarray, y_test: np.ndarray) -> Dict[str, Any]:
        """Comprehensive model evaluation"""
        logger.info("Evaluating final model...")
        
        # Predictions
        y_pred = model.predict(X_test)
        y_proba = model.predict_proba(X_test)[:, 1] if hasattr(model, 'predict_proba') else None
        
        # Metrics
        metrics = {
            'accuracy': accuracy_score(y_test, y_pred),
            'precision': precision_score(y_test, y_pred, average='weighted'),
            'recall': recall_score(y_test, y_pred, average='weighted'),
            'f1': f1_score(y_test, y_pred, average='weighted')
        }
        
        if y_proba is not None and len(np.unique(y_test)) == 2:
            metrics['auc'] = roc_auc_score(y_test, y_proba)
        
        # Classification report
        report = classification_report(y_test, y_pred)
        
        # Confusion matrix
        cm = confusion_matrix(y_test, y_pred)
        
        logger.info(f"Final model metrics: {metrics}")
        
        return {
            'metrics': metrics,
            'classification_report': report,
            'confusion_matrix': cm,
            'predictions': y_pred,
            'probabilities': y_proba
        }
    
    def plot_results(self, results: Dict[str, Any], save_path: str = 'model_results.png'):
        """Plot evaluation results"""
        fig, axes = plt.subplots(2, 2, figsize=(12, 10))
        
        # Confusion Matrix
        sns.heatmap(results['confusion_matrix'], annot=True, fmt='d', ax=axes[0, 0])
        axes[0, 0].set_title('Confusion Matrix')
        axes[0, 0].set_xlabel('Predicted')
        axes[0, 0].set_ylabel('Actual')
        
        # Metrics bar plot
        metrics = results['metrics']
        metric_names = list(metrics.keys())
        metric_values = list(metrics.values())
        
        axes[0, 1].bar(metric_names, metric_values)
        axes[0, 1].set_title('Model Metrics')
        axes[0, 1].set_ylim(0, 1)
        axes[0, 1].tick_params(axis='x', rotation=45)
        
        # Feature importance (if available)
        if hasattr(self, 'feature_importance'):
            top_features = self.feature_importance.head(10)
            axes[1, 0].barh(top_features.index, top_features.values)
            axes[1, 0].set_title('Top 10 Feature Importance')
        
        # ROC Curve (if probabilities available)
        if results['probabilities'] is not None:
            from sklearn.metrics import roc_curve
            fpr, tpr, _ = roc_curve(results['actual'], results['probabilities'])
            axes[1, 1].plot(fpr, tpr, label=f"AUC = {results['metrics']['auc']:.3f}")
            axes[1, 1].plot([0, 1], [0, 1], 'k--')
            axes[1, 1].set_title('ROC Curve')
            axes[1, 1].set_xlabel('False Positive Rate')
            axes[1, 1].set_ylabel('True Positive Rate')
            axes[1, 1].legend()
        
        plt.tight_layout()
        plt.savefig(save_path)
        plt.close()

class MLFlowTracker:
    """Handle MLflow experiment tracking"""
    
    def __init__(self, experiment_name: str):
        mlflow.set_experiment(experiment_name)
        self.experiment_name = experiment_name
    
    def log_experiment(self, model: Any, metrics: Dict[str, float], 
                      params: Dict[str, Any], artifacts: List[str]):
        """Log experiment to MLflow"""
        with mlflow.start_run():
            # Log parameters
            mlflow.log_params(params)
            
            # Log metrics
            mlflow.log_metrics(metrics)
            
            # Log model
            mlflow.sklearn.log_model(model, "model")
            
            # Log artifacts
            for artifact in artifacts:
                if os.path.exists(artifact):
                    mlflow.log_artifact(artifact)

class RecommendationPipeline:
    """Main pipeline orchestrator"""
    
    def __init__(self, data_path: str, target_column: str, experiment_name: str = "recommendation_system"):
        self.data_path = data_path
        self.target_column = target_column
        self.experiment_name = experiment_name
        
        self.data_processor = DataProcessor(data_path)
        self.model_trainer = ModelTrainer()
        self.model_evaluator = ModelEvaluator()
        self.mlflow_tracker = MLFlowTracker(experiment_name)
    
    def run_pipeline(self) -> Dict[str, Any]:
        """Execute the complete ML pipeline"""
        logger.info("Starting ML pipeline...")
        
        # Load and explore data
        df = self.data_processor.load_data()
        analysis = self.data_processor.explore_data(df)
        
        # Clean and engineer features
        df_clean = self.data_processor.clean_data(df)
        df_features = self.data_processor.feature_engineering(df_clean)
        
        # Prepare features and target
        X, y = self.data_processor.prepare_features(df_features, self.target_column)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train baseline models
        baseline_results = self.model_trainer.train_baseline_models(X_train, X_test, y_train, y_test)
        
        # Select best performing model for tuning
        best_baseline = max(baseline_results.keys(), 
                          key=lambda k: baseline_results[k]['test_accuracy'])
        
        # Hyperparameter tuning
        best_params = self.model_trainer.hyperparameter_tuning(X_train, y_train, best_baseline)
        
        # Train final model
        final_model = self.model_trainer.train_final_model(X_train, y_train, best_baseline, best_params)
        
        # Evaluate final model
        evaluation_results = self.model_evaluator.evaluate_model(final_model, X_test, y_test)
        evaluation_results['actual'] = y_test
        
        # Plot results
        self.model_evaluator.plot_results(evaluation_results)
        
        # Log to MLflow
        self.mlflow_tracker.log_experiment(
            model=final_model,
            metrics=evaluation_results['metrics'],
            params=best_params,
            artifacts=['model_results.png', 'data_distributions.png']
        )
        
        # Save model
        model_path = f'models/recommendation_model_{datetime.now().strftime("%Y%m%d_%H%M%S")}.joblib'
        os.makedirs('models', exist_ok=True)
        joblib.dump(final_model, model_path)
        
        # Save preprocessor
        preprocessor_path = f'models/preprocessor_{datetime.now().strftime("%Y%m%d_%H%M%S")}.joblib'
        joblib.dump(self.data_processor.preprocessor, preprocessor_path)
        
        logger.info(f"Pipeline completed. Model saved to {model_path}")
        
        return {
            'final_model': final_model,
            'evaluation_results': evaluation_results,
            'baseline_results': baseline_results,
            'best_params': best_params,
            'model_path': model_path,
            'preprocessor_path': preprocessor_path
        }

def main():
    """Main execution function"""
    # Example usage
    pipeline = RecommendationPipeline(
        data_path="data/ecommerce_data.csv",
        target_column="will_buy",
        experiment_name="ecommerce_recommendation"
    )
    
    results = pipeline.run_pipeline()
    
    print("\n=== Pipeline Results ===")
    print(f"Final model accuracy: {results['evaluation_results']['metrics']['accuracy']:.4f}")
    print(f"Model saved to: {results['model_path']}")
    print(f"Preprocessor saved to: {results['preprocessor_path']}")

if __name__ == "__main__":
    main() 