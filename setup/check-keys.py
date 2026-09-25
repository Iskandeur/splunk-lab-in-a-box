#!/usr/bin/env python3
"""Re-verify every answer key in labs/manifest.json against the running lab.

This exists because the answer keys of these labs were wrong eight times during their
first run, every time because a behaviour had been recalled instead of measured. Run it
after editing a lab, after a Splunk upgrade, or whenever the vendor regenerates the
tutorial archive:

    ./setup/check-keys.py            # all labs
    ./setup/check-keys.py 05 08      # only those labs

Missions of lab 05 need the lookup *definitions* that the learner is meant to create.
This script creates them temporarily and removes the ones it created, so it never does
the exercise for anybody.
"""
import json
import os
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
LOOKUPS = {"prices_lookup": "prices.csv", "http_status_lookup": "http_status.csv"}


def env_file():
    # Same resolution as setup/lab.sh: LAB_STATE_DIR (plugin install) unless a clone's .env exists.
    state = os.environ.get("LAB_STATE_DIR")
    if state and (pathlib.Path(state) / ".env").is_file():
        return pathlib.Path(state) / ".env"
    return HERE / ".env"


def env():
    values = {}
    for line in env_file().read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            values[k] = v
    return values


def curl(cfg, method, path, *args):
    cmd = ["docker", "exec", "-u", "splunk", cfg.get("LAB_CONTAINER", "splunk-lab"),
           "curl", "-s", "-k", "-u", f"admin:{cfg['SPLUNK_PASSWORD']}", "-X", method,
           f"https://localhost:8089{path}", *args]
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def spl(query):
    return subprocess.run([str(HERE / "lab.sh"), "spl", query],
                          capture_output=True, text=True, cwd=ROOT).stdout


def main():
    wanted = sys.argv[1:]
    manifest = json.loads((ROOT / "labs" / "manifest.json").read_text())
    cfg = env()

    existing = curl(cfg, "GET", "/servicesNS/nobody/search/data/transforms/lookups?count=0&output_mode=json")
    created = []
    for name, filename in LOOKUPS.items():
        if f'"{name}"' not in existing:
            curl(cfg, "POST", "/servicesNS/nobody/search/data/transforms/lookups",
                 "-d", f"name={name}", "-d", f"filename={filename}")
            created.append(name)
    if created:
        print(f"(temporarily created: {', '.join(created)})\n")

    ok = fail = manual = 0
    try:
        for lab in manifest["labs"]:
            if wanted and not any(lab["id"].startswith(w) for w in wanted):
                continue
            for mission in lab["missions"]:
                if "spl" not in mission:
                    manual += 1
                    continue
                out = spl(mission["spl"])
                tokens = set(re.findall(r"[\w.\-]+", out))
                expected = [t for t in re.findall(r"[\w.\-]+", mission["expect"].split("(")[0])
                            if t not in ("and", "NO", "out", "of")]
                missing = [e for e in expected if e not in tokens]
                if missing:
                    fail += 1
                    print(f"  FAIL {lab['id']:<30} {mission['id']:<4} missing {missing}")
                    for line in out.strip().splitlines()[:4]:
                        print(f"       {line.strip()}")
                else:
                    ok += 1
                    print(f"  ok   {lab['id']:<30} {mission['id']:<4} {mission['expect'][:60]}")
    finally:
        for name in created:
            curl(cfg, "DELETE", f"/servicesNS/nobody/search/data/transforms/lookups/{name}")
        if created:
            print(f"\n(removed again: {', '.join(created)} — creating them is lab 05, M1)")

    print(f"\n{ok} verified, {fail} failed, {manual} manual-only")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
