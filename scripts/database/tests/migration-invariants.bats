#!/usr/bin/env bats
#
# Copyright (c) 2026. Cloud Software Group, Inc.
#
# Repo-wide invariants over the numbered Postgres migration corpus
# (scripts/database/postgres/<group>/<service>/sql/N-up.sql + scripts/metadata.bash).
#
# WHY THESE EXIST (PCP-22686). The migration runner only ever *reads* SCHEMA_VERSION —
# `upgradeDBSchema` in postgres-helper.bash does a SELECT and never a write — so each
# N-up.sql is itself responsible for advancing the version it represents. Nothing
# enforced that. A migration that omits the bump still *applies* (the DDL is
# idempotent), so it looks green: the loop simply re-reads the old version, re-runs the
# same script on every Job invocation, and the version never converges to what
# version-map.yaml asserts — leaving `check-schema-version <service>` permanently
# mismatched. That failure is silent at authoring time and only shows up in a deployed
# environment, which is exactly the shape a static test should catch.
#
# These are CORPUS tests: they read the tree, source nothing, and stub nothing, so they
# stay valid as services are added. Both invariants hold for all services today —
# they lock in existing behaviour rather than introducing a new requirement.

SQL_ROOT="${BATS_TEST_DIRNAME}/../postgres"

setup() {
  bats_require_minimum_version 1.5.0
}

# Highest N among the service's N-up.sql files (0 when it has none).
# $1 = service directory (the one containing sql/ and scripts/).
_max_up_version() {
  local svc="$1" max=0 n f
  for f in "${svc}"/sql/*-up.sql; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"; n="${n%-up.sql}"
    case "$n" in ''|*[!0-9]*) continue ;; esac   # skip non-numeric (e.g. create-other-db-objects)
    [ "$n" -gt "$max" ] && max="$n"
  done
  echo "$max"
}

# Every service directory that declares a schema version, i.e. the parent of
# <service>/scripts/metadata.bash. Uses shell parameter expansion rather than
# `xargs dirname` -- two fewer process spawns per service, and it does not wedge
# under Git-for-Windows bash the way the xargs pipeline does.
_services() {
  local md
  find "$SQL_ROOT" -name metadata.bash | while read -r md; do
    md="${md%/*}"   # strip /metadata.bash -> <service>/scripts
    echo "${md%/*}" # strip /scripts       -> <service>
  done | sort
}

# --- invariant 1: the declared CURRENT_VERSION matches the migrations actually present.
#     Catches "added N-up.sql, forgot metadata.bash" and its inverse (a version-map bump
#     with no migration behind it) -- both of which strand check-schema-version. ---
@test "every service's CURRENT_VERSION equals the highest N-up.sql it ships" {
  local svc cur max offenders=""
  while read -r svc; do
    [ -n "$svc" ] || continue
    cur="$(grep -E '^[[:space:]]*CURRENT_VERSION=' "${svc}/scripts/metadata.bash" | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
    max="$(_max_up_version "$svc")"
    if [ "$cur" != "$max" ]; then
      offenders="${offenders}
  ${svc#"${SQL_ROOT}/"}: CURRENT_VERSION=${cur} but highest migration is ${max}-up.sql"
    fi
  done < <(_services)

  if [ -n "$offenders" ]; then
    printf 'CURRENT_VERSION / migration-file mismatch:%s\n' "$offenders" >&2
    return 1
  fi
}

# --- invariant 2: each N-up.sql (N>=2) advances SCHEMA_VERSION to its own N.
#     1-up.sql is exempt: it CREATEs the table and seeds version 1 with an INSERT, so it
#     has no preceding row to UPDATE. This is the check that would have caught the
#     PCP-22686 mcphub 2-up.sql shipping without its bump. ---
@test "every N-up.sql with N>=2 advances SCHEMA_VERSION to N" {
  local svc f n offenders=""
  while read -r svc; do
    [ -n "$svc" ] || continue
    for f in "${svc}"/sql/*-up.sql; do
      [ -e "$f" ] || continue
      n="$(basename "$f")"; n="${n%-up.sql}"
      case "$n" in ''|*[!0-9]*) continue ;; esac
      [ "$n" -ge 2 ] || continue
      # Tolerant of case and inner whitespace; deliberately NOT tolerant of a different
      # target version -- bumping to the wrong N is the same silent-drift bug.
      if ! grep -qiE "UPDATE[[:space:]]+SCHEMA_VERSION[[:space:]]+SET[[:space:]]+VERSION[[:space:]]*=[[:space:]]*${n}[[:space:]]*;" "$f"; then
        offenders="${offenders}
  ${f#"${SQL_ROOT}/"}: missing 'UPDATE SCHEMA_VERSION SET VERSION = ${n};'"
      fi
    done
  done < <(_services)

  if [ -n "$offenders" ]; then
    printf 'migrations that never advance the schema version:%s\n' "$offenders" >&2
    return 1
  fi
}

# --- invariant 3: the version-map must be REACHABLE from the appVersion the Job actually sends.
#     `manageDbSchema $CHART_APP_VERSION` -> resolve_target_schema_version, which keeps only map
#     keys <= that target and returns EMPTY otherwise. On empty, manageDbSchemaCommand logs
#     "No version-map entry ... skipping" and `continue`s -- the service's schema is never
#     created, the Job still exits 0, and the failure only surfaces as backend 500s at runtime.
#     So a map keyed AHEAD of the appVersion is silently fatal. mcp-hub is asserted concretely
#     because the coupling is chart-specific: jobs.yaml lives in the mcp-hub-webserver SUBCHART,
#     so its {{ .Chart.AppVersion }} is that subchart's appVersion -- NOT the parent chart's
#     version or appVersion, which is the easy thing to get wrong. ---
@test "mcp-hub: version-map resolves from the appVersion jobs.yaml actually passes" {
  local helper="${BATS_TEST_DIRNAME}/../postgres-helper.bash"
  local chart="${BATS_TEST_DIRNAME}/../../../charts/tibco-cp-mcp-hub/charts/mcp-hub-webserver/Chart.yaml"
  local map="${SQL_ROOT}/mcp-hub/version-map.yaml"

  [ -f "$chart" ] || { echo "mcp-hub-webserver Chart.yaml not found at $chart" >&2; return 1; }
  [ -f "$map" ]   || { echo "mcp-hub version-map.yaml not found at $map" >&2; return 1; }

  # The exact value jobs.yaml renders into CHART_APP_VERSION.
  local appv
  appv=$(grep -E '^appVersion:' "$chart" | head -1 | cut -d: -f2- | tr -d ' "'"'"'')
  [ -n "$appv" ] || { echo "could not read appVersion from $chart" >&2; return 1; }

  # Use the REAL resolver, not a reimplementation of it.
  source "$helper"
  local resolved
  resolved=$(VERSION_MAP_FILE="$map" resolve_target_schema_version mcphub "$appv")

  if [ -z "$resolved" ]; then
    echo "mcp-hub-webserver appVersion is ${appv}, but no version-map key is <= that." >&2
    echo "manageDbSchema would SKIP mcphub and never create the database. Map keys:" >&2
    grep -E '^[[:space:]]*"' "$map" >&2
    return 1
  fi
  echo "appVersion=${appv} resolves to mcphub schema version ${resolved}"
}
