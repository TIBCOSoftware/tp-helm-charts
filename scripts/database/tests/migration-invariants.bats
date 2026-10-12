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

# Roots are overridable so the invariants can be pointed at a fixture tree. That is what
# migration-invariants-meta.bats does: it injects a known fault and asserts the relevant
# invariant actually fails. Without that, an invariant can silently degrade to always-pass
# and nothing says so -- which is not hypothetical here. Invariant 2 shipped wrong (a false
# positive on multi-line UPDATE) and nobody found out because nothing ran it; invariant 4
# shipped under-covering (see _managed_db_charts) and nothing failed either. Defaults are
# the real repo, so normal runs need no environment at all.
SQL_ROOT="${MIGRATION_SQL_ROOT:-${BATS_TEST_DIRNAME}/../postgres}"
CHARTS_ROOT="${MIGRATION_CHARTS_ROOT:-${BATS_TEST_DIRNAME}/../../../charts}"
WORKFLOW_FILE="${MIGRATION_WORKFLOW_FILE:-${BATS_TEST_DIRNAME}/../../../.github/workflows/script-tests.yaml}"
HELPER_FILE="${MIGRATION_HELPER_FILE:-${BATS_TEST_DIRNAME}/../postgres-helper.bash}"
REPO_ROOT="${MIGRATION_REPO_ROOT:-${BATS_TEST_DIRNAME}/../../..}"
PIN_FILE="${MIGRATION_PIN_FILE:-${BATS_TEST_DIRNAME}/released-migrations.txt}"

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
      # Tolerant of case, inner whitespace, and of the statement spanning multiple lines
      # (`UPDATE SCHEMA_VERSION\nSET version = N,\n    description = '...';` is the shape
      # tibco-cp-ai-agent uses), so the file is flattened before matching. Deliberately NOT
      # tolerant of a different target version -- bumping to the wrong N is the same
      # silent-drift bug. The trailing [,;] is what makes that strict: it anchors the end of
      # the number, so VERSION = 34 cannot satisfy the check for N=3.
      if ! tr '\n' ' ' < "$f" | grep -qiE "UPDATE[[:space:]]+SCHEMA_VERSION[[:space:]]+SET[[:space:]]+VERSION[[:space:]]*=[[:space:]]*${n}[[:space:]]*[,;]"; then
        offenders="${offenders}
  ${f#"${SQL_ROOT}/"}: missing 'UPDATE SCHEMA_VERSION SET VERSION = ${n}' (';' or ',' terminated)"
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

# Every chart on the `manageDbSchema $CHART_APP_VERSION` path, discovered rather than
# hardcoded so a new capability chart is covered the day it lands. Emits one
# "<jobs.yaml>|<chart dir>|<version-map>" per chart.
#
# The pairing comes out of the template itself: PSQL_SCRIPTS_LOCATION is
# /opt/tibco/tsc/scripts/postgres/<group>, and /opt/tibco/tsc/scripts is this repo's
# scripts/database (the core-cp-scripts Dockerfile does `COPY scripts /opt/tibco/tsc/scripts`),
# so <group> selects scripts/database/postgres/<group>/version-map.yaml.
# Every template carrying the invocation, whatever it is named. This deliberately does NOT
# filter on --include=jobs.yaml: tying coverage to a filename made this silently
# under-cover. Renaming mcp-hub's template to db-jobs.yaml dropped that chart from
# discovery while the suite stayed green, because tp-cp-core was still found and only the
# zero-charts case was guarded. A gate that quietly stops covering something is worse than
# no gate. `chart="${j%/templates/*}"` already constrains matches to a chart's templates/ dir.
_managed_db_invocations() {
  grep -rl 'manageDbSchema \$CHART_APP_VERSION' "$CHARTS_ROOT" --include='*.yaml' 2>/dev/null | sort
}

# Emits "<template>|<chart dir>|<version-map>" per chart.
#
# The pairing comes out of the template itself: PSQL_SCRIPTS_LOCATION is
# /opt/tibco/tsc/scripts/postgres/<group>, and /opt/tibco/tsc/scripts is this repo's
# scripts/database (the core-cp-scripts Dockerfile does `COPY scripts /opt/tibco/tsc/scripts`),
# so <group> selects scripts/database/postgres/<group>/version-map.yaml.
#
# The scan forward for the value is a state machine rather than `grep -A1`, which assumed
# `value:` sits directly under `name: PSQL_SCRIPTS_LOCATION` -- true today, but an ordering
# assumption, and its failure mode is again a silently dropped chart.
_managed_db_charts() {
  local j chart group
  while read -r j; do
    [ -n "$j" ] || continue
    chart="${j%/templates/*}"
    group="$(awk '
      /name:[[:space:]]*PSQL_SCRIPTS_LOCATION/ { seen = 1 }
      seen && match($0, /\/opt\/tibco\/tsc\/scripts\/postgres\/[A-Za-z0-9._-]+/) {
        print substr($0, RSTART, RLENGTH); exit
      }' "$j")"
    group="${group##*/}"
    [ -n "$group" ] || { echo "${j}|${chart}|"; continue; }
    echo "${j}|${chart}|${SQL_ROOT}/${group}/version-map.yaml"
  done < <(_managed_db_invocations)
}

# --- invariant 4: the appVersion the Job sends must be an EXACT key in the version-map.
#     This is the one that would have caught PCP-22004, PCP-22370 and PCP-23435. Invariant 3
#     checks *reachability* (some key <= appVersion), which is the mcp-hub failure mode --
#     but manageDbSchema calls validate_target_chart_version FIRST, and that requires an
#     exact top-level key match. A missing exact key is not a silent skip: it aborts
#     tp-cp-core-db-schema-management, so pengine-postgres-credential is never created and
#     the entire Control Plane install hangs. One exact-key assertion covers both directions
#     (map behind appVersion = hard fail; map ahead = silent skip).
#
#     NOTE this asserts the map *in this repo*. The map that actually runs is the one baked
#     into the pinned core-cp-scripts image, so this cannot catch a chart pinned to an image
#     older than its own version-map -- that needs a check that reads the pinned tag, which
#     needs registry credentials in CI. This closes the authoring half of the gap. ---
@test "every manageDbSchema chart's appVersion is an exact key in its version-map" {
  source "$HELPER_FILE"

  local j chart map appv offenders="" checked=0 expected=0
  expected=$(_managed_db_invocations | grep -c . || true)

  while IFS='|' read -r j chart map; do
    [ -n "$j" ] || continue

    # The test assumes CHART_APP_VERSION is the SUBCHART's own appVersion. If that ever stops
    # being true the assertion below is silently meaningless, so fail loudly instead.
    if ! grep -A5 'name: CHART_APP_VERSION' "$j" | grep -q '{{ .Chart.AppVersion }}'; then
      offenders="${offenders}
  ${j}: CHART_APP_VERSION is no longer {{ .Chart.AppVersion }} -- this test's assumption is stale"
      continue
    fi

    if [ -z "$map" ]; then
      offenders="${offenders}
  ${j}: carries manageDbSchema but no PSQL_SCRIPTS_LOCATION could be read -- cannot pair it to a version-map"
      continue
    fi

    if [ ! -f "$map" ]; then
      offenders="${offenders}
  ${j}: PSQL_SCRIPTS_LOCATION points at a group with no version-map.yaml (${map})"
      continue
    fi

    appv=$(grep -E '^appVersion:' "${chart}/Chart.yaml" | head -1 | cut -d: -f2- | tr -d ' "'"'"'')
    if [ -z "$appv" ]; then
      offenders="${offenders}
  ${chart}/Chart.yaml: no appVersion"
      continue
    fi

    checked=$((checked + 1))
    # The same function validate_target_chart_version uses -- not a reimplementation.
    if _yaml_has_version "$map" "$appv"; then
      echo "ok: ${chart##*/} appVersion=${appv} is a key in ${map##*/postgres/}"
    else
      offenders="${offenders}
  ${chart}: appVersion ${appv} is NOT a key in ${map#"${SQL_ROOT}/"}
      manageDbSchema would abort with \"Target chart version '${appv}' is not defined\".
      Keys present: $(_yaml_get_version_keys "$map" | tr '\n' ' ')
      Fix: add a \"${appv}\": entry to that version-map, then rebuild core-cp-scripts and re-pin cpScripts.tag."
    fi
  done < <(_managed_db_charts)

  # Guard PARTIAL discovery, not just total discovery failure. Previously only the
  # checked-eq-0 case was caught, so dropping one chart of two left the suite green -- the
  # gate reporting success while covering less than it claims is the failure this whole
  # file exists to prevent.
  if [ "$checked" -ne "$expected" ] && [ -z "$offenders" ]; then
    printf 'discovery dropped charts: %s template(s) carry manageDbSchema but only %s were checked\n' \
      "$expected" "$checked" >&2
    _managed_db_invocations >&2
    return 1
  fi

  if [ "$expected" -eq 0 ]; then
    echo "found no charts on the manageDbSchema path -- discovery is broken, not the charts" >&2
    return 1
  fi

  if [ -n "$offenders" ]; then
    printf 'chart appVersion / version-map mismatch:%s\n' "$offenders" >&2
    return 1
  fi
}

# --- invariant 6: every chart invariant 4 discovers must also be inside the workflow's
#     `paths:` filter, or the gate never runs on the change it exists to catch.
#     script-tests.yaml is paths-filtered, so an appVersion bump in a chart missing from that
#     list does not trigger the workflow at all -- invariant 4 would happily catch it, and
#     never be asked. The list was previously kept in step by a comment saying "ADD ANY NEW
#     SUCH CHART HERE", i.e. the same manual step whose omission caused this bug class three
#     times. The test already computes the list, so it can assert it instead. ---
@test "every discovered chart is covered by script-tests.yaml's paths filter" {
  [ -f "$WORKFLOW_FILE" ] || { echo "workflow not found at $WORKFLOW_FILE" >&2; return 1; }

  local j chart top offenders="" seen=""
  while IFS='|' read -r j chart map; do
    [ -n "$chart" ] || continue
    # charts/<top-level chart>/... -- the unit a paths: entry addresses.
    top="${chart#"${CHARTS_ROOT}/"}"; top="${top%%/*}"
    case " ${seen} " in *" ${top} "*) continue ;; esac
    seen="${seen} ${top}"
    if ! grep -qE "^[[:space:]]*-[[:space:]]*'?charts/${top}/" "$WORKFLOW_FILE"; then
      offenders="${offenders}
  charts/${top}/** is not in the paths: filter, so an appVersion bump there would not run this gate"
    fi
  done < <(_managed_db_charts)

  if [ -n "$offenders" ]; then
    printf 'charts on the manageDbSchema path missing from %s:%s\n' "${WORKFLOW_FILE##*/}" "$offenders" >&2
    return 1
  fi
}

# --- invariant 7: no migration may infer TRUSTED provenance from a URL (TESSA-627).
#
#     tenant_mcp_servers.provisioning_source = 'system' is the provenance half of control-plane
#     trust: the agent treats a server as trusted when provisioning_source='system' AND its role
#     is in TRUSTED_ROLES (mcp_tool_approval_service.trusted_server_ids), and a trusted server's
#     tools are acknowledged on sight, bypassing the whole approval gate TESSA-627 exists to
#     build.
#
#     5-up.sql used to backfill that value by matching the row's URL against the managed
#     in-cluster host pattern. Successive drafts tightened the match -- substring LIKE, then an
#     anchored host regex -- on the theory that a tight enough pattern makes the inference sound.
#     It does not. The inference is the defect. A URL is a field a TENANT writes: the settings
#     API validates only that it is syntactically HTTP(S) with a host, so a server a customer
#     created through Settings, whose URL happens to sit on the cluster DNS pattern, was promoted
#     to control-plane trust.
#
#     Unknown history must stay 'user'. This invariant is written as a corpus rule rather than a
#     one-off edit to 5-up.sql because the tightening drafts are the evidence that the idea keeps
#     coming back: 6-up.sql must not be able to reintroduce it either.
#
#     Deliberately narrow: it fires only on an UPDATE that SETs provisioning_source to 'system'
#     whose predicate mentions `url`. Setting it to 'user' from anything is fine (that direction
#     only ever removes trust), and an INSERT written by a provisioner is fine (that IS the
#     provenance). ---
@test "no migration derives provisioning_source='system' from a url predicate" {
  local f offenders="" flat

  while read -r f; do
    [ -n "$f" ] || continue
    # Flatten to one line: these statements span many lines, comments included. Comments are
    # stripped first so the long explanatory note ABOVE a compliant statement cannot supply the
    # 'url' token by itself -- and so a reviewer cannot silence this by rewording a comment.
    flat="$(sed -E "s/--.*$//" "$f" | tr '\n' ' ' | tr -s ' ')"

    # Split on ';' and inspect each statement on its own, so an unrelated later UPDATE that
    # mentions url cannot be joined to an earlier provisioning_source assignment.
    while IFS= read -r stmt; do
      printf '%s' "$stmt" | grep -qiE "UPDATE[[:space:]]+tenant_mcp_servers" || continue
      printf '%s' "$stmt" | grep -qiE "provisioning_source[[:space:]]*=[[:space:]]*'system'" || continue
      printf '%s' "$stmt" | grep -qiE "\burl\b" || continue
      offenders="${offenders}
  ${f#"${SQL_ROOT}/"}: promotes provisioning_source to 'system' from a url predicate
      A URL is tenant-supplied input, not provenance. Leave unknown rows 'user'.
      ${stmt}"
    done < <(printf '%s' "$flat" | tr ';' '\n')
  done < <(find "$SQL_ROOT" -name '*-up.sql' | sort)

  if [ -n "$offenders" ]; then
    printf 'migrations inferring trusted provenance from a URL:%s\n' "$offenders" >&2
    return 1
  fi
}

# --- invariant 5: every line the parser reads as a version-block body must be a real
#     `<service>: <integer>` mapping.
#
#     _yaml_get_service_version only leaves a block when it hits the next "X.Y.Z" key, so
#     every line in between -- including comments written between two entries -- is read as
#     body content and split on ':'. It returns the FIRST field match, so a junk line can
#     shadow a service that has no legitimate entry in that block.
#
#     Measured against the real parser rather than assumed, because the intuitive version of
#     this hazard is wrong. tscorch legitimately resolves to 1 from the 1.13.0 block:
#         "1.20.0":                                  resolve tscorch @1.20.0
#           # tscorch: unchanged here          -->     1          (safe)
#           tscorch: unchanged here            -->     "unchanged here"  (WRONG)
#     A comment is safe because '#' binds to the key token: awk -F: yields "# tscorch", which
#     matches no service. So commentary between entries cannot poison a lookup -- but the
#     moment such a line loses its '#' (a careless edit, a bad merge resolution) it silently
#     starts answering lookups with a string. Shadowing also requires the service to be
#     absent from that block; where it is present, the real entry wins on first match.
#
#     This asserts the property that makes both cases safe: non-comment body lines are
#     always `<known-service>: <integer>`. ---
@test "version-map blocks contain only '<known-service>: <integer>' lines" {
  local map group offenders=""
  for map in "${SQL_ROOT}"/*/version-map.yaml; do
    [ -e "$map" ] || continue
    group="${map%/version-map.yaml}"; group="${group##*/}"

    # Services with value -1 are explicitly removed; skip them in all version blocks.
    local removed_svcs=" $(grep -E ':[[:space:]]*-1[[:space:]]*$' "$map" | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' | tr '\n' ' ')"

    local in_block=false line svc stripped
    while IFS= read -r line; do
      # printf, not echo: echo mangles payloads containing -n/-e or backslash escapes, and
      # these lines are arbitrary file content.
      # A version key opens the next block.
      if printf '%s\n' "$line" | grep -qE '^[[:space:]]+"[0-9]+\.[0-9]+\.[0-9]+"'; then in_block=true; continue; fi
      [ "$in_block" = true ] || continue
      # Blank lines and the top-level 'versions:' key are not body content.
      stripped="$(printf '%s' "$line" | tr -d '[:space:]')"
      [ -n "$stripped" ] || continue

      # Comments are inherently safe: awk -F: puts '#' in $1, so "# svc" matches no service.
      case "$stripped" in '#'*) continue ;; esac

      if ! printf '%s\n' "$line" | grep -qE '^[[:space:]]+[A-Za-z0-9_-]+:[[:space:]]*-?[0-9]+[[:space:]]*$'; then
        offenders="${offenders}
  ${group}/version-map.yaml: not a '<service>: <integer>' mapping
      ${line}"
        continue
      fi
      # Only now that the shape is known-good: everything before the ':' is the service
      # name. Parameter expansion, so this costs no extra process per line.
      svc="${line%%:*}"; svc="${svc#"${svc%%[![:space:]]*}"}"; svc="${svc%"${svc##*[![:space:]]}"}"
      # Skip directory check for services explicitly removed (value -1 in any block).
      case "$removed_svcs" in *" ${svc} "*) continue ;; esac
      if [ ! -d "${SQL_ROOT}/${group}/${svc}" ]; then
        offenders="${offenders}
  ${group}/version-map.yaml: '${svc}' has no ${group}/${svc}/ directory (typo, or a removed service)"
      fi
    done < "$map"
  done

  if [ -n "$offenders" ]; then
    printf 'version-map body lines the runtime parser would misread:%s\n' "$offenders" >&2
    return 1
  fi
}


# ---------------------------------------------------------------------------------------
# PCP-23824: the released-migration freeze. Helpers first, then invariants 7 and 8.
# ---------------------------------------------------------------------------------------

# GNU coreutils on Linux and Git-for-Windows; stock macOS ships only `shasum`. Both accept
# `-c --strict` and the same "<hex>  <path>" checklist format. Never degrade to a `skip` or a
# `|| true` here: a missing checksum tool must be a loud failure, not a pass.
_sha256_check() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c --strict "$@"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c --strict "$@"
  else
    echo "neither sha256sum nor shasum is available -- cannot verify the pin" >&2
    return 1
  fi
}

# The released migrations that MUST have a line in the pin file. `sha256sum -c` cannot notice
# an entry that is not there, so deleting one line from released-migrations.txt silently
# disarms invariant 7 for that file. Keeping the list HERE means disarming it is a change to
# the test source, which a reviewer sees. Repo-root-relative, matching the pin's path column.
# ADD A LINE HERE whenever a new migration ships (see the pin file's header).
#
# 2-up.sql is pinned here as of core-cp-scripts:9743, which ships those bytes.
_required_pins() {
  printf '%s\n' \
    'scripts/database/postgres/mcp-hub/mcphub/sql/1-up.sql' \
    'scripts/database/postgres/mcp-hub/mcphub/sql/2-up.sql'
}

# The remediation invariant 7 prints. This message IS the deliverable: the pin cannot PREVENT
# a fold (one PR can change the .sql and the pin line together, and there is no honoured
# CODEOWNERS backstop), it can only make one self-describing to whoever reads the diff.
# printf '%s\n' with single-quoted arguments, not a heredoc and not echo, so the text survives
# transcription and cannot be mangled by a payload that looks like a shell escape.
_frozen_migration_howto() {
  printf '%s\n' \
    '' \
    '  WHY THIS IS BLOCKED' \
    '  Every path in scripts/database/tests/released-migrations.txt has shipped inside a' \
    '  released tp-mcp-hub artifact, so its BYTES are part of the contract. Editing one is not' \
    '  a schema update. A COMMENT-ONLY edit is the same edit: the digest covers the whole file.' \
    '' \
    '  On a SELF-APPLY install (DB_TYPE=postgres with DB_AUTO_MIGRATE on, which is the default' \
    '  outside CP mode) tp-mcp-hub records the sha256 of every migration it applies' \
    '  (backend/src/pg-migrate.ts) and REFUSES TO START when an applied file changes -- a' \
    '  start-up failure in every database that already applied the old bytes.' \
    '' \
    '  On a CP install that runner is OFF and no digest is recorded, so the failure is quieter' \
    '  and arguably worse: manageDbSchemaCommand finds the recorded version already equal to' \
    '  the target, prints "already at target ... no action needed", and the edited bytes NEVER' \
    '  REACH an existing database. Fresh installs get the new text, upgraded ones keep the old,' \
    '  and nothing anywhere reports an error.' \
    '' \
    '  WHAT TO DO INSTEAD -- add the next migration, do not edit this one:' \
    '    1. mcphub/sql/<N>-up.sql,   ending "UPDATE SCHEMA_VERSION SET VERSION = <N>;"  (invariant 2)' \
    '    2. mcphub/sql/<N>-down.sql, ending "UPDATE SCHEMA_VERSION SET VERSION = <N-1>;"' \
    '       ...where <N> is CURRENT_VERSION + 1. Invariant 8 checks only that the DOWN FILE' \
    '       EXISTS. Nothing reads its contents, so an empty or version-line-less <N>-down.sql' \
    '       passes CI and still reports a successful rollback that did nothing. Getting the' \
    '       body right is on you and your reviewer.' \
    '    3. mcphub/scripts/metadata.bash: CURRENT_VERSION=<N>                      (invariant 1)' \
    '    4. mcp-hub/version-map.yaml: add the key -- READ THAT FILE FIRST.' \
    '       Invariants 3 and 4 assert the KEY against mcp-hub-webserver appVersion; invariant 5' \
    '       asserts only that a body line is "<service>: <integer>". NOTHING asserts that' \
    '       "mcphub: N" matches CURRENT_VERSION, and no invariant enforces the appVersion /' \
    '       core-cp-scripts image ordering -- both of those are review-only.' \
    '  See "Adding a schema change" in scripts/database/README.md.' \
    '' \
    '  THE COMMENTS INSIDE 1-up.sql SAY THE OPPOSITE. They are HISTORY, not permission: they' \
    '  were written before the file shipped and they cannot be corrected, because correcting' \
    '  them IS the edit this guard just rejected. See mcphub/sql/README.md.' \
    '' \
    '  IF A RELEASED MIGRATION GENUINELY MUST CHANGE, that is a fleet-wide event, not a' \
    '  two-line PR. Get the schema owner, say why in the PR body, and regenerate from git --' \
    '  never from a working tree. The recipe is in the pin file header; note that Git Bash' \
    '  prints "<hex> *-" from a pipe, which is a binary marker and the filename stdin.' \
    ''
}


# --- invariant 7: every path in released-migrations.txt still hashes to its pinned value.
#     A migration that has reached a customer-reachable artifact is FROZEN; see
#     _frozen_migration_howto for why and for the procedure.
#
#     Seven ways this could report ok while checking nothing, and the closure for each. FIVE of
#     the seven -- (a), (b), (d), (e), (g) -- have a fault-injection meta-test in
#     migration-invariants-meta.bats. (c) and (f) sit BEHIND a check that catches the same
#     fault first, so nothing in the meta suite reaches them; they are deliberate
#     belt-and-braces for the day that earlier check is "simplified", and each says so below.
#     Do not read a green meta suite as proof that (c) or (f) works.
#       (a) pin file gone                     -> explicit -f test.                    [meta]
#       (b) pin file emptied / comments-only  -> well-formed entry count >= 1.
#           NOT meta-tested on this branch -- see the coverage note at the end of this list.
#       (c) pin file half-mangled by a merge  -> --strict, AND every non-comment line must be
#           well-formed. `sha256sum -c` WITHOUT --strict exits 0 on a junk line and prints
#           only "WARNING: 1 line is improperly formatted" (measured, GNU coreutils 8.32).
#           NOT meta-tested: the well-formedness pre-check below rejects every line --strict
#           would and runs FIRST, so the "half-mangled pin file" meta-test asserts on the
#           pre-check's message, never on --strict. --strict is the backstop underneath it.
#       (d) a blank line added to the header  -> its own message. --strict rejects blank lines
#           as improperly formatted, so without this the most likely edit to a comment-heavy
#           file reports the most alarming possible wrong answer ("a released migration
#           changed") when nothing changed.                                          [meta]
#       (e) the mcp-hub line quietly deleted  -> _required_pins must all still be present.
#                                                                                    [meta]
#       (f) an entry skipped rather than verified -> the count of ": OK" output lines must
#           equal the number of pinned entries. This is the only thing that still catches a
#           future --ignore-missing: measured, `-c --strict --ignore-missing` over 2 entries
#           with 1 missing exits 0. NEVER add --ignore-missing. It is the flag someone will
#           reach for to "fix" a path problem; fix REPO_ROOT instead.
#           NOT meta-tested: every way to inject a skipped entry also makes _sha256_check exit
#           non-zero, so the "A RELEASED MIGRATION CHANGED" arm returns first and the count
#           comparison is never reached. It only ever fires if a future flag makes sha256sum
#           exit 0 while skipping -- which is precisely the scenario it is here for.
#       (g) .gitattributes losing `*.sql text eol=lf` -> every Windows worktree would then
#           hash CRLF bytes and this would red with "a released migration changed". The CR
#           pre-pass turns that into a diagnosis instead of a false accusation.
#           NOT meta-tested on this branch -- see the coverage note below.
#
#     COVERAGE NOTE: only (a), (d) and (e) are meta-tested here, plus the core digest-change
#     case; the tags above were corrected to match. Porting more? Move a tag back only with
#     its test. ---
@test "released migrations still hash to their pinned sha256" {
  [ -f "$PIN_FILE" ] || { printf 'pin file not found: %s\n' "$PIN_FILE" >&2; return 1; }

  # Absolutise BEFORE the cd below, or a relative override resolves against the wrong dir.
  local pin_abs
  pin_abs="$(cd "$(dirname "$PIN_FILE")" && pwd)/$(basename "$PIN_FILE")"

  # CRLF detection via tr, NOT `grep -q $'\r'`: MSYS grep reads in text mode and strips CR, so
  # grep reports a CRLF pin file clean (measured on Git Bash). Left undetected it surfaces
  # later as an unreadable "FAILED open or read" on a path with a trailing carriage return.
  local crs
  crs="$(LC_ALL=C tr -cd '\r' < "$pin_abs" | wc -c | tr -d '[:space:]')"
  if [ "${crs:-0}" != 0 ]; then
    printf 'pin file has CRLF line endings (%s CR bytes in %s) -- expected LF.\n' "$crs" "$pin_abs" >&2
    printf 'sha256sum -c would look for a path with a trailing carriage return. Check .gitattributes.\n' >&2
    return 1
  fi

  # `|| true` on every grep -c: grep exits 1 on zero matches and this body runs under errexit.
  local blanks content pinned
  blanks="$(grep -cE '^[[:space:]]*$' "$pin_abs" || true)"
  if [ "$blanks" -ne 0 ]; then
    printf 'pin file %s contains %s blank line(s).\n' "$pin_abs" "$blanks" >&2
    printf 'sha256sum -c --strict treats a blank line as improperly formatted and fails. Remove them:\n' >&2
    grep -nE '^[[:space:]]*$' "$pin_abs" >&2 || true
    return 1
  fi
  content="$(grep -cvE '^#' "$pin_abs" || true)"
  # [0-9a-fA-F], not [0-9a-f]: `sha256sum -c --strict` accepts an UPPERCASE digest (measured,
  # GNU coreutils 8.32), so a pin written that way is valid and must not be counted malformed
  # here -- doing so would red the guard on a correct pin file.
  pinned="$(grep -cE '^[0-9a-fA-F]{64}  [^[:space:]]' "$pin_abs" || true)"
  if [ "$pinned" -lt 1 ] || [ "$pinned" -ne "$content" ]; then
    if [ "$pinned" -lt 1 ]; then
      printf 'pin file %s has no well-formed "<sha256><2 spaces><path>" entries -- refusing to pass vacuously.\n' \
        "$pin_abs" >&2
    else
      printf 'pin file %s has %s non-comment line(s) but only %s are well-formed "<sha256><2 spaces><path>":\n' \
        "$pin_abs" "$content" "$pinned" >&2
    fi
    # The diagnostics belong to BOTH arms. They used to live only in the count-mismatch arm, so
    # the likeliest real case -- the single shipping entry mangled, which drives the well-formed
    # count to 0 and trips the vacuity arm -- printed "refusing to pass vacuously" and nothing
    # actionable. The offending line and the Git-Bash hint ARE the deliverable.
    if [ "$content" -gt 0 ]; then
      printf 'offending non-comment line(s):\n' >&2
      grep -nvE '^#|^[0-9a-fA-F]{64}  [^[:space:]]' "$pin_abs" >&2 || true
      printf 'NOTE: Git Bash `... | sha256sum` prints "<hex> *-" -- one space, a binary marker and stdin.\n' >&2
    fi
    return 1
  fi

  local required offenders=""
  while read -r required; do
    [ -n "$required" ] || continue
    # awk with an exact string compare, not grep: a path contains '.' and '-', which are regex
    # metacharacters, and a near-miss must not count as a match. The digest column is matched
    # with length()+a negated class rather than /^[0-9a-fA-F]{64}$/ because POSIX interval
    # support in mawk (the default awk on ubuntu-latest) is not something this suite can verify
    # from here; length() and a character class are portable to every awk.
    if ! awk -v p="$required" \
         'length($1) == 64 && $1 !~ /[^0-9a-fA-F]/ && $2 == p { f = 1 } END { exit !f }' "$pin_abs"; then
      offenders="${offenders}
  ${required}"
    fi
  done < <(_required_pins)
  if [ -n "$offenders" ]; then
    printf 'released migrations that are no longer pinned AT ALL:%s\n' "$offenders" >&2
    printf 'Deleting a line from %s is how this guard gets disarmed. Re-add it.\n' "${pin_abs##*/}" >&2
    return 1
  fi

  # CR pre-pass over the pinned files themselves. .gitattributes (`*.sql text eol=lf`) is the
  # only reason a Windows worktree hashes the same bytes as the git blob under
  # core.autocrlf=true; if that line is ever weakened this fires with a diagnosis instead of
  # accusing the author of editing a released migration.
  local pth eol=""
  while read -r _ pth; do
    [ -n "$pth" ] || continue
    # A DELETED/MOVED pinned migration must not be reported as a CHANGED one. Falling through to
    # sha256sum -c lands on the "A RELEASED MIGRATION CHANGED" arm, which accuses the author of
    # editing a released file when they did the opposite -- and the remedy is different (restore
    # the path, rather than re-cut the pin).
    [ -f "${REPO_ROOT}/${pth}" ] || {
      printf 'pinned migration is MISSING, not changed: %s\n' "$pth" >&2
      printf 'It was deleted or moved. Restore the path -- do not re-pin, and do not drop the line.\n' >&2
      return 1
    }
    crs="$(LC_ALL=C tr -cd '\r' < "${REPO_ROOT}/${pth}" | wc -c | tr -d '[:space:]')"
    [ "${crs:-0}" = 0 ] || eol="${eol}
  ${pth}: ${crs} CR byte(s)"
  done < <(grep -E '^[0-9a-fA-F]{64}  [^[:space:]]' "$pin_abs")
  if [ -n "$eol" ]; then
    printf 'pinned migration(s) have CRLF line endings in the working tree:%s\n' "$eol" >&2
    printf 'The pin is over LF bytes. Check that .gitattributes still carries "*.sql text eol=lf"\n' >&2
    printf 'and re-checkout; do NOT re-pin the CRLF digest.\n' >&2
    return 1
  fi

  # Command substitution inside `if !`, not a bare call: under errexit a non-zero exit status
  # aborts the body before the remediation below could print, and the remediation is the point.
  local out okc
  if ! out="$( cd "$REPO_ROOT" && _sha256_check "$pin_abs" 2>&1 )"; then
    printf 'A RELEASED MIGRATION CHANGED (repo root %s):\n%s\n' "$REPO_ROOT" "$out" >&2
    _frozen_migration_howto >&2
    return 1
  fi
  okc="$(printf '%s\n' "$out" | grep -c ': OK$' || true)"
  if [ "$okc" -ne "$pinned" ]; then
    printf 'pin file lists %s entries but only %s were verified -- entries are being skipped:\n%s\n' \
      "$pinned" "$okc" "$out" >&2
    return 1
  fi
  printf 'verified %s pinned migration(s) against %s\n' "$okc" "$REPO_ROOT"
}

# --- The version-map VALUE must agree with the CURRENT_VERSION it fronts.
#
#     metadata.bash's CURRENT_VERSION is OVERWRITTEN at runtime by resolve_target_schema_version,
#     so the MAP VALUE decides which N-up.sql files the Job runs. Add a migration, bump
#     metadata.bash, forget the map, and every other invariant stays green -- 1 compares
#     metadata.bash to the highest N-up.sql, 3/4 check key reachability and exact-key match, 5
#     only checks line shape. The Job then targets the stale number, logs "already at the
#     required version N", exits 0, and the migration never runs. Green build, green Job,
#     nothing delivered.
#
#     Uses the REAL resolver against the REAL appVersion rather than re-reading the YAML.
#     CANNOT catch a chart pinned to an image older than its own version-map (the map that runs
#     is the one baked into that image) -- same limitation invariant 4 documents. ---
@test "every service's version-map target equals the CURRENT_VERSION it declares" {
  source "$HELPER_FILE"

  local pairs offenders="" checked=0
  pairs="$(_managed_db_charts)"
  [ -n "$pairs" ] || { echo "no manageDbSchema charts discovered -- refusing to pass vacuously" >&2; return 1; }

  local entry tmpl chart map appv group svc svcdir declared resolved
  while IFS='|' read -r tmpl chart map; do
    [ -n "$map" ] || continue
    [ -f "$map" ] || { offenders="${offenders}
  ${tmpl}: version-map not found at ${map}"; continue; }
    [ -f "${chart}/Chart.yaml" ] || { offenders="${offenders}
  ${chart}: no Chart.yaml"; continue; }

    # The exact value jobs.yaml renders into CHART_APP_VERSION (invariant 3's reading).
    appv="$(grep -E '^appVersion:' "${chart}/Chart.yaml" | head -1 | cut -d: -f2- | tr -d ' "'"'"'')"
    [ -n "$appv" ] || { offenders="${offenders}
  ${chart}/Chart.yaml: could not read appVersion"; continue; }

    group="${map%/version-map.yaml}"; group="${group##*/}"

    # Every service in this group that declares a schema version.
    for svcdir in "${SQL_ROOT}/${group}"/*; do
      [ -d "$svcdir" ] || continue
      [ -f "${svcdir}/scripts/metadata.bash" ] || continue
      svc="${svcdir##*/}"

      # Distinguish "resolver FAILED" from "legitimately unreachable". Swallowing both with
      # `2>/dev/null || true` made a broken resolver -- a malformed version-map, a renamed key, a
      # refactor of resolve_target_schema_version -- indistinguishable from a service that simply
      # has no key <= appVersion, and silently dropped it from the comparison. The `checked > 0`
      # guard below is global, so with a second managed chart present that would leave this
      # invariant green while checking nothing about mcphub.
      # Capture inside an `if` CONDITION, never as a bare assignment: under errexit a bare
      # assignment whose command substitution exits non-zero is itself a failing simple command,
      # so the body aborts before `rrc=$?` is reached and the offender message below is never
      # printed -- the test would just die with no diagnostic. Same rule the comment at the top
      # of invariant 7 states. (Caught in review; the first version of this arm could never fire.)
      # One invocation, both streams: two calls could disagree and cost a second resolve.
      local rerr rrc errf="${BATS_TEST_TMPDIR}/resolve.err"
      if resolved="$(VERSION_MAP_FILE="$map" resolve_target_schema_version "$svc" "$appv" 2>"$errf")"; then rrc=0; else rrc=$?; fi
      rerr="$(cat "$errf" 2>/dev/null || true)"
      if [ "$rrc" -ne 0 ]; then
        offenders="${offenders}
  ${group}/${svc}: resolve_target_schema_version EXITED ${rrc} for appVersion ${appv} (not merely unreachable).
      ${rerr}"
        continue
      fi
      # Unreachable (invariant 3's job) or explicitly removed (-1, as invariant 5 skips).
      [ -n "$resolved" ] || continue
      [ "$resolved" = "-1" ] && continue

      declared="$(grep -E '^CURRENT_VERSION=' "${svcdir}/scripts/metadata.bash" | head -1 | cut -d= -f2 | tr -d ' ')"
      [ -n "$declared" ] || { offenders="${offenders}
  ${svc}: no CURRENT_VERSION in ${svcdir}/scripts/metadata.bash"; continue; }

      checked=$((checked + 1))
      if [ "$resolved" != "$declared" ]; then
        offenders="${offenders}
  ${group}/${svc}: version-map resolves ${resolved} for appVersion ${appv}, but metadata.bash declares CURRENT_VERSION=${declared}.
      The Job targets ${resolved}, so ${svcdir##*/}/sql/*-up.sql above ${resolved} would NEVER RUN.
      Fix ${map} (the value under the key <= ${appv}), not metadata.bash, unless the migration itself is wrong."
      fi
    done
  done <<< "$pairs"

  # A silently-empty walk would make this pass without asserting anything -- the exact way
  # invariant 4 once under-covered. Demand at least one real comparison.
  [ "$checked" -gt 0 ] || { echo "no <service, version-map> pairs were compared -- refusing to pass vacuously" >&2; return 1; }

  if [ -n "$offenders" ]; then
    printf 'version-map target disagrees with the declared CURRENT_VERSION:%s\n' "$offenders" >&2
    return 1
  fi
  echo "verified ${checked} service(s): version-map target == declared CURRENT_VERSION"
}
