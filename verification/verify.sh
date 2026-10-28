#!/usr/bin/env bash
#
# verify.sh - acceptance gate for the dsh-rev-eng DeepSeek Harness plugin bundle.
#
# Runs from a checkout of the package (verification/ sits at the package root).
# Everything it writes lives under <repo>/.dsh-test/verify-home (gitignored), an
# isolated DSH_HOME with its own npm/pnpm/XDG caches redirected inside it. It
# never writes to ~/.dsh and never touches the Electron-managed `desktop`
# profile.
#
# Usage:
#   ./verification/verify.sh            offline gate: static checks, unit tests,
#                                       skills lint, isolated profile install,
#                                       bundle composition, REA MCP overlay
#                                       parsing, malformed-overlay negative
#                                       control, desktop-profile refusal guard.
#   ./verification/verify.sh --full     the above, plus a live `dsh web` boot of
#                                       the isolated profile with the REA MCP
#                                       overlay and a check that the REA MCP
#                                       server child process connects.
#                                       Needs a free loopback port and network
#                                       access on the first npx run.
#   ./verification/verify.sh --keep     keep the isolated DSH_HOME for debugging.
#
# Exit code 0 only when every executed check passes.
#
# Environment overrides:
#   DSH_BIN            dsh CLI to test (default: `dsh` from PATH)
#   VERIFY_PROFILE     isolated profile name for the core gate (default: reveng-verify)
#   VERIFY_WEB_PROFILE profile name booted by --full (default: web template profile)
#   VERIFY_DSH_HOME    isolated home (must live under <repo>/.dsh-test/)
#
# See README.md in this directory for what each check proves and for known
# sandbox limits, and REPORT.md for the tested install story.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DSH_BIN="${DSH_BIN:-dsh}"
CORE_PROFILE="${VERIFY_PROFILE:-reveng-verify}"
WEB_PROFILE="${VERIFY_WEB_PROFILE:-web}"
BASE_HOME="${VERIFY_DSH_HOME:-$ROOT/.dsh-test/verify-home}"
OVERLAY="$ROOT/patches/rea-mcp.yml"

FULL=0
KEEP=0

usage() {
  cat <<'EOF'
verify.sh - acceptance gate for the dsh-rev-eng DeepSeek Harness plugin bundle

Usage:
  ./verification/verify.sh           offline gate (default)
  ./verification/verify.sh --full    also boot an isolated dsh web server with
                                     the REA MCP overlay and verify the MCP child
  ./verification/verify.sh --keep    keep the isolated DSH_HOME (debugging)
  ./verification/verify.sh --help    this text

Exit code 0 only when every executed check passes. See verification/README.md.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --full) FULL=1 ;;
    --keep) KEEP=1 ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'verify: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# --- safety rails: only ever clean a directory this script owns ---------------
case "$BASE_HOME" in
  "$ROOT"/.dsh-test/*) ;;
  *)
    printf 'verify: VERIFY_DSH_HOME must live under %s/.dsh-test/ (got %s)\n' "$ROOT" "$BASE_HOME" >&2
    exit 2
    ;;
esac

if ! command -v "$DSH_BIN" >/dev/null 2>&1; then
  printf 'verify: dsh CLI not found: %s (install the DeepSeek Harness app/CLI)\n' "$DSH_BIN" >&2
  exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  printf 'verify: node not found on PATH\n' >&2
  exit 2
fi

# Keep every cache and store inside the isolated home: the file sandbox may deny
# writes to $HOME, and the gate must never pollute the user's toolchain.
export DSH_HOME="$BASE_HOME"
export XDG_CACHE_HOME="$BASE_HOME/cache/xdg-cache"
export XDG_DATA_HOME="$BASE_HOME/cache/xdg-data"
export XDG_STATE_HOME="$BASE_HOME/cache/xdg-state"
export npm_config_cache="$BASE_HOME/cache/npm"
export npm_config_store_dir="$BASE_HOME/cache/pnpm-store"
export PNPM_HOME="$BASE_HOME/cache/pnpm-home"
export npm_config_update_notifier=false
export npm_config_fund=false
export npm_config_audit=false
export NO_UPDATE_NOTIFIER=1

rm -rf "$BASE_HOME"
mkdir -p "$BASE_HOME/cache" "$BASE_HOME/logs"
LOG_DIR="$BASE_HOME/logs"
LOG_SEQ=0
PASS=0
FAIL=0
FAILED_LIST=""
SERVER_PID=""
MCP_PIDS=""
MCP_PIDS_BEFORE=""

cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -TERM "$SERVER_PID" 2>/dev/null
    n=0
    while kill -0 "$SERVER_PID" 2>/dev/null && [ "$n" -lt 40 ]; do
      sleep 0.25
      n=$((n + 1))
    done
    kill -KILL "$SERVER_PID" 2>/dev/null
  fi
  for pid in $MCP_PIDS; do
    kill -TERM "$pid" 2>/dev/null
  done
  if [ "$KEEP" -eq 1 ]; then
    printf 'verify: kept isolated DSH_HOME at %s\n' "$BASE_HOME"
  else
    rm -rf "$BASE_HOME"
    rmdir "$ROOT/.dsh-test" 2>/dev/null || true
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

logfile() {
  LOG_SEQ=$((LOG_SEQ + 1))
  printf '%s/%02d-%s.log' "$LOG_DIR" "$LOG_SEQ" "$1"
}

pass() {
  PASS=$((PASS + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILED_LIST="${FAILED_LIST}  - $1"$'\n'
  printf 'FAIL  %s\n' "$1"
  if [ "$#" -ge 2 ] && [ -f "$2" ]; then
    printf '      --- %s (tail) ---\n' "$2"
    tail -n 20 "$2" | sed 's/^/      /'
  fi
}

note() {
  printf 'NOTE  %s\n' "$1"
}

run_ok() {
  name="$1"
  log="$2"
  shift 2
  if "$@" >"$log" 2>&1; then
    pass "$name"
    return 0
  fi
  fail "$name" "$log"
  return 1
}

assert_grep() {
  name="$1"
  file="$2"
  pattern="$3"
  # Patterns are anchored regular expressions written for the dump-config text.
  if [ -f "$file" ] && grep -Eq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name (pattern not found: $pattern)"
  fi
}

# --- checks ------------------------------------------------------------------

check_syntax() {
  node --check "$ROOT/src/index.js" &&
    node --check "$ROOT/src/frontmatter.js" &&
    node --check "$ROOT/scripts/lint-skills.mjs"
}

check_tests() {
  ( cd "$ROOT" && node --test test/plugin.test.mjs )
}

check_lint() {
  ( cd "$ROOT" && node scripts/lint-skills.mjs )
}

check_manifest() {
  node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    const root = process.argv[1];
    const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
    if (pkg.name !== "dsh-rev-eng") throw new Error("unexpected package name: " + pkg.name);
    const patch = pkg.dsh && pkg.dsh.bundle && pkg.dsh.bundle.patch;
    if (!patch) throw new Error("package.json has no dsh.bundle.patch");
    if (!fs.existsSync(path.join(root, patch))) throw new Error("bundle patch file is missing: " + patch);
    if (!pkg.engines || !pkg.engines.dsh) throw new Error("package.json has no engines.dsh");
    console.log("name=" + pkg.name);
    console.log("bundle.patch=" + patch);
    console.log("engines.dsh=" + pkg.engines.dsh);
  ' "$ROOT"
}

check_profile_manifest() {
  node -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
    const bundles = (pkg.dsh && pkg.dsh.profile && pkg.dsh.profile.bundles) || [];
    if (!bundles.includes("dsh-rev-eng")) {
      throw new Error("dsh-rev-eng missing from dsh.profile.bundles: " + JSON.stringify(bundles));
    }
    const dep = pkg.dependencies && pkg.dependencies["dsh-rev-eng"];
    if (!dep) throw new Error("dsh-rev-eng dependency is missing");
    if (!/^(link:|file:)/.test(dep)) throw new Error("unexpected dependency spec: " + dep);
    console.log("bundles=" + JSON.stringify(bundles));
    console.log("dependency=" + dep);
  ' "$BASE_HOME/profiles/$CORE_PROFILE/package.json"
}

install_core() {
  "$DSH_BIN" plugin --profile "$CORE_PROFILE" add "$ROOT"
}

install_web() {
  "$DSH_BIN" plugin --profile "$WEB_PROFILE" add "$ROOT"
}

printf 'dsh-rev-eng verification\n'
printf '  repo:  %s\n' "$ROOT"
printf '  dsh:   %s (%s)\n' "$(command -v "$DSH_BIN")" "$("$DSH_BIN" --version 2>/dev/null | head -n 1)"
printf '  node:  %s\n' "$(node --version)"
printf '  home:  %s\n' "$BASE_HOME"
printf '  mode:  %s\n' "$([ "$FULL" -eq 1 ] && printf 'full (live boot + MCP)' || printf 'offline core')"

# [1/6] static checks ----------------------------------------------------------
printf '\n[1/6] static checks\n'
run_ok "syntax: node --check src/index.js src/frontmatter.js scripts/lint-skills.mjs" "$(logfile syntax)" check_syntax
run_ok "unit tests: node --test test/plugin.test.mjs" "$(logfile unit-tests)" check_tests
run_ok "skills lint: node scripts/lint-skills.mjs" "$(logfile lint-skills)" check_lint
run_ok "package manifest: dsh.bundle.patch exists, engines.dsh present" "$(logfile manifest)" check_manifest

# [2/6] isolated install + bundle composition ---------------------------------
printf '\n[2/6] isolated profile install + bundle composition\n'
run_ok "dsh plugin --profile $CORE_PROFILE add <repo> (fresh isolated profile)" "$(logfile install)" install_core
run_ok "profile manifest lists dsh-rev-eng bundle with a link: dependency" "$(logfile profile-manifest)" check_profile_manifest

DUMP_CORE_LOG="$(logfile dump-config-core)"
if "$DSH_BIN" --profile "$CORE_PROFILE" --dump-config >"$DUMP_CORE_LOG" 2>&1; then
  pass "dsh --profile $CORE_PROFILE --dump-config exits 0"
  assert_grep "composed tree contains the '# == dsh-rev-eng' bundle layer" "$DUMP_CORE_LOG" '^# == dsh-rev-eng$'
  assert_grep "bundle layer inserts the rev-eng-skills row" "$DUMP_CORE_LOG" '^- id: rev-eng-skills$'
  assert_grep "rev-eng-skills row mounts the dsh-rev-eng plugin" "$DUMP_CORE_LOG" '^  name: dsh-rev-eng$'
else
  fail "dsh --profile $CORE_PROFILE --dump-config exits 0" "$DUMP_CORE_LOG"
fi

# [3/6] REA MCP overlay --------------------------------------------------------
printf '\n[3/6] REA MCP overlay (patches/rea-mcp.yml)\n'
if [ ! -f "$OVERLAY" ]; then
  fail "patches/rea-mcp.yml exists (required optional overlay)"
else
  OVERLAY_LOG="$(logfile dump-config-overlay)"
  if "$DSH_BIN" --profile "$CORE_PROFILE" --patch "$OVERLAY" --dump-config >"$OVERLAY_LOG" 2>&1; then
    pass "dsh --patch patches/rea-mcp.yml --dump-config exits 0"
    assert_grep "overlay appears as its own composed layer" "$OVERLAY_LOG" 'patches/rea-mcp.yml'
    assert_grep "overlay inserts id rea-mcp (the id rea setup --client dsh uses)" "$OVERLAY_LOG" '^- id: rea-mcp$'
    assert_grep "row mounts @deepseek-ai/dsh-mcp-client" "$OVERLAY_LOG" "^  name: '@deepseek-ai/dsh-mcp-client'$"
    assert_grep "row sets serverName: rea" "$OVERLAY_LOG" '^    serverName: rea$'
    assert_grep "row uses stdio transport" "$OVERLAY_LOG" '^    transport: stdio$'
    assert_grep "row pins rea-agents@6.8.0" "$OVERLAY_LOG" 'rea-agents@6.8.0'
    assert_grep "row sets an explicit toolCallTimeoutMs" "$OVERLAY_LOG" 'toolCallTimeoutMs:'
  else
    fail "dsh --patch patches/rea-mcp.yml --dump-config exits 0" "$OVERLAY_LOG"
  fi

  BAD_OVERLAY="$BASE_HOME/malformed-overlay.yml"
  printf -- '- insert: [unterminated\n' >"$BAD_OVERLAY"
  BAD_LOG="$(logfile dump-config-malformed)"
  if "$DSH_BIN" --profile "$CORE_PROFILE" --patch "$BAD_OVERLAY" --dump-config >"$BAD_LOG" 2>&1; then
    fail "malformed --patch overlay is rejected (expected nonzero exit)"
  else
    pass "malformed --patch overlay is rejected (expected nonzero exit)"
    note "the overlay parser is active, so a green overlay check above is meaningful"
  fi
fi

# [4/6] desktop-profile guard --------------------------------------------------
printf '\n[4/6] desktop-profile guard (read-only; argument validation refuses before any profile is read)\n'
DESKTOP_LOG="$(logfile desktop-guard)"
if "$DSH_BIN" --profile desktop --dump-config >"$DESKTOP_LOG" 2>&1; then
  fail "dsh --profile desktop --dump-config is refused (unexpectedly succeeded)"
else
  if grep -Fq 'managed exclusively by the Electron application' "$DESKTOP_LOG"; then
    pass "desktop profile boot/dump is refused with the Electron-managed message"
  else
    fail "desktop profile refusal message changed" "$DESKTOP_LOG"
  fi
fi

# [5/6] optional live boot + MCP connection ------------------------------------
printf '\n[5/6] live boot + REA MCP connection\n'
if [ "$FULL" -ne 1 ]; then
  note "skipped (offline mode): run with --full to boot dsh web and verify the MCP child"
else
  run_ok "dsh plugin --profile $WEB_PROFILE add <repo> (isolated web profile)" "$(logfile install-web)" install_web

  if command -v pgrep >/dev/null 2>&1; then
    MCP_PIDS_BEFORE="$(pgrep -f 'rea-agents@6\.8\.0 mcp' 2>/dev/null | sort | tr '\n' ' ')"
  fi

  BOOT_OUT="$(logfile boot-stdout)"
  BOOT_ERR="$(logfile boot-stderr)"
  "$DSH_BIN" --profile "$WEB_PROFILE" --patch "$OVERLAY" --port 0 --no-open >"$BOOT_OUT" 2>"$BOOT_ERR" &
  SERVER_PID=$!
  note "started dsh web (pid $SERVER_PID); waiting for the server URL"

  BOOTED=0
  i=0
  while [ "$i" -lt 240 ]; do
    if grep -Fq 'dsh web:' "$BOOT_OUT" 2>/dev/null; then
      BOOTED=1
      break
    fi
    kill -0 "$SERVER_PID" 2>/dev/null || break
    sleep 0.5
    i=$((i + 1))
  done

  if [ "$BOOTED" -eq 1 ]; then
    pass "dsh web boots the isolated profile with the plugin bundle and REA MCP overlay"
  else
    BOOT_FAIL_LOG="$(logfile boot-failure)"
    cat "$BOOT_OUT" "$BOOT_ERR" >"$BOOT_FAIL_LOG" 2>/dev/null
    fail "dsh web boot completes (server URL printed)" "$BOOT_FAIL_LOG"
  fi

  if [ "$BOOTED" -eq 1 ]; then
    if grep -Fq 'did not activate' "$BOOT_ERR"; then
      fail "no plugin activation warnings during boot" "$BOOT_ERR"
    else
      pass "no plugin activation warnings during boot"
    fi

    if command -v pgrep >/dev/null 2>&1; then
      MCP_FOUND=""
      i=0
      while [ "$i" -lt 240 ]; do
        MCP_FOUND="$(pgrep -f 'rea-agents@6\.8\.0 mcp' 2>/dev/null | sort | tr '\n' ' ')"
        [ -n "$MCP_FOUND" ] && break
        kill -0 "$SERVER_PID" 2>/dev/null || break
        sleep 0.5
        i=$((i + 1))
      done
      MCP_NEW=""
      for pid in $MCP_FOUND; do
        case " $MCP_PIDS_BEFORE " in
          *" $pid "*) ;;
          *) MCP_NEW="$MCP_NEW $pid" ;;
        esac
      done
      MCP_PIDS="$MCP_NEW"
      if [ -n "$MCP_PIDS" ]; then
        pass "dsh-mcp-client connected to REA (MCP child process:$MCP_PIDS)"
      else
        fail "dsh-mcp-client spawns the REA MCP server (no matching child process)" "$BOOT_ERR"
      fi
    else
      note "pgrep is unavailable; skipped the REA child-process check"
    fi
  fi

  note "stopping dsh web (pid $SERVER_PID)"
  kill -TERM "$SERVER_PID" 2>/dev/null
  i=0
  while kill -0 "$SERVER_PID" 2>/dev/null && [ "$i" -lt 80 ]; do
    sleep 0.25
    i=$((i + 1))
  done
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -KILL "$SERVER_PID" 2>/dev/null
    fail "dsh web stops on SIGTERM"
  else
    pass "dsh web stops on SIGTERM"
  fi
  SERVER_PID=""

  LEAK=""
  if [ -n "$MCP_PIDS" ]; then
    i=0
    while [ "$i" -lt 80 ]; do
      LEAK=""
      for pid in $MCP_PIDS; do
        kill -0 "$pid" 2>/dev/null && LEAK="$LEAK $pid"
      done
      [ -z "$LEAK" ] && break
      sleep 0.25
      i=$((i + 1))
    done
  fi
  if [ -n "$LEAK" ]; then
    fail "MCP child processes exit after the harness stops (left:$LEAK)"
    for pid in $LEAK; do
      kill -KILL "$pid" 2>/dev/null
    done
  else
    pass "MCP child processes exit after the harness stops"
  fi
  MCP_PIDS=""
fi

# [6/6] summary ----------------------------------------------------------------
printf '\n[6/6] summary\n'
printf 'checks: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
  printf 'failed checks:\n%b' "$FAILED_LIST"
  printf 'verify: FAIL\n'
  exit 1
fi
printf 'verify: PASS\n'
exit 0
