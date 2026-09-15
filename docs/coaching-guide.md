# Coaching guide

How to teach with these labs — whether you are an agent following `CLAUDE.md`, or a human running a
session for a colleague. Every rule here was extracted from a real run in which the learner was
better served after the rule than before it.

## 1. Ask for a result, never a keystroke

"Run this command and see what happens" trains recognition. "The sales director wants to know which
product earns the most" trains production, and only production survives contact with a job where
nobody hands you the syntax.

The mission shape, used throughout labs 04 and 05:

1. **the request**, phrased as a person would phrase it;
2. **the deliverable** — the *shape* of the answer (a number, a top 5, a three-column table). It
   frames the work without revealing the path;
3. **a hint**, set aside, naming the *family* of tool ("a subsearch in square brackets") and never
   the line;
4. **the key**, with the query **and the figure**, plus the sentence that matters: *if your figure
   matches, your query is right even if it looks nothing like mine*.

## 2. Grade on the number

SPL has ten ways to write anything. Correcting a style the learner did not ask about turns them into
a copier. Grade the result; mention an alternative form only when it teaches something they will
reuse — `sort 5 -revenue` instead of `| sort -revenue | head 5` is worth a sentence, renaming their
variables is not.

## 3. Verify before asserting

You have an instance and an admin account. `./setup/lab.sh spl '<search>'` costs two seconds. The
answer keys in this repository were corrected **eight times** during their first run, every time
because a behaviour had been recalled instead of measured, and every time the correction came from a
learner's answer rather than from a re-reading.

Corollary: an exercise that cannot fail teaches the teacher nothing either.

## 4. Investigate before asking the learner to investigate

When their result and yours disagree, the first move is to fetch **their** artifact with your own
access — their job's `search.log`, the job list, the index, the config. Ask them only for what exists
solely on their screen: what they clicked, what the UI rendered, a constraint of their machine.

Asking a learner to gather evidence you could gather yourself looks like rigour and is a transfer of
work. In the run that produced this repo, the log the learner was asked to paste contained the
refutation of what the teacher was teaching.

## 5. Derive every formula you introduce

If you write `sqrt(p(1-p)/n)`, show where it comes from: a binomial count, then a division by `n`.
A learner handed a formula has learned to trust you. A learner shown its origin can rederive it, and
can tell when it does not apply — which, for that particular formula, is most of the time, because
web requests are not independent draws.

## 6. Correct yourself out loud, and fix the file

When a learner's answer contradicts a key, say so plainly, measure, fix the file, commit. Their
finding is worth more than your authority, and a lab that silently carries a wrong key wastes the
next person's evening.

## 7. Watch the two failure modes of the lab itself

- **Stale data.** The relative ranges go quiet as the dataset ages; `data_age_hours` in
  `./setup/lab.sh status --json` tells you before the learner is confused.
- **A silent half-success.** `./setup/lab.sh verify` exists because "the data is there" and "the data
  is usable for the exercise the learner is about to do" are two different propositions, and the
  first one is the easy one to check by accident.

## 8. Pace

Labs 00–03 are 20–25 minutes each, 04 and 05 about 30. A learner who has done 00 to 03 in one sitting
has absorbed enough; 04 is the one that pays off at work, and 05 is the one that separates an analyst
from a query writer. If time is short, skip 05's exercises but read its answer key aloud — it is
written to be readable on its own.
