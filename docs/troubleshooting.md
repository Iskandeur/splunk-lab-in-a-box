# Troubleshooting

Every entry here cost someone hours. They are ordered by how likely you are to hit them.

## The container restarts every 55 seconds

The image requires **two** licence acceptances, and the second one is recent:

```yaml
SPLUNK_START_ARGS: --accept-license                        # the historic one
SPLUNK_GENERAL_TERMS: --accept-sgt-current-at-splunk-com   # without it: exit 1, in a loop
```

The error message (`License not accepted, please adjust SPLUNK_GENERAL_TERMS`) is explicit, but it
is **buried in a twelve-line legal notice repeated at every attempt**, so `docker logs --tail 20`
shows you the notice and not the verdict. Read `--tail 60`, or grep for `License not accepted`.

`docker-compose.yml` sets both. This note is here for the day you write your own.

## Downloading the dataset returns 403

`docs.splunk.com` refuses `curl`'s default user-agent. With a browser user-agent, the same URL
returns 200. **A 403 is about who is asking, not about what exists** — `setup/lab.sh` sets the header
for you.

## The prices lookup is corrupted or is not UTF-8

`Prices.csv.zip` contains a macOS resource fork, `__MACOSX/._prices.csv`. Extracting everything and
then looping over `*.csv` overwrites the real file with the 392-byte fork. Extract the entry **by
name** (`setup/lab.sh` does), and strip the trailing empty line and the trailing space in one `Code`
value while you are there.

## A search without `index=` returns twice the expected number

Default search indexes of **imported** roles are unioned. `admin` imports `power`, which imports
`user`, and both default to `main`. Setting `srchIndexesDefault` on `admin` alone leaves `main` in
the union, so a bare search hits `main` **and** `tutorial`. `setup/lab.sh load` patches all three
roles. Check with:

```
./setup/lab.sh spl 'sourcetype=access_combined_wcookie | stats count by index'
```

One row, or something is wrong.

## `Unknown search command 'not'`

After a `|`, Splunk expects a **command**. `NOT`, `AND`, `field=value` are arguments of `search`:

```
... | NOT action=*            wrong
... | search NOT action=*     right
... NOT action=*              right (and better: it filters in the base search)
```

## The numbers in the answer key do not match mine

In order of likelihood:

1. **Your time range differs.** The keys use *Last 30 days* unless stated. Check the banner under
   the search bar: it prints the range actually used.
2. **You read the count before the job finished.** The counter keeps climbing while the search runs.
3. **The dataset has aged.** `./setup/lab.sh status --json` → if `data_age_hours` is large, the
   relative ranges are empty; `./setup/lab.sh reindex --yes` fixes it.
4. **The optimiser changed your result.** Read `optimizedSearch` in the Job Inspector — see below.

## A result that makes no sense at all

`stats count by _time` returning 8 rows instead of 25 753 is the canonical case: with a `sourcetype=`
filter present, the optimiser rewrites the search into `tstats`, and `tstats … by _time` **buckets by
day** unless given a span. The optimiser does not only change speed; it can change the **result**.

```
... | noop search_optimization=false | stats count by _time
```

turns the rewriting off and gives you back the raw behaviour. And `Job → Inspect Job →
`optimizedSearch`` always shows what actually ran.

## The banner lies about `tstats`

"This search has completed and has returned 3 results by scanning 109 864 events" appears for a
`tstats` search too, where it counts tsidx rows aggregated rather than events read. Do not use that
sentence to judge the cost of a `tstats`.

## Splunk will not start after a host reboot

The compose file uses `restart: unless-stopped`, so it comes back on its own — unless you stopped it
explicitly with `./setup/lab.sh stop`, which is the intended way to free ~1.1 GB of RAM between
sessions. Data survives in named volumes either way.

## Wiping and starting over

```
./setup/lab.sh reindex --yes    # keeps dashboards and saved searches, reloads events
./setup/lab.sh destroy --yes    # removes everything, including volumes
```
