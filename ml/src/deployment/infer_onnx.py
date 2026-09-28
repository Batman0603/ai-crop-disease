"""Run ONNX Runtime inference for one image."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from evaluation.evaluate import build_validation_transform  # noqa: E402


MODEL_PATH = PROJECT_ROOT / "models" / "crop_disease_efficientnet_v2_s.onnx"
METADATA_PATH = PROJECT_ROOT / "models" / "model_metadata.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="Path to an RGB image")
    args = parser.parse_args()
    image_path = args.image.expanduser().resolve()
    if not image_path.is_file():
        parser.error(f"Image does not exist: {image_path}")
    if not MODEL_PATH.is_file() or not METADATA_PATH.is_file():
        parser.error("ONNX model or metadata missing; run export_onnx.py first")

    metadata = json.loads(METADATA_PATH.read_text(encoding="utf-8"))
    classes = [metadata["class_mapping"][str(index)] for index in range(metadata["class_count"])]
    image_size = int(metadata["input_size"][0])
    image_transform = build_validation_transform(image_size)
    with Image.open(image_path) as image:
        tensor = image_transform(image.convert("RGB")).unsqueeze(0).numpy().astype(np.float32)

    session = ort.InferenceSession(str(MODEL_PATH), providers=["CPUExecutionProvider"])
    logits = session.run(["logits"], {"images": tensor})[0][0]
    shifted_logits = logits - np.max(logits)
    probabilities = np.exp(shifted_logits)
    probabilities /= probabilities.sum()
    top_indices = np.argsort(probabilities)[::-1][:3]
    predicted_class = classes[int(top_indices[0])]
    crop, disease = predicted_class.split("___", maxsplit=1)

    print(f"Crop: {crop}")
    print(f"Disease: {disease}")
    print(f"Confidence: {probabilities[top_indices[0]]:.6f}")
    print("Top-3 predictions:")
    for index in top_indices:
        print(f"  {classes[int(index)]}: {probabilities[index]:.6f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())