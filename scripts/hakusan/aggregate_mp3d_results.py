#!/usr/bin/env python3
import argparse
import ast
import gzip
import json
from pathlib import Path


def read_dict_lines(path: Path):
    rows = []
    if not path.exists():
        return rows
    for line in path.read_text().splitlines():
        line = line.strip()
        if line:
            rows.append(ast.literal_eval(line))
    return rows


def count_expected_episodes(episodes_root: Path, split_l: int, split_r: int):
    if not episodes_root.exists():
        return None
    files = sorted(episodes_root.glob("*.json.gz"))
    if split_l >= len(files):
        return None
    expected = 0
    for path in files[split_l:split_r]:
        with gzip.open(path, "rt") as handle:
            expected += len(json.load(handle).get("episodes", []))
    return expected


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate SG-Nav MP3D split metrics from data/results/experiment_0/[l:r]."
    )
    parser.add_argument(
        "--results-root",
        default="assets/data/results/experiment_0",
        help="Host-side results root on Hakusan.",
    )
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--end", type=int, default=11)
    parser.add_argument(
        "--episodes-root",
        default="assets/data/MatterPort3D/objectnav/mp3d/v1/val/content",
        help="Host-side ObjectNav content directory used to detect incomplete split results.",
    )
    args = parser.parse_args()

    root = Path(args.results_root)
    episodes_root = Path(args.episodes_root)
    totals = {}
    total_episodes = 0
    found = []
    missing = []
    incomplete = []

    for split_l in range(args.start, args.end):
        split_r = split_l + 1
        split_dir = root / f"[{split_l}:{split_r}]"
        result_rows = read_dict_lines(split_dir / "results.txt")
        avg_rows = read_dict_lines(split_dir / "results_avg.txt")
        if not result_rows:
            missing.append(f"[{split_l}:{split_r}]")
            continue

        expected = count_expected_episodes(episodes_root, split_l, split_r)
        if expected is not None and len(result_rows) != expected:
            incomplete.append(f"[{split_l}:{split_r}] {len(result_rows)}/{expected}")

        found.append((split_l, split_r, len(result_rows)))
        for row in result_rows:
            for key, value in row.items():
                if isinstance(value, (int, float)):
                    totals[key] = totals.get(key, 0.0) + float(value)
        total_episodes += len(result_rows)

        final_avg = avg_rows[-1] if avg_rows else {}
        compact = ", ".join(
            f"{name}={final_avg[name]:.4f}"
            for name in ("distance_to_goal", "success", "spl")
            if name in final_avg
        )
        expected_suffix = f"/{expected}" if expected is not None else ""
        print(f"[split {split_l}:{split_r}] episodes={len(result_rows)}{expected_suffix} {compact}")

    print()
    print(
        f"found_splits={len(found)} missing_splits={len(missing)} "
        f"incomplete_splits={len(incomplete)} total_result_rows={total_episodes}"
    )
    if missing:
        print("missing:", ", ".join(missing))
    if incomplete:
        print("incomplete:", "; ".join(incomplete))
        print("NOTE: weighted_average below includes incomplete split rows.")

    if total_episodes == 0:
        raise SystemExit("No result rows were found.")

    print("weighted_average:")
    for key in sorted(totals):
        avg = totals[key] / total_episodes
        if key in {"success", "spl", "softspl"}:
            print(f"  {key}: {avg:.6f} ({avg * 100:.2f}%)")
        else:
            print(f"  {key}: {avg:.6f}")


if __name__ == "__main__":
    main()
