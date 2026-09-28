"""Analyze the official PlantVillage color dataset without modifying images."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt
from tqdm import tqdm

sys.path.insert(0, str(Path(__file__).resolve().parent))
from download_plantvillage import load_plantvillage, raw_cache_dir  # noqa: E402

REPORT_DIR = Path(__file__).resolve().parents[2] / "reports"
TARGET_CROPS = {"Tomato", "Potato", "Corn_(maize)", "Grape", "Apple"}


def _json_default(value: Any) -> Any:
    if isinstance(value, Counter):
        return dict(value)
    raise TypeError(f"Cannot serialize {type(value).__name__}")


def _write_plot(path: Path, counts: Counter[str], title: str) -> None:
    labels = list(counts)
    values = [counts[label] for label in labels]
    figure, axis = plt.subplots(figsize=(max(10, min(18, len(labels) * 0.42)), 6))
    axis.bar(labels, values, color="#2f7d5a")
    axis.set_title(title)
    axis.set_ylabel("Images")
    axis.tick_params(axis="x", labelrotation=75)
    figure.tight_layout()
    figure.savefig(path, dpi=150)
    plt.close(figure)


def analyze(dataset: Any) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    class_counts: Counter[str] = Counter()
    crop_counts: Counter[str] = Counter()
    healthy_counts: Counter[str] = Counter()
    dimensions: Counter[str] = Counter()
    modes: Counter[str] = Counter()
    class_crops: dict[str, str] = {}
    class_diseases: dict[str, str] = {}
    group_images: defaultdict[str, list[str]] = defaultdict(list)
    byte_hashes: defaultdict[str, list[str]] = defaultdict(list)
    corrupt_images: list[dict[str, str]] = []
    available_columns = set()
    total_bytes = 0
    label_names = dataset[next(iter(dataset))].features["label"].names

    for split_name, split in dataset.items():
        available_columns.update(split.column_names)
        for row in tqdm(split, desc=f"Analyzing {split_name}"):
            image_path = str(row.get("image_path", ""))
            label_value = row.get("label", "")
            class_name = label_names[label_value] if isinstance(label_value, int) else str(label_value)
            crop = str(row.get("crop", ""))
            disease = str(row.get("disease", ""))
            group_id = str(row.get("leaf_id", ""))
            class_counts[class_name] += 1
            crop_counts[crop] += 1
            class_crops[class_name] = crop
            class_diseases[class_name] = disease
            healthy_counts["healthy" if disease.lower() == "healthy" else "diseased"] += 1
            group_images[group_id].append(image_path)
            try:
                image = row["image"]
                dimensions[f"{image.width}x{image.height}"] += 1
                modes[image.mode] += 1
                image_bytes = image.convert("RGB").tobytes()
                byte_hashes[hashlib.sha256(image_bytes).hexdigest()].append(image_path)
                total_bytes += len(image_bytes)
            except Exception as error:
                corrupt_images.append({"image_path": image_path, "error": str(error)})

    multi_image_groups = {group_id: paths for group_id, paths in group_images.items() if len(paths) > 1}
    duplicate_groups = [paths for paths in byte_hashes.values() if len(paths) > 1]
    crop_classes: defaultdict[str, list[str]] = defaultdict(list)
    for class_name, crop in class_crops.items():
        crop_classes[crop].append(class_name)

    candidates = []
    for class_name in sorted(class_counts):
        crop = class_crops[class_name]
        disease = class_diseases[class_name]
        healthy = disease.lower() == "healthy"
        candidates.append(
            {
                "crop": crop,
                "disease": disease,
                "class_name": class_name,
                "image_count": class_counts[class_name],
                "healthy": healthy,
                "suitable_for_initial_training": crop in TARGET_CROPS and class_counts[class_name] >= 100,
                "plantdoc_class_appears_available": None,
                "plantdoc_status": "not acquired or checked; kept separate by design",
            }
        )

    report = {
        "dataset": "mohanty/PlantVillage",
        "configuration_requested": "color",
        "splits_analyzed": {name: len(split) for name, split in dataset.items()},
        "total_images": sum(class_counts.values()),
        "number_of_classes": len(class_counts),
        "class_names": sorted(class_counts),
        "images_per_class": dict(sorted(class_counts.items())),
        "number_of_crops": len(crop_counts),
        "images_per_crop": dict(sorted(crop_counts.items())),
        "classes_per_crop": {crop: sorted(classes) for crop, classes in sorted(crop_classes.items())},
        "healthy_vs_diseased": dict(healthy_counts),
        "image_dimensions": dict(dimensions),
        "image_channels_or_modes": dict(modes),
        "missing_or_corrupt_images": corrupt_images,
        "duplicate_images": {"exact_decoded_rgb_groups": duplicate_groups, "group_count": len(duplicate_groups)},
        "metadata_columns": sorted(available_columns),
        "leaf_id_available": "leaf_id" in available_columns,
        "unique_leaf_or_group_ids": len(group_images),
        "groups_with_multiple_images": len(multi_image_groups),
        "images_in_multi_image_groups": sum(map(len, multi_image_groups.values())),
        "multiple_images_per_physical_leaf_detected": bool(multi_image_groups),
        "estimated_decoded_rgb_bytes": total_bytes,
        "estimated_archive_download_bytes": 2_000_000_000,
        "limitations": [
            "PlantVillage images are mostly controlled, non-phone imagery.",
            "PlantDoc is not mixed into training or this analysis.",
            "Exact duplicate detection hashes decoded RGB pixels; near-duplicates are not identified.",
            "The official dataset supplied split is 80/20; a reviewed custom 70/15/15 split is planned.",
        ],
        "recommended_classes": ["Review Tomato, Potato, Corn_(maize), Grape, and Apple classes with healthy and disease coverage; do not finalize automatically."],
        "recommended_split_strategy": {"train": 0.70, "validation": 0.15, "test": 0.15, "unit": "leaf_id/group_id", "seed": 42},
    }
    return report, candidates


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, default=None)
    args = parser.parse_args()
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    try:
        dataset = load_plantvillage(args.cache_dir or raw_cache_dir())
        report, candidates = analyze(dataset)
    except Exception as error:
        print(f"PlantVillage analysis failed: {error}", file=sys.stderr)
        return 1
    (REPORT_DIR / "plantvillage_analysis.json").write_text(json.dumps(report, indent=2, default=_json_default), encoding="utf-8")
    (REPORT_DIR / "candidate_classes.json").write_text(json.dumps(candidates, indent=2, default=_json_default), encoding="utf-8")
    lines = [
        "PlantVillage analysis",
        f"Total images: {report['total_images']:,}",
        f"Classes: {report['number_of_classes']}",
        f"Crops: {report['number_of_crops']}",
        f"Healthy/diseased: {report['healthy_vs_diseased']}",
        f"Leaf IDs: {report['leaf_id_available']} ({report['unique_leaf_or_group_ids']:,} unique)",
        f"Multi-image leaf groups: {report['groups_with_multiple_images']:,}",
        "",
        "Images per class:",
    ]
    lines.extend(f"  {name}: {count:,}" for name, count in report["images_per_class"].items())
    lines.extend(["", "Recommendation: review candidate classes before approving a split.", "PlantDoc remains a separate real-world evaluation dataset."])
    (REPORT_DIR / "plantvillage_analysis.txt").write_text("\n".join(lines), encoding="utf-8")
    _write_plot(REPORT_DIR / "class_distribution.png", Counter(report["images_per_class"]), "PlantVillage class distribution")
    _write_plot(REPORT_DIR / "crop_distribution.png", Counter(report["images_per_crop"]), "PlantVillage crop distribution")
    print("Analysis reports written to:", REPORT_DIR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())