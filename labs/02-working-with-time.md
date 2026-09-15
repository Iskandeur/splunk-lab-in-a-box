# Lab 02 — Working with time

**Time:** 25 min.

> ⚠️ **Two facts about this dataset, before you start.**
> 1. It was **shifted forward by a whole number of days** at load time so that it ends within the
>    last 24 hours. *Today* is therefore nearly empty, and **weekday names are meaningless** — the
>    shift moved them. Hour-of-day, on the other hand, is intact.
> 2. **Never do a time exercise on `secure-2`**: its 40 088 events carry only **8 distinct
>    timestamps** (a whole day of SSH logs shares `23:23:5x`). That is how the vendor's file is
>    built. Use `access_combined_wcookie` for anything involving time. `vendor_sales` is
>    synthetically flat — 180 events per hour, every hour — which makes it useless for trends and
>    convenient for statistics.

---

## Concepts

### `_time` is a number

Every event carries `_time`, seconds since 1970-01-01 UTC. Everything else — the picker, `earliest`,
`span`, the x-axis — is arithmetic on that number. Two consequences you will meet today:

- you can subtract two `_time` values to get a duration, but only **before** turning them into text
  with `strftime`. Format last, compute first.
- what you *see* is `_time` rendered in **your profile's timezone**, while `date_hour`, `date_wday`
  and friends were extracted from the **text of the event** at index time and never move. If those
  two disagree, you have just found a timezone bug — this is the number one cause of "our two
  dashboards show different numbers".

### The picker writes two parameters

Every range is `earliest` + `latest`, whether you clicked it or typed it:

| picker | SPL |
|---|---|
| Last 24 hours | `earliest=-24h latest=now` |
| Last 7 days | `earliest=-7d@h latest=now` |
| Yesterday | `earliest=-1d@d latest=@d` |
| Today | `earliest=@d latest=now` |

### Snapping: the `@`

`@` means "then round **down** to the start of that unit".

- `-1d` at 14:30 = yesterday 14:30.
- `-1d@d` at 14:30 = yesterday **00:00**.
- `@d` = today 00:00. `@h`, `@m`, `@w0` (Sunday), `@mon`, `@y` all exist.

Snapped ranges are what you want for reports ("yesterday" must mean the same thing whenever it
runs); unsnapped ones are what you want for alerts ("the last 15 minutes").

### Absolute ranges

`earliest="09/12/2026:00:00:00" latest="09/13/2026:00:00:00"` — note the `MM/DD/YYYY:HH:MM:SS`
format. Absolute ranges are the only ones whose result never changes, which makes them the right
choice when you are comparing two runs or writing a test.

### Bucketing

- `timechart span=15m count` builds the buckets for you and fills the holes.
- `bin _time span=4h | stats count by _time` does the same thing by hand — useful when you want to
  bucket *and* group by something else at the same time.
- `span` accepts `s m h d w mon`, and `1d@w0`-style alignment for weeks.

### Reading and making time with `eval`

```
| eval readable = strftime(_time, "%Y-%m-%d %H:%M:%S")     number -> text
| eval epoch    = strptime(when, "%Y-%m-%d %H:%M:%S")      text -> number
| eval hour     = strftime(_time, "%H")                    hour in YOUR timezone
```

---

## Missions

### M1 — Feel the ranges

Run `index=tutorial sourcetype=access_combined_wcookie` over *Today*, *Yesterday*, *Last 24 hours*,
*Last 7 days* and *Last 30 days*. Write down the five numbers. Which of them will be different
tomorrow, and which will not? Justify each.

### M2 — The same ranges, typed

Reproduce *Last 24 hours* and *Yesterday* using `earliest`/`latest` in the search bar. Then explain,
with a clock in hand, the difference between `earliest=-1d` and `earliest=-1d@d` at 14:30.

### M3 — Find the boundaries of your own dataset

Write the search that tells you the first and last event of the index, in readable form. Then use
the result to build an **absolute** range covering one full day of data, and count the events of
each sourcetype in it.

> 💡 `stats min(_time) as first max(_time) as last`, then `strftime` — format last, compute first.

### M4 — Resolution

Take a four-hour window inside your dataset and chart it with `span=15m`. How many rows do you
expect before you run it? Then try `span=1h` and `span=5m` and decide where the signal stops and the
noise starts.

Then count, over the whole dataset, how many 4-hour buckets actually contain events.

### M5 — Hour of day

Across the whole dataset, which hours of the day are busiest? Answer with `strftime`, then answer
again **without `eval`** — Splunk already extracted a field for it.

Then do the same by day of the week, and explain why that second answer must not be trusted here.

### M6 — Durations

For each session (`JSESSIONID`), compute the elapsed time between its first and last request, and
show the five longest with readable start and end times.

> 💡 Compute the duration first, format afterwards. If you format first you will get null.

---

## Answer key

Counts marked **exact** are properties of the dataset and will match for you. Counts marked *shape*
depend on the hour you run them — compare the order of magnitude, not the digits.

- **M1** — *Today*: nearly empty (*shape* — the shift leaves the newest event within the last 24 h).
  *Last 30 days*: **39 532**, exact, and it will still be 39 532 tomorrow: neither boundary crosses
  any data. The other three shrink every hour as the window slides off the end of the dataset. A
  relative range only moves when **one of its two boundaries crosses events**.
- **M2** — at 14:30, `-1d` = yesterday 14:30 (a rolling 24 h), `-1d@d` = yesterday 00:00 (a calendar
  day). `@` always rounds down.
- **M3** —
  ```
  index=tutorial | stats min(_time) as first, max(_time) as last
  | eval first=strftime(first,"%F %T"), last=strftime(last,"%F %T")
  ```
  The dataset spans **just over 7 days** and ends within the last 24 hours. A **full** day of it
  holds about **5 500** web events, **5 600** auth events and **4 320** sales events (the sales
  figure is exactly 24 × 180, because that source is synthetic).
- **M4** — four hours at `span=15m` is **16 rows** — compute it before running it, that habit alone
  catches half of all span mistakes. Over the whole dataset, `bin _time span=4h` yields **43**
  non-empty buckets (exact).
- **M5** — busiest hours: **03:00 (2 378)**, 01:00 (2 255), 15:00 (2 006) — exact, and preserved by
  the shift, which moves whole days. Without `eval`: `| stats count by date_hour`. By weekday the
  numbers are the same three values attached to different day names, because a whole-day shift
  rotates the calendar: **any conclusion about weekdays here is an artifact of the lab, not a
  property of the shop.** When you analyse someone else's dataset, ask what was done to it before it
  reached you.
- **M6** —
  ```
  index=tutorial sourcetype=access_combined_wcookie
  | stats min(_time) as start, max(_time) as end by JSESSIONID
  | eval duration=round(end-start) | sort - duration | head 5
  | eval start=strftime(start,"%F %T"), end=strftime(end,"%F %T")
  ```
  There are **5 297** distinct sessions (exact). `_time` is a number; once `strftime` has turned it
  into a string, subtraction is meaningless.
