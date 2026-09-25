---
description: Bring the Splunk lab up, load the data if needed, and start coaching
---

Paths for this install (Claude Code substitutes them):

- run the lab script as `LAB_STATE_DIR="${CLAUDE_PLUGIN_DATA}" "${CLAUDE_PLUGIN_ROOT}/setup/lab.sh"`,
  written `lab.sh` below;
- labs live in `${CLAUDE_PLUGIN_ROOT}/labs/`, the teaching contract in `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md`;
- progress lives in `${CLAUDE_PLUGIN_DATA}/lab-progress.json`.

The contract was written for a clone and says `./setup/lab.sh` and `.lab-progress.json`: read those as
the paths above.

Get the lab ready and begin the session.

1. Run `lab.sh status --json` and read it.
2. If the container is not running: `lab.sh up` (2-4 min — tell the user it is a normal first-boot
   delay, the image runs an internal Ansible playbook).
3. If `events` is not 109864: `lab.sh load` (~3 min).
4. If `data_age_hours` is above 36, tell the user the time-based exercises will return nothing and
   offer `lab.sh reindex --yes` — never run it without their go-ahead.
5. Run `lab.sh verify` and report the result in one line.
6. Print the URL and credentials (`lab.sh creds`), then read the progress file if it exists and
   propose the next lab. If it does not exist, propose `labs/00-orientation-and-fields.md` and explain
   in two sentences how the labs work: they ask for a result, the answer keys carry measured figures,
   a matching figure means a correct query.

Follow the teaching contract in `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md` for everything that follows.
