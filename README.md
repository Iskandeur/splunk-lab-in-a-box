# splunk-lab-in-a-box

A complete, self-hosted Splunk lab: one container, the official *Buttercup Games* tutorial dataset
(109 864 events), and **six labs that replace the vendor's video courses**. Every answer key is a
figure measured on the running instance, not a recollection.

It is also built to be driven by an **AI coding agent**: clone it, open Claude Code (or any agent
that reads `AGENTS.md`), and the session already knows how to start the lab, check its health, run
searches to grade your answers, and teach the material.

```bash
git clone <this repo> && cd splunk-lab-in-a-box
./setup/lab.sh up      # starts Splunk, generates credentials  (2-4 min)
./setup/lab.sh load    # downloads, time-shifts and indexes the data  (~3 min)
./setup/lab.sh creds   # url + login
```

That is the whole setup. `./setup/lab.sh verify` runs ten assertions and tells you the lab is ready.

## Why this exists

Splunk's free introductory courses are videos. Watching them teaches recognition; writing queries
teaches production, and only the second one survives contact with a real job. So these labs ask for
a **result**, never a keystroke: *"the sales director wants to know which product earns the most"*,
and you write the SPL.

Two problems had to be solved to make that work offline:

- **The official dataset is stale on arrival.** Its events stop a day or two before you download it,
  so *Today* and *Last 24 hours* return nothing and the entire time module becomes impossible.
  `setup/shift-times.py` shifts every timestamp by a whole number of days at load time.
- **Nothing tells you when the lab is subtly broken.** `./setup/lab.sh verify` checks event counts
  per sourcetype, host count, lookup row counts, and that a bare search reaches the right index.

## The curriculum

| # | lab | what you leave with |
|---|---|---|
| 00 | [Orientation and fields](labs/00-orientation-and-fields.md) | metadata vs extracted fields, terms vs fields, the `!=` trap |
| 01 | [Visualization](labs/01-visualization.md) | `timechart`/`chart`/`stats`, spans, `OTHER` and `NULL`, dashboards |
| 02 | [Working with time](labs/02-working-with-time.md) | `earliest`/`latest`, snapping, `bin`, `strftime`, timezone bugs |
| 03 | [Statistical processing](labs/03-statistical-processing.md) | `stats` vs `eventstats`, percentiles, long vs wide |
| 04 | [Lookups and subsearches](labs/04-lookups-and-subsearches.md) | enrichment, subsearch rules, base rates |
| 05 | [Search optimization](labs/05-search-optimization.md) | scan counts, the optimiser, `tstats`, sizing a detection |

Labs 00–03 take 20–25 minutes each, 04 and 05 about 30. The whole path is a focused afternoon.

Lab 05 ends on something the courses do not teach: how to size a detection so that it can actually
fire, and how to compute the number of false alerts a threshold will generate before you deploy it.

## Using it with an agent

`CLAUDE.md` is the agent's brief: the lab state machine, the teaching contract, the verification
tooling, and the data traps it must not get wrong. A session that starts in this directory will:

```bash
./setup/lab.sh status --json   # {"running":true,"events":109864,"data_age_hours":19,"ready":true}
./setup/lab.sh spl '<search>'  # run SPL and read the result — how it grades your answers
```

Custom commands are provided in `.claude/commands/`: `/lab-start`, `/lab-status`, `/lab-next`,
`/lab-check`.

Progress lives in `.lab-progress.json` (gitignored), so a new session resumes where you stopped.

## Requirements

Docker with Compose v2, `python3`, `curl`, `unzip`, and about 3 GB of free RAM. Splunk Web is
published on `127.0.0.1` only — the lab never listens on a public interface.

The container runs a **60-day trial licence** capped at 500 MB/day of indexing. This dataset is
~19 MB, so reloading it costs nothing.

## Commands

```
./setup/lab.sh up | load | status [--json] | verify | spl '<search>' [earliest] [latest]
                 | url | creds | stop | reindex --yes | destroy --yes
```

`reindex --yes` re-shifts the dataset to today (useful after a few days: the time-based exercises go
quiet as the data ages). `destroy --yes` removes the container and its volumes.

## Notes and credits

The dataset and the `prices.csv` lookup are the official Splunk *Search Tutorial* files, downloaded
at build time from `docs.splunk.com` — they are not redistributed here. `setup/lookups/http_status.csv`
is written for this lab because the vendor's copy is no longer reachable. The labs' answer keys were
produced by running the queries on this exact dataset.

Splunk is a trademark of Splunk Inc. This project is not affiliated with or endorsed by Splunk Inc.
Licensed under MIT — see [LICENSE](LICENSE).
