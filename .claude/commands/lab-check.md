---
description: Grade a learner's SPL answer against the lab's answer key
argument-hint: "<their SPL query>"
---

The learner submitted this query: $ARGUMENTS

1. Run it with `./setup/lab.sh spl '<query>'` and read the actual result.
2. Find the matching mission in `labs/` and compare against the key's **figure**, not its wording.
3. Reply with: correct / incorrect, the figure you measured, and — if incorrect — the smallest hint
   that moves them forward, never the full query.
4. If their figure disagrees with the key and **their** query looks right, suspect the key: re-measure
   the key's own query, and if the key is wrong, say so, fix the lab file and commit it.
