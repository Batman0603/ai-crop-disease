"""Download the official color PlantVillage dataset into the ML cache."""

from __future__ import annotations

import argparse
import os
import signal
import sys
from pathlib import Path

from datasets import DatasetDict, load_dataset
from huggingface_hub import hf_hub_download

DATASET_ID = "mohanty/PlantVillage"
CONFIG = "color"


def project_root() -> Path:
    return Path(__file__).resolve().parents[3]


def raw_cache_dir() -> Path:
    return project_root() / "ml" / "dataset" / "raw" / "huggingface"


def _allow_remote_code_on_windows() -> None:
    if os.name == "nt" and not hasattr(signal, "SIGALRM"):
        signal.SIGALRM = signal.SIGINT  # type: ignore[attr-defined]
        signal.alarm = lambda _seconds: None  # type: ignore[attr-defined]


def load_plantvillage(cache_dir: Path | None = None) -> DatasetDict:
    cache_dir = cache_dir or raw_cache_dir()
    cache_dir.mkdir(parents=True, exist_ok=True)
    _allow_remote_code_on_windows()
    loader_path = hf_hub_download(
        DATASET_ID,
        "plant_village.py",
        repo_type="dataset",
        cache_dir=str(cache_dir),
    )
    return load_dataset(
        loader_path,
        "default",
        cache_dir=str(cache_dir),
        trust_remote_code=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, default=None)
    args = parser.parse_args()
    cache_dir = (args.cache_dir or raw_cache_dir()).resolve()
    print(f"Loading {DATASET_ID} ({CONFIG}) with the official Hugging Face loader...")
    print(f"Cache directory: {cache_dir}")
    try:
        dataset = load_plantvillage(cache_dir)
    except Exception as error:
        print(f"PlantVillage download/load failed: {error}", file=sys.stderr)
        print("Check network access and rerun; the source dataset is not modified.", file=sys.stderr)
        return 1
    print(f"Loaded splits: {', '.join(dataset.keys())}")
    for split_name, split in dataset.items():
        print(f"  {split_name}: {len(split):,} examples")
    print(f"Dataset cache is stored at: {cache_dir}")
    print("Rerunning this command reuses the Hugging Face cache when unchanged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())