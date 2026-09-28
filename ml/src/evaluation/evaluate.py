"""Evaluate the saved best checkpoint on the held-out PlantVillage test split."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
import torch
from PIL import Image
from sklearn.metrics import accuracy_score, confusion_matrix, precision_recall_fscore_support
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
from torchvision.models import EfficientNet_V2_S_Weights, efficientnet_v2_s
from tqdm import tqdm


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = PROJECT_ROOT / "dataset" / "processed" / "manifest.csv"
CLASS_NAMES_PATH = PROJECT_ROOT / "models" / "class_names.json"
CHECKPOINT_PATH = PROJECT_ROOT / "models" / "best_model.pth"
TRAINING_CONFIG_PATH = PROJECT_ROOT / "models" / "training_config.json"
REPORT_DIR = PROJECT_ROOT / "reports"
EXPECTED_TEST_SAMPLES = 4680
SPLIT_NAMES = ("train", "validation", "test")


def load_classes(path: Path) -> list[str]:
    classes = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(classes, list) or len(classes) != 25 or len(set(classes)) != 25:
        raise ValueError(f"{path} must contain exactly 25 unique class names")
    return classes


def read_test_rows(path: Path, classes: list[str]) -> tuple[list[dict[str, str]], dict[str, int]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"Manifest is empty: {path}")
    required_fields = {"image_path", "class_name", "group_id", "split"}
    if not required_fields.issubset(rows[0]):
        raise ValueError(f"Manifest must contain fields: {sorted(required_fields)}")

    class_set = set(classes)
    manifest_classes = {row["class_name"] for row in rows}
    if manifest_classes != class_set:
        raise ValueError("Manifest classes do not exactly match models/class_names.json")
    split_values = {row["split"] for row in rows}
    if not split_values.issubset(SPLIT_NAMES) or set(SPLIT_NAMES) - split_values:
        raise ValueError(f"Manifest splits are invalid: {sorted(split_values)}")

    split_groups = {
        split: {row["group_id"] for row in rows if row["split"] == split}
        for split in SPLIT_NAMES
    }
    for left_index, left in enumerate(SPLIT_NAMES):
        for right in SPLIT_NAMES[left_index + 1 :]:
            overlap = split_groups[left] & split_groups[right]
            if overlap:
                raise ValueError(
                    f"Group leakage detected between {left} and {right}: {len(overlap)} groups"
                )

    test_rows = [row for row in rows if row["split"] == "test"]
    if len(test_rows) != EXPECTED_TEST_SAMPLES:
        raise ValueError(
            f"Expected {EXPECTED_TEST_SAMPLES} test samples, found {len(test_rows)}"
        )
    test_paths = [row["image_path"] for row in test_rows]
    if len(test_paths) != len(set(test_paths)):
        raise ValueError("Duplicate image paths found in the test split")
    if any(not row["group_id"] for row in test_rows):
        raise ValueError("Test split contains an empty group_id")
    if any(row["class_name"] not in class_set for row in test_rows):
        raise ValueError("Test split contains a class missing from class_names.json")
    return test_rows, {split: len(groups) for split, groups in split_groups.items()}


def find_image_root(sample_path: str, configured_root: str | None) -> Path:
    candidates = []
    if configured_root:
        candidates.append(Path(configured_root))
    candidates.extend(
        [
            PROJECT_ROOT / "dataset" / "raw",
            Path.home() / ".cache" / "huggingface" / "datasets" / "downloads" / "extracted",
        ]
    )
    relative_path = Path(sample_path)
    for candidate in candidates:
        if candidate.is_file():
            continue
        direct_path = candidate / relative_path
        if direct_path.is_file():
            return candidate
        if candidate.exists():
            matches = candidate.glob(f"**/{sample_path}")
            match = next((item for item in matches if item.is_file()), None)
            if match is not None:
                return match.parents[len(relative_path.parts) - 1]
    raise FileNotFoundError(
        f"Could not resolve '{sample_path}'. Pass --image-root pointing to the "
        "official PlantVillage extracted root."
    )


class TestDataset(Dataset[tuple[torch.Tensor, int]]):
    def __init__(
        self,
        rows: list[dict[str, str]],
        image_root: Path,
        class_to_index: dict[str, int],
        image_transform: Any,
    ) -> None:
        self.rows = rows
        self.image_root = image_root
        self.class_to_index = class_to_index
        self.image_transform = image_transform

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        row = self.rows[index]
        with Image.open(self.image_root / row["image_path"]) as image:
            image = image.convert("RGB")
        return self.image_transform(image), self.class_to_index[row["class_name"]]


def build_validation_transform(image_size: int) -> Any:
    weights = EfficientNet_V2_S_Weights.DEFAULT
    pretrained_preprocess = weights.transforms()
    normalize = transforms.Normalize(
        mean=pretrained_preprocess.mean,
        std=pretrained_preprocess.std,
    )
    return transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(image_size),
            transforms.ToTensor(),
            normalize,
        ]
    )


def load_checkpoint(
    checkpoint_path: Path,
    classes: list[str],
    config: dict[str, Any],
    device: torch.device,
) -> nn.Module:
    try:
        checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=True)
    except TypeError:
        checkpoint = torch.load(checkpoint_path, map_location=device)
    if checkpoint.get("classes") != classes:
        raise ValueError("Checkpoint classes do not match models/class_names.json")
    checkpoint_config = checkpoint.get("config", {})
    if checkpoint_config.get("image_size") != config.get("image_size"):
        raise ValueError("Checkpoint image_size does not match training_config.json")

    model = efficientnet_v2_s(weights=None)
    model.classifier[-1] = nn.Linear(model.classifier[-1].in_features, len(classes))
    model.load_state_dict(checkpoint["model_state_dict"], strict=True)
    return model.to(device).eval()


def save_confusion_matrix(matrix: np.ndarray, classes: list[str], output_path: Path) -> None:
    figure, axis = plt.subplots(figsize=(16, 14))
    axis.imshow(matrix, cmap="Blues")
    axis.set_title("PlantVillage held-out test confusion matrix")
    axis.set_xlabel("Predicted class")
    axis.set_ylabel("True class")
    axis.set_xticks(range(len(classes)), classes, rotation=90, fontsize=6)
    axis.set_yticks(range(len(classes)), classes, fontsize=6)
    figure.tight_layout()
    figure.savefig(output_path, dpi=150)
    plt.close(figure)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image-root", type=Path, default=None)
    args = parser.parse_args()

    classes = load_classes(CLASS_NAMES_PATH)
    training_config = json.loads(TRAINING_CONFIG_PATH.read_text(encoding="utf-8"))
    test_rows, group_counts = read_test_rows(MANIFEST_PATH, classes)
    image_root = find_image_root(
        test_rows[0]["image_path"],
        str(args.image_root) if args.image_root else training_config.get("image_root"),
    )
    missing_images = [
        row["image_path"] for row in test_rows if not (image_root / row["image_path"]).is_file()
    ]
    if missing_images:
        raise FileNotFoundError(f"{len(missing_images)} test images are missing under {image_root}")

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = load_checkpoint(CHECKPOINT_PATH, classes, training_config, device)
    dataset = TestDataset(
        test_rows,
        image_root,
        {class_name: index for index, class_name in enumerate(classes)},
        build_validation_transform(int(training_config["image_size"])),
    )
    loader = DataLoader(
        dataset,
        batch_size=int(training_config["batch_size"]),
        shuffle=False,
        num_workers=int(training_config.get("num_workers", 0)),
        pin_memory=device.type == "cuda",
    )

    targets: list[int] = []
    predictions: list[int] = []
    with torch.inference_mode():
        for images, labels in tqdm(loader, desc="Final test evaluation", unit="batch"):
            outputs = model(images.to(device, non_blocking=True))
            predictions.extend(outputs.argmax(dim=1).cpu().tolist())
            targets.extend(labels.tolist())

    label_indices = list(range(len(classes)))
    precision, recall, f1, support = precision_recall_fscore_support(
        targets,
        predictions,
        labels=label_indices,
        zero_division=0,
    )
    matrix = confusion_matrix(targets, predictions, labels=label_indices)
    per_class = {
        class_name: {
            "precision": float(precision[index]),
            "recall": float(recall[index]),
            "f1": float(f1[index]),
            "support": int(support[index]),
        }
        for index, class_name in enumerate(classes)
    }
    metrics = {
        "accuracy": float(accuracy_score(targets, predictions)),
        "macro_precision": float(np.mean(precision)),
        "macro_recall": float(np.mean(recall)),
        "macro_f1": float(np.mean(f1)),
        "weighted_precision": float(np.average(precision, weights=support)),
        "weighted_recall": float(np.average(recall, weights=support)),
        "weighted_f1": float(np.average(f1, weights=support)),
    }
    confusion_pairs = [
        {
            "true_class": classes[true_index],
            "predicted_class": classes[predicted_index],
            "count": int(matrix[true_index, predicted_index]),
        }
        for true_index, predicted_index in zip(*np.where(matrix - np.diag(np.diag(matrix)) > 0))
    ]
    confusion_pairs.sort(key=lambda pair: (-pair["count"], pair["true_class"], pair["predicted_class"]))

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    evaluation = {
        "evaluation": "PlantVillage held-out test performance",
        "checkpoint": str(CHECKPOINT_PATH.relative_to(PROJECT_ROOT)),
        "class_names": classes,
        "test_samples": len(test_rows),
        "split_group_counts": group_counts,
        "metrics": metrics,
        "per_class": per_class,
        "confusion_matrix": matrix.tolist(),
        "most_common_confusion_pairs": confusion_pairs[:10],
    }
    (REPORT_DIR / "test_evaluation.json").write_text(
        json.dumps(evaluation, indent=2), encoding="utf-8"
    )
    with (REPORT_DIR / "test_classification_report.csv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.writer(handle)
        writer.writerow(["class", "precision", "recall", "f1", "support"])
        for class_name in sorted(classes):
            values = per_class[class_name]
            writer.writerow(
                [class_name, values["precision"], values["recall"], values["f1"], values["support"]]
            )
    save_confusion_matrix(matrix, classes, REPORT_DIR / "test_confusion_matrix.png")

    print("=" * 60)
    print("FINAL TEST EVALUATION")
    print("=" * 60)
    print(f"Test Samples       : {len(test_rows)}")
    print(f"Accuracy           : {metrics['accuracy']:.6f}")
    print(f"Macro Precision    : {metrics['macro_precision']:.6f}")
    print(f"Macro Recall       : {metrics['macro_recall']:.6f}")
    print(f"Macro F1           : {metrics['macro_f1']:.6f}")
    print(f"Weighted F1        : {metrics['weighted_f1']:.6f}")
    print("=" * 60)
    print("PlantVillage held-out test performance")
    print("Class | Precision | Recall | F1 | Support")
    for class_name in sorted(classes):
        values = per_class[class_name]
        print(
            f"{class_name} | {values['precision']:.6f} | {values['recall']:.6f} | "
            f"{values['f1']:.6f} | {values['support']}"
        )
    print("\nFive classes with lowest F1:")
    lowest_f1 = sorted(
        classes,
        key=lambda class_name: (per_class[class_name]["f1"], class_name),
    )[:5]
    for class_name in lowest_f1:
        values = per_class[class_name]
        print(f"{class_name}: F1={values['f1']:.6f}, support={values['support']}")
    print("\nMost common confusion pairs (true -> predicted):")
    for pair in confusion_pairs[:10]:
        print(f"{pair['true_class']} -> {pair['predicted_class']}: {pair['count']}")
    print(f"\nReports saved under: {REPORT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())