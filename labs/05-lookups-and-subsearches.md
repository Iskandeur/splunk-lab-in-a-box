# Lab 05 — Lookups and subsearches

**Day 6.** The sales logs contain nothing but codes. Today you turn `Code=B` into "Dream Crusher,
€24.99" — which is the moment logs become business information, and the most reusable skill in the
course.

**Time:** 30 min · **Range:** *Last 30 days* everywhere.

**Before you start:** labs 00–04.
**After this lab you can:** enrich events from a reference file, check that the enrichment is
complete, filter one source by the contents of another, and — the mission that pays for the whole
course — tell a busy address from a dangerous one.

This lab is written as **missions**: a business request, a deliverable, a hint if you are stuck, and
an answer key holding both the query and the figure. **If your figure matches, your query is right,
even if it looks nothing like mine.** There are ten ways to write any SPL.

It is also the most useful lab of the six: a lookup is what turns `Code=B` into "Dream Crusher,
€24.99" — logs into business information.

---

## Concepts

### A lookup is a join against a file

Splunk keeps CSV files as *lookup table files*, and you reference them through a *lookup definition*
(a name pointing at a file, plus optional matching rules). Two files ship with this lab, already in
`Settings → Lookups → Lookup table files`:

- `prices.csv` — `productId`, `product_name`, `price`, `sale_price`, `Code` (16 products)
- `http_status.csv` — `status`, `status_description`, `status_type` (19 codes)

Three commands:

| command | direction | typical use |
|---|---|---|
| `\| inputlookup prices.csv` | file → results | inspect the file, or use it as a source |
| `\| lookup prices_lookup Code OUTPUT product_name` | file → events | enrich events |
| `\| outputlookup top_ips.csv` | results → file | build a watchlist |

`inputlookup` is a *generating* command: it creates the result stream, so it starts the pipeline
after a bare `|`, with no `index=`.

`OUTPUT` overwrites a field of the same name if it exists; `OUTPUTNEW` only fills it when empty.

**Automatic lookups** (`Settings → Lookups → Automatic lookups`) apply a lookup to a sourcetype
without anyone writing `| lookup` — the enriched field simply appears in the sidebar. Powerful, and
worth knowing precisely because it makes fields appear that are in no raw event.

### Enrich late, not early

`lookup` runs **once per event**. Enriching 30 000 events to decorate 14 distinct codes is 30 000
lookups for 14 answers. When the looked-up value is constant for a key, aggregate first and enrich
after — same numbers, a fraction of the work. Lab 05 measures the difference.

### A subsearch is a filter computed first

```
outer search [ search ... | fields foo ]
```

Splunk runs the bracketed search **first**, turns each returned row into `field=value` constraints
joined with `OR`, and only then runs the outer search. Hence the golden rule: **a subsearch must
return only fields that exist in the outer search** — which is what the trailing `| fields x` is
for. Every extra column becomes an extra constraint, and a constraint on a field the outer events do
not have matches nothing.

Limits to know: a subsearch stops at **10 000 rows** or **60 seconds**, and it fails **silently** —
truncated result, no error. That is why a well-written `stats` beats a subsearch as soon as volume
grows.

---

## Missions

### M0 — Read the catalogue

**Request:** "Before you plug anything in, show me what is in that price file, and tell me which
product has the deepest discount **in percent**."

**Deliverable:** the number of products, and the name plus percentage of the deepest discount.

> 💡 Reading a lookup file does not involve events. And watch your sort key: the biggest discount in
> euros and in percent are two different products.

### M1 — Wire the catalogue in (UI)

`Settings → Lookups → Lookup definitions → New Lookup Definition`, app `Search & Reporting`, name
**`prices_lookup`**, type *File-based*, file `prices.csv`. Do the same for `http_status.csv` as
**`http_status_lookup`**.

### M2 — Revenue per product

**Request from the sales director:** "Which product earns the most? Top 5 by actual revenue, with the
number of sales next to it."

**Deliverable:** `product_name | revenue | sales`, sorted, five rows.

Then answer: one product in your top 5 sells **more** than another while earning **less**. Which,
and what does that tell you?

> 💡 The price actually paid is `sale_price`, not `price`.

### M3 — What the discount cost

**Request from finance:** "We sold at a discount all year. How much did we leave on the table
compared to catalogue price?"

**Deliverable:** one number, two decimals.

### M4 — Site health in plain words

**Request:** "How many requests succeeded, how many were client errors, how many server errors? I do
not want to read three-digit codes."

**Deliverable:** three rows, `status_type | count`.

### M5 — The check nobody runs

Does your M4 table add up to the full 39 532? If the reference file were missing a code, **nothing
would tell you**: the field would be empty and your totals would quietly stop matching.

**Deliverable:** a query that returns **0** if and only if every status code in the data is covered
by the lookup — and the number it would return if one were missing.

> 💡 After the `lookup`, hunt for events whose output field is absent.

### M6 — Subsearch

**Request:** "Do our expensive products (catalogue price above €30) actually sell? Give me the
purchase count for each, from the web logs."

The catch: the list of expensive products lives in the **CSV**, the purchases live in the **events**.

**Deliverable:** `productId | count`, and the total.

> 💡 `... action=purchase [ | inputlookup ... | where ... | fields <one field> ]`.
> Then remove the `| fields` and watch the search return nothing. That failure is the lesson.

### M7 — The analyst's real reflex

**The alert:** "An IP is throwing 5xx errors at us. Find it."

- **Step A** — the naive answer: which IP produces the **most** 5xx errors?
- **Step B** — the better question: which IP has the highest error **rate**? Compare it to the
  site-wide rate. Keep only IPs with at least 300 requests.
- **Step C** — conclude: is the step A address actually responsible?
- **Step D** — the step almost nobody takes: how many **standard deviations** from normal is your
  step B winner? A ranking always returns a first place, even when there is nothing to find.

**Deliverable:** both rankings, the site-wide rate, a sigma count, and a one-sentence verdict.

> 💡 `count(eval(status>=500))` counts a sub-population inside the same `stats` as the total.
> ⚠️ Where you place `eventstats` relative to `where` decides whether your "global" rate is global.

### M8 — Build a watchlist

**Request from security:** "Give me the 10 busiest IPs in a file, we will monitor them."

**Deliverable:** a lookup file created by the query, and proof that it reads back.

### Challenge

Which reseller carries the widest catalogue — the most distinct products sold? Rank them, then look
at the top of your ranking before answering.

---

## Answer key

**M0** — `| inputlookup prices.csv | stats count` → **16** products.
```
| inputlookup prices.csv | eval discount=round((price-sale_price)/price*100,2) | sort - discount
```
→ **Puppies vs. Zombies** (4.99 → 1.99, **−60,1 %**), then *Fire Resistance Suit of Provolone*
(−50,13 %) and *Holy Blade of Gouda* (−50,08 %) — a tie only if you round to one decimal. The most
expensive product is *Pony Run* (49.99 → 41.99). Sorting by discount **in euros** instead gives a
completely different podium (Dream Crusher, €15 off but only 37,5 %): the question dictates the sort
key, and "our biggest discounts" means two different things to finance and to marketing.

**M2** —
```
index=tutorial sourcetype=vendor_sales
| lookup prices_lookup Code OUTPUT product_name, sale_price
| stats sum(sale_price) as revenue, count as sales by product_name | sort 5 -revenue
```
(`sort 5 -revenue` limits inside the sort — cheaper than `| sort -revenue | head 5`.)

| product | revenue | sales |
|---|---|---|
| Dream Crusher | 73 595,55 | 2 945 |
| World of Cheese | 58 810,58 | 2 942 |
| SIM Cubicle | 53 484,52 | **3 148** |
| Manganiello Bros. | 51 354,45 | 2 055 |
| Mediocre Kingdoms | 38 140,92 | 1 908 |

**SIM Cubicle sells the most and ranks third**: 16.99 against 24.99 for Dream Crusher. Volume is not
revenue — the inversion a "top sellers" dashboard hides and a "top revenue" dashboard reveals.

**M3** — catalogue **622 064,56**, collected **434 761,56**, so **187 303,00 €** left on the table
over 30 244 sales (30 % of catalogue value).

**M4** — `Success` **34 282** · `Client Error` **3 085** · `Server Error` **2 165**. Total 39 532 ✓.

**M5** —
```
... | lookup http_status_lookup status OUTPUT status_type | where isnull(status_type) | stats count
```
→ **0**. An earlier version of this lab shipped an `http_status.csv` without code **406**, present
710 times: this same query returned 710, and nothing else in Splunk said a word. **An incomplete
lookup never complains — it leaves a hole.** Write this check every time you wire up a reference
file.
(Do not test the emptiness by turning it into a string: `if(isnull(x),"NULL",x)` then
`search x=NULL` also catches events whose real value is the word `NULL` — see lab 02, M5.)

**M6** —
```
index=tutorial sourcetype=access_combined_wcookie action=purchase
  [| inputlookup prices.csv | where price > 30 | fields productId]
| stats count by productId
```
→ `DC-SG-G02` **226**, `MB-AG-G07` **223**, `FI-AG-G08` **163**, `SF-BVS-01` **1** — **613**
purchases. Without `| fields productId`, the subsearch returns every column of the CSV and Splunk
turns them into joined constraints: `(productId=… AND product_name="Dream Crusher" AND price=39.99
AND Code=B) OR (…)`. Since `product_name` and `price` do not exist in web logs, nothing can match.

**M7** —
```
A) ... status>=500 | top limit=1 clientip
B) ... | stats count as n, count(eval(status>=500)) as err by clientip
     | where n>=300 | eval rate=round(err*100/n,2) | sort - rate | head 5
C) ... | stats count as n, count(eval(status>=500)) as err | eval site_rate=round(err*100/n,3)
```
- **A** → `87.194.216.51`, **58** errors. It is also the busiest IP on the site (**1 036** requests).
- **B** → `107.3.146.207` **7,03 %**, `188.138.40.166` 6,76 %, `109.169.32.135` 5,92 %,
  `194.215.205.19` 5,75 %, `128.241.220.82` 5,70 %.
- **C** → site-wide rate **5,477 %**. The step A address sits at 58/1 036 = **5,60 %**, i.e. **1,02×**
  the site. It is not guilty, it is **loud**.

**First conclusion:** an absolute ranking measures volume, not anomaly.

**Second conclusion, the one that matters:** `107.3.146.207` is not guilty either. The yardstick is
not the spread between IPs — that spread already contains sampling noise — it is each IP's own
**binomial standard error**, `sqrt(p(1-p)/n)`:
```
| eventstats sum(err) as E, sum(n) as N      <- before any filter, or it is no longer "the site"
| eval p=E/N, rate=err/n, se=sqrt(p*(1-p)/n), z=round((rate-p)/se,2)
```
→ **highest z = 1,34**. And across the **182** IPs in the dataset, **6** exceed 2σ where chance alone
predicts about **8** (5 % of 182); the largest z observed, **3,02**, is exactly what the maximum of
182 normal draws looks like. **There are fewer anomalies here than randomness manufactures.**

Lab 05 turns this into a working alert, and derives the statistics from scratch.

⚠️ Construction trap in that query: put the `eventstats` **after** `| where n>=300` and your "global"
rate becomes that of the 11 surviving IPs (**5,367 %**) instead of the site (**5,477 %**). The number
stays true; its **name** starts lying. An aggregate computed after a filter no longer describes the
population its name claims.

**M8** —
```
index=tutorial sourcetype=access_combined_wcookie | top clientip limit=10 showperc=f
| outputlookup top_ips.csv
```
then `| inputlookup top_ips.csv`. You have just written a watchlist — the exact pattern behind
blocked-IP lists, sensitive accounts and critical assets in production.
⚠️ `outputlookup` **overwrites without asking**. In production, write to a dated file, or read and
merge first.
- **Challenge** — `| stats dc(Code) as products, count as sales by VendorID | sort - products` →
  the maximum is **14** distinct products, and **219 vendors** are tied at it. "The widest catalogue"
  has no single answer here, and a dashboard showing "top vendor by variety" would display whichever
  of the 219 the sort happened to put first, differently on each run. When a ranking is topped by a
  large tie, the ranking is the wrong question — ask for the distribution instead
  (`| stats count by products`).
