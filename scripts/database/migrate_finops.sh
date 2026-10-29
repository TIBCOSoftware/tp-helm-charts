#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
# PCP-23012 - migrate historical finops data from monitoringdb into tscutdb.
#
# Part of the orch-mon merge (PCP-19871): monitoring-service is gone and its tables now live
# in tscutdb. Live state (dataplanes, capability instances, services, resources, domains,
# tibtunnel status) rebuilds itself from heartbeats and crons, so only the five historical
# finops tables need copying. SCHEMA_VERSION must never be copied - it would corrupt version
# tracking. CLIENT_CONNECTIONS (v1) is dead: nothing reads or writes it, and PCP-4460 remapped
# all reads to v2.
#
# Read-only on the source. monitoringdb is never modified, and nothing anywhere drops it: PCP-23723
# retires the database the PCP-6689 way, by marking it `monitoringdb: -1` in version-map.yaml so
# resolve_target_schema_version skips it. A fresh install therefore never creates it; an existing
# one keeps it, orphaned but intact. So the original data survives indefinitely and a chart
# rollback finds it exactly where it was.
#
# ALL OR NOTHING, in two phases:
#
#   Phase 1 (slow, over the network) copies every source table into a staging table. The real
#           target tables are not touched at all, so a failure here leaves nothing to undo.
#   Phase 2 (fast, entirely local) moves all of it into the target tables and drops the staging
#           tables in ONE transaction. Any error rolls back the lot.
#
# Splitting it this way is what keeps the transaction short. Production is ~780k rows / ~174 MB
# (measured 2026-08-10), so phase 2 is a few seconds and phase 1 is well under a minute.
#
# REPEATABLE, not one-shot (PCP-23723). There is no marker table any more, so this runs on every
# upgrade and every step must be safe to repeat - see the block above drop_all_staging(). A failed
# run leaves nothing behind and the next upgrade simply starts again; there is deliberately no
# per-table resume, because there is no partial state to resume from.
#
# Staging tables rather than TEMP tables: TEMP tables die with the psql session, and phase 1 needs
# one session per table. They are dropped inside the phase 2 transaction, by the EXIT trap if we
# fail before that, and by drop_all_staging() at the start of the next run.
#
# The conflict rule differs by table, and the difference matters:
#   - the DO_NOTHING_TABLES use DO NOTHING. For the four dated telemetry tables the key includes
#     DATED and the finops cron only inserts rows for new dates, so an existing row is always one
#     we copied. services is not dated, but the rule is right for the same practical reason: a row
#     already present was written by the orchestrator from a live MA payload and is fresher than
#     anything we could copy, so it must not be overwritten.
#   - homepage_metrics MERGES. Its key has no DATED, the orchestrator creates the row itself
#     (29 zeros plus today's real count) and is already running when we start, so DO NOTHING
#     there would silently discard the history. See the block above HOMEPAGE_CONFLICT.
#
set -euo pipefail

: "${PGHOST:?}" "${PGPORT:?}" "${DB_PREFIX:?}" "${MASTER_PGUSER:?}" "${MASTER_PGPASSWORD:?}"
export PGPASSWORD="$MASTER_PGPASSWORD"

SRCDB="${DB_PREFIX}monitoringdb"
DSTDB="${DB_PREFIX}tscutdb"

# The master superuser has no per-schema search_path - only the per-service users
# (${DB_PREFIX}monitoringuser, ${DB_PREFIX}tscutuser) get one. Without this every unqualified
# name fails, including inside triggers.
SRC="host=$PGHOST port=$PGPORT dbname=$SRCDB user=$MASTER_PGUSER options=--search_path=$SRCDB"
DST="host=$PGHOST port=$PGPORT dbname=$DSTDB user=$MASTER_PGUSER options=--search_path=$DSTDB"

WAIT_FOR_TARGET_SECS="${WAIT_FOR_TARGET_SECS:-300}"

STG_PREFIX="mon_stg_"
COMMITTED=false

HOMEPAGE_SRC="homepage_metrics"
HOMEPAGE_DST="v3_homepage_metrics"
HOMEPAGE_COLS="subscription_id,capability_id,metric_id,region,host_cloud_type,history,last_updated"

# Explicit column lists throughout: if a column is ever added to either side, an ordering
# mismatch would silently write values into the wrong fields.
#
# Fields: source_table|dest_table|dest_columns|source_columns
#
# The fourth field is only needed where the two sides disagree, and is optional — when it is
# empty the destination list is used for both. PCP-23429 renamed
# client_connections_v2.instance_id to capability_instance_id on the destination, while
# monitoringdb (frozen, never migrated) still calls it instance_id. Both lists must stay in
# the same ORDER: the copy is positional, so a mismatch would silently load values into the
# wrong columns rather than fail.
#
# PCP-24285: services is in this list even though it has no DATED column. 24-up.sql creates
# v3_capability_instance_services_status EMPTY, and nothing back-fills it - the orchestrator only
# writes those rows from a full MA payload, which the agent sends solely when its own view changes
# or it restarts. So after an upgrade every capability renders with no services under it until
# something happens on the DP. Measured on the local cluster: 0 rows in tscutdb against 6 live
# rows in monitoringdb, and 0 -> 6 the moment tp-dp-monitor-agent was restarted. The target is
# column-identical to monitoringdb.SERVICES apart from INSTANCE_ID -> CAPABILITY_INSTANCE_ID, and
# carries no foreign key (the monitoringdb one had FK_INSTANCE_ID), so this is a plain copy.
DO_NOTHING_TABLES=(
  "running_app_instances|v3_telemetry_running_app_instances|dataplane_id,subscription_id,app_id,capability_id,connectors,tags,rai,dated|"
  "client_connections_v2|v3_telemetry_client_connections|dataplane_id,subscription_id,capability_id,capability_instance_id,connections,dated|dataplane_id,subscription_id,capability_id,instance_id,connections,dated"
  "adapters|v3_telemetry_adapters|dataplane_id,subscription_id,capability_id,adapters,dated|"
  "processors|v3_telemetry_processors|dataplane_id,subscription_id,capability_id,agent_ip,processors,dated|"
  "services|v3_capability_instance_services_status|name,capability_instance_id,status,last_updated,message|name,instance_id,status,last_updated,message"
)

ALL_STAGING="${STG_PREFIX}${HOMEPAGE_SRC}"
for _entry in "${DO_NOTHING_TABLES[@]}"; do
  ALL_STAGING="$ALL_STAGING ${STG_PREFIX}${_entry%%|*}"
done

# HISTORY is jsonb and holds a rolling 30-day window. Verified on ins-orchmon-0608: the hourly
# refresh preserves whatever keys are already in HISTORY and only writes today's bucket (see
# persistHomepageMetrics), so migrated history survives and keeps being extended. That is what
# makes this table worth copying at all.
#
# Nothing in the deployment orders the orchestrator after this script: its init container gates on
# tscorch and cronjobs' on tscscheduler, while these tables live in tscutd - which
# postgres-helper.bash processes last, alphabetically. So the orchestrator is already serving by
# the time 23-up.sql creates this table and its hourly refresh may well get here first.
#
# The merge is what makes the outcome independent of who wins that race. On a miss
# GetHPMetricsForSub returns an empty History rather than nil, so persistHomepageMetrics takes the
# len==0 branch and CREATES the row - 29 zeros plus TODAY'S REAL COUNT in the last bucket. That
# trailing non-zero is why "overwrite only if the target is all zeros" is not sufficient: for any
# customer with apps deployed, the placeholder does not look like a placeholder.
#
# So instead of choosing between the two rows, combine them: take the source history, then layer
# the target's non-zero entries on top (jsonb || lets the right-hand side win). Zeros are filled
# in from history, today's live count survives, and the result is the same whichever ran first.
# HOMEPAGE_SELECT below trims the SOURCE history to the live rolling window as it is read out of
# staging. This is what makes the migration safe to run on every upgrade now that the marker is
# gone (PCP-23723).
#
# Without it, a repeat run re-injects source dates that have already aged out. The orchestrator's
# hourly refresh only ever deletes the key that is EXACTLY 31 days old, so anything re-added older
# than that is never cleared again and the jsonb grows without bound.
#
# The key format is DD-MM-YYYY - dateLayout = "02-01-2006" in both the merged orchestrator and the
# old standalone service, so historical keys use the same format and compare correctly. The regex
# guard runs BEFORE to_date so a malformed key is skipped rather than aborting the whole migration.
# The filter belongs in the SELECT, not in the ON CONFLICT clause. There are two ways this insert
# can land and they must agree:
#
#   migration wins the race -> target row absent -> plain INSERT -> the SELECT list is used
#   orchestrator wins       -> target row exists -> ON CONFLICT   -> `excluded` is used
#
# `excluded` is the row the SELECT proposed, so filtering here covers BOTH. Filtering only in the
# ON CONFLICT clause left the insert path unfiltered, which meant the same source data produced
# different history depending on who won the race - caught on ins-orchmon-0409-01, where the
# migration won and a stale key went straight in.
HOMEPAGE_SELECT="subscription_id,capability_id,metric_id,region,host_cloud_type,(
       select coalesce(jsonb_object_agg(k, v), '{}'::jsonb)
       from jsonb_each(history) s(k, v)
       where s.k ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}\$'
         and to_date(s.k, 'DD-MM-YYYY') >= current_date - 30
     ),last_updated"

# excluded.history is already windowed by HOMEPAGE_SELECT, so this is the original merge rule
# unchanged: take the source history, then layer the target's NON-ZERO entries on top (jsonb ||
# lets the right-hand side win). Zeros are placeholders the orchestrator wrote, so real source
# values replace them; today's live count survives because it is non-zero.
HOMEPAGE_CONFLICT="on conflict (subscription_id, capability_id, metric_id, region, host_cloud_type)
   do update set
     history = excluded.history || (
       select coalesce(jsonb_object_agg(k, v), '{}'::jsonb)
       from jsonb_each(v3_homepage_metrics.history) t(k, v)
       where t.v::text <> '0'
     ),
     last_updated = greatest(v3_homepage_metrics.last_updated, excluded.last_updated)"

# The nightly finops cron (cronjobs -> GET /api/v1/triggerMetricRefresh, schedule "0 1 0 * * *")
# writes yesterday's rows into these same target tables at 00:01 UTC.
#
# This used to refuse to run inside that window. It no longer does, for two reasons. First,
# there is only ever one attempt: the migration runs as part of the base-chart deploy and
# nobody comes back to re-run an upgrade afterwards, so declining means the historical data
# is simply never migrated. Second, refusing exited non-zero, which turned the whole core
# upgrade job red immediately after the schema upgrade had succeeded - the most misleading
# failure we could produce.
#
# Overlap is safe on its own terms: the DO_NOTHING_TABLES skip on conflict, and the homepage merge
# runs under the row lock ON CONFLICT DO UPDATE takes, so it and the cron serialize in either
# order. Warn only, so the overlap is visible to anyone reading the log later.
# 10# forces base 10; without it "0010" is parsed as octal and the comparison breaks silently.
check_cron_window() {
  local now
  now=$((10#$(date -u +%H%M)))
  if [ "$now" -ge 2355 ] || [ "$now" -le 10 ]; then
    echo "NOTE: $(date -u +%H:%M) UTC falls inside the finops cron window (23:55-00:10 UTC)."
    echo "      Writes are safe, but the row counts below may shift under concurrent cron writes."
  fi
}

# The core upgrade job that applies the schema migrations is a plain Job, not a helm hook, so
# helm does not wait for it. Rather than depend on ordering - or on a particular N-up.sql file
# number, which moves with every release - wait for the target tables themselves to exist.
wait_for_target() {
  local waited=0
  while true; do
    if psql "$DST" -tAc "select to_regclass('v3_telemetry_running_app_instances') is not null" 2>/dev/null | grep -q '^t$'; then
      return 0
    fi
    if [ "$waited" -ge "$WAIT_FOR_TARGET_SECS" ]; then
      echo "ERROR: target tables not present in $DSTDB after ${WAIT_FOR_TARGET_SECS}s."
      echo "The tscutdb schema upgrade has not completed. Nothing migrated; safe to re-run."
      exit 1
    fi
    [ "$waited" -eq 0 ] && echo "Waiting for the tscutdb schema upgrade to create the target tables..."
    sleep 5
    waited=$((waited + 5))
  done
}

# NO MARKER TABLE (PCP-23723). There used to be a mon_finops_migration_marker here - a one-row
# table created by this script, not by any N-up.sql, whose only job was "have I run before?".
# It was removed because nothing outside the schema files should be creating tables in tscutdb;
# 24-up.sql now drops it so existing control planes are cleaned up too.
#
# Losing the marker means this migration RUNS ON EVERY UPGRADE, so every step it performs has to
# be safe to repeat:
#
#   * the DO_NOTHING_TABLES insert with ON CONFLICT DO NOTHING, so a repeat run inserts only what
#     is genuinely new and skips the rest. The four telemetry tables are keyed on DATED; services
#     is keyed on (NAME, CAPABILITY_INSTANCE_ID) and a present row is a live one the orchestrator
#     wrote, which is exactly what DO NOTHING must not disturb.
#   * homepage_metrics MERGES jsonb history, which is NOT naturally repeatable - a plain re-merge
#     would keep re-injecting source dates that have already aged out of the rolling 30-day
#     window, and the hourly refresh only ever deletes the key exactly 31 days old, so they would
#     accumulate for ever. HOMEPAGE_SRC_WINDOW below is what makes it safe: source keys older than
#     the window are dropped before the merge, so a repeat run can only ever contribute dates that
#     are still legitimately live.
#
# The upside of re-running is that it fixes the roll-back gap. Under the old marker, data written
# to monitoringdb while a customer was rolled back was stranded for ever, because the marker
# survived the rollback and the next upgrade skipped. Now it is simply picked up.
#
# The cost is re-streaming the source each upgrade - measured at ~780k rows / 174 MB in production,
# once per upgrade rather than per tick. Accepted deliberately.

drop_all_staging() {
  local t
  for t in $ALL_STAGING; do
    psql "$DST" -q -c "drop table if exists $t" >/dev/null 2>&1 || true
  done
}

STAGED_SRC=()
STAGED_DST=()
STAGED_COLS=()
STAGED_ROWS=()

# Phase 1. Copies one source table into its staging table and proves the copy was complete.
# Nothing here writes to a target table.
stage_table() {
  local src="$1" dst="$2" cols="$3" src_cols="${4:-}"
  local stg="${STG_PREFIX}${src}"
  local src_rows stg_rows

  # The staging table is created LIKE the destination, so it carries the DESTINATION column
  # names. Where a column was renamed on the destination (PCP-23429), the source must still
  # be read under its own name — hence the separate list. Same order on both sides.
  [ -n "$src_cols" ] || src_cols="$cols"

  # Not every monitoringdb is at the latest schema. CLIENT_CONNECTIONS_V2 only arrives in
  # 3-up.sql, so on an old install the count below would error. An absent source table just
  # means nothing to migrate.
  if [ "$(psql "$SRC" -tAc "select to_regclass('$src') is not null")" != "t" ]; then
    printf '%-24s not present in %s, skipping\n' "$src" "$SRCDB"
    return 0
  fi

  src_rows=$(psql "$SRC" -tAc "select count(*) from $src")
  if [ "$src_rows" -eq 0 ]; then
    printf '%-24s source empty, nothing to stage\n' "$src"
    return 0
  fi

  # Plain LIKE copies the column definitions but NOT the primary key, so nothing can conflict
  # while the rows are streaming in. COPY has no ON CONFLICT of its own - that is the whole
  # reason the staging table exists.
  psql "$DST" -v ON_ERROR_STOP=1 -q -c "create table $stg (like $dst)"

  psql "$SRC" -v ON_ERROR_STOP=1 -c "\copy (select $src_cols from $src) to stdout" \
    | psql "$DST" -v ON_ERROR_STOP=1 -q -c "\copy $stg ($cols) from stdin" > /dev/null

  # The copy is the one step that can lose rows silently: in `A | B` the shell reports only B, so
  # a source that dies mid-stream would leave a truncated staging table behind. set -o pipefail
  # catches most of that; this catches the rest. Strict equality is safe because nothing writes to
  # monitoringdb any more - monitoring-service is disabled by default in the chart, so the source
  # is frozen and cannot grow underneath us.
  stg_rows=$(psql "$DST" -tAc "select count(*) from $stg")
  if [ "$stg_rows" != "$src_rows" ]; then
    echo "ERROR: $src staged $stg_rows of $src_rows rows - the copy was truncated."
    echo "Nothing has been written to the target tables. Safe to re-run."
    exit 1
  fi

  printf '%-24s staged %s rows\n' "$src" "$stg_rows"
  STAGED_SRC+=("$src")
  STAGED_DST+=("$dst")
  STAGED_COLS+=("$cols")
  STAGED_ROWS+=("$stg_rows")
}

# Phase 2. Emits the whole transaction as one SQL stream.
#
# Order matters: homepage is LAST. ON CONFLICT DO UPDATE takes a row lock that is held until
# COMMIT, so putting homepage first would hold it across every other insert - worse than the
# per-table transactions it replaces. Last means the lock exists for a moment.
#
# The DO_NOTHING_TABLES staging tables are dropped in here too, so they disappear atomically with the
# commit. mon_stg_homepage_metrics deliberately survives: the second pass below reads from it.
generate_transaction_sql() {
  local i src

  for i in "${!STAGED_SRC[@]}"; do
    src="${STAGED_SRC[$i]}"
    if [ "$src" = "$HOMEPAGE_SRC" ]; then
      continue
    fi
    echo "insert into ${STAGED_DST[$i]} (${STAGED_COLS[$i]})
          select ${STAGED_COLS[$i]} from ${STG_PREFIX}${src} on conflict do nothing;"
  done

  for i in "${!STAGED_SRC[@]}"; do
    src="${STAGED_SRC[$i]}"
    if [ "$src" = "$HOMEPAGE_SRC" ]; then
      continue
    fi
    echo "drop table ${STG_PREFIX}${src};"
  done

  for i in "${!STAGED_SRC[@]}"; do
    if [ "${STAGED_SRC[$i]}" != "$HOMEPAGE_SRC" ]; then
      continue
    fi
    echo "insert into $HOMEPAGE_DST ($HOMEPAGE_COLS)
          select $HOMEPAGE_SELECT from ${STG_PREFIX}${HOMEPAGE_SRC} $HOMEPAGE_CONFLICT;"
  done
}

check_cron_window

echo "=== PCP-23012 finops migration: $SRCDB -> $DSTDB ==="

# monitoringdb is absent on a control plane that never ran monitoring-service, and on any
# environment installed fresh after the merge. That is not an error - there is simply nothing
# to migrate.
if ! psql "$DST" -tAc "select 1 from pg_database where datname = '$SRCDB'" | grep -q '^1$'; then
  echo "$SRCDB does not exist - nothing to migrate. Done."
  exit 0
fi

wait_for_target

# No marker check (PCP-23723): this runs on every upgrade. Every step is repeat-safe -- the dated
# tables use ON CONFLICT DO NOTHING, and the homepage merge is trimmed to the live window by
# HOMEPAGE_SRC_WINDOW. A repeat run therefore copies only what is genuinely new.

# A previous run may have been killed between creating a staging table and committing.
drop_all_staging

# From here on a failure must leave nothing behind. Phase 2 drops the DO_NOTHING_TABLES staging tables
# itself, so after COMMITTED=true only mon_stg_homepage_metrics is still around and the second
# pass owns it.
trap 'if [ "$COMMITTED" != "true" ]; then echo "Rolling back: dropping staging tables."; drop_all_staging; fi' EXIT

echo "--- phase 1: copying into staging tables (targets untouched) ---"

# homepage first only so that a schema surprise on the fiddliest table fails before we spend a
# minute streaming the big ones. Copy order is otherwise irrelevant - nothing is visible until
# phase 2 commits.
stage_table "$HOMEPAGE_SRC" "$HOMEPAGE_DST" "$HOMEPAGE_COLS"

for _entry in "${DO_NOTHING_TABLES[@]}"; do
  IFS='|' read -r _src _dst _cols _src_cols <<< "$_entry"
  stage_table "$_src" "$_dst" "$_cols" "$_src_cols"
done

if [ "${#STAGED_SRC[@]}" -eq 0 ]; then
  # Every source table was absent or empty - the normal case on a fresh install, where
  # monitoringdb is never created at all. Nothing to do, and nothing to record: the next upgrade
  # will look again, which is cheap when there is nothing to copy.
  echo "Nothing to migrate - all source tables absent or empty."
  COMMITTED=true
  echo "=== done - nothing to migrate ==="
  exit 0
fi

BEFORE_COUNTS=()
for _i in "${!STAGED_SRC[@]}"; do
  BEFORE_COUNTS+=("$(psql "$DST" -tAc "select count(*) from ${STAGED_DST[$_i]}")")
done

echo "--- phase 2: one transaction - insert all, drop staging ---"

generate_transaction_sql | psql "$DST" -v ON_ERROR_STOP=1 --single-transaction -q -f -

COMMITTED=true

for _i in "${!STAGED_SRC[@]}"; do
  _after=$(psql "$DST" -tAc "select count(*) from ${STAGED_DST[$_i]}")
  _inserted=$((_after - BEFORE_COUNTS[_i]))
  printf '%-24s staged=%-8s target %s -> %s  (inserted %s, skipped %s)\n' \
    "${STAGED_SRC[$_i]}" "${STAGED_ROWS[$_i]}" "${BEFORE_COUNTS[$_i]}" "$_after" \
    "$_inserted" "$((STAGED_ROWS[_i] - _inserted))"
done

# Second homepage pass. Not belt-and-braces - it closes a real gap that no conflict rule can.
#
# The hourly refresh is a read-modify-write split across two calls: GetHPMetricsForSub, then think
# in Go, then UpdateHomepageMetricsTable writing the WHOLE history back. If it read a row before
# our commit and wrote after it, it overwrites us with a decision made from stale state - an
# ordinary UPDATE on a row we committed and no longer hold a lock on. ON CONFLICT governs our
# statement only; it cannot defend a row after we have finished. So the repair has to happen
# afterwards, and it cannot live inside the transaction: with the lock still held nothing could
# have changed, and a failure there would roll back the entire successful migration.
#
# The refresh runs 10 workers concurrently (GetHomepageMetricsWorkerCount) and our insert is a
# single statement covering every row, so the exposure is every row those workers have read but
# not yet written - not one row.
#
# It reads mon_stg_homepage_metrics rather than going back to monitoringdb: faster, and it still
# works if the source or the network has gone away in the seconds since we committed.
#
# Side effect worth knowing: if the cron legitimately advanced the row between passes (added
# today, dropped the 31-day-old key), this re-adds that dropped key, so a row can briefly carry
# 31-32 dates. Nothing reads them - getAppOverviewCounts and getTopCapCounts look up exactly one
# key, computed from LAST_UPDATED - and the refresh trims one per day.
if [ "$(psql "$DST" -tAc "select to_regclass('${STG_PREFIX}${HOMEPAGE_SRC}') is not null")" = "t" ]; then
  echo "--- second homepage pass (guards against a concurrent refresh overwriting the first) ---"
  if psql "$DST" -v ON_ERROR_STOP=1 -q -c \
     "insert into $HOMEPAGE_DST ($HOMEPAGE_COLS)
      select $HOMEPAGE_SELECT from ${STG_PREFIX}${HOMEPAGE_SRC} $HOMEPAGE_CONFLICT"; then
    echo "second homepage pass done"
  else
    # Deliberately not fatal, and deliberately does not remove the marker. The migration is
    # committed and complete; this pass only repairs a race that usually has not happened. Failing
    # the job here would be misleading, and a re-run would see the marker and exit anyway.
    echo "WARNING: second homepage pass failed. The migration itself is committed and complete."
    echo "         Only the guard against a concurrent homepage refresh did not run."
  fi
  psql "$DST" -q -c "drop table if exists ${STG_PREFIX}${HOMEPAGE_SRC}" >/dev/null 2>&1 || true
fi

echo "=== done - this migration runs again on every upgrade (no marker) ==="