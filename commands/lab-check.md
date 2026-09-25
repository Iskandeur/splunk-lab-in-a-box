---
description: Grade a learner's SPL answer against the lab's answer key
argument-hint: "<their SPL query>"
---

Paths for this install (Claude Code substitutes them): the lab script is
`LAB_STATE_DIR="${CLAUDE_PLUGIN_DATA}" "${CLAUDE_PLUGIN_ROOT}/setup/lab.sh"` (written `lab.sh`
below), labs are in `${CLAUDE_PLUGIN_ROOT}/labs/`.

The learner submitted this query: $ARGUMENTS

1. Run it with `lab.sh spl '<query>'` and read the actual result.
2. Find the matching mission in the labs and compare against the key's **figure**, not its wording.
3. Reply with: correct / incorrect, the figure you measured, and — if incorrect — the smallest hint
   that moves them forward, never the full query.
4. If their figure disagrees with the key and **their** query looks right, suspect the key: re-measure
   the key's own query, and if the key is wrong, say so and suggest opening an issue on
   https://github.com/Iskandeur/splunk-lab-in-a-box with both figures.
