# splunk-lab-in-a-box

A complete, self-hosted Splunk lab: one container, the official *Buttercup Games* tutorial dataset
(109 864 events), and **nine labs that replace the vendor's video courses**. Every answer key is a
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
| 00 | [First day: orientation and fields](labs/00-orientation-and-fields.md) | metadata vs extracted fields, terms vs fields, the `!=` trap |
| 01 | [The search language](labs/01-the-search-language.md) | `eval`, `where`, `rex`, building fields the data never had |
| 02 | [Visualization](labs/02-visualization.md) | `timechart`/`chart`/`stats`, spans, `OTHER` and `NULL`, dashboards |
| 03 | [Working with time](labs/03-working-with-time.md) | `earliest`/`latest`, snapping, `bin`, timezone bugs |
| 04 | [Statistical processing](labs/04-statistical-processing.md) | `stats` vs `eventstats`, percentiles, long vs wide |
| 05 | [Lookups and subsearches](labs/05-lookups-and-subsearches.md) | enrichment, subsearch rules, base rates |
| 06 | [Making knowledge stick](labs/06-knowledge-objects.md) | field extractions, event types, tags, reports, macros |
| 07 | [Search optimization](labs/07-search-optimization.md) | scan counts, the optimiser, `tstats`, sizing a detection |
| 08 | [Capstone: the 3 a.m. page](labs/08-capstone-investigation.md) | a full investigation, end to end |

The labs are a story. You are the first analyst hired by Buttercup Games; each lab is a day on the
job, each opens with what you need and what you will be able to do, and each ends with an optional
**Challenge**. Lab 08 is the page at three in the morning that uses all of it — and its answer is not
the one the alert suggests.

About four hours in total — a focused afternoon, or a lab a day for nine days. If you only have one
hour, do 00, 01 and 05; if you only want the part no course teaches, read 07 and do 08.

Every figure in every answer key was measured on a running instance, and you can re-verify all of
them yourself:

```bash
./setup/check-keys.py       # 35 figures replayed against your own lab
```

## Using it with an agent

`CLAUDE.md` is the agent's brief: the lab state machine, the teaching contract, the verification
tooling, and the data traps it must not get wrong. A session that starts in this directory will:

```bash
./setup/lab.sh status --json   # {"running":true,"events":109864,"data_age_hours":19,"ready":true}
./setup/lab.sh spl '<search>'  # run SPL and read the result — how it grades your answers
```

Custom commands are provided in `.claude/commands/`: `/lab-start`, `/lab-status`, `/lab-next`,
`/lab-check`. Progress lives in `.lab-progress.json` (gitignored), so a new session resumes where
you stopped.

## Or install it as a Claude Code plugin

No clone needed: the plugin carries the lab scripts, the nine labs and the coach.

```bash
claude plugin marketplace add Iskandeur/splunk-lab-in-a-box
claude plugin install splunk-lab-in-a-box@splunk-lab-in-a-box
```

Then, in any session, type `/splunk-lab-in-a-box:lab-start`. The other commands are `lab-status`,
`lab-next` and `lab-check <SPL>`. Credentials, downloads and progress are kept in the plugin's data
directory (`~/.claude/plugins/data/`), so they survive plugin updates. Loading the plugin from a
clone (`claude --plugin-dir .`) reuses the clone's `setup/.env`. A clone and an installed copy both
drive the one container named `splunk-lab`, so pick one of the two per machine.

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
