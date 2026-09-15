# Lab 05 — Search optimization and detection sizing

**Time:** 30 min · **Range:** *Last 30 days* unless stated.

> **The setting.** You are a SOC analyst. Your searches do not run once in front of you — they run
> **every 15 minutes, 24/7, on a shared cluster**. A query that costs ten times too much does not
> return worse results; it goes unnoticed until the morning everyone's SIEM falls behind.
> Optimisation here is not aesthetics, it is availability.

**The instrument:** `Job → Inspect Job`. Three numbers, always the same three:

| number | what it means |
|---|---|
| **scan count** | events actually **read from disk** |
| **result count** | events **returned** |
| **duration** | wall-clock time |

`scan / result` is your **waste ratio**. This whole lab is about lowering it.

---

## Concepts

### What happens when you press enter

1. The **time range** eliminates whole buckets — without opening them. Free.
2. **`index`/`sourcetype`/`host`/`source`** eliminate more buckets, then narrow inside the rest.
3. The **terms** of your base search are looked up in the tsidx, producing a candidate list. Only
   those events get decompressed.
4. **Fields are extracted** on those events, and `field=value` conditions are verified.
5. The **pipeline** runs on what has already been retrieved. It can throw work away; it cannot avoid
   it.

Levers 1 and 2 decide *which buckets to open*. Lever 3 decides *which events to read inside them*.
Keeping those two apart is how you diagnose a slow search in production.

### The optimiser rewrites what you wrote

Since Splunk 6.6, a `| search` sitting after a pipe is **lifted into the base search** automatically.
The Job Inspector shows the truth in the `optimizedSearch` property — read it before doubting your
data. Two things follow:

- benchmarking `| search x=y` against `x=y` measures nothing: they become the same search;
- the optimiser sometimes changes the **result**, not just the speed. With a `sourcetype=` filter
  present, `stats count by _time` is converted to `tstats`, and `tstats … by _time` **buckets by
  day** unless you give it a span. Same query, 8 rows instead of 25 753.

You can switch the rewriting off to see it: `| noop search_optimization=false`.

### Wildcards

The tsidx is sorted. A **trailing** wildcard (`clientip=87.194.*`) is a range scan — Splunk jumps
straight to the right page of the phone book. A **leading** one (`clientip=*216.51`) forbids that
jump: it must walk the terms and retrieve every plausible candidate, then verify after extraction.
**You may prefix, never suffix.** Same reasoning for `NOT` and `!=`: a negation cannot be looked up
in an inverted index, only verified after reading.

### `tstats`

`tstats` answers from the tsidx alone — timestamps, host, source, sourcetype, terms — without
opening a single event. Its boundary is exactly that list: it knows nothing about fields extracted
at search time (`action`, `status`, `categoryId`), so `| tstats count where index=tutorial by action`
returns nothing. **`tstats` for `index`/`sourcetype`/`host`/`source`/`_time`, `stats` for the rest.**

### Where the work happens (invisible in this single-instance lab, decisive in production)

- **Distributable** commands (`search`, `eval`, `rex`, `fields`, `where`) run **on every indexer, in
  parallel**, on its own slice of the data.
- **Centralising** commands (`stats`, `sort`, `dedup`, `top`, `transaction`, any subsearch) pull
  everything back to the search head, which becomes the bottleneck.

Hence the rule at scale: push as much filtering and computing as possible **before** the first
centralising command. And prefer `stats` to `transaction` (which holds events in memory) and to
`dedup`.

### Fast / Smart / Verbose

*Fast* extracts only the fields your search needs and skips event types and tags. *Verbose* extracts
everything and builds the full sidebar. *Smart* switches between them depending on whether your
search transforms. Exploring → Verbose. Dashboard or alert → **Fast, always**.

No timings are given here on purpose: measuring a 10 % effect on a 40 000-event dataset in one run
produces noise, not evidence. Refusing a number is also part of the craft.

---

## Missions

### M1 — Quantify the waste

Run `index=tutorial sourcetype=access_combined_wcookie status=503`, note scan count and result count,
then the same filter moved after a pipe (`| where status=503`). Explain the gap.

### M2 — Rank the four levers

Measure and rank, by how much work they remove:

1. narrowing the **time range** (*Last 30 days* → one full day of your dataset → *Last 24 hours*);
2. naming the **index** (`index=*` → `index=tutorial`);
3. a **term** in the base search (`status=200`);
4. a filter **after the pipe** (`| where status=200`).

**Deliverable:** the ranking, each scan count, and one sentence saying *when* the winner acts.

> 💡 Lab 02, M3 gives you the boundaries of your own dataset for the "one full day" range.

### M3 — What Splunk actually ran

Prove that `... status=200 | stats count` and `... | search status=200 | stats count` are the same
search. Then make the difference reappear.

### M4 — Wildcards

Predict the ranking of scan counts for `clientip=87.194.216.51`, `clientip=87.194.*` and
`clientip=*216.51`. Then measure. One of your predictions will be wrong for a reason that is about
this dataset, not about Splunk — find it.

### M5 — The heavy weapon and its boundary

**Request:** "How many events per sourcetype? I need it under 100 ms, it goes in a dashboard that
refreshes every 30 seconds."

Write the naive query and the fast one, compare, then **read the `search.log` or `optimizedSearch` of
the naive one** before concluding anything. Then find the boundary: ask the same question "by
`action`" and explain the failure.

### M6 — Size a detection (the most useful mission of the six)

**Request:** "Write the alert that catches an IP throwing abnormally many 5xx errors. It will run
every 15 minutes."

This is not an SPL exercise — the query is six lines. It is a **sizing** exercise. Three questions,
in order:

1. **What does "abnormal" mean?** A count? A rate? A deviation from what?
2. **Which threshold?** Compute how many false alerts per day your threshold produces. Do not
   estimate it.
3. **Which window?** How much traffic must you observe for the question to have an answer at all?

**Deliverable:** the query, the threshold **justified by a false-alert calculation**, the window
**justified by a volume calculation**, and the alert settings.

> 💡 Do not start with SPL. Start by measuring your throughput:
> `index=tutorial sourcetype=access_combined_wcookie earliest=-24h | stats count by clientip
> | stats count, max(count), avg(count)`.

---

## Answer key

### M1

| search | scan | results | waste | duration |
|---|---|---|---|---|
| `status=503` in the base search | **1 004** | 952 | 1,05:1 | 0,147 s |
| `\| where status=503` | **39 532** | 952 | **41:1** | 0,335 s |

The first reads 1 004 events to return 952: the term `503` goes to the inverted index, which returns
1 004 candidates (the 52 extras are events where `503` appears somewhere other than the status —
same intruders as in lab 00), and field extraction settles it. The second reads everything and throws
97,6 % of it away.

### M2

| lever | scan count |
|---|---|
| range: *Last 30 days* | 39 532 |
| range: one full day | ~5 500 |
| range: *Last 24 hours* | ~2 000 (shrinks hourly) |
| `index=*` | **79 064** |
| `index=tutorial` | 39 532 |
| `status=200` in base | 34 333 |
| `\| where status=200` | 39 532 (no gain) |

**Time wins**, and by a distance: it is the only lever acting **before a bucket is opened**. Then the
index (also bucket-level), then terms (event-level), then the post-pipe filter, which removes
nothing.

⚠️ `index=*` here is not merely twice as slow, it is **wrong**: it also counts the copy of the same
dataset living in `main` if you ever loaded one. In production it will be a test index, a duplicated
forwarder, a summary index. Naming your index is a correctness practice before it is a performance
one.

### M3

`optimizedSearch` shows `| search (index=tutorial sourcetype=access_combined_wcookie status=200)
| stats count` in **both** cases — the optimiser lifted the filter. Both scan **34 333**. Add
`| noop search_optimization=false` and the pipeline version goes back to **39 532**: proof by
breaking it.

And 34 333 rather than 34 282 results: the index knows **terms**, not fields. The 51 events where
`200` is a byte count are only dropped after extraction.

### M4

| form | scan count |
|---|---|
| `clientip=87.194.216.51` | **1 036** |
| `clientip=87.194.*` | **1 036** |
| `clientip=*216.51` | **2 548** |

If you predicted that the prefix would cost more than the exact value, your reasoning was right and
the data hid it: **exactly one IP in this dataset starts with `87.194.`**, so the prefix range
contains a single term. Widen it to `87.*` and you get 2 IPs and 1 193 events. A benchmark on one
dataset can conceal a general rule — which is itself the lesson.

### M5

```
index=tutorial | stats count by sourcetype     → 0,109 s   (banner: "scanning 109 864 events")
| tstats count by sourcetype                   → 0,027 s   (banner: "scanning 109 864 events")
```

Now read the `search.log` of the first one:

```
ReplaceStatsCmdsWithTstatsVisitor - Replacing the command with Tstats
Optimized Search = | tstats prestats=true … count WHERE index=tutorial BY sourcetype | stats count by sourcetype
```

**Splunk had already made the conversion.** Both searches run `tstats`. The remaining gap (×4) is not
"reading events versus reading the index" — it is the **event-search scaffolding** Splunk builds
anyway in the first case (`typer | tags`, the timeliner, the required-fields list) and skips when you
write `tstats` yourself (`Disabling timeliner since event search is empty`).

⚠️ And the banner says "by scanning 109 864 events" in **both** cases: on a `tstats` search that
counter reports tsidx rows aggregated, not events read. **Never judge the cost of a `tstats` from
that sentence.** Read `optimizedSearch`, or the job's own properties.

The boundary: `| tstats count where index=tutorial by action` returns **nothing**, because `action`
is extracted at search time. Indexed fields only.

### M6 — the answer key is a course, because the difficulty is entirely here

**1. Why a rate and not a count.** Lab 04 showed it: the IP with the most 5xx errors is simply the
one making the most requests. An absolute ranking measures volume. So we compare rates.

**2. Why a rate is not enough either.** An IP makes 20 requests, 3 fail: 15 %, nearly three times the
site. Guilty? No — with 20 draws, getting 3 where you expect 1,1 is unremarkable, exactly as 7 heads
out of 10 proves nothing. **On 1 000 tosses, 700 heads proves something; on 10, it does not.** The
question is never "is this rate high?" but "is it higher than chance produces *at that volume*?".

**3. Where `sqrt(p(1-p)/n)` comes from.** Model each request as a coin flip: error with probability
`p`. Then the **number** of errors over `n` requests follows a binomial distribution:

```
mean of the COUNT        = n·p
std-dev of the COUNT     = sqrt(n·p·(1-p))
```

You are not watching a count but a **rate**, i.e. that count divided by `n`. Dividing a variable by a
constant divides its standard deviation by the same constant:

```
std-dev of the RATE = sqrt(n·p·(1-p)) / n = sqrt(p(1-p)/n)
```

Read what the `1/√n` says: **uncertainty shrinks as the square root of volume**. To halve your error
bar you need four times the traffic. That is the deep reason a rate-based detection cannot live in a
small window — and nobody ever says it.

**4. The z-score.**

```
z = (observed rate − p) / sqrt(p(1-p)/n)
```

Numerator: how far you overshoot. Denominator: how far you were **entitled** to overshoot by chance,
given your volume. The ratio is **dimensionless**, so an IP with 300 requests and one with 30 000
finally become comparable.

**5. Choosing the threshold: count your false alerts.** An alert does not make one test, it makes one
**per IP per run**. Here ~180 IPs, every 15 minutes = **17 280 tests per day**:

| threshold | chance an innocent IP exceeds it | false alerts/day |
|---|---|---|
| 2σ | 2,28 % | **393** |
| 3σ | 0,135 % | **23** |
| 4σ | 0,0032 % | **0,55** |
| 4,5σ | 0,00034 % | **0,06** |

The "3σ" everyone recites would produce **23 false alerts a day** on this scope. That is the
multiple-comparisons problem: searching in 17 280 places guarantees coincidences. **A threshold is
derived from the number of tests and the team's false-alert budget**, never from tradition.

**6. The window follows from the threshold.** Invert the z formula: for an effect of size `Δ` to
reach threshold `z`,

```
z = Δ / sqrt(p(1-p)/n)    ⟹    n ≥ z²·p(1-p)/Δ²
```

With p = 5,477 % and Δ = p (detecting a **doubling**):

| threshold | requests needed **per IP per window** |
|---|---|
| 3σ | 155 |
| 4σ | **276** |
| 4,5σ | 350 |

Detecting a mere +50 % instead of a doubling needs **1 105** requests at 4σ: sensitivity costs
quadratically.

**7. The verdict on the original request.** The busiest IP in this dataset makes about **6 requests
per hour**. It needs **46 hours** to accumulate the 276 requests a 4σ test requires. **A rate-based
detection every 15 minutes is mathematically impossible on this traffic** — and no SPL will fix that.
This is the rule copied from a blog post that never fires and that nobody notices is mute: *a
detection that never triggers is indistinguishable from a broken one.*

Two honest designs:

```
# A — rate detection, at the scale statistics demands (daily)
index=tutorial sourcetype=access_combined_wcookie earliest=-24h latest=now
| stats count as n, count(eval(status>=500)) as err by clientip
| eventstats sum(err) as E, sum(n) as N
| where n >= 276
| eval p=E/N, rate=err/n, se=sqrt(p*(1-p)/n), z=round((rate-p)/se,2)
| where z > 4

# B — break detection, which does fit in 15 minutes because it changes the quantity measured:
#     not a rate, but each IP's deviation from its own habit
index=tutorial sourcetype=access_combined_wcookie earliest=-24h latest=now
| bin _time span=15m
| stats count as n by _time, clientip
| eventstats avg(n) as mean, stdev(n) as sd by clientip
| eval z=(n-mean)/sd
| where z > 4 AND n > 10
```

**8. What the model assumes, and gets wrong.** The binomial assumes **independent** draws. Requests
from one IP are not: a broken page produces a burst of correlated errors. Real variance is therefore
**larger** than `p(1-p)/n`, and your z **overstates** the anomaly. So these formulas are for
**sizing** — which window, which order of magnitude — not for deciding. The final threshold is
**calibrated on history**: replay the rule over thirty past days, count what it would have produced,
raise the threshold until the volume is bearable. A detection is tuned on data, not on a normal
table.

**9. Alert settings.**

| setting | value | why |
|---|---|---|
| Alert type | Scheduled, cron `*/15 * * * *` | |
| Time range | **equal to the frequency** (`-15m@m` → `@m`) | otherwise you re-alert on events already handled; the `@m` avoids a few seconds of overlap between runs |
| Trigger condition | `Number of Results > 0` | the filtering lives in the query, not in the condition |
| Throttle | *Suppress by field* `clientip`, 1 hour | without it the same IP fires four times an hour and the team learns to ignore the alert |

**10. The last step nobody takes.** **Prove your alert can fire.** Lower the threshold to `z > 1`,
check that `107.3.146.207` shows up, then put it back. A detection that has never triggered and a
broken one produce the same silence — the incomplete-lookup problem of lab 04, applied to security.
