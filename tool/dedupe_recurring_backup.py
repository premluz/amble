#!/usr/bin/env python3
"""One-off repair for the duplicate-recurring-series bug.

Reads an Amble backup export, removes the stranded parallel generations a
recurring series accumulated, and writes a repaired copy. Never edits the
input file in place.

WHY THIS EXISTS
---------------
Changing a recurring task's time of day used to re-materialize the whole
8-week window at the new time WITHOUT removing the old generation, because
the generator matched occupancy on exact `DateTime`s (see
docs/ERROR_LOG.md). Each time edit therefore left a complete parallel
series behind under the same `recurrenceId`. The app-launch top-up
(`materializeDueRecurrences`) then refilled the window again on every
restart. The code path is fixed; this repairs data that already drifted.

WHAT IT KEEPS
-------------
For each (recurrenceId, calendar day) group holding more than one row, one
row survives, chosen in this order:

  1. `completed` / `skipped` — real history, never discarded.
  2. A genuinely moved row (`originalScheduledAt` set and different from
     `scheduledAt`) — a deliberate act on that specific day.
  3. Otherwise, the row whose time-of-day matches the series template's
     current anchor — the generation the series actually belongs at.
  4. Failing all of the above, the earliest row of the day.

Rows outside any duplicate group are copied through untouched. Tasks with
no `recurrenceId`, or with no `scheduledAt`, are never candidates.

USAGE
-----
    python3 tool/dedupe_recurring_backup.py <backup.json>            # report only
    python3 tool/dedupe_recurring_backup.py <backup.json> --write    # write repaired copy

The repaired file is written next to the input as
`<name>-deduped.json`, which can then be imported through Settings.
"""

import argparse
import json
import sys
from collections import defaultdict


def day_of(iso):
    """The calendar day part of an ISO timestamp, or None."""
    return iso[:10] if iso else None


def time_of(iso):
    """The HH:MM part of an ISO timestamp, or None."""
    return iso[11:16] if iso else None


def pick_survivor(rows, anchor_time):
    """Choose which of several same-day rows to keep. See module docstring."""
    history = [r for r in rows if r.get("status") in ("completed", "skipped")]
    if history:
        # Earliest, so the choice is deterministic if somehow several.
        return min(history, key=lambda r: r["scheduledAt"])

    moved = [
        r
        for r in rows
        if r.get("originalScheduledAt")
        and r["originalScheduledAt"] != r["scheduledAt"]
    ]
    if moved:
        return min(moved, key=lambda r: r["scheduledAt"])

    if anchor_time:
        on_anchor = [r for r in rows if time_of(r["scheduledAt"]) == anchor_time]
        if on_anchor:
            return min(on_anchor, key=lambda r: r["scheduledAt"])

    return min(rows, key=lambda r: r["scheduledAt"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", help="path to the exported backup .json")
    parser.add_argument(
        "--write",
        action="store_true",
        help="write the repaired copy (default is a dry-run report)",
    )
    args = parser.parse_args()

    with open(args.backup) as handle:
        data = json.load(handle)

    tasks = data.get("tasks", [])

    # The template of each series carries the rule; its time of day is the
    # anchor the series is meant to sit at.
    anchor_time_by_series = {}
    for task in tasks:
        if task.get("recurrenceRule") and task.get("recurrenceId"):
            anchor_time_by_series[task["recurrenceId"]] = time_of(
                task.get("scheduledAt")
            )

    groups = defaultdict(list)
    for task in tasks:
        series = task.get("recurrenceId")
        day = day_of(task.get("scheduledAt"))
        if series and day:
            groups[(series, day)].append(task)

    drop_ids = set()
    for (series, _day), rows in groups.items():
        if len(rows) < 2:
            continue
        survivor = pick_survivor(rows, anchor_time_by_series.get(series))
        for row in rows:
            if row["id"] != survivor["id"]:
                drop_ids.add(row["id"])

    duplicate_groups = sum(1 for rows in groups.values() if len(rows) > 1)
    print(f"tasks in backup:        {len(tasks)}")
    print(f"duplicate day-groups:   {duplicate_groups}")
    print(f"rows to remove:         {len(drop_ids)}")
    print(f"tasks after repair:     {len(tasks) - len(drop_ids)}")

    by_series = defaultdict(int)
    for task in tasks:
        if task["id"] in drop_ids:
            by_series[(task.get("recurrenceId"), task.get("title"))] += 1
    if by_series:
        print("\nremoved per series:")
        for (series, title), count in sorted(
            by_series.items(), key=lambda item: -item[1]
        ):
            print(f"  {title!r:24} {str(series)[:8]}  -{count}")

    if not args.write:
        print("\nDry run — nothing written. Re-run with --write to save.")
        return 0

    data["tasks"] = [task for task in tasks if task["id"] not in drop_ids]
    out = args.backup.replace(".json", "") + "-deduped.json"
    with open(out, "w") as handle:
        json.dump(data, handle, indent=2)
    print(f"\nWrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
