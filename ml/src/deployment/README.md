# ONNX Deployment

## Export

The exported model is reconstructed using the training pipeline's `build_model`
factory, with `weights=None`, then loaded strictly from
`ml/models/best_model.pth`. The checkpoint class list is checked against
`ml/models/class_names.json` before export. The ONNX graph uses opset 17, named
input `images`, named output `logits`, and a dynamic batch dimension. Spatial
input dimensions remain fixed at `[3, 224, 224]`; tensors and logits are
float32.

From the repository root, use the ML environment:

```powershell
& ml/.venv/Scripts/python.exe ml/src/deployment/export_onnx.py
```

The exporter checks the ONNX graph, input/output names and types, dynamic batch
axis, output shape, and an ONNX Runtime smoke inference. It writes
`ml/models/crop_disease_efficientnet_v2_s.onnx` and
`ml/models/model_metadata.json`.

## Preprocessing And Output

Preprocess each image as RGB with the same deterministic pipeline used for
validation and test evaluation:

1. `Resize(256)`
2. `CenterCrop(224)`
3. `ToTensor()` (float32 RGB values scaled to `[0, 1]`)
4. Normalize with the torchvision EfficientNetV2-S ImageNet weight mean and
   standard deviation (`[0.485, 0.456, 0.406]` and
   `[0.229, 0.224, 0.225]`)

The `logits` output has shape `[batch, 25]`. Index order is the exact training
order recorded in `model_metadata.json` under `class_mapping`; apply softmax on
the final axis to obtain class probabilities. Do not sort or otherwise change
the class mapping.

## Single-Image Inference

```powershell
& ml/.venv/Scripts/python.exe ml/src/deployment/infer_onnx.py <image-path>
```

The utility prints crop, disease, confidence, and the three highest-probability
class predictions. It currently uses ONNX Runtime's CPU provider; ONNX Runtime
Mobile can load the same graph and metadata in a later mobile integration.

## Verification

Run the parity check from the repository root:

```powershell
& ml/.venv/Scripts/python.exe ml/src/deployment/verify_onnx.py
```

Verification uses only the 4,680 rows marked `test` in
`ml/dataset/processed/manifest.csv`, validates the existing split isolation,
and applies the same deterministic transform to both runtimes. It compares
PyTorch and ONNX predictions for the complete held-out test set and records
logits, predicted indexes/classes, and confidence comparisons for 128
deterministically selected test images. The report is
`ml/reports/onnx_verification.json`.

### Recorded Result

| Check | Result |
|---|---:|
| Test images | 4,680 |
| Detailed image comparisons | 128 |
| Prediction agreement | 100.000000% |
| Mismatches | 0 |
| Maximum absolute logit difference | 0.00002384 |
| Mean absolute logit difference | 0.00000149 |
| Maximum confidence difference | 0.00000417 |
| PyTorch accuracy | 0.993162 |
| ONNX accuracy | 0.993162 |
| PyTorch macro F1 | 0.992035 |
| ONNX macro F1 | 0.992035 |
| Status | PASS |

Both PyTorch and ONNX Runtime used CPU for the parity run. ONNX Runtime in the
available environment does not expose a CUDA execution provider; comparing
CPU-to-CPU avoids conflating exporter parity with different accelerator
kernel numerics. The initial CUDA-PyTorch/CPU-ONNX comparison had identical
predicted classes on all test images but larger numeric logit deltas, so it is
not the reported parity result.

## React Native Handoff

After parity is accepted, the React Native application can load
`crop_disease_efficientnet_v2_s.onnx` with ONNX Runtime Mobile, preprocess an
image to the documented normalized RGB tensor, execute input `images`, and map
the output `logits` through `class_mapping`. Mobile integration is not part of
this deployment stage. The current model has not been validated on smartphone
photographs or described as real-world accuracy.