"""Prepare a reviewed, group-aware PlantVillage manifest."""

from __future__ import annotations

import argparse
import csv
import json
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from download_plantvillage import load_plantvillage, raw_cache_dir  # noqa: E402


SPLIT_NAMES = ("train", "validation", "test")


def assign_groups(rows: list[dict[str, str]], ratios: tuple[float, float, float], seed: int) -> None:
    grouped: defaultdict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[(row["class_name"], row["group_id"])].append(row)
    by_class: defaultdict[str, list[tuple[str, list[dict[str, str]]]]] = defaultdict(list)
    for (class_name, group_id), group_rows in grouped.items():
        by_class[class_name].append((group_id, group_rows))
    rng = random.Random(seed)
    for class_name, class_groups in sorted(by_class.items()):
        rng.shuffle(class_groups)
        class_total = sum(len(group_rows) for _, group_rows in class_groups)
        targets = [class_total * ratio for ratio in ratios]
        assigned = [0, 0, 0]
        for _, group_rows in sorted(class_groups, key=lambda item: len(item[1]), reverse=True):
            split_index = min(
                range(3),
                key=lambda index: (assigned[index] + len(group_rows)) / max(targets[index], 1),
            )
            for row in group_rows:
                row["split"] = SPLIT_NAMES[split_index]
            assigned[split_index] += len(group_rows)


def build_summary(rows: list[dict[str, str]], classes: list[str], seed: int, ratios: tuple[float, float, float]) -> dict[str, object]:
    split_rows = {split: [row for row in rows if row["split"] == split] for split in SPLIT_NAMES}
    split_groups = {split: {row["group_id"] for row in split_rows[split]} for split in SPLIT_NAMES}
    overlaps = {
        f"{left}_and_{right}": sorted(split_groups[left] & split_groups[right])
        for index, left in enumerate(SPLIT_NAMES)
        for right in SPLIT_NAMES[index + 1 :]
    }
    per_class = {
        class_name: {
            split: sum(row["class_name"] == class_name for row in split_rows[split])
            for split in SPLIT_NAMES
        }
        for class_name in classes
    }
    return {
        "approved_classes": classes,
        "seed": seed,
        "ratios": dict(zip(SPLIT_NAMES, ratios)),
        "total_selected_images": len(rows),
        "images_per_split": {split: len(split_rows[split]) for split in SPLIT_NAMES},
        "unique_groups_per_split": {split: len(split_groups[split]) for split in SPLIT_NAMES},
        "per_class_counts": per_class,
        "group_overlap": {name: values for name, values in overlaps.items()},
        "zero_group_overlap": not any(overlaps.values()),
        "special_handling": [
            "Potato___healthy has 152 images; monitor validation/test sample counts and use stratified metrics during training."
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--classes", nargs="+", help="Reviewed class names to include")
    parser.add_argument("--classes-file", type=Path, help="Approved JSON file containing a classes list")
    parser.add_argument("--approve-selection", action="store_true")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--train-ratio", type=float, default=0.70)
    parser.add_argument("--validation-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    parser.add_argument("--allow-unknown-groups", action="store_true")
    parser.add_argument("--cache-dir", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[2] / "dataset" / "processed" / "manifest.csv")
    args = parser.parse_args()
    classes = args.classes
    if args.classes_file:
        approval = json.loads(args.classes_file.read_text(encoding="utf-8"))
        classes = approval.get("classes")
    if not args.approve_selection or not classes:
        print("Refusing to create split assignments: review analysis and pass --approve-selection with --classes.")
        return 2
    ratios = (args.train_ratio, args.validation_ratio, args.test_ratio)
    if any(ratio <= 0 for ratio in ratios) or abs(sum(ratios) - 1.0) > 1e-6:
        print("Split ratios must be positive and sum to 1.0.", file=sys.stderr)
        return 2
    dataset = load_plantvillage(args.cache_dir or raw_cache_dir())
    selected = set(classes)
    label_names = dataset[next(iter(dataset))].features["label"].names
    rows: list[dict[str, str]] = []
    for split in dataset.values():
        for item in split:
            label_value = item["label"]
            class_name = label_names[label_value] if isinstance(label_value, int) else str(label_value)
            if class_name not in selected:
                continue
            group_id = str(item.get("leaf_id", ""))
            if not group_id or group_id == "unknown":
                if not args.allow_unknown_groups:
                    raise RuntimeError("Selected data contains unknown leaf IDs; refusing an unsafe split.")
                group_id = f"unknown:{item['image_path']}"
            rows.append({"image_path": str(item["image_path"]), "crop": str(item["crop"]), "disease": str(item["disease"]), "class_name": class_name, "group_id": group_id, "split": ""})
    if not rows:
        raise RuntimeError("No images matched the reviewed class selection.")
    assign_groups(rows, ratios, args.seed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "crop", "disease", "class_name", "group_id", "split"])
        writer.writeheader()
        writer.writerows(rows)
    summary_path = args.output.with_name("split_summary.json")
    summary_path.write_text(json.dumps(build_summary(rows, sorted(selected), args.seed, ratios), indent=2), encoding="utf-8")
    print(f"Wrote {len(rows):,} manifest rows to {args.output.resolve()}")
    print(f"Wrote split audit to {summary_path.resolve()}")
    print("All rows sharing a group_id receive the same split; no images are modified.")
    summary = build_summary(rows, sorted(selected), args.seed, ratios)
    print(f"Images per split: {summary['images_per_split']}")
    print(f"Unique groups per split: {summary['unique_groups_per_split']}")
    print(f"Zero group overlap: {summary['zero_group_overlap']}")
    for class_name, counts in summary["per_class_counts"].items():
        print(f"  {class_name}: {counts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())