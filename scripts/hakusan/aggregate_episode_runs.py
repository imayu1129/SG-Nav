#!/usr/bin/env python3
import argparse
import ast
from pathlib import Path


def read_rows(path: Path):
    rows = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if line:
            rows.append(ast.literal_eval(line))
    return rows


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
        path = Path(raw_path)
        results_file = path / "results.txt" if path.is_dir() else path
        rows = read_rows(results_file)
        print(f"[{results_file}] episodes={len(rows)}")
        for row in rows:
            for key, value in row.items():
                if isinstance(value, (int, float)):
                    totals[key] = totals.get(key, 0.0) + float(value)
        total_rows += len(rows)

    if total_rows == 0:
        raise SystemExit("No result rows were found.")

    print()
    print(f"total_episodes={total_rows}")
    print("weighted_average:")
    for key in sorted(totals):
        avg = totals[key] / total_rows
        if key in {"success", "spl", "softspl"}:
            print(f"  {key}: {avg:.6f} ({avg * 100:.2f}%)")
        else:
            print(f"  {key}: {avg:.6f}")


if __name__ == "__main__":
    main()
