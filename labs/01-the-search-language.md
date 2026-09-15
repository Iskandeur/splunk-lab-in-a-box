# Lab 01 — The search language

**Day 2.** Yesterday you learned to find events. Today you learn to *shape* them: rename, compute,
classify, extract. This is the lab that turns Splunk from a search engine into a tool.

**Time:** 25 min · **Range:** *Last 30 days* everywhere.

**Before you start:** lab 00.
**After this lab you can:** build fields that do not exist in the data, classify events by rule,
clean up a messy table, and extract structure from an unstructured log line with `rex`.

---

## Concepts

### Choosing columns: `fields`, `table`, `rename`

```
| fields clientip, status          keep only these (and speed the pipeline up)
| fields - punct, useragent        drop these
| table clientip, status, bytes    keep, in this order, as a table
| rename clientip as "Client IP"   presentation
```

`fields` is a projection, not a filter — it removes **columns**, never rows. Confusing the two costs
people an hour at least once. Put `| fields` early when you know what you need: everything after it
carries less data.

### Computing: `eval`

`eval` creates or overwrites a field. Its function library is where most of your daily work happens:

```
| eval kb = round(bytes/1024, 2)
| eval is_error   = if(status >= 400, "yes", "no")
| eval class      = case(status < 300, "success", status < 500, "client error", 1==1, "server error")
| eval label      = coalesce(product_name, productId, "unknown")     first non-null wins
| eval host_up    = upper(host)
| eval when       = strftime(_time, "%F %H:%M")
| eval path_len   = len(uri_path)
```

`case()` takes pairs of (condition, value) and stops at the first true one; `1==1` is the idiomatic
"else". There is no `else` keyword.

⚠️ **Quoting rule that bites everyone:** in `eval`, `"text"` is a literal string and `field` is a
field. A field whose *name* looks like a number must be wrapped in single quotes: `'403'` is the
field, `403` is the number. `| eval total = 200 + 403` silently computes 603.

### Filtering after the pipe: `where` vs `search`

```
| search status=200 bytes>2000       index-style syntax, wildcards allowed
| where status=200 AND bytes>2000    expression syntax, can compare TWO FIELDS
| where bytes > avg_bytes            impossible with `search`
```

Use `search` for simple value filters, `where` when you need a function (`isnull`, `match`, `like`,
`len`) or a comparison between fields. And keep in mind — lab 07 measures it — that `search` can be
lifted back into the base search by the optimiser, while `where` never is.

### Deduplicating and sorting

```
| dedup clientip                   first event per value (keeps the rest of the event)
| dedup clientip sortby -bytes     first after sorting
| sort - bytes                      descending; `sort 5 -bytes` also limits to 5
```

`dedup` keeps whole events, `stats` summarises them. When you only need a distinct list,
`| stats count by clientip` is cheaper and clearer than `| dedup clientip | table clientip`.

### Filling the gaps

```
| fillnull value=0 status_count      nulls become 0
| fillnull value="unknown"           everywhere
```

A null is not a zero. Deciding it should be is a statement about meaning — do it on purpose, not by
reflex.

### Extracting what was never extracted: `rex`

Some sourcetypes arrive with almost nothing extracted. Look at an SSH line from `secure-2`:

```
Mon Sep 14 2026 06:46:07 mailsv1 sshd[5276]: Failed password for invalid user appserver from 194.8.74.23 port 3351 ssh2
```

There is no `user` field and no source IP field — Splunk sees one blob of text. `rex` creates fields
at search time with a named-capture regex:

```
| rex "password for (invalid user )?(?<user>\S+) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
```

Things to know before you fight it for an hour:

- `(?<name>...)` names a capture group; that name becomes the field.
- `rex` is **case sensitive** by default. Prefix with `(?i)` to fold case — and read the warning in
  mission M6 before you decide you do not need it.
- events that do not match are left **untouched**, not dropped. That silence is the usual reason a
  count is lower than expected.
- `| rex mode=sed "s/\d/x/g"` rewrites a field instead of extracting from it.

`rex` is the search-time version. Lab 06 turns the same regex into a permanent field extraction so
that nobody ever has to type it again.

---

## Missions

### M1 — A readable table

**Request:** "Give me the fifty largest web responses, as a table: time, client, page, size in
kilobytes — and I want readable column names."

**Deliverable:** the query, and the size of the largest response in KB.

> 💡 `eval` for the conversion, `table` for the columns, `rename` for the labels, `sort` for the
> ranking.

### M2 — Classify by rule

**Request:** "Split the web traffic into success, client error and server error. I do not want to see
status codes."

**Deliverable:** three rows with counts. Keep the query — lab 05 does the same thing with a lookup
file, and you will compare.

> 💡 `case()`, then `stats count by` your new field.

### M3 — Two fields, one comparison

**Request:** "How many responses are bigger than the average response of their own server?"

**Deliverable:** one number.

> 💡 You cannot compare a field to another field with `search`. And you need the average attached to
> each event — lab 04 names that command, but you can find it: it is `stats`' sibling that *adds* a
> column instead of replacing the stream.

### M4 — Clean up a sparse table

Produce the average response size per host and per status as a matrix. Some cells are empty. Make
them read `0` instead, then explain in one sentence why that may be a lie.

### M5 — Build the fields nobody built for you

**Request:** "Our SSH logs are unusable — nothing is extracted. I want to know which accounts are
being targeted and from where."

**Deliverable:** a query using `rex` that produces `user` and `src_ip`, then the five most targeted
accounts and the five loudest source addresses.

> 💡 Start from one raw event (`sourcetype=secure-2 | head 1`), write the regex against *that* line,
> and check your field count before trusting it: `| stats count(user) as extracted, count as total`.

### M6 — The silence that costs you

Run your M5 extraction and compare `count(user)` with the number of events containing the word
*password*. You will be short by **184** events. Find them.

> 💡 Search terms are case-insensitive. Regular expressions are not.

### Challenge

Write a single search that returns, for each SSH source address: the number of failures, the number
of successes, and a `verdict` column reading `"compromised"` if it ever succeeded and `"noise"`
otherwise. You will need `rex`, `count(eval(...))` and `case()` — and the answer is the backbone of
lab 08.

---

## Answer key

- **M1** — `| eval kb=round(bytes/1024,2) | table _time clientip uri_path kb | rename ... | sort 50 -kb`.
  The largest response is **4 000 bytes = 3,91 KB**: this dataset is capped, which you would want to
  know before writing an alert on response size.
- **M2** — `| eval class=case(status<300,"success",status<500,"client error",1==1,"server error")
  | stats count by class` → **success 34 282**, **client error 3 085**, **server error 2 165**.
  (Lab 05 produces the same three numbers from `http_status.csv` — a rule you wrote by hand versus a
  reference file you can share. The second one scales, the first one is faster to write.)
- **M3** — `| eventstats avg(bytes) as host_avg by host | where bytes > host_avg | stats count` →
  **19 744**, which is *exactly* the figure you get against the **global** mean (lab 04, M5). That
  identity is not a law, it is a property of this dataset: the three servers have statistically
  identical response-size distributions, so grouping by host moves nothing. On real data the two
  definitions diverge, and choosing between "above average" and "above its own group's average" is
  a modelling decision — a server that is slow for everyone should not look normal just because all
  its own responses are slow.
- **M4** — `| chart avg(bytes) over host by status | fillnull value=0`. Empty cells come from
  host/status pairs that never occurred (www1 and www3 have no `403`, www2 no `505`). Writing 0 there
  claims "the average size was zero" when the truth is "there was nothing to measure" — fine for a
  graph, wrong for a calculation.
- **M5** —
  ```
  index=tutorial sourcetype=secure-2
  | rex "(?i)password for (invalid user )?(?<user>\S+) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
  | top limit=5 user
  ```
  → `root` **1 493**, `administrator` 1 020, `admin` 938, `operator` 923, `mail` 753. Loudest
  sources: `87.194.216.51` **948**, `211.166.11.101` 743, `128.241.220.82` 622. Overall the
  extraction yields **154 distinct accounts** and **185 distinct addresses**.
  A list of targeted accounts made only of `root`, `administrator`, `admin`, `operator`, `mail` is
  the signature of an untargeted, automated sweep — nobody who knows your company guesses `operator`.
- **M6** — the missing 184 events say **`failed password`** in lowercase. A case-sensitive regex
  ignores them silently; `(?i)` catches them. And the punchline, which you will meet again in lab 08:
  those 184 lowercase events are exactly the **internal** failures. The variant you would have
  dropped is the one that matters.
- **Challenge** —
  ```
  index=tutorial sourcetype=secure-2 password
  | rex "(?i)password for (invalid user )?(?<user>\S+) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
  | stats count(eval(match(_raw,"(?i)failed"))) as failures,
          count(eval(match(_raw,"(?i)accepted"))) as successes by src_ip
  | eval verdict=case(successes>0,"got in",1==1,"noise")
  | where successes>0
  ```
  Three addresses ever succeeded — and all three are `10.x.x.x`. Lab 08 turns that into an
  investigation.
