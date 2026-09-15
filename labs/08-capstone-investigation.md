# Lab 08 — Capstone: the 3 a.m. page

**Day 10.** You are on call. This is the whole course in one investigation: no new commands, only
everything you already know, in the order a real analyst uses it.

**Time:** 45 min · **Range:** *Last 30 days* unless you need otherwise.
**Before you start:** labs 00–07.

---

> **The page.** 03:07. Your monitoring counted **33 000 failed SSH logins** across the estate.
> The CTO is awake and wants three things, in this order: *are we breached, what do we do now, and
> what do we do so this page never wakes anyone again.*

You have SSH logs (`secure-2`), web logs (`access_combined_wcookie`), reseller sales
(`vendor_sales`), and forty-five minutes. Work through the stages before reading any answer — the
whole point is the order of the questions, not the SPL.

---

## Stage 1 — Scope it before you panic

Answer, with one query each:

1. how many failed authentications, over what period?
2. how many distinct accounts were targeted, and which five most?
3. how many distinct source addresses, and which five loudest?

> 💡 Nothing is extracted in `secure-2` — this is the `rex` from lab 01. If you completed lab 06, you
> already have permanent `user` and `src_ip` fields and can skip straight to the counting.

**Then stop and characterise.** Look at your list of targeted accounts. Does it look like someone who
knows your company, or like someone who knows nothing about it?

## Stage 2 — The only question that matters tonight

Everything above is noise until you answer this one: **did anyone get in?**

Write the single query that answers it — for every source address, how many failures and how many
successes — and do not settle for "no successes in the top 10". You want the complete answer.

> 💡 `count(eval(...))` counts a sub-population inside the same `stats`. You are looking for a row
> where the success count is greater than zero.

## Stage 3 — Now look at who succeeded

You will find a short list. For each successful address, ask:

1. is it inside or outside the network?
2. did it also fail, and does the ratio look like an attacker or like a human with a keyboard?
3. is the account name random, or is it a person?

## Stage 4 — The loudest is not the threat

The noisiest source address in your SSH logs is also the busiest client in your **web** logs. That
looks like a targeted actor casing the shop.

Test it properly: compute that address's web error rate and compare it to the site's. Then rank
addresses by error **rate** rather than by volume, as in lab 05.

## Stage 5 — The evidence that is too good

Now run the correlation everyone runs at this point: how many of your SSH source addresses also
appear in the web logs? Use a subsearch (lab 05).

Look hard at the number before you write it in a report.

## Stage 6 — Deliver

Three artefacts, in the order the CTO asked for them:

1. **The brief** — three sentences, no SPL: what happened, what the impact is, what you recommend.
2. **A dashboard** with three panels: failures over time, top targeted accounts, and a table of any
   address that ever succeeded.
3. **An alert** that would fire on a *real* event rather than on this noise — the design work of
   lab 07. State the query, the window, the threshold and the throttling, and justify the threshold
   with a false-alert count.

## Stage 7 — Debrief

Write down, for yourself:

- which of your first three hypotheses turned out to be about the data rather than about an attacker;
- which query you would have shipped as an alert before doing stage 4, and how many pages a night it
  would have produced;
- what you would have missed if your regex had been case-sensitive.

---

## Answer key

### Stage 1

```
index=tutorial sourcetype=secure-2 "failed password"
| rex "(?i)password for (invalid user )?(?<user>\S+) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
| stats count, dc(user) as accounts, dc(src_ip) as sources
```
**33 253** failures, **154** accounts, **185** source addresses, spread over the seven days of the
dataset. Top accounts: `root` **1 493**, `administrator` 1 020, `admin` 938, `operator` 923,
`mail` 753.

That list is the signature of an **untargeted sweep**. Nobody who has researched your company guesses
`operator`; these are the default names in every scanner's wordlist. An attacker who knew you would
be trying the names on your Confluence.

### Stage 2

```
index=tutorial sourcetype=secure-2 password
| rex "(?i)password for (invalid user )?(?<user>\S+) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
| stats count(eval(match(_raw,"(?i)failed")))   as failures,
        count(eval(match(_raw,"(?i)accepted"))) as successes by src_ip
| where successes > 0
```

| src_ip | failures | successes |
|---|---|---|
| 10.3.10.46 | 121 | 955 |
| 10.2.10.163 | 47 | 478 |
| 10.1.10.172 | 16 | 166 |

Cross-tabulated, the whole picture is four numbers:

| scope | outcome | events |
|---|---|---|
| external | failure | **33 069** |
| internal | failure | 184 |
| internal | success | 1 599 |
| **external** | **success** | **0** |

**Nobody got in.** Not one external address ever authenticated successfully. You can tell the CTO to
go back to bed in the first ninety seconds of the investigation, and everything after this is about
noise reduction rather than incident response.

### Stage 3

The three successful addresses are all **RFC 1918 internal** (`10.x.x.x`), the accounts are people
(`djohnson`, `nsharpe`, `myuan`), and the failure-to-success ratios (121/955, 47/478, 16/166) are
about one fumbled password in eight — exactly what humans with keyboards produce. An attacker who had
guessed a password would show the opposite shape: hundreds of failures, then a success, then no more
failures.

### Stage 4

`87.194.216.51` is the loudest SSH source (**948** failures) *and* the busiest web client
(**1 036** requests). Tempting. But its web error rate is 58/1 036 = **5,60 %**, against a site-wide
**5,477 %** — it is **1,02×** the average. It is not casing anything; it is simply the loudest thing
pointed at you. Ranking by rate instead of volume (lab 05) puts `107.3.146.207` on top at 7,03 %,
and even that is **1,34 σ** from normal, which is nothing.

**Volume measures how noisy something is. Anomaly is a ratio.** Confusing them is how a team spends a
night on the most talkative innocent on the internet.

### Stage 5

```
index=tutorial sourcetype=access_combined_wcookie
  [ search index=tutorial sourcetype=secure-2 "failed password"
    | rex "(?i) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
    | stats count by src_ip | rename src_ip as clientip | fields clientip ]
| stats dc(clientip) as ips_in_both
```

→ **182**. And the web logs contain exactly **182** distinct client addresses in total.

**Every single one of your web visitors also brute-forced your SSH.** Written in a report, that
sentence would start a war. It is of course impossible: it means the two log sources were generated
from the same pool of addresses — which they were, this is a teaching dataset.

Keep the reflex, it is the real lesson of this lab: **a correlation of 100 % is not evidence, it is a
symptom of your pipeline.** Before you accuse anyone, ask what would have to be true for the number
to be real, and whether a mundane explanation — one generator, one NAT gateway, one proxy, one
misconfigured forwarder — produces the same picture more cheaply.

### Stage 6 — the brief

> Between the 7th and the 14th we recorded 33 253 failed SSH authentications from 185 external
> addresses, targeting 154 generic account names — the profile of an automated, untargeted internet
> sweep rather than an attack aimed at us. **No external address authenticated successfully**; all
> 1 599 successful logins came from three internal addresses belonging to named employees, with a
> normal rate of mistyped passwords. No action is required tonight. I recommend we stop paging on
> failure volume, which measures the internet's background noise rather than our risk, and alert
> instead on the event that would actually matter: a successful authentication from outside.

The alert that follows from it is almost embarrassingly simple, and would never have fired this week:

```
index=tutorial sourcetype=secure-2 "accepted password" earliest=-15m@m latest=@m
| rex "(?i)password for (invalid user )?(?<user>\S+) from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
| where NOT match(src_ip, "^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)")
```

Trigger on `> 0` results, throttle by `src_ip` for an hour. **No threshold calculation is needed**,
because the event is rare by construction rather than rare by statistics — and that is the first
thing to look for when designing a detection. A rule that needs four sigma of evidence is a rule
watching the wrong thing; find the event that is *categorically* abnormal and watch that instead.

### Stage 7 — what this course was about

Six habits, in the order you will need them:

1. **Measure before you assert.** Every number above came from a query, and two of them contradicted
   what the analyst expected.
2. **The question before the query.** Stage 2 costs one search and ends the incident; stages 1, 4 and
   5 are context. Asking them in the wrong order is how a two-minute answer becomes a night.
3. **A ranking always returns a first place.** Volume is not anomaly; anomaly is a ratio, and even a
   ratio needs a noise model before it means anything.
4. **Silence is a result.** The 184 lowercase events, the missing 406 in a lookup, an alert that
   never fires: nothing in Splunk tells you about what it did not match.
5. **When the evidence is too clean, suspect the pipeline.** 182 out of 182 is not an adversary.
6. **Write it down where the next person will find it** — a field extraction, an event type, a
   report, an alert. Lab 06 exists because knowledge that lives in your browser tab dies with it.
