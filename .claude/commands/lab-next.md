---
description: Start the next lab and coach through it
---

Read `.lab-progress.json` to find where the learner stopped, then open the next lab file under
`labs/`.

Present it the way the teaching contract in CLAUDE.md requires:

- summarise the **concepts** section in your own words, briefly, and answer questions about it — the
  learner should never need to watch a vendor video;
- give them the missions **one at a time**, and wait for their answer;
- when they answer, verify it yourself with `./setup/lab.sh spl '<their query>'` and compare against
  the key's figure. If the figure matches, say the query is correct even if it differs from yours;
- if they are stuck, give the hint, then the next hint, then the family of tool. Give the query
  itself only if they ask for it twice.

Update `.lab-progress.json` when the lab is finished.
