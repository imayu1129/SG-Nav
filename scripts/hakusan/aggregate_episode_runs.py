#!/usr/bin/env python3
import argparse
import ast
import glob
from pathlib import Path


def read_rows(path: Path):
    rows = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if line:
            rows.append(ast.literal_eval(line))
    return rows


def resolve_results_files(raw_path: str):
    path = Path(raw_path)
    if path.is_dir():
        direct = path / "results.txt"
        if direct.exists():
            return [direct]
        return sorted(path.glob("**/results.txt"))
    if path.exists():
        return [path]

    matches = [Path(match) for match in sorted(glob.glob(raw_path))]
    files = []
    for match in matches:
        if match.is_dir() and (match / "results.txt").exists():
            files.append(match / "results.txt")
        elif match.name == "results.txt":
            files.append(match)
    return files


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate one or more SG-Nav results.txt files."
    )
    parser.add_argument(
        "paths",
        nargs="+",
        help="Result directories or results.txt files.",
    )
    args = parser.parse_args()

    totals = {}
    total_rows = 0
    for raw_path in args.paths:
        results_files = resolve_results_files(raw_path)
        if not results_files:
            print(f"[missing] {raw_path}")
            continue
        for results_file in results_files:
            rows = read_rows(results_file)
            print(f"[{results_file}] episodes={len(rows)}")
            for row in rows:
                for key, value in row.items():
                    if isinstance(value, (int, float)):
                        totals[key] = totals.get(key, 0.0) + float(value)
            total_rows += len(rows)

    if total_rows == 0:
        raise SystemExit(
            "No result rows were found. Try: "
            "scripts/hakusan/aggregate_episode_runs.py assets/data/results/experiment_0"
        )

    print()
    print(f"total_episodes={total_rows}")
    print("weighted_average:")
    averages = {}
    for key in sorted(totals):
        avg = totals[key] / total_rows
        averages[key] = avg
        if key in {"success", "spl", "softspl"}:
            print(f"  {key}: {avg:.6f} ({avg * 100:.2f}%)")
        else:
            print(f"  {key}: {avg:.6f}")

    print()
    print("report:")
    if "success" in averages:
        print(f"  SR: {averages['success'] * 100:.1f}%")
    if "spl" in averages:
        print(f"  SPL: {averages['spl'] * 100:.1f}%")
    if "distance_to_goal" in averages:
        print(f"  Distance-to-goal: {averages['distance_to_goal']:.3f}")


if __name__ == "__main__":
    main()
