"""Compare the exported ONNX model with PyTorch on held-out test images."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
import onnxruntime as ort
import torch
from sklearn.metrics import accuracy_score, f1_score
from torch.utils.data import DataLoader
from tqdm import tqdm


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from evaluation.evaluate import (  # noqa: E402
    CHECKPOINT_PATH,
    CLASS_NAMES_PATH,
    MANIFEST_PATH,
    REPORT_DIR,
    TRAINING_CONFIG_PATH,
    TestDataset,
    build_validation_transform,
    find_image_root,
    load_checkpoint,
    load_classes,
    read_test_rows,
)


ONNX_PATH = PROJECT_ROOT / "models" / "crop_disease_efficientnet_v2_s.onnx"
METADATA_PATH = PROJECT_ROOT / "models" / "model_metadata.json"
REPORT_PATH = REPORT_DIR / "onnx_verification.json"
SAMPLE_COUNT = 128
MAX_LOGIT_ERROR = 1e-3
MAX_CONFIDENCE_ERROR = 1e-4


def softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - np.max(logits, axis=1, keepdims=True)
    exp_values = np.exp(shifted)
    return exp_values / exp_values.sum(axis=1, keepdims=True)


def load_test_data(image_root_arg: Path | None) -> tuple[list[str], list[int], DataLoader, list[str]]:
    classes = load_classes(CLASS_NAMES_PATH)
    config = json.loads(TRAINING_CONFIG_PATH.read_text(encoding="utf-8"))
    rows, _ = read_test_rows(MANIFEST_PATH, classes)
    configured_root = str(image_root_arg) if image_root_arg else config.get("image_root")
    image_root = find_image_root(rows[0]["image_path"], configured_root)
    missing = [row["image_path"] for row in rows if not (image_root / row["image_path"]).is_file()]
    if missing:
        raise FileNotFoundError(f"{len(missing)} test images are missing under {image_root}")

    dataset = TestDataset(
        rows,
        image_root,
        {class_name: index for index, class_name in enumerate(classes)},
        build_validation_transform(int(config["image_size"])),
    )
    loader = DataLoader(
        dataset,
        batch_size=int(config["batch_size"]),
        shuffle=False,
        num_workers=int(config.get("num_workers", 0)),
        pin_memory=False,
    )
    paths = [row["image_path"] for row in rows]
    targets = [dataset.class_to_index[row["class_name"]] for row in rows]
    return paths, targets, loader, classes


def collect_sample_comparison(
    image_path: str,
    true_index: int,
    torch_logits: np.ndarray,
    onnx_logits: np.ndarray,
    classes: list[str],
) -> dict[str, Any]:
    torch_probabilities = softmax(torch_logits[None, :])[0]
    onnx_probabilities = softmax(onnx_logits[None, :])[0]
    torch_index = int(np.argmax(torch_logits))
    onnx_index = int(np.argmax(onnx_logits))
    differences = np.abs(torch_logits - onnx_logits)
    return {
        "image_path": image_path,
        "true_class": classes[true_index],
        "pytorch_predicted_class": classes[torch_index],
        "pytorch_predicted_index": torch_index,
        "pytorch_confidence": float(torch_probabilities[torch_index]),
        "onnx_predicted_class": classes[onnx_index],
        "onnx_predicted_index": onnx_index,
        "onnx_confidence": float(onnx_probabilities[onnx_index]),
        "predictions_match": torch_index == onnx_index,
        "max_abs_logit_difference": float(np.max(differences)),
        "mean_abs_logit_difference": float(np.mean(differences)),
        "max_confidence_difference": float(
            abs(np.max(torch_probabilities) - np.max(onnx_probabilities))
        ),
        "pytorch_logits": torch_logits.astype(float).tolist(),
        "onnx_logits": onnx_logits.astype(float).tolist(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image-root", type=Path, default=None)
    args = parser.parse_args()

    classes = load_classes(CLASS_NAMES_PATH)
    if not ONNX_PATH.is_file():
        raise FileNotFoundError(f"Exported model not found: {ONNX_PATH}; run export_onnx.py first")
    metadata = json.loads(METADATA_PATH.read_text(encoding="utf-8"))
    expected_mapping = {str(index): name for index, name in enumerate(classes)}
    if metadata.get("class_mapping") != expected_mapping:
        raise ValueError("ONNX metadata class mapping does not match the training class order")

    image_paths, targets, loader, classes = load_test_data(args.image_root)
    device = torch.device("cpu")
    config = json.loads(TRAINING_CONFIG_PATH.read_text(encoding="utf-8"))
    model = load_checkpoint(CHECKPOINT_PATH, classes, config, device)
    session = ort.InferenceSession(str(ONNX_PATH), providers=["CPUExecutionProvider"])
    input_info = session.get_inputs()[0]
    output_info = session.get_outputs()[0]
    if input_info.name != "images" or output_info.name != "logits":
        raise ValueError("ONNX input/output names do not match deployment metadata")

    sample_indices = set(
        np.linspace(0, len(image_paths) - 1, min(SAMPLE_COUNT, len(image_paths)), dtype=int).tolist()
    )
    sample_comparisons: list[dict[str, Any]] = []
    mismatch_examples: list[dict[str, Any]] = []
    pytorch_predictions: list[int] = []
    onnx_predictions: list[int] = []
    absolute_difference_sum = 0.0
    absolute_difference_count = 0
    max_abs_logit_difference = 0.0
    max_confidence_difference = 0.0
    sample_offset = 0

    model.eval()
    with torch.inference_mode():
        for images, labels in tqdm(loader, desc="Verify ONNX on held-out test", unit="batch"):
            pytorch_logits = model(images.to(device, non_blocking=True)).float().cpu().numpy()
            onnx_logits = session.run(
                ["logits"], {"images": images.numpy().astype(np.float32, copy=False)}
            )[0]
            if pytorch_logits.shape != onnx_logits.shape:
                raise RuntimeError(
                    f"PyTorch/ONNX output shape mismatch: {pytorch_logits.shape} vs {onnx_logits.shape}"
                )

            absolute_differences = np.abs(pytorch_logits - onnx_logits)
            absolute_difference_sum += float(absolute_differences.sum(dtype=np.float64))
            absolute_difference_count += absolute_differences.size
            max_abs_logit_difference = max(
                max_abs_logit_difference, float(absolute_differences.max(initial=0.0))
            )
            pytorch_batch_predictions = np.argmax(pytorch_logits, axis=1)
            onnx_batch_predictions = np.argmax(onnx_logits, axis=1)
            pytorch_predictions.extend(pytorch_batch_predictions.tolist())
            onnx_predictions.extend(onnx_batch_predictions.tolist())
            pytorch_probabilities = softmax(pytorch_logits)
            onnx_probabilities = softmax(onnx_logits)
            batch_confidence_difference = np.abs(
                np.max(pytorch_probabilities, axis=1) - np.max(onnx_probabilities, axis=1)
            )
            max_confidence_difference = max(
                max_confidence_difference, float(batch_confidence_difference.max(initial=0.0))
            )

            for local_index in range(len(labels)):
                global_index = sample_offset + local_index
                if global_index in sample_indices:
                    sample_comparisons.append(
                        collect_sample_comparison(
                            image_paths[global_index],
                            int(labels[local_index]),
                            pytorch_logits[local_index],
                            onnx_logits[local_index],
                            classes,
                        )
                    )
                if (
                    pytorch_batch_predictions[local_index] != onnx_batch_predictions[local_index]
                    and len(mismatch_examples) < 20
                ):
                    torch_index = int(pytorch_batch_predictions[local_index])
                    onnx_index = int(onnx_batch_predictions[local_index])
                    mismatch_examples.append(
                        {
                            "image_path": image_paths[global_index],
                            "true_class": classes[int(labels[local_index])],
                            "pytorch_predicted_class": classes[torch_index],
                            "onnx_predicted_class": classes[onnx_index],
                            "max_abs_logit_difference": float(
                                absolute_differences[local_index].max()
                            ),
                        }
                    )
            sample_offset += len(labels)

    if sample_offset != len(image_paths):
        raise RuntimeError(f"Evaluated {sample_offset} images, expected {len(image_paths)}")

    pytorch_accuracy = float(accuracy_score(targets, pytorch_predictions))
    onnx_accuracy = float(accuracy_score(targets, onnx_predictions))
    pytorch_macro_f1 = float(f1_score(targets, pytorch_predictions, average="macro", zero_division=0))
    onnx_macro_f1 = float(f1_score(targets, onnx_predictions, average="macro", zero_division=0))
    mismatch_count = int(np.count_nonzero(np.asarray(pytorch_predictions) != np.asarray(onnx_predictions)))
    prediction_agreement = 100.0 * (len(targets) - mismatch_count) / len(targets)
    mean_abs_logit_difference = absolute_difference_sum / absolute_difference_count
    sample_mismatches = sum(not item["predictions_match"] for item in sample_comparisons)
    status = (
        "PASS"
        if mismatch_count == 0
        and max_abs_logit_difference <= MAX_LOGIT_ERROR
        and max_confidence_difference <= MAX_CONFIDENCE_ERROR
        else "FAIL"
    )

    report = {
        "model": "EfficientNetV2-S crop disease classifier",
        "input_shape": "[batch, 3, 224, 224]",
        "num_classes": len(classes),
        "test_images": len(image_paths),
        "verification_sample_images": len(sample_comparisons),
        "prediction_agreement": prediction_agreement,
        "mismatches": mismatch_count,
        "max_abs_logit_difference": max_abs_logit_difference,
        "mean_abs_logit_difference": mean_abs_logit_difference,
        "max_confidence_difference": max_confidence_difference,
        "pytorch_accuracy": pytorch_accuracy,
        "onnx_accuracy": onnx_accuracy,
        "pytorch_macro_f1": pytorch_macro_f1,
        "onnx_macro_f1": onnx_macro_f1,
        "pytorch_device": str(device),
        "onnx_execution_provider": "CPUExecutionProvider",
        "status": status,
        "verification_sample_agreement": (
            100.0 * (len(sample_comparisons) - sample_mismatches) / len(sample_comparisons)
        ),
        "verification_sample_mismatches": sample_mismatches,
        "verification_thresholds": {
            "required_prediction_agreement_percent": 100.0,
            "max_abs_logit_difference": MAX_LOGIT_ERROR,
            "max_confidence_difference": MAX_CONFIDENCE_ERROR,
        },
        "mismatch_examples": mismatch_examples,
        "sample_comparisons": sample_comparisons,
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print("VERIFICATION")
    print("----------------")
    print(f"Images tested: {len(image_paths)} (detailed sample: {len(sample_comparisons)})")
    print(f"Prediction agreement: {prediction_agreement:.6f}%")
    print(f"Mismatches: {mismatch_count}")
    print(f"Max logit difference: {max_abs_logit_difference:.8g}")
    print(f"Mean logit difference: {mean_abs_logit_difference:.8g}")
    print(f"Max confidence difference: {max_confidence_difference:.8g}")
    if mismatch_examples:
        print("Mismatch examples:")
        for example in mismatch_examples:
            print(
                f"  {example['image_path']}: {example['pytorch_predicted_class']} -> "
                f"{example['onnx_predicted_class']}"
            )
    print("\nTEST SET COMPARISON")
    print("----------------")
    print(f"PyTorch accuracy: {pytorch_accuracy:.6f}")
    print(f"ONNX accuracy: {onnx_accuracy:.6f}")
    print(f"PyTorch macro F1: {pytorch_macro_f1:.6f}")
    print(f"ONNX macro F1: {onnx_macro_f1:.6f}")
    print(f"Prediction agreement: {prediction_agreement:.6f}%")
    print(f"Mismatches: {mismatch_count}")
    print("\nFINAL STATUS:")
    print(status)
    print(f"Verification report: {REPORT_PATH}")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())