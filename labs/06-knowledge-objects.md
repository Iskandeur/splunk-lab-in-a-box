# Lab 06 — Making knowledge stick

**Day 7.** Everything you have built so far died when you closed the tab. Today you make it
permanent: a regex becomes a field for everyone, a search becomes a report, a report becomes an
alert, and a pile of events becomes a named concept.

**Time:** 30 min · **Range:** *Last 30 days*.

**Before you start:** labs 00–05 (you need the `rex` from lab 01 and the alert reasoning from 05).
**After this lab you can:** hand your work to a team instead of retyping it, and understand why a
field can exist for you and not for your colleague.

---

## Concepts

Splunk calls all of this **knowledge objects**: things that live in configuration rather than in
data. They share three properties that explain most team confusion:

1. they apply **at search time**, so they affect old data retroactively;
2. they belong to an **app** and to an **owner**, and they are **private until shared**;
3. they are configuration, so they can be exported, reviewed and versioned — which is how grown-up
   teams manage them.

### Field extractions

`| rex "..."` works for one search. A **field extraction** applies the same regex automatically to
every event of a sourcetype, for everyone. The UI path is `Settings → Fields → Field extractions →
New`, or the **Interactive Field Extractor** (IFX) reached from any event: `Event Actions → Extract
Fields`, which writes the regex for you from examples.

The trade-off worth understanding: an extraction is applied to **every search** on that sourcetype,
so a greedy or slow regex taxes everyone, forever.

### Reports

A saved search. Give it a name and a time range, and it becomes a report others can run. Schedule it
and Splunk runs it for you, on a cron, storing the results — which is what makes dashboards fast and
alerts possible.

### Alerts

A scheduled report with a trigger condition and actions (email, webhook, script). Lab 07 covers the
part nobody does: computing a threshold so it fires when something happens and stays quiet otherwise.

### Event types and tags

An **event type** names a *class* of events: `sourcetype=secure-2 "failed password"` becomes
`eventtype=ssh_failure`. You then search `eventtype=ssh_failure` and never retype the definition —
and if the underlying logic changes, it changes in one place.

A **tag** is a label you attach to a field value or an event type: tag `ssh_failure` as
`authentication` and `failure`, and a search for `tag=failure` finds SSH failures, web 5xx and
anything else you tagged the same way — across sourcetypes that share nothing.

That is the whole idea behind normalisation frameworks like Splunk's CIM: detections written against
**concepts** (`tag=authentication`, `src_ip`) survive a change of product; detections written against
one vendor's field names die with that product.

### Macros

A named, reusable SPL fragment, with arguments: `` `failed_by_ip(5)` `` expands into a search. It is
the function of the SPL world, and the honest answer to copy-pasting the same six lines into eleven
dashboards.

---

## Missions

### M1 — Make your regex permanent

**Request:** "Nobody else should ever have to write that SSH regex again."

Turn the lab 01 extraction into a **field extraction** on `sourcetype=secure-2` producing `user` and
`src_ip`. Verify by running a search that uses those fields **without** any `rex`.

> 💡 `Settings → Fields → Field extractions → New Field Extraction`, type *Inline*, sourcetype
> `secure-2`, and your named-capture regex. Remember the `(?i)` — lab 01, M6 explains what it costs
> you to forget it.

**Then answer:** your colleague logs in and does not see the fields. Why, and what do you change?

### M2 — Name a class of events

**Request:** "I want to be able to search for authentication failures without remembering how each
product words them."

Create an **event type** `ssh_failure` covering failed SSH passwords, then tag it with
`authentication` and `failure`. Prove it works by counting `eventtype=ssh_failure`, then by counting
`tag=failure`.

> 💡 `Settings → Event types`, then `Settings → Tags → List by tag name`.

### M3 — A report worth scheduling

**Request:** "Every morning I want yesterday's top ten targeted accounts."

Build it, save it as a report, schedule it daily, and make the time range **snapped** so it means the
same thing whatever minute it runs.

**Deliverable:** the query, the schedule, and one sentence on why `-1d@d` to `@d` and not `-24h`.

### M4 — A macro

**Request:** "Three dashboards repeat the same five lines."

Create a macro `ssh_failures_by_ip(1)` taking a minimum-count argument and returning the source
addresses above it. Use it in a search.

> 💡 `Settings → Advanced search → Search macros`. The argument is `$count$` inside the definition,
> and the macro is called between backticks.

### M5 — Sharing, and the trap

Look at your four objects in their settings pages and note their **owner** and **sharing** status.
Set the event type and the field extraction to app-level sharing, and leave the report private.

**Then answer:** a teammate builds a dashboard on `eventtype=ssh_failure` while it is still private
to you. What do they see, and when do they find out?

### Challenge

Export your knowledge objects as configuration: find where Splunk wrote them
(`$SPLUNK_HOME/etc/users/...` versus `$SPLUNK_HOME/etc/apps/search/local/...`) and read the stanzas.
In this lab:

```
./setup/lab.sh spl '| rest /services/admin/props-extract | table title eai:acl.owner eai:acl.sharing'
```

Understanding that these are text files in an app directory is what lets a team put them in git, and
it is the difference between a Splunk you can hand over and one that lives in someone's browser.

---

## Answer key

- **M1** — after the extraction exists,
  `index=tutorial sourcetype=secure-2 | top limit=5 user` returns `root` **1 493**,
  `administrator` 1 020, `admin` 938 — the lab 01 figures, with no `rex` in sight. Your colleague
  sees nothing because a new extraction is **private to its creator** until you share it at app or
  global level (`Settings → Fields → Field extractions → Permissions`). This is the single most
  common "it works on my machine" in Splunk.
- **M2** — `eventtype=ssh_failure` returns **33 253** events (the same count as the lab 01
  extraction, including the 184 lowercase ones if your definition is case-insensitive — check it).
  `tag=failure` returns the same set today, and would return more the day you tag web 5xx the same
  way. That is the point: you are building a vocabulary, not a shortcut.
- **M3** — `index=tutorial sourcetype=secure-2 eventtype=ssh_failure | top limit=10 user`, range
  `-1d@d` to `@d`, cron `0 6 * * *`. Snapped, because a report titled "yesterday" that actually
  covers "the last 24 hours" produces a different number depending on the minute it runs, and nobody
  will ever notice — they will just stop trusting the report.
- **M4** — definition: `search index=tutorial eventtype=ssh_failure | stats count by src_ip
  | where count > $count$`, one argument. Called as `` `ssh_failures_by_ip(500)` `` → **five**
  addresses on this dataset.
- **M5** — a private object is invisible to everyone else, and their dashboard silently returns
  **zero results** rather than an error. They find out when a user asks why the panel is empty, which
  is usually weeks later. Share at app level, or expect that phone call.
