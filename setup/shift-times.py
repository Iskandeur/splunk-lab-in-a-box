#!/usr/bin/env python3
"""Shift the Splunk tutorial dataset forward so it ends today.

Why this exists: the official archive (docs.splunk.com/images/Tutorial/tutorialdata.zip)
is regenerated periodically, but its events already stop ~2 days before you download it.
"Today" and "Last 24 hours" therefore return ZERO, which makes the entire
"Working with Time" lab impossible and quietly breaks half the exercises.

The shift is a whole number of DAYS, which preserves the hour-of-day distribution
(so timecharts still look like real traffic) and never produces events in the future.
Side effect to know about: weekday names move with the shift, so any conclusion about
"the busiest day of the week" is an artifact — the labs say so explicitly.

Usage: shift-times.py <source-dir> <output-dir>
"""
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

APACHE = re.compile(r"\[(\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2})\]")
SECURE = re.compile(r"^([A-Za-z]{3} [A-Za-z]{3} \d{2} \d{4} \d{2}:\d{2}:\d{2})")
AP_FMT, SEC_FMT = "%d/%b/%Y:%H:%M:%S", "%a %b %d %Y %H:%M:%S"


def parse(line):
    """Return (timestamp, format-key, match) for the two timestamp shapes in the dataset."""
    m = APACHE.search(line)
    if m:
        return datetime.strptime(m.group(1), AP_FMT), "apache", m
    m = SECURE.match(line)
    if m:
        return datetime.strptime(m.group(1), SEC_FMT), "secure", m
    return None, None, None


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    files = sorted(p for p in src.rglob("*.log") if p.is_file())
    if not files:
        sys.exit(f"no .log files under {src}")

    # Pass 1: find the newest event across the whole dataset.
    newest, total, unparsed = None, 0, 0
    for f in files:
        for line in f.open(errors="replace"):
            total += 1
            ts, _, _ = parse(line)
            if ts is None:
                unparsed += 1
                continue
            if newest is None or ts > newest:
                newest = ts
    print(f"{len(files)} files, {total} lines, {unparsed} without a recognised timestamp")
    print(f"newest event: {newest}")

    days = (datetime.now() - newest).days  # floor -> never shifts into the future
    delta = timedelta(days=days)
    if days < 1:
        # The archive is occasionally regenerated the same day you fetch it. Copy the
        # files through unchanged so the caller always finds the same output layout.
        print("dataset is already current (shift < 1 day) — copying through unchanged")
    else:
        print(f"shifting by +{days} day(s) -> newest event becomes {newest + delta}")

    # Pass 2: rewrite. strftime recomputes weekday names for the secure.log format.
    written = 0
    for f in files:
        out = dst / f.relative_to(src)
        out.parent.mkdir(parents=True, exist_ok=True)
        with f.open(errors="replace") as fi, out.open("w") as fo:
            for line in fi:
                ts, kind, m = parse(line)
                if ts is None:
                    fo.write(line)
                    continue
                new = (ts + delta).strftime(AP_FMT if kind == "apache" else SEC_FMT)
                fo.write(line[:m.start(1)] + new + line[m.end(1):])
                written += 1
    print(f"{written} lines rewritten under {dst}")


if __name__ == "__main__":
    main()
