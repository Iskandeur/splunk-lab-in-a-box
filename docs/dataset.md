# The dataset, and its three traps

The lab indexes the official Splunk *Search Tutorial* data — a fictional online game shop called
Buttercup Games — into an index named `tutorial`, which is also the **default search index** for the
`admin` role. A search without `index=` therefore reaches it, and you can paste examples from any
Splunk course unchanged.

## What is in it

**109 864 events**, 5 hosts, 8 sources, 3 sourcetypes, spanning a bit over **7 days** and ending
within the last 24 hours (see *time shifting* below).

| sourcetype | hosts | events | content |
|---|---|---|---|
| `access_combined_wcookie` | www1, www2, www3 | 39 532 | Apache web logs of the shop |
| `secure-2` | www1, www2, www3, mailsv | 40 088 | SSH authentication logs |
| `vendor_sales` | vendor_sales | 30 244 | reseller sales: `VendorID`, `Code`, `AcctID` |

Useful fields on the web logs: `clientip`, `status`, `bytes`, `action`, `categoryId`, `productId`,
`itemId`, `JSESSIONID`, `referer_domain`, `useragent`, `method`, `uri_path`, `file`.

Lookups installed in `Settings → Lookups → Lookup table files`:

- **`prices.csv`** — 16 products: `productId`, `product_name`, `price`, `sale_price`, `Code`
- **`http_status.csv`** — 19 codes: `status`, `status_description`, `status_type`

Lookup **definitions** are deliberately *not* created: creating them is an exercise (lab 04, M1).

## Trap 1 — the dataset is time-shifted, so weekdays are meaningless

The vendor's archive already ends a day or two before you download it, which would make *Today* and
*Last 24 hours* empty and the whole time module impossible. `setup/shift-times.py` therefore moves
every timestamp forward by a **whole number of days** at load time.

Whole days are deliberate: the hour-of-day distribution is preserved (timecharts still look like real
traffic) and no event lands in the future. The cost is that **weekday names rotate with the shift**.
Any statement about "the busiest day of the week" in this lab is an artifact. Hour-of-day is safe.

Practical consequence: after a few days the data ages out of the short relative ranges. When
`./setup/lab.sh status --json` reports `data_age_hours` above ~36, run `./setup/lab.sh reindex --yes`.

## Trap 2 — `secure-2` timestamps are clustered, and its fields are missing

Measured on 2026-09-15: **18 distinct timestamps for 40 088 events**. The vendor regenerates the
archive from time to time and that number moves (it was 8 on an earlier download), so measure it
rather than quoting it: `| stats dc(_time)`. Either way the conclusion holds — a `timechart` on
`secure-2` shows a few tall spikes that look exactly like an attack and are an artifact of the file.

`secure-2` also arrives with **almost nothing extracted**: no user, no source IP, just text. That is
not a loading failure, it is the raw material of lab 01 (`rex`) and lab 06 (permanent field
extractions).

And a detail that becomes the point of a whole mission: **184 of its events write `failed password` in
lowercase**. Splunk's search terms are case-insensitive so a term search finds them, but a regex is
case-sensitive and silently drops them — and those 184 events are exactly the *internal* failures,
the only ones an analyst would care about.

Use `access_combined_wcookie` for anything involving time. `vendor_sales` is synthetically flat
(exactly 180 events per hour), which makes it good for statistics and useless for trends.

## Trap 3 — `categoryId` contains the literal string `"NULL"`

| state of `categoryId` | events |
|---|---|
| field absent | 22 364 |
| field present, value is the string `"NULL"` | 2 041 |
| a real category | 15 127 |

The 2 041 come from the referer URL: `http://www.buttercupgames.com/category.screen?categoryId=NULL`.
The site writes the word in its own links and field extraction captures it faithfully.

Both populations show up in a chart under one column named `NULL`, and each requires a different
filter: `categoryId=*` removes the absent ones, `NOT categoryId=NULL` removes the literal ones.
Lab 01, M5 is built on this.

## Figures that are stable, and figures that are not

Stable regardless of when you load (the shift moves whole days):

- every total and every breakdown by host, sourcetype, status, action, category, vendor;
- the hour-of-day distribution (busiest hour 03:00 with 2 378 web events);
- 169 non-empty hourly buckets, peak 395 requests in one hour;
- 43 non-empty 4-hour buckets; 5 297 distinct sessions; 182 distinct client IPs;
- the site-wide 5xx rate: 2 165 / 39 532 = 5,477 %.

Not stable — they depend on the hour you run them:

- anything using `Last 24 hours`, `Yesterday`, `Today` or a calendar date;
- weekday names, as explained above.

The labs mark which is which.

## Trap 4 — every web client also appears in the SSH logs

All **182** distinct `clientip` values of the web logs are among the **185** source addresses of the
SSH failures. In a real network that would be extraordinary; here it means the two sources were
generated from one pool of addresses.

It is left in on purpose: lab 08 walks the learner into running that correlation and reading the
number. **A correlation of 100 % is a statement about your pipeline, not about an adversary.**
