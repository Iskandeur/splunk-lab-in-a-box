# Lab 00 — First day: orientation and fields

**Day 1.** You have just joined Buttercup Games, an online shop selling video games, as their
first data analyst. Three log sources were plugged into Splunk last week and nobody has ever asked
it a question. Today you learn to find things.

**Time:** 20 min · **Range for every exercise:** *Last 30 days* (covers the whole dataset).

**Before you start:** nothing — this is the entry point.
**After this lab you can:** tell metadata from extracted fields, filter on either, and avoid the two
traps (`"200"` vs `status=200`, and `!=` vs `NOT`) that silently return the wrong number.

---

## Concepts

You do not need a video. Here is everything this lab assumes.

### What Splunk actually stores

Your data lives in **indexes**. An index is not a table — it is a set of directories on disk called
**buckets**, each holding two things:

- the **raw journal**: your log lines, compressed, exactly as they arrived;
- a **tsidx**: an inverted index mapping every *token* (word) to the events that contain it.

Nothing is parsed into columns at write time. Fields are extracted **when you search**
(*schema-on-read*). That single design choice explains most of Splunk's behaviour: you can change
how a field is extracted tomorrow and it applies retroactively to data indexed last year, but you
pay for that extraction on every search.

### The five fields that exist before any extraction

Written at index time, available to every search, and the only ones fast commands can use:

| field | question it answers | in this lab |
|---|---|---|
| `index` | which store | `tutorial` |
| `host` | which machine produced it | `www1`, `www2`, `www3`, `mailsv`, `vendor_sales` |
| `source` | where on that machine | the file path — 8 of them |
| `sourcetype` | what *format* it is written in | 3 of them |
| `_time` | when it happened | epoch seconds |

`sourcetype` is the important one. It is not the origin, it is the **shape**: it tells Splunk where
the timestamp sits in the line and which fields to extract. A wrong sourcetype means no `status`,
no `clientip`, just text.

### Anatomy of a search

```
index=tutorial sourcetype=access_combined_wcookie status=200 | stats count by host
└──────────────── base search ────────────────────────────┘ └──── pipeline ────┘
```

Everything before the first `|` is turned into index lookups: the time range selects buckets, the
terms are looked up in the tsidx, and only matching events are decompressed. Everything after a `|`
runs on events **already retrieved** — it can throw work away, never avoid it.

What you type at the start of the bar is really an implicit `search` command:
`index=tutorial foo=bar` ≡ `| search index=tutorial foo=bar`. This matters: after a pipe, Splunk
expects a **command**. `NOT`, `AND`, `field=value` are arguments of `search`, not commands, which is
why `... | NOT action=*` fails with *Unknown search command 'not'* and `... | search NOT action=*`
works.

### Terms vs fields

- `status=200` tests the **extracted field**.
- `"200"` searches the **raw text** for the token `200` — it matches bytes counts, response times,
  anything. It is slower and less precise. It is also tokenised, not substring: `200` does not match
  `2001`.

### Absent fields, and the trap that follows

Not every event carries every field. `action` exists on 49.9 % of the web events. Two consequences
that bite everyone once:

- `action!=purchase` silently **excludes events that have no `action` at all** — `!=` only considers
  events where the field exists. To include them you need `NOT action=purchase`.
- To count events missing a field: `NOT action=*`, or `| where isnull(action)`.

### The sidebar

**Selected fields** show under every event. **Interesting fields** are those present in at least
20 % of results; `a` marks a string, `#` a number. Clicking a field gives you top values, a mini
report, without writing SPL.

---

## Missions

### M0 — Inventory without writing a search

`Search & Reporting` → **Data Summary**. How many hosts, sources and sourcetypes? Which sourcetype
carries the most events?

### M1 — The shape of the data

Write one search that returns, in a single table, the number of events for every combination of
host, source and sourcetype. What does it tell you about `www1` that a count by host alone hides?

> 💡 `stats` takes several `by` fields.

### M2 — Filtering on a field

For `sourcetype=access_combined_wcookie`: how many events in total, how many with `status=200`, how
many with `status=503`, and how many that are *not* 200?

Then run `index=tutorial "200"` and explain — before reading the key — why the number differs from
`status=200`.

### M3 — The field with a hole in it

Produce the distribution of the `action` field. The counts will not add up to the sourcetype total.
Find the missing events and write the search that counts them.

> 💡 Two ways: one in the base search, one with `isnull()`. Both should return the same number.

### M4 — The `!=` trap

Count the web events whose `action` is not `purchase`. Do it twice — once with `!=`, once with
`NOT`. They disagree. Explain which one is right for the question "how many events are not a
purchase?".

### M5 — Ranking

Write searches that answer:
1. the five busiest client IPs, with their share of traffic;
2. the three rarest HTTP status codes;
3. the five most purchased product categories (`categoryId`, only on `action=purchase`).

> 💡 `top` and `rare` are `stats` + `sort` + `head` in one command, and they add a `percent` column.

### M6 — Where the filter goes

These two return the same number:

```
index=tutorial sourcetype=access_combined_wcookie | search status=200 | stats count
index=tutorial sourcetype=access_combined_wcookie status=200 | stats count
```

Which one would you write, and why? Keep your answer — lab 07 measures it, and the result will
surprise you.

### Challenge

Which client address **converts** best? Rank addresses by the share of their requests that end in a
purchase, keeping only those with at least 200 requests. You will need one `stats` with two counts
in it — the pattern that carries the rest of this course.

---

## Answer key

- **M0** — 5 hosts, 8 sources, 3 sourcetypes. Biggest: `secure-2` (**40 088**), just ahead of
  `access_combined_wcookie` (**39 532**); `vendor_sales` has 30 244.
- **M1** — `index=tutorial | stats count by host, source, sourcetype` → 8 rows. `www1`, `www2` and
  `www3` each appear **twice**: one machine producing two files in two different formats. A count by
  host alone would have hidden that a web server also ships auth logs.
- **M2** — 39 532 total · `status=200` → **34 282** · `status=503` → **952** · `status!=200` →
  **5 250**. The bare term `"200"` returns **34 333**, fifty-one more: those events contain the token
  `200` somewhere else (a byte count, a response time, a URL). A term search reads the raw text; a
  field filter reads an extracted value.
- **M3** — `addtocart` 5 743, `purchase` 5 737, `view` 5 391, `remove` 1 445, `changequantity` 1 402
  = 19 718. The other **19 814** events have no `action` field at all (requests that never touch the
  cart). Either of these counts them:
  `index=tutorial sourcetype=access_combined_wcookie NOT action=*` or `... | where isnull(action)`.
- **M4** — `action!=purchase` → **13 981** (= 19 718 − 5 737: only events that *have* the field).
  `NOT action=purchase` → **33 795** (= 39 532 − 5 737). The question "not a purchase" means the
  second. `!=` is a filter on a value; `NOT` is a filter on a proposition.
- **M5** — `87.194.216.51` with **1 036** hits (2,62 %) · rarest: `403` (228), `505` (480), `404`
  (690) · purchases: `STRATEGY` 885, `ARCADE` 537, `TEE` 404, `ACCESSORIES` 387, `SHOOTER` 275.
  Note that the rarest code is not the most serious one: 403 is a routine refusal, while the 952
  `503` are real outages. Frequency says nothing about severity.
- **M6** — write the filter in the base search. Not because the pipeline version is always slower —
  lab 07 will show you Splunk often rewrites it for you — but because it is the only version whose
  cost does not depend on an optimiser understanding your intent.
- **Challenge** — `| stats count as reqs, count(eval(action=="purchase")) as buys by clientip
  | where reqs>=200 | eval rate=round(buys*100/reqs,2) | sort - rate` → **74.125.19.106**, 47
  purchases out of 232 requests, **20,26 %**. Note what the `where` is doing: without a minimum
  volume, an address with 2 requests and 1 purchase would top the ranking at 50 %. Every ranking of
  a ratio needs a floor — lab 07 turns that intuition into a calculation.
