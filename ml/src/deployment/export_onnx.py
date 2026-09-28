"""Export the trained EfficientNetV2-S checkpoint for ONNX Runtime Mobile."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
from torchvision.models import EfficientNet_V2_S_Weights


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TRAINING_DIR = PROJECT_ROOT / "src" / "training"
EVALUATION_DIR = PROJECT_ROOT / "src" / "evaluation"
sys.path.insert(0, str(TRAINING_DIR))
sys.path.insert(0, str(EVALUATION_DIR))

from evaluate import build_validation_transform, load_classes  # noqa: E402
from train import build_model  # noqa: E402


CHECKPOINT_PATH = PROJECT_ROOT / "models" / "best_model.pth"
CLASS_NAMES_PATH = PROJECT_ROOT / "models" / "class_names.json"
CONFIG_PATH = PROJECT_ROOT / "models" / "training_config.json"
ONNX_PATH = PROJECT_ROOT / "models" / "crop_disease_efficientnet_v2_s.onnx"
METADATA_PATH = PROJECT_ROOT / "models" / "model_metadata.json"
OPSET_VERSION = 17


def load_trained_model(classes: list[str]) -> torch.nn.Module:
    try:
        checkpoint = torch.load(CHECKPOINT_PATH, map_location="cpu", weights_only=True)
    except TypeError:
        checkpoint = torch.load(CHECKPOINT_PATH, map_location="cpu")
    if checkpoint.get("classes") != classes:
        raise ValueError("Checkpoint classes do not exactly match models/class_names.json")
    model = build_model(len(classes), weights=None)
    model.load_state_dict(checkpoint["model_state_dict"], strict=True)
    return model.eval()


def write_metadata(classes: list[str], image_size: int) -> None:
    weights = EfficientNet_V2_S_Weights.DEFAULT
    preprocess = build_validation_transform(image_size)
    normalization = preprocess.transforms[-1]
    metadata = {
        "model_name": "Crop Disease EfficientNetV2-S",
        "architecture": "EfficientNetV2-S",
        "framework": "PyTorch exported to ONNX",
        "input_size": [image_size, image_size],
        "input_channels": 3,
        "color_format": "RGB",
        "normalization_mean": list(normalization.mean),
        "normalization_std": list(normalization.std),
        "class_count": len(classes),
        "class_mapping": {str(index): class_name for index, class_name in enumerate(classes)},
        "onnx_filename": ONNX_PATH.name,
        "onnx_opset": OPSET_VERSION,
        "input_name": "images",
        "input_shape": ["batch", 3, image_size, image_size],
        "input_dtype": "float32",
        "preprocessing": (
            "Decode image as RGB; torchvision Resize(256); CenterCrop(224); "
            "ToTensor() to scale to [0, 1]; Normalize with the EfficientNetV2-S "
            f"{weights.name} mean and standard deviation."
        ),
        "output_name": "logits",
        "output_description": (
            "Unnormalized float32 class logits in class_mapping index order; "
            "apply softmax over the final dimension for probabilities."
        ),
    }
    METADATA_PATH.write_text(json.dumps(metadata, indent=2), encoding="utf-8")


def main() -> int:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    image_size = int(config["image_size"])
    if image_size != 224:
        raise ValueError(f"Expected the trained input size 224, found {image_size}")
    classes = load_classes(CLASS_NAMES_PATH)
    if len(classes) != 25:
        raise ValueError(f"Expected 25 classes, found {len(classes)}")
    model = load_trained_model(classes)
    dummy_input = torch.zeros((1, 3, image_size, image_size), dtype=torch.float32)

    torch.onnx.export(
        model,
        (dummy_input,),
        str(ONNX_PATH),
        input_names=["images"],
        output_names=["logits"],
        dynamic_axes={"images": {0: "batch"}, "logits": {0: "batch"}},
        opset_version=OPSET_VERSION,
        dynamo=False,
        do_constant_folding=True,
        export_params=True,
    )
    if not ONNX_PATH.is_file() or ONNX_PATH.stat().st_size == 0:
        raise RuntimeError(f"ONNX export did not create a non-empty file at {ONNX_PATH}")

    onnx_model = onnx.load(str(ONNX_PATH))
    onnx.checker.check_model(onnx_model)
    session = ort.InferenceSession(str(ONNX_PATH), providers=["CPUExecutionProvider"])
    inputs = session.get_inputs()
    outputs = session.get_outputs()
    if len(inputs) != 1 or inputs[0].name != "images" or inputs[0].type != "tensor(float)":
        raise RuntimeError("Exported ONNX input must be float32 and named 'images'")
    if list(inputs[0].shape[1:]) != [3, image_size, image_size]:
        raise RuntimeError(f"Unexpected ONNX input shape: {inputs[0].shape}")
    if inputs[0].shape[0] != "batch":
        raise RuntimeError(f"ONNX batch dimension is not dynamic: {inputs[0].shape}")
    if len(outputs) != 1 or outputs[0].name != "logits":
        raise RuntimeError("Exported ONNX output must be named 'logits'")
    output = session.run(None, {"images": np.zeros((1, 3, image_size, image_size), dtype=np.float32)})[0]
    if output.shape != (1, len(classes)) or output.dtype != np.float32:
        raise RuntimeError(f"Unexpected ONNX output shape/dtype: {output.shape}/{output.dtype}")

    write_metadata(classes, image_size)
    size_mb = ONNX_PATH.stat().st_size / (1024**2)
    print("ONNX EXPORT")
    print("----------------")
    print("Export status: PASS")
    print(f"ONNX path: {ONNX_PATH}")
    print(f"ONNX size: {size_mb:.2f} MB")
    print(f"ONNX opset: {OPSET_VERSION}")
    print(f"Input: images float32 {inputs[0].shape}")
    print(f"Output: logits float32 {output.shape}")
    print(f"Metadata: {METADATA_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())