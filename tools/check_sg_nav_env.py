#!/usr/bin/env python
"""Lightweight SG-Nav reproduction environment checks."""

import gzip
import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = ROOT / "data" / "MatterPort3D"
EPISODE_FILE = DATA_ROOT / "objectnav" / "mp3d" / "v1" / "val" / "val.json.gz"


def require_path(path: Path, label: str) -> None:
    if not path.exists():
        raise FileNotFoundError(f"{label} is missing: {path}")
    print(f"[ok] {label}: {path.relative_to(ROOT)}")


def main() -> None:
    print(f"repo: {ROOT}")

    require_path(DATA_ROOT / "mp3d", "Matterport3D scenes directory")
    require_path(EPISODE_FILE, "ObjectNav val episode file")

    scene_files = sorted((DATA_ROOT / "mp3d").glob("*/*.glb"))
    if not scene_files:
        raise FileNotFoundError("No .glb scene files were found under data/MatterPort3D/mp3d")
    print(f"[ok] scene count: {len(scene_files)}")

    with gzip.open(EPISODE_FILE, "rt", encoding="utf-8") as f:
        split_episodes = json.load(f).get("episodes", [])
    content_files = sorted(EPISODE_FILE.parent.glob("content/*.json.gz"))
    episode_count = len(split_episodes)
    for content_file in content_files:
        with gzip.open(content_file, "rt", encoding="utf-8") as f:
            episode_count += len(json.load(f).get("episodes", []))
    if episode_count == 0:
        raise RuntimeError(f"No episodes were found under {EPISODE_FILE.parent}")
    print(f"[ok] episode count: {episode_count} across {len(content_files)} content files")

    import torch
    import habitat
    import habitat_sim
    import faiss
    import pytorch3d
    import segment_anything
    import groundingdino
    import maskrcnn_benchmark

    print(f"[ok] torch: {torch.__version__}, cuda_available={torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"[ok] gpu: {torch.cuda.get_device_name(0)}")
    print(f"[ok] habitat: {habitat.__version__}")
    print(f"[ok] habitat_sim: {habitat_sim.__version__}")
    print(f"[ok] faiss: {faiss.__version__}, gpu_count={faiss.get_num_gpus()}")
    print(f"[ok] pytorch3d: {pytorch3d.__version__}")
    print(f"[ok] segment_anything: {Path(segment_anything.__file__).resolve().relative_to(ROOT)}")
    print(f"[ok] groundingdino: {Path(groundingdino.__file__).resolve().relative_to(ROOT)}")
    print(f"[ok] GLIP maskrcnn_benchmark: {Path(maskrcnn_benchmark.__file__).resolve().relative_to(ROOT)}")

    for model_path in [
        ROOT / "data" / "models" / "sam_vit_h_4b8939.pth",
        ROOT / "data" / "models" / "groundingdino_swint_ogc.pth",
        ROOT / "GLIP" / "MODEL" / "glip_large_model.pth",
    ]:
        require_path(model_path, "model checkpoint")

    if os.system(f"curl -fsS http://{os.environ.get('OLLAMA_HOST', '127.0.0.1:11434')}/api/tags >/dev/null 2>&1") == 0:
        print("[ok] Ollama server is reachable")
    else:
        print("[warn] Ollama server is not reachable; run ./run_sg_nav.sh to auto-start the local server")


if __name__ == "__main__":
    main()
