# Lab 04 — Statistical processing

**Day 5.** Counting is easy. Saying something true about the counts is the job.

**Time:** 25 min · **Range:** *Last 30 days* everywhere, so your numbers match the key exactly.

**Before you start:** labs 00–03.
**After this lab you can:** aggregate with the right function, compare an event to its group with
`eventstats`, and know why a mean, a median and a 95th percentile tell three different stories about
the same column.

---

## Concepts

### `stats` is the workhorse

```
| stats count, dc(clientip) as visitors, sum(bytes) as bytes, avg(bytes) as mean by host
```

The functions you will use daily: `count`, `count(field)` (only events **where the field exists**),
`dc()` (distinct), `sum`, `avg`, `median`, `perc95`, `min`, `max`, `range`, `values()` (the distinct
list), `list()` (all of them, in order), `earliest()`/`latest()` (the value of a field at the
boundaries of the window).

Two of those pairs cause most confusion:

- `count` vs `dc()`: 39 532 requests, 182 visitors. One counts rows, the other counts distinct
  values.
- `count` vs `count(field)`: the second silently ignores events missing the field, which makes
  `| stats count(action) as with, count as total | eval without=total-with` the fastest way to
  measure a field's coverage.

### `by` and the shape of the output

`stats ... by A, B` produces one row per **observed** pair. Pairs that never occur do not appear —
which is why a `by host, status` on this dataset gives 24 rows and not 3 × 9 = 27. `chart` would
have shown you the three missing cells. Neither is more correct; they answer different needs.

### `stats` replaces the stream, `eventstats` enriches it

This is the distinction the whole lab turns on.

```
... | stats avg(bytes) as m          -> ONE row. The events are gone, and so is `bytes`.
... | eventstats avg(bytes) as m     -> every event, plus a new column `m` on each of them.
```

So `| stats avg(bytes) as m | where bytes > m` cannot work — after `stats` there is no `bytes` left
to compare. With `eventstats` it works, and it is how you answer "which events are above their
group's average", the single most useful pattern in detection work. `eventstats ... by host` does it
per group.

Its streaming cousin `streamstats` computes over the events **seen so far** (running totals, deltas,
"time since the previous event for this user").

### `top` / `rare` are shorthands

`| top limit=5 clientip` is `| stats count by clientip | sort - count | head 5` plus a `percent`
column. Compact for exploration; in a shared dashboard prefer the explicit form — you control the
column names, the sort key and the tie-breaking. Which matters: on ties, `sort - count` picks an
arbitrary winner. Add a second key (`| sort - count, clientip`) when the ranking must be
reproducible.

### Mean, median, percentile

A mean is a bad summary of anything with a tail. Compare `avg`, `median` and `perc95` before you
publish a number. If mean ≈ median, the distribution is roughly symmetric and the mean is safe; if
p95 sits far above both, a minority of users lives in a world your average is hiding — which is why
service levels are written in p95 or p99 and never in averages.

### The quoting trap

A field whose name looks like a number must be quoted with single quotes in `eval`:
`'403'` is the field, `403` is the number. Write `| eval total = 200 + 403` and Splunk computes
**603** for every row, without a warning.

---

## Missions

### M1 — The five numbers

For the web sourcetype, produce in one search: the event count, the number of distinct client IPs,
the number of distinct sessions, the total bytes and the mean bytes. Then round the mean to one
decimal, and explain the gap between `count` and `dc(clientip)`.

### M2 — Per group

Break the count and the mean size down by host. Are the three servers equivalent? Then count by
host **and** status: how many rows do you expect, how many do you get, and which combinations are
missing?

> 💡 To see the missing ones, ask `chart` instead of `stats`.

### M3 — Rankings

Write the five busiest client IPs twice: once with `top`, once with `stats`+`sort`+`head`. Which one
goes into a dashboard, and why? Then find the three rarest status codes, and say whether the rarest
is the most serious.

### M4 — What the mean hides

Compute mean, median, p95 and max of `bytes` in one search. What shape of distribution do those four
numbers describe? Why would an SLA be written on p95 rather than on the mean?

### M5 — Above average

Count the web events whose size is above the **overall** mean. Then do the same against the mean
**of their own host**. Predict the proportion before running it.

Then break your own query: replace `eventstats` with `stats` and explain the error in one sentence.

### M6 — Empty cells

Produce the host × status matrix twice, once with `count` and once with `avg(bytes)`, and inspect a
cell that has no events in it. Does it hold `0`, an empty string, or null? Does an `eval` on it raise
an error?

> 💡 `| eval state=if(isnull('403'),"null cell","value")` — mind the single quotes around the field
> name.

### M7 — The sales data

On `vendor_sales`: the three most active `VendorID`, and the most frequent `Code`. Then try to sum a
`price` field, and explain the empty result.

### Challenge

Your colleague computes the average response size per host, then averages those three numbers to get
"the site average". Write the two searches that show his number and the true one, and explain in one
sentence why they differ — and when they would not.

---

## Answer key

- **M1** — count **39 532** · `dc(clientip)` **182** · `dc(JSESSIONID)` **5 297** · `sum(bytes)`
  **82 927 431** · `avg(bytes)` **2 097,7**. 182 visitors for 39 532 requests: one IP loads dozens of
  pages. Rounding: `round(x,1)` → 2 097,7 · `round(x)` → 2 098 · `floor(x)` → 2 097 ·
  `ceiling(x)` → 2 098. (`round` goes to the nearest, `ceiling` always up — use `ceiling` when
  sizing capacity, `round` when displaying.)
- **M2** — www1 13 628 (mean 2 088,8) · www2 12 912 (2 100,1) · www3 12 992 (2 104,7): equivalent,
  as a load balancer should make them. `by host, status` gives **24** rows, not 27: **www1 and www3
  have no `403` at all, www2 has no `505`**. `stats` only emits observed combinations; `chart` shows
  the holes.
- **M3** — `87.194.216.51`, **1 036** hits (2,62 %). The explicit form belongs in a dashboard: you
  name the columns, you choose the sort key, and you can break ties deterministically. Rarest codes:
  `403` (228), `505` (480), `404` (690) — and no, the rarest is not the most serious: 403 is a
  routine refusal while the 952 `503` are outages.
- **M4** — mean **2 097,7** · median **2 092** · p95 **3 810** · max **4 000**. Mean ≈ median and p95
  close to max: a roughly uniform, bounded distribution with no tail. An SLA uses p95 because the
  question is never "how is the average user doing" but "how bad is it for the unlucky ones".
- **M5** — **19 744** events above the overall mean, i.e. **49,9 %** — exactly what a symmetric
  distribution predicts. With `stats` instead of `eventstats` the search breaks because `stats`
  collapses the stream to a single row with no `bytes` column left to compare.
- **M6** — `chart count` fills empty cells with **0**; `chart avg(bytes)` leaves them **null**. An
  `eval` on a null cell raises **no error** — it returns null, silently, and the row quietly drops
  out of your calculation. Deciding to `fillnull value=0` after an `avg` is a statement of meaning
  ("no measurement counts as zero"), not a formatting step.
- **M7** — VendorID **1060** (135), **7014** (133), then **1005 and 1015 tied at 128** — a tie, so
  any "top 3" here is arbitrary unless you add a second sort key. Most frequent `Code`: **L**
  (3 148). `sum(price)` is empty because **`price` is not a field of these events** — it lives in
  `prices.csv`, and joining the two is lab 05.
- **Challenge** — the true mean is `| stats avg(bytes)` → **2 097,73**. Averaging the three host
  means (2 088,8 / 2 100,1 / 2 104,7) gives **2 097,88**: close, because the three hosts carry
  almost the same number of events. **An average of averages weights each group equally instead of
  each event equally** — the error is invisible here and catastrophic the day one host carries 90 %
  of the traffic. The general fix is to keep the counts: `| stats sum(bytes) as b, count as n by host
  | stats sum(b)/sum(n)`.
