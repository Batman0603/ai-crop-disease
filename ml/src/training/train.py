"""Train or sanity-check an ImageNet-initialized EfficientNetV2-S classifier.

Default execution is a short sanity check. Use ``--full-train`` only after
reviewing the sanity output. The test split is intentionally never loaded by
this training pipeline.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import random
import sys
import time
from collections import Counter
from itertools import islice
from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
import torch
from PIL import Image
from sklearn.metrics import accuracy_score, confusion_matrix, precision_recall_fscore_support
from torch import nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import ReduceLROnPlateau
from torch.utils.data import DataLoader, Dataset
from tqdm import tqdm
from torchvision import transforms
from torchvision.models import EfficientNet_V2_S_Weights, efficientnet_v2_s

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config import PROJECT_ROOT, TrainingConfig  # noqa: E402


CLASS_FIELD = "class_name"
SPLIT_FIELD = "split"
SPLITS = ("train", "validation", "test")


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


def load_classes(path: Path) -> list[str]:
    classes = json.loads(path.read_text(encoding="utf-8"))["classes"]
    if len(classes) != 25 or len(set(classes)) != len(classes):
        raise ValueError("approved_classes.json must contain exactly 25 unique classes")
    return classes


def find_image_root(config: TrainingConfig, sample_relative_path: str) -> Path:
    candidates: list[Path] = []
    if config.image_root:
        candidates.append(config.image_root)
    candidates.extend(
        [
            PROJECT_ROOT / "dataset" / "raw",
            Path.home() / ".cache" / "huggingface" / "datasets" / "downloads" / "extracted",
        ]
    )
    for candidate in candidates:
        if candidate.is_file():
            continue
        if (candidate / sample_relative_path).is_file():
            return candidate
        matches = list(candidate.glob(f"**/{sample_relative_path}")) if candidate.exists() else []
        if matches:
            return matches[0].parents[len(Path(sample_relative_path).parts) - 1]
    raise FileNotFoundError(
        f"Could not resolve '{sample_relative_path}'. Pass --image-root pointing to the "
        "official PlantVillage extracted root."
    )


def read_manifest(config: TrainingConfig, classes: list[str]) -> tuple[list[dict[str, str]], Path]:
    with config.manifest_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError("Manifest is empty")
    class_set = set(classes)
    if {row[CLASS_FIELD] for row in rows} != class_set:
        raise ValueError("Manifest classes do not exactly match approved_classes.json")
    split_values = {row[SPLIT_FIELD] for row in rows}
    if not split_values.issubset(SPLITS) or "test" not in split_values:
        raise ValueError(f"Manifest splits are invalid: {split_values}")
    group_by_split = {
        split: {row["group_id"] for row in rows if row[SPLIT_FIELD] == split}
        for split in SPLITS
    }
    for left_index, left in enumerate(SPLITS):
        for right in SPLITS[left_index + 1 :]:
            overlap = group_by_split[left] & group_by_split[right]
            if overlap:
                raise ValueError(f"Group leakage detected between {left} and {right}: {len(overlap)} groups")
    image_root = find_image_root(config, rows[0]["image_path"])
    missing = [row["image_path"] for row in rows if not (image_root / row["image_path"]).is_file()]
    if missing:
        raise FileNotFoundError(f"{len(missing)} manifest images are missing under {image_root}")
    return rows, image_root


class ManifestDataset(Dataset[tuple[torch.Tensor, int]]):
    def __init__(self, rows: list[dict[str, str]], image_root: Path, class_to_index: dict[str, int], transform: Any):
        self.rows = rows
        self.image_root = image_root
        self.class_to_index = class_to_index
        self.transform = transform

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        row = self.rows[index]
        with Image.open(self.image_root / row["image_path"]) as image:
            image = image.convert("RGB")
        return self.transform(image), self.class_to_index[row[CLASS_FIELD]]


def build_transforms(config: TrainingConfig, weights: EfficientNet_V2_S_Weights) -> tuple[Any, Any]:
    pretrained_preprocess = weights.transforms()
    normalize = transforms.Normalize(mean=pretrained_preprocess.mean, std=pretrained_preprocess.std)
    train_ops: list[Any] = [
        transforms.RandomResizedCrop(config.image_size, scale=(0.75, 1.0), ratio=(0.9, 1.1)),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomRotation(10),
        transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.15, hue=0.02),
    ]
    if config.use_random_affine:
        train_ops.append(transforms.RandomAffine(degrees=0, translate=(0.05, 0.05), scale=(0.95, 1.05)))
    train_ops.extend([transforms.ToTensor(), normalize])
    validation = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(config.image_size), transforms.ToTensor(), normalize])
    return transforms.Compose(train_ops), validation


def build_model(num_classes: int, weights: EfficientNet_V2_S_Weights | None) -> nn.Module:
    model = efficientnet_v2_s(weights=weights)
    model.classifier[-1] = nn.Linear(model.classifier[-1].in_features, num_classes)
    return model


def class_weights(rows: list[dict[str, str]], classes: list[str]) -> torch.Tensor:
    counts = Counter(row[CLASS_FIELD] for row in rows)
    total = len(rows)
    weights = [total / (len(classes) * counts[class_name]) for class_name in classes]
    return torch.tensor(weights, dtype=torch.float32)


def metrics_from_predictions(targets: list[int], predictions: list[int], loss: float, classes: list[str]) -> dict[str, Any]:
    precision, recall, f1, support = precision_recall_fscore_support(targets, predictions, labels=list(range(len(classes))), zero_division=0)
    return {
        "loss": loss,
        "accuracy": accuracy_score(targets, predictions),
        "macro_precision": float(np.mean(precision)),
        "macro_recall": float(np.mean(recall)),
        "macro_f1": float(np.mean(f1)),
        "weighted_f1": float(np.average(f1, weights=support)) if support.sum() else 0.0,
        "per_class": {class_name: {"precision": float(precision[index]), "recall": float(recall[index]), "f1": float(f1[index]), "support": int(support[index])} for index, class_name in enumerate(classes)},
    }


def run_batches(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: AdamW | None,
    device: torch.device,
    scaler: torch.amp.GradScaler,
    train: bool,
    desc: str,
    learning_rate: float | None = None,
    max_batches: int | None = None,
) -> dict[str, Any]:
    model.train(train)
    total_loss = 0.0
    targets: list[int] = []
    predictions: list[int] = []
    running_correct = 0
    autocast_enabled = device.type == "cuda"
    total_batches = len(loader) if max_batches is None else min(len(loader), max_batches)
    batch_iterator = loader if max_batches is None else islice(loader, max_batches)
    progress = tqdm(batch_iterator, total=total_batches, desc=desc, unit="batch", dynamic_ncols=True)
    for batch_index, (images, labels) in enumerate(progress, start=1):
        images, labels = images.to(device, non_blocking=True), labels.to(device, non_blocking=True)
        if train:
            if optimizer is None:
                raise ValueError("Optimizer is required for training batches")
            optimizer.zero_grad(set_to_none=True)
        with torch.set_grad_enabled(train):
            with torch.autocast(device_type=device.type, dtype=torch.float16, enabled=autocast_enabled):
                outputs = model(images)
                loss = criterion(outputs, labels)
        if train:
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
        total_loss += loss.item() * labels.size(0)
        batch_predictions = outputs.argmax(dim=1).detach()
        running_correct += int((batch_predictions == labels).sum().item())
        predictions.extend(batch_predictions.cpu().tolist())
        targets.extend(labels.cpu().tolist())
        processed = len(targets)
        running_loss = total_loss / processed
        running_accuracy = running_correct / processed
        postfix = {
            "loss": f"{running_loss:.3f}",
            "acc": f"{running_accuracy * 100:.1f}%",
        }
        if learning_rate is not None:
            postfix["lr"] = f"{learning_rate:.2e}"
        if device.type == "cuda" and (batch_index % 10 == 0 or batch_index == total_batches):
            allocated_gb = torch.cuda.memory_allocated(device) / 1024**3
            postfix["gpu"] = f"{allocated_gb:.2f}G"
        progress.set_postfix(postfix, refresh=False)
    sample_count = len(targets)
    return metrics_from_predictions(
        targets,
        predictions,
        total_loss / max(sample_count, 1),
        classes=list(loader.dataset.class_to_index),
    )


def format_duration(seconds: float) -> str:
    total_seconds = max(0, int(seconds))
    hours, remainder = divmod(total_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f"{hours}h {minutes}m {seconds}s"
    if minutes:
        return f"{minutes}m {seconds}s"
    return f"{seconds}s"


def print_training_configuration(config: TrainingConfig, device: torch.device, parameter_count: int) -> None:
    print("Training Configuration")
    print("=" * 60)
    print(f"Device          : {device}")
    if device.type == "cuda":
        print(f"GPU             : {torch.cuda.get_device_name(0)}")
        print(f"VRAM            : {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
    else:
        print("GPU             : unavailable; using CPU")
        print("VRAM            : unavailable")
    print("Model           : EfficientNetV2-S")
    print(f"Parameters      : {parameter_count:,}")
    print(f"Batch Size      : {config.batch_size}")
    print(f"Image Size      : {config.image_size}x{config.image_size}")
    print(f"Epochs          : {config.max_epochs}")
    print(f"Mixed Precision : {'enabled' if device.type == 'cuda' else 'disabled'}")
    print("=" * 60)


def save_checkpoint_atomic(checkpoint: dict[str, Any], checkpoint_path: Path) -> None:
    temporary_path = checkpoint_path.with_name(f".{checkpoint_path.name}.tmp")
    try:
        torch.save(checkpoint, temporary_path)
        os.replace(temporary_path, checkpoint_path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def plot_history(history: dict[str, list[float]], report_dir: Path) -> None:
    report_dir.mkdir(parents=True, exist_ok=True)
    for metric, title in (("loss", "Loss"), ("accuracy", "Accuracy")):
        figure, axis = plt.subplots(figsize=(8, 5))
        axis.plot(history[f"train_{metric}"], label="train")
        axis.plot(history[f"validation_{metric}"], label="validation")
        axis.set_title(title)
        axis.set_xlabel("Epoch")
        axis.legend()
        figure.tight_layout()
        figure.savefig(report_dir / f"{metric}_curve.png", dpi=150)
        plt.close(figure)


def run(config: TrainingConfig, full_train: bool) -> dict[str, Any]:
    set_seed(config.seed)
    classes = load_classes(config.approved_classes_path)
    rows, image_root = read_manifest(config, classes)
    counts = {split: Counter(row[CLASS_FIELD] for row in rows if row[SPLIT_FIELD] == split) for split in ("train", "validation", "test")}
    print("Class distribution:")
    for class_name in classes:
        print(f"  {class_name}: train={counts['train'][class_name]}, validation={counts['validation'][class_name]}, test={counts['test'][class_name]}")
    print(f"Image root: {image_root}")
    print("Test rows are verified but never loaded into a DataLoader.")

    weights = EfficientNet_V2_S_Weights.DEFAULT
    train_transform, validation_transform = build_transforms(config, weights)
    class_to_index = {class_name: index for index, class_name in enumerate(classes)}
    train_rows = [row for row in rows if row[SPLIT_FIELD] == "train"]
    validation_rows = [row for row in rows if row[SPLIT_FIELD] == "validation"]
    train_dataset = ManifestDataset(train_rows, image_root, class_to_index, train_transform)
    validation_dataset = ManifestDataset(validation_rows, image_root, class_to_index, validation_transform)
    train_loader = DataLoader(train_dataset, batch_size=config.batch_size, shuffle=True, num_workers=config.num_workers, pin_memory=torch.cuda.is_available())
    validation_loader = DataLoader(validation_dataset, batch_size=config.batch_size, shuffle=False, num_workers=config.num_workers, pin_memory=torch.cuda.is_available())

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = build_model(len(classes), weights).to(device)
    parameter_count = sum(parameter.numel() for parameter in model.parameters())
    print_training_configuration(config, device, parameter_count)
    criterion = nn.CrossEntropyLoss(weight=class_weights(train_rows, classes).to(device) if config.use_class_weights else None)
    optimizer = AdamW(model.parameters(), lr=config.learning_rate, weight_decay=config.weight_decay)
    scheduler = ReduceLROnPlateau(optimizer, mode="min", factor=0.3, patience=2)
    scaler = torch.amp.GradScaler("cuda", enabled=device.type == "cuda")
    if not full_train:
        train_result = run_batches(model, train_loader, criterion, optimizer, device, scaler, train=True, desc="Sanity [Train]", learning_rate=optimizer.param_groups[0]["lr"], max_batches=config.sanity_train_batches)
        validation_result = run_batches(model, validation_loader, criterion, None, device, scaler, train=False, desc="Sanity [Val]", max_batches=config.sanity_validation_batches)
        sample_images, sample_labels = next(iter(train_loader))
        print(f"Augmented batch verified: shape={tuple(sample_images.shape)}, labels={sample_labels[:8].tolist()}")
        print(f"Sanity train metrics: {train_result}")
        print(f"Sanity validation metrics: {validation_result}")
        return {"sanity_check": "passed", "parameter_count": parameter_count, "device": str(device), "image_root": str(image_root)}

    config.output_dir.mkdir(parents=True, exist_ok=True)
    config.report_dir.mkdir(parents=True, exist_ok=True)
    (config.output_dir / "class_names.json").write_text(json.dumps(classes, indent=2), encoding="utf-8")
    (config.output_dir / "training_config.json").write_text(json.dumps(config.to_serializable(), indent=2), encoding="utf-8")
    history: dict[str, list[float]] = {"train_loss": [], "validation_loss": [], "train_accuracy": [], "validation_accuracy": []}
    best_loss = float("inf")
    best_macro_f1 = float("-inf")
    best_accuracy = 0.0
    best_epoch = 0
    epochs_without_improvement = 0
    training_started = time.perf_counter()
    for epoch in range(config.max_epochs):
        epoch_started = time.perf_counter()
        epoch_number = epoch + 1
        current_lr = optimizer.param_groups[0]["lr"]
        train_result = run_batches(model, train_loader, criterion, optimizer, device, scaler, train=True, desc=f"Epoch {epoch_number}/{config.max_epochs} [Train]", learning_rate=current_lr)
        validation_result = run_batches(model, validation_loader, criterion, None, device, scaler, train=False, desc=f"Epoch {epoch_number}/{config.max_epochs} [Val]")
        epoch_seconds = time.perf_counter() - epoch_started
        scheduler.step(validation_result["loss"])
        for key, result_key in (("train_loss", "loss"), ("validation_loss", "loss"), ("train_accuracy", "accuracy"), ("validation_accuracy", "accuracy")):
            history[key].append(train_result[result_key] if key.startswith("train") else validation_result[result_key])
        improved = validation_result["loss"] < best_loss
        if improved:
            best_loss = validation_result["loss"]
            best_macro_f1 = validation_result["macro_f1"]
            best_accuracy = validation_result["accuracy"]
            best_epoch = epoch_number
            checkpoint_path = config.output_dir / "best_model.pth"
            save_checkpoint_atomic({"model_state_dict": model.state_dict(), "classes": classes, "config": config.to_serializable(), "validation_metrics": validation_result, "best_epoch": best_epoch}, checkpoint_path)
            epochs_without_improvement = 0
        else:
            epochs_without_improvement += 1
        remaining_epochs = config.max_epochs - epoch_number
        elapsed = time.perf_counter() - training_started
        estimated_remaining = (elapsed / epoch_number) * remaining_epochs
        tqdm.write("=" * 60)
        tqdm.write(f"Epoch {epoch_number}/{config.max_epochs}")
        tqdm.write("-" * 60)
        tqdm.write(f"Train Loss       : {train_result['loss']:.4f}")
        tqdm.write(f"Train Accuracy   : {train_result['accuracy'] * 100:.2f}%")
        tqdm.write(f"Val Loss         : {validation_result['loss']:.4f}")
        tqdm.write(f"Val Accuracy     : {validation_result['accuracy'] * 100:.2f}%")
        tqdm.write(f"Val Macro F1     : {validation_result['macro_f1']:.4f}")
        tqdm.write(f"Learning Rate    : {current_lr:.2e}")
        tqdm.write(f"Epoch Time       : {format_duration(epoch_seconds)}")
        tqdm.write(f"Estimated Remaining: {format_duration(estimated_remaining)}")
        if improved:
            tqdm.write("*** NEW BEST MODEL ***")
            tqdm.write(f"Validation Macro F1: {best_macro_f1:.4f}")
            tqdm.write(f"Saved: {checkpoint_path}")
        else:
            tqdm.write(f"Best Validation Macro F1: {best_macro_f1:.4f} (epoch {best_epoch})")
        tqdm.write("=" * 60)
        if epochs_without_improvement >= config.patience:
            break
    plot_history(history, config.report_dir)
    model.load_state_dict(torch.load(config.output_dir / "best_model.pth", map_location=device)["model_state_dict"])
    final_validation = run_batches(model, validation_loader, criterion, None, device, scaler, train=False, desc="Best checkpoint [Val]")
    (config.report_dir / "validation_metrics.json").write_text(json.dumps(final_validation, indent=2), encoding="utf-8")
    targets = []
    predictions = []
    model.eval()
    with torch.no_grad():
        for images, labels in tqdm(validation_loader, desc="Best checkpoint [Val CM]", unit="batch", dynamic_ncols=True):
            outputs = model(images.to(device, non_blocking=True))
            predictions.extend(outputs.argmax(dim=1).cpu().tolist())
            targets.extend(labels.tolist())
    matrix = confusion_matrix(targets, predictions, labels=list(range(len(classes))))
    figure, axis = plt.subplots(figsize=(16, 14))
    axis.imshow(matrix, cmap="Blues")
    axis.set_title("Validation confusion matrix")
    axis.set_xlabel("Predicted class")
    axis.set_ylabel("True class")
    axis.set_xticks(range(len(classes)), classes, rotation=90, fontsize=6)
    axis.set_yticks(range(len(classes)), classes, fontsize=6)
    figure.tight_layout()
    figure.savefig(config.report_dir / "confusion_matrix.png", dpi=150)
    plt.close(figure)
    (config.report_dir / "per_class_metrics.json").write_text(json.dumps(final_validation["per_class"], indent=2), encoding="utf-8")
    (config.report_dir / "training_history.json").write_text(json.dumps(history, indent=2), encoding="utf-8")
    total_training_time = time.perf_counter() - training_started
    print("=" * 60)
    print("TRAINING COMPLETE")
    print("=" * 60)
    print(f"Best Epoch: {best_epoch}")
    print(f"Best Validation Macro F1: {best_macro_f1:.4f}")
    print(f"Best Validation Accuracy: {best_accuracy * 100:.2f}%")
    print(f"Best Checkpoint: {config.output_dir / 'best_model.pth'}")
    print(f"Total Training Time: {format_duration(total_training_time)}")
    print("=" * 60)
    return {"training": "completed", "best_validation_loss": best_loss, "best_validation_macro_f1": best_macro_f1, "best_epoch": best_epoch, "epochs": len(history["train_loss"])}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full-train", action="store_true", help="Run full training; default is a short sanity check")
    parser.add_argument("--image-root", type=Path, default=None)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--max-epochs", type=int, default=20)
    parser.add_argument("--patience", type=int, default=5)
    parser.add_argument("--unweighted-loss", action="store_true")
    args = parser.parse_args()
    config = TrainingConfig(image_root=args.image_root, batch_size=args.batch_size, image_size=args.image_size, learning_rate=args.learning_rate, weight_decay=args.weight_decay, max_epochs=args.max_epochs, patience=args.patience, use_class_weights=not args.unweighted_loss)
    try:
        result = run(config, full_train=args.full_train)
    except KeyboardInterrupt:
        print("\nTraining interrupted by user.")
        checkpoint_path = config.output_dir / "best_model.pth"
        if checkpoint_path.exists():
            print(f"Best checkpoint available at: {checkpoint_path}")
        else:
            print("No best checkpoint was saved before interruption.")
        return 0
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
