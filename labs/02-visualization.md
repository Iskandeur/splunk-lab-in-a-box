# Lab 02 — Visualization

**Day 3.** Your first table impressed nobody. Marketing wants pictures, and the only honest way
to draw one is to understand what the drawing hides.

**Time:** 25 min · **Range:** *Last 30 days* unless stated. Spend this lab in the **Visualization**
tab and the **Format** menu — half the subject lives there, not in SPL.

**Before you start:** labs 00–01.
**After this lab you can:** choose between `stats`, `chart` and `timechart` on purpose, pick a span
that shows the signal, and spot the two columns (`OTHER`, `NULL`) that quietly change what a graph
claims.

---

## Concepts

### Three commands that look alike and are not

| command | what it produces | when |
|---|---|---|
| `stats` | a table: one row per observed combination | you want numbers |
| `chart` | a **pivot table**: rows × columns | you want to compare categories |
| `timechart` | a pivot table whose x-axis is **time**, with regular buckets | you want a trend |

`timechart span=1h count by status` is `chart count over _time by status` with three guarantees
`chart` does not give you: buckets of equal width, empty buckets filled with zero, and a cap on the
number of series.

That last one matters. `timechart`/`chart` keep the **10 biggest series** by default (`limit=10`)
and fold the rest into a column called `OTHER`. `useother=f` drops that column — and the events in
it are then simply **absent from your graph**, not regrouped. A chart where "everything looks fine"
because the ugly series fell below `limit` is a classic lying dashboard. Use `limit=0` when you are
counting errors.

There is a second phantom column: **`NULL`**, for events where the `by` field does not exist.
`usenull=f` hides it. Hiding it is a decision about meaning, not formatting.

### Choosing a span

`span` does not change how many events are read — all of them are, either way. It changes the
**bucket width**, so `rows = range ÷ span`. Aim for 30–200 points: fewer and you flatten the shape
you are looking for, more and each bar is sampling noise. Omit `span` and Splunk picks one (about
30–50 buckets for the range you chose), which is convenient interactively and dangerous in a
dashboard: the granularity then changes whenever someone changes the time picker.

### Long vs wide

`stats count by host, status` gives you the **long** form (one row per observed pair, missing pairs
simply absent). `chart count over host by status` gives the **wide** form (a matrix, missing pairs
become visible cells). Same data, two shapes: the long one is for computing, the wide one is for
looking.

One subtlety worth more than it seems: in the wide form, what fills an empty cell depends on the
function. `chart count` writes **0** — a count of nothing is zero. `chart avg(bytes)` leaves
**null** — the average of nothing does not exist — and any `eval` touching that cell returns null
silently, with no error.

### Picking the visualization

- **Line / area**: a trend over time. Needs `timechart`.
- **Column, stacked**: composition over time (`by status`), when the total matters too.
- **Bar**: comparing categories, when labels are long.
- **Pie**: one dimension only. Given two, Splunk does not refuse — it silently charts the first
  column and drops the rest, which is worse than an error.
- **Single value**: one number. On a *time series* it shows the **last point**, not the total, plus a
  trend arrow against the previous one.
- **Gauge**: a number against a range you define. Rarely the best choice; people like it anyway.

---

## Missions

### M1 — A trend

Chart the volume of web requests per hour. How many rows does the table have, how many of them are
non-empty, and what is the busiest hour worth?

> 💡 The gap between the two numbers is the whole point of `timechart`.

### M2 — Break it down

Split the same trend by `status`, then by `host`. How many series each time? Switch to stacked
columns and read the share of `200`. Do the three web servers behave alike?

### M3 — Make `OTHER` appear

Add `useother=f limit=0` to the `by status` version. Nothing changes. Work out why, then write the
search that *forces* the `OTHER` column into existence, and the one that removes it again.

Then run the same trend `by action` and explain the extra column you did not ask for.

### M4 — Compare categories, not time

Produce a table of request counts per `categoryId`, broken down by `status`, and read off which
category produces the most `503`. Then flip the two dimensions and decide which of the two answers
the question "which categories are failing?".

⚠️ One column will dominate and it is called `NULL`. Getting rid of it is mission M5.

### M5 — The column that resists two correct filters

In the previous table, try to remove the `NULL` column with `categoryId=*`. It is still there. Try
`NOT categoryId=NULL`. Still there. Both filters are correct SPL. Find out why neither is enough.

> 💡 Ask the data what kind of emptiness you are dealing with:
> ```
> ... | eval state=case(isnull(categoryId),"field absent", categoryId=="NULL","literal string NULL",
>                       1==1,"real category") | stats count by state
> ```

### M6 — One number

Build a Single Value panel showing purchases. First with `stats count`, then replace it with
`timechart span=1h count` — you will get **0**, with a chart that visibly has peaks. Explain, then
make it work.

> 💡 Look at the last row of the table, not the sum. Then make your window end where the data ends.

### M7 — A dashboard

Save the M2 search as a new dashboard panel, add the M4 table and the M6 single value. Then open
`Edit → Source` and read the XML: `<search>`, `<query>`, `<earliest>`. That is what a dashboard
review looks like in a real team.

Last question: your Single Value panel uses a relative range. What will it show tomorrow morning,
and is that a bug?

### Challenge

Chart the server-error **rate** per day rather than the error count. A rate is not a series Splunk
can draw directly — you have to compute it inside the `timechart`.

> 💡 `timechart` accepts `count(eval(...))` just like `stats` does, and `eval` works on the result.

---

## Answer key

- **M1** — `index=tutorial sourcetype=access_combined_wcookie | timechart span=1h count` over
  *Last 30 days*: **721 rows** (one per hour of the range, gaps included), of which **169** are
  non-empty — the hours the shop actually served traffic. Busiest hour: **395** requests.
  `timechart` invents the empty buckets on purpose: a trend with holes in it lies about its shape.
- **M2** — **9** series by status (200, 400, 403, 404, 406, 408, 500, 503, 505); `200` is
  34 282 / 39 532 = **86,7 %**. By host: 13 628 / 12 912 / 12 992 — a load balancer doing its job.
- **M3** — `limit` defaults to **10** and there are only 9 status values, so `OTHER` never existed:
  nothing to remove. Force it with `limit=3` → columns `200, 408, 503, OTHER`; add `useother=f` and
  you are left with three columns whose total no longer matches 39 532. `by action` adds a **`NULL`**
  column: those are the 19 814 events with no `action` field (lab 00, M3). `usenull=f` hides them.
- **M4** — `| chart count over categoryId by status`, read the `503` column: **STRATEGY** leads among
  real categories. The right orientation for "which categories are failing" is categories on the
  x-axis: the axis carries what you compare, the segments carry what explains.
- **M5** — the `NULL` column is **two populations under one label**:

  | state of `categoryId` | events |
  |---|---|
  | field absent | **22 364** |
  | field present, value is the string `"NULL"` | **2 041** |
  | real category | **15 127** |

  The 2 041 come from the referer: `http://www.buttercupgames.com/category.screen?categoryId=NULL` —
  the site writes the word in its own URLs and extraction dutifully captures it. So `categoryId=*`
  removes the 22 364 absent ones but **keeps** the literal ones; `NOT categoryId=NULL` removes the
  literal ones but **keeps** the absent ones (a negation is true when the field does not exist —
  the mirror image of the `!=` trap in lab 00). What works: `usenull=f`, or the explicit
  `categoryId=* NOT categoryId="NULL"`.
  Take the habit: `NULL`, `null`, `-`, `N/A`, `unknown` are **values** in half the world's logs.
  Before filtering an emptiness, ask the data which emptiness it is.
- **M6** — a Single Value on a time series displays the **last point**. Any window ending *now* ends
  with empty buckets, because the dataset stops a few hours ago. Make the window end where the data
  does — e.g. `earliest=-8d@d latest=@d` with `span=1d` — and you get the last full day plus a trend
  arrow against the day before.
- **M7** — tomorrow the panel shows zero, and that is **correct behaviour**: a relative range empties
  when the source goes quiet, which is exactly how you notice a dead collector in production. Here it
  only means the lab data needs re-shifting (`./setup/lab.sh reindex --yes`).
- **Challenge** — `| timechart span=1d count(eval(status>=500)) as err, count as total
  | eval rate=round(err*100/total,2)` → the daily 5xx rate sits between **5,03 %** and **6,31 %**
  across the week. A count chart would have shown the shape of your **traffic**; the rate chart shows
  the shape of your **reliability**, and they are different pictures of the same data. Anything
  remarkable would stand out against that flat band — which is exactly the reasoning lab 08 needs.
