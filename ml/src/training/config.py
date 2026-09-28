"""Configuration for the EfficientNetV2-S training pipeline."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]


@dataclass
class TrainingConfig:
    manifest_path: Path = PROJECT_ROOT / "dataset" / "processed" / "manifest.csv"
    approved_classes_path: Path = PROJECT_ROOT / "reports" / "approved_classes.json"
    image_root: Path | None = None
    output_dir: Path = PROJECT_ROOT / "models"
    report_dir: Path = PROJECT_ROOT / "reports" / "training"
    image_size: int = 224
    batch_size: int = 16
    num_workers: int = 0
    learning_rate: float = 1e-4
    weight_decay: float = 1e-4
    max_epochs: int = 20
    patience: int = 5
    seed: int = 42
    use_class_weights: bool = True
    use_random_affine: bool = False
    sanity_train_batches: int = 3
    sanity_validation_batches: int = 2

    def to_serializable(self) -> dict[str, Any]:
        values = asdict(self)
        return {key: str(value) if isinstance(value, Path) else value for key, value in values.items()}
