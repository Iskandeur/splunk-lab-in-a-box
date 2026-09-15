#!/usr/bin/env bash
# splunk-lab-in-a-box — single entry point for humans and agents.
#
#   ./setup/lab.sh up          start Splunk (generates credentials on first run)
#   ./setup/lab.sh load        download, time-shift and index the tutorial dataset
#   ./setup/lab.sh status      one-line state  (--json for machines)
#   ./setup/lab.sh verify      full health + data check (--json for machines)
#   ./setup/lab.sh spl '<spl>' run a search and print the result table
#   ./setup/lab.sh url         print the web URL
#   ./setup/lab.sh creds       print admin credentials
#   ./setup/lab.sh stop        stop the container (data survives)
#   ./setup/lab.sh reindex     re-shift dates to today and reload (destructive, needs --yes)
#   ./setup/lab.sh destroy     remove container AND volumes (needs --yes)
#
#   ./setup/check-keys.py     replay every answer-key figure against this instance
#
# Requirements: docker + docker compose v2, python3, curl, unzip.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
ENV_FILE="$HERE/.env"
WORK="$HERE/.work"
COMPOSE=(docker compose -f "$HERE/docker-compose.yml" --env-file "$ENV_FILE")
DATA_URL="https://docs.splunk.com/images/Tutorial/tutorialdata.zip"
PRICES_URL="https://docs.splunk.com/images/d/db/Prices.csv.zip"
# docs.splunk.com answers 403 to curl's default user-agent. This is not about what
# exists, it is about who asks. See docs/troubleshooting.md.
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

die() { echo "error: $*" >&2; exit 1; }
say() { echo "==> $*"; }

init_env() {
  [ -f "$ENV_FILE" ] && return 0
  say "first run: generating credentials in setup/.env (gitignored)"
  local pw; pw="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"
  sed "s/^SPLUNK_PASSWORD=.*/SPLUNK_PASSWORD=$pw/" "$HERE/.env.example" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

load_env() { init_env; set -a; . "$ENV_FILE"; set +a; CONT="${LAB_CONTAINER:-splunk-lab}"; }

in_splunk() { docker exec -u splunk "$CONT" "$@"; }

spl() { # spl <search> [earliest] [latest]
  # The time range goes in as CLI arguments, never appended to the query: a bare
  # "earliest=" glued to the end of a piped search lands INSIDE the last command.
  local q="$1" e="${2:--30d}" l="${3:-now}"
  in_splunk /opt/splunk/bin/splunk search "$q" -earliest_time "$e" -latest_time "$l" \
      -auth "admin:$SPLUNK_PASSWORD" -maxout 0 2>&1 \
    | grep -vE '^WARNING: Server Certificate|^$|^INFO: ' || true
}

spl_value() { # first cell of a one-column search, or empty string
  spl "$1" "${2:--30d}" "${3:-now}" | awk 'NR>2 {gsub(/ /,"");print;exit}' || true
}

running() { [ "$(docker inspect -f '{{.State.Running}}' "$CONT" 2>/dev/null || echo false)" = true ]; }
healthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONT" 2>/dev/null || echo none)" = healthy ]; }

cmd_up() {
  load_env
  say "starting Splunk (first boot takes 2-4 minutes: the image runs an internal Ansible playbook)"
  "${COMPOSE[@]}" up -d
  local i=0
  until healthy; do
    i=$((i+1)); [ $i -gt 120 ] && die "container never became healthy — try: docker logs $CONT --tail 60"
    sleep 5
    [ $((i % 6)) -eq 0 ] && echo "   ... still booting (${i}0s)"
  done
  say "Splunk is up: $(cmd_url)"
}

cmd_fetch() {
  load_env; mkdir -p "$WORK"
  if [ ! -s "$WORK/tutorialdata.zip" ]; then
    say "downloading the official tutorial dataset (~2 MB)"
    curl -fsS -A "$UA" -o "$WORK/tutorialdata.zip" "$DATA_URL" \
      || die "download failed. If this is a 403, the site refused the user-agent, not the file."
  fi
  if [ ! -s "$WORK/prices.csv" ]; then
    say "downloading the prices lookup"
    curl -fsS -A "$UA" -o "$WORK/prices.csv.zip" "$PRICES_URL" || die "prices download failed"
    # Extract the named entry only: the archive also carries a macOS resource fork
    # (__MACOSX/._prices.csv) which overwrites the real file if you loop over *.csv.
    python3 - "$WORK" <<'PY'
import sys, zipfile, pathlib
work = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(work / "prices.csv.zip") as z:
    name = next(n for n in z.namelist() if n.lower().endswith("prices.csv") and "__MACOSX" not in n)
    data = z.read(name).decode("utf-8-sig")
# The shipped file has a trailing empty line and a trailing space in one Code value.
lines = [l.rstrip() for l in data.splitlines() if l.strip()]
(work / "prices.csv").write_text("\n".join(lines) + "\n")
print(f"   prices.csv: {len(lines)-1} products")
PY
  fi
  rm -rf "$WORK/raw"; mkdir -p "$WORK/raw"
  unzip -q -o "$WORK/tutorialdata.zip" -d "$WORK/raw"
}

cmd_load() {
  load_env; running || die "container is not running — run: ./setup/lab.sh up"
  cmd_fetch
  say "shifting timestamps so the dataset ends today"
  rm -rf "$WORK/shifted"
  python3 "$HERE/shift-times.py" "$WORK/raw" "$WORK/shifted"
  local stamp; stamp="$(date +%Y%m%d%H%M%S)"
  docker cp "$WORK/shifted" "$CONT:/tmp/data-$stamp" >/dev/null
  docker exec -u root "$CONT" chown -R splunk:splunk "/tmp/data-$stamp"

  say "creating the 'tutorial' index"
  in_splunk /opt/splunk/bin/splunk add index tutorial -auth "admin:$SPLUNK_PASSWORD" >/dev/null 2>&1 || true

  say "indexing (one oneshot per file, host name taken from the folder)"
  for d in www1 www2 www3 mailsv vendor_sales; do
    for f in $(in_splunk sh -c "ls /tmp/data-$stamp/$d/*.log 2>/dev/null" || true); do
      printf '   %-13s %s\n' "$d" "$(basename "$f")"
      in_splunk /opt/splunk/bin/splunk add oneshot "$f" -index tutorial -hostname "$d" \
        -auth "admin:$SPLUNK_PASSWORD" >/dev/null
    done
  done

  say "installing lookup files"
  docker cp "$WORK/prices.csv" "$CONT:/opt/splunk/etc/apps/search/lookups/prices.csv" >/dev/null
  docker cp "$HERE/lookups/http_status.csv" "$CONT:/opt/splunk/etc/apps/search/lookups/http_status.csv" >/dev/null
  docker exec -u root "$CONT" chown splunk:splunk \
    /opt/splunk/etc/apps/search/lookups/prices.csv /opt/splunk/etc/apps/search/lookups/http_status.csv

  # Make bare searches (no index=) hit 'tutorial'. Default indexes of IMPORTED roles are
  # unioned, so patching 'admin' alone leaves 'main' in — patch user and power too.
  say "pointing the default search index at 'tutorial'"
  for role in user power admin; do
    in_splunk curl -s -k -u "admin:$SPLUNK_PASSWORD" -X POST \
      "https://localhost:8089/services/authorization/roles/$role" -d srchIndexesDefault=tutorial -o /dev/null
  done
  say "waiting for indexing to settle"
  local i=0
  until [ "$(spl_value 'index=tutorial | stats count' 0 now)" = "109864" ]; do
    i=$((i+1)); [ $i -gt 60 ] && { say "warning: expected 109864 events, got $(spl_value 'index=tutorial | stats count' 0 now)"; break; }
    sleep 5
  done
  cmd_verify
}

cmd_url() { load_env; echo "http://127.0.0.1:${LAB_PORT:-8010}"; }
cmd_creds() { load_env; echo "user: admin"; echo "password: $SPLUNK_PASSWORD"; echo "url: $(cmd_url)"; }

cmd_spl() {
  load_env; running || die "container is not running"
  [ $# -ge 1 ] || die "usage: lab.sh spl '<search>' [earliest] [latest]"
  spl "$@"
}

collect() { # populates the shell variables used by status/verify
  load_env
  RUN=false; HEALTH=none; TOTAL=0; NEWEST=""; AGE_H=""; LOOKUPS=0
  running && RUN=true
  HEALTH="$(docker inspect -f '{{.State.Health.Status}}' "$CONT" 2>/dev/null || echo none)"
  if [ "$RUN" = true ] && [ "$HEALTH" = healthy ]; then
    TOTAL="$(spl_value 'index=tutorial | stats count' 0 now)"; TOTAL="${TOTAL:-0}"
    if [ "$TOTAL" != "0" ]; then
      NEWEST="$(spl 'index=tutorial | stats max(_time) as t | eval t=strftime(t,"%Y-%m-%d %H:%M:%S")' 0 now | awk 'NR>2{print $1" "$2;exit}')"
      AGE_H="$(spl_value 'index=tutorial | stats max(_time) as t | eval h=round((now()-t)/3600)| fields h' 0 now)"
    fi
    LOOKUPS="$(spl_value '| inputlookup prices.csv | stats count' 0 now)"; LOOKUPS="${LOOKUPS:-0}"
  fi
}

cmd_status() {
  collect
  if [ "${1:-}" = "--json" ]; then
    python3 -c "
import json;print(json.dumps({'running':'$RUN'=='true','health':'$HEALTH','url':'http://127.0.0.1:${LAB_PORT:-8010}',
'events':int('${TOTAL:-0}' or 0),'newest_event':'${NEWEST}','data_age_hours':int('${AGE_H:-0}' or 0),
'prices_lookup_rows':int('${LOOKUPS:-0}' or 0),'ready':'$RUN'=='true' and '$HEALTH'=='healthy' and '${TOTAL:-0}'=='109864'},indent=2))"
  else
    echo "container : $CONT (running=$RUN health=$HEALTH)"
    echo "url       : http://127.0.0.1:${LAB_PORT:-8010}"
    echo "events    : ${TOTAL:-0} (expected 109864)"
    echo "newest    : ${NEWEST:-n/a}${AGE_H:+  (${AGE_H}h ago)}"
    echo "lookups   : prices.csv ${LOOKUPS:-0} rows (expected 16)"
  fi
}

cmd_verify() {
  collect
  local fails=0
  check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then printf '  \033[32mok\033[0m   %-34s %s\n' "$1" "$2"
    else printf '  \033[31mFAIL\033[0m %-34s got %s, expected %s\n' "$1" "$2" "$3"; fails=$((fails+1)); fi
  }
  echo "lab check"
  check "container healthy" "$HEALTH" "healthy"
  check "total events" "${TOTAL:-0}" "109864"
  check "web sourcetype" "$(spl_value 'index=tutorial sourcetype=access_combined_wcookie | stats count' 0 now)" "39532"
  check "auth sourcetype" "$(spl_value 'index=tutorial sourcetype=secure-2 | stats count' 0 now)" "40088"
  check "sales sourcetype" "$(spl_value 'index=tutorial sourcetype=vendor_sales | stats count' 0 now)" "30244"
  check "distinct hosts" "$(spl_value 'index=tutorial | stats dc(host)' 0 now)" "5"
  check "prices lookup rows" "${LOOKUPS:-0}" "16"
  check "http_status lookup rows" "$(spl_value '| inputlookup http_status.csv | stats count' 0 now)" "19"
  check "bare search hits tutorial" "$(spl_value 'sourcetype=access_combined_wcookie | stats count' 0 now)" "39532"
  local last24; last24="$(spl_value 'index=tutorial | stats count' -24h now)"
  if [ "${last24:-0}" -gt 0 ] 2>/dev/null; then
    printf '  \033[32mok\033[0m   %-34s %s events\n' "last 24h is populated" "$last24"
  else
    printf '  \033[33mwarn\033[0m %-34s dataset is stale — run: ./setup/lab.sh reindex --yes\n' "last 24h is empty"
  fi
  echo
  if [ "$fails" -eq 0 ]; then echo "lab is ready — $(cmd_url)"; else echo "$fails check(s) failed"; return 1; fi
}

cmd_reindex() {
  [ "${1:-}" = "--yes" ] || die "this deletes every event in the 'tutorial' index and reloads it. Re-run with --yes"
  load_env; running || die "container is not running"
  say "granting the delete capability, purging the index, then reloading"
  in_splunk /opt/splunk/bin/splunk edit user admin -roles admin -roles can_delete \
    -auth "admin:$SPLUNK_PASSWORD" >/dev/null
  spl 'index=tutorial | delete' 0 now >/dev/null
  cmd_load
}

cmd_stop() { load_env; "${COMPOSE[@]}" stop; say "stopped. Data survives in the named volumes. Restart with: ./setup/lab.sh up"; }

cmd_destroy() {
  [ "${1:-}" = "--yes" ] || die "this removes the container AND its volumes (all indexed data, saved searches, dashboards). Re-run with --yes"
  load_env; "${COMPOSE[@]}" down -v; say "removed. ./setup/lab.sh up && ./setup/lab.sh load rebuilds from scratch."
}

case "${1:-}" in
  up) shift; cmd_up "$@" ;;
  load) shift; cmd_load "$@" ;;
  fetch) shift; cmd_fetch "$@" ;;
  status) shift; cmd_status "$@" ;;
  verify) shift; cmd_verify "$@" ;;
  spl) shift; cmd_spl "$@" ;;
  url) shift; cmd_url "$@" ;;
  creds) shift; cmd_creds "$@" ;;
  reindex) shift; cmd_reindex "$@" ;;
  stop) shift; cmd_stop "$@" ;;
  destroy) shift; cmd_destroy "$@" ;;
  *) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
