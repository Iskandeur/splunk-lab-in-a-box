---
description: Report the lab's health and the learner's progress
---

Paths for this install (Claude Code substitutes them): the lab script is
`LAB_STATE_DIR="${CLAUDE_PLUGIN_DATA}" "${CLAUDE_PLUGIN_ROOT}/setup/lab.sh"` (written `lab.sh`
below), progress is `${CLAUDE_PLUGIN_DATA}/lab-progress.json`.

Run `lab.sh status --json`, then `lab.sh verify`, then read the progress file.

Report, in at most five lines: whether the lab is usable right now, how old the data is, which labs
are done, and what you suggest next. If a verify check fails, name the failing check and the fix from
`${CLAUDE_PLUGIN_ROOT}/docs/troubleshooting.md` — do not improvise a repair.
