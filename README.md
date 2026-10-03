# CropCare

**A plant health assistant that brings crop disease image classification and practical crop-care guidance into one app.**

CropCare is a Flutter application for identifying possible diseases from a plant-leaf photo. Inference runs on the device with an ONNX model, so the image classification flow does not require an application server. The app also includes a disease reference library, locally stored scan history, and a CropCare assistant screen.

> **Please use results as a screening aid.** Predictions can be wrong, especially on photos or crops unlike the model's training data. Confirm important decisions with a qualified agricultural adviser.

## Features

- Capture a photo or choose one from the image gallery.
- Classify a leaf image on device with an EfficientNetV2-S ONNX model.
- View the predicted crop, disease, confidence, symptoms, and care guidance.
- Browse disease information for supported classes.
- Review recent scans; scan records and copied images are stored locally on the device (up to 50 entries).
- Ask common crop-care questions in the assistant screen, which currently uses a small set of built-in responses.

## Supported crop classes

The bundled classifier recognizes 25 classes across five crops:

| Crop | Classes |
| --- | --- |
| Apple | Apple scab, Black rot, Cedar-apple rust, Healthy |
| Corn (maize) | Cercospora / gray leaf spot, Common rust, Northern leaf blight, Healthy |
| Grape | Black rot, Esca (black measles), Leaf blight, Healthy |
| Potato | Early blight, Late blight, Healthy |
| Tomato | Bacterial spot, Early blight, Late blight, Leaf mold, Septoria leaf spot, Spider mites, Target spot, Yellow leaf curl virus, Mosaic virus, Healthy |

The model returns a best match among these classes. It is not a general plant identifier and may still return a class for an unsupported crop or an image that does not show a leaf.

## Project layout

```text
.
├── README.md                 # Project overview and setup
├── frontend/                 # Flutter app and platform projects
│   ├── lib/                  # Screens, services, models, and theme
│   └── assets/models/        # ONNX model bundled with the app
└── ml/                       # Dataset, training, evaluation, and deployment code
    ├── src/
    ├── models/
    └── reports/
```

## Requirements

- Flutter SDK compatible with the Dart constraint in `frontend/pubspec.yaml` (Dart `^3.13.4`).
- An available Flutter target, such as an Android device/emulator, iOS device/simulator, or desktop target supported by Flutter.
- For Android release builds, the Android SDK and toolchain required by Flutter.

## Run the app

From the repository root:

```bash
cd frontend
flutter pub get
flutter run
```

To list available devices before launching:

```bash
flutter devices
```

Build an Android APK:

```bash
cd frontend
flutter build apk --release
```

The Android launcher label is **CropCare**. The Android manifest references the CropCare drawable icon at `frontend/android/app/src/main/res/drawable/ic_cropcare.xml`.

## How image detection works

1. Select or capture a plant image.
2. CropCare applies image orientation, resizes the shorter edge to 256 pixels, center-crops to 224 × 224, and normalizes RGB channels.
3. The app runs the bundled `frontend/assets/models/crop_disease_efficientnet_v2_s.onnx` model with ONNX Runtime.
4. The predicted class is matched to the in-app disease information. If saved, the scan and a copy of its image are stored on device.

The model expects an RGB tensor with shape `[1, 3, 224, 224]` and returns logits for 25 classes. Class ordering is part of the model contract; see [`ml/models/model_metadata.json`](ml/models/model_metadata.json) and [`ml/models/class_names.json`](ml/models/class_names.json).

## Model performance and limitations

The repository records **99.32% accuracy** and **99.20% macro F1** on a held-out test split of 4,680 PlantVillage images. The ONNX export matched the PyTorch predictions on that test set. These are results on the PlantVillage test data, which is largely controlled imagery; they do not establish equivalent performance on field conditions or smartphone photos. Lighting, background, camera quality, crop variety, overlapping symptoms, and unsupported classes can affect predictions.

Confidence is a model score, not a calibrated probability that the diagnosis is correct. Treatment guidance is general educational information; follow local agricultural advice and product labels.

## Machine learning pipeline

The `ml/` directory contains scripts for PlantVillage dataset preparation and analysis, EfficientNetV2-S training, held-out evaluation, ONNX export, single-image inference, and export verification. Deployment details and commands are documented in [`ml/src/deployment/README.md`](ml/src/deployment/README.md). Training requires the dataset and Python dependencies used by those scripts; no Python dependency lock or requirements file is currently included in the repository.

The mobile app consumes the committed ONNX model and does not need the training pipeline to run.

## Tests and analysis

Run the Flutter test suite and static analysis from `frontend/`:

```bash
cd frontend
flutter test
flutter analyze
```

## Privacy

Image inference is performed locally. Scan history stores scan details and copied images in the app's local storage. The current assistant uses built-in responses and does not provide AI-powered conversations. Removing the app or clearing its history removes these local records according to the platform's storage behavior.

## License

No repository-level license file is currently included. Contact the project maintainers for permission and licensing details before redistributing this project or its assets.
