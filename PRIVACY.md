# Privacy

Splunk Lab in a Box (the repository and the Claude Code plugin) collects no data and sends
nothing to its author. There is no server, no analytics and no account.

What runs, and where:

- Everything runs on your machine. The Splunk container publishes its web interface on
  `127.0.0.1` only.
- `setup/lab.sh load` downloads Splunk's public tutorial dataset and prices lookup from
  `docs.splunk.com`. Those requests go to Splunk, under Splunk's terms.
- The admin password is generated locally and stored in a local `.env` file (mode 600) that is
  never committed.
- Splunk Enterprise itself may offer to share usage data with Splunk. That is Splunk's feature,
  governed by Splunk's privacy policy, and can be turned off in Splunk Web under
  *Settings > Instrumentation*.
- What you type to Claude is handled by Anthropic under your own Claude account's terms; this
  project adds no other recipient.

Questions: open an issue on https://github.com/Iskandeur/splunk-lab-in-a-box/issues.
