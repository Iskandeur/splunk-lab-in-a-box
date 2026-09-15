---
description: Report the lab's health and the learner's progress
---

Run `./setup/lab.sh status --json`, then `./setup/lab.sh verify`, then read `.lab-progress.json`.

Report, in at most five lines: whether the lab is usable right now, how old the data is, which labs
are done, and what you suggest next. If a verify check fails, name the failing check and the fix from
`docs/troubleshooting.md` — do not improvise a repair.
