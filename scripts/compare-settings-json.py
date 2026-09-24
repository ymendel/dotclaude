#!/usr/bin/env python3
"""Compare HEAD:settings.json against the working copy as parsed data.

Claude Usage.app rewrites the installed statusline scripts on every launch, and
its Apply path rewrites settings.json — reordering keys and stripping the blank
lines that group the permission arrays. The result is a diff of tens of lines
for a change of two or three actual settings, which no reading by eye separates.

This answers the one question that decides what to do about it: was anything
added, dropped, or altered, or is the whole diff presentational? Cosmetic-only
means the file can be restored from HEAD and any intentional edit re-applied by
hand.

Empty output under every heading means no semantic change.

    ./scripts/compare-settings-json.py
"""

import json
import subprocess
import sys


def flatten(node, prefix=""):
    """Leaf paths -> (kind, value).

    Lists of scalars become a single SET leaf, because order in the permission
    arrays is presentational: `settings.md` keeps them grouped for human
    scanning and records that any reformatter will strip the grouping. A list
    holding dicts or lists is indexed instead, since position carries meaning
    there (hook matchers, for one).
    """
    leaves = {}
    if isinstance(node, dict):
        for key, value in node.items():
            leaves.update(flatten(value, f"{prefix}.{key}" if prefix else key))
    elif isinstance(node, list):
        if all(not isinstance(item, (dict, list)) for item in node):
            leaves[prefix] = ("SET", frozenset(node))
        else:
            for index, item in enumerate(node):
                leaves.update(flatten(item, f"{prefix}[{index}]"))
    else:
        leaves[prefix] = ("VALUE", node)
    return leaves


def compare(head, work):
    """Semantic differences between two parsed settings documents.

    Returns (added, dropped, changed): two sorted path lists, and a list of
    (path, kind, head_value, work_value) for paths present on both sides whose
    value moved. A SET's values are the sorted members unique to each side, so
    a reordered array reports nothing at all.
    """
    head_leaves, work_leaves = flatten(head), flatten(work)

    added = sorted(set(work_leaves) - set(head_leaves))
    dropped = sorted(set(head_leaves) - set(work_leaves))

    changed = []
    for path in sorted(set(head_leaves) & set(work_leaves)):
        kind, head_value = head_leaves[path]
        _, work_value = work_leaves[path]
        if head_value == work_value:
            continue
        if kind == "SET":
            changed.append((path, kind,
                            sorted(head_value - work_value),
                            sorted(work_value - head_value)))
        else:
            changed.append((path, kind, head_value, work_value))
    return added, dropped, changed


def main():
    head = json.loads(subprocess.run(
        ["git", "show", "HEAD:settings.json"],
        capture_output=True, check=True).stdout)
    with open("settings.json") as handle:
        work = json.load(handle)

    added, dropped, changed = compare(head, work)

    print("PATHS ONLY IN WORKING COPY:", added or "none")
    print("PATHS ONLY IN HEAD:", dropped or "none")
    print()
    print("VALUE DIFFERENCES ON SHARED PATHS:")
    for path, kind, head_value, work_value in changed:
        if kind == "SET":
            print(f"  {path}:")
            print(f"      added:   {work_value or 'none'}")
            print(f"      removed: {head_value or 'none'}")
        else:
            print(f"  {path}: {head_value!r} -> {work_value!r}")


if __name__ == "__main__":
    sys.exit(main())
