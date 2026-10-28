# verification — acceptance gate for dsh-rev-eng

Repeatable checks that prove the `dsh-rev-eng` package is a valid, installable DeepSeek
Harness plugin bundle: static checks, unit tests, skills lint, a real isolated-profile
install into dsh, bundle-layer composition through `dsh --dump-config`, the optional REA
MCP overlay, an optional live `dsh web` boot with the MCP server connected, and cleanup.

It never touches `~/.dsh` and never installs into the Electron-managed `desktop` profile.

## Contents

| File | Purpose |
|---|---|
| `verify.sh` | The gate. Exit 0 only when every executed check passes. |
| `README.md` | This file: how to run it, what each check proves, known limits. |
| `REPORT.md` | Findings: tested install story, desktop/Plugins-UI behaviour, REA MCP results, bugs, exact commands. |

## Requirements

- macOS or Linux with the DeepSeek Harness CLI on `PATH` (`dsh`; tested with
  `0.2.1-rc.3` from the desktop app installation). `DSH_BIN=/path/to/dsh` overrides it.
- Node.js >= 22 on `PATH` (used for `node --check`, `node --test`, and the lint script).
- Default (offline) mode needs no network and no npm registry access.
- `--full` needs a free loopback port and network access on its first run: it boots
  `dsh web` and lets `dsh-mcp-client` start the REA server through `npx`, which downloads
  `rea-agents@6.8.0` once (about 13 s cold on this machine; instant once cached).

## Run it

From the package root (the directory containing `package.json`):

```sh
./verification/verify.sh          # offline acceptance gate
./verification/verify.sh --full   # + live dsh web boot with the REA MCP overlay
./verification/verify.sh --keep   # keep the isolated DSH_HOME after the run
./verification/verify.sh --help
```

The path may contain spaces; every path in the script is quoted. Examples below use
`ROOT="$(pwd)"` to make that explicit.

## What the checks prove

| Section | Checks | What a pass proves |
|---|---|---|
| 1. static | `node --check src/index.js src/frontmatter.js scripts/lint-skills.mjs`; `node --test test/plugin.test.mjs`; `node scripts/lint-skills.mjs` | The plugin source parses, the provider contract and packaged skill tree pass the unit tests (all 23 skills list/load with no ignored directories), and every shipped `SKILL.md` meets the porting contract (frontmatter, forbidden strings, relative links). |
| 1. static | package manifest | `package.json` declares `dsh.bundle.patch`, the referenced patch file exists, and `engines.dsh` is present — the three fields dsh checks when it loads a bundle. |
| 2. install + composition | `dsh plugin --profile reveng-verify add "$ROOT"` | dsh's own plugin command (forwarding to the installation's bundled pnpm) accepts the package from an absolute local path, records it as a profile dependency and selects its bundle, in a fresh profile inside the isolated home. |
| 2. install + composition | `dsh --profile reveng-verify --dump-config` | The profile composes: the bundle layer appears as `# == dsh-rev-eng` and inserts `- id: rev-eng-skills / name: dsh-rev-eng`. This is the same composition dsh mounts at boot, without mounting it. |
| 3. REA MCP overlay | `dsh --profile reveng-verify --patch "$ROOT/patches/rea-mcp.yml" --dump-config` | The shipped overlay parses through the real dsh patch loader and composes a `rea-mcp` row for `@deepseek-ai/dsh-mcp-client` with `serverName: rea`, stdio, the pinned `rea-agents@6.8.0` launcher and an explicit `toolCallTimeoutMs`. |
| 3. REA MCP overlay | malformed-overlay negative control | A deliberately broken YAML overlay makes `--dump-config` exit non-zero. This proves the overlay-pass check above is meaningful (dsh really parses the file rather than ignoring it). |
| 4. desktop guard | `dsh --profile desktop --dump-config` | The CLI refuses to boot/dump the `desktop` profile (`profile "desktop" is managed exclusively by the Electron application`). The check is read-only: the launcher rejects the profile name before it reads any profile file. |
| 5. full only | `dsh plugin --profile web add "$ROOT"` then `dsh --profile web --patch patches/rea-mcp.yml --port 0 --no-open` | A real harness boot of an isolated web profile: the server URL is printed, **no plugin activation warnings** appear, `dsh-mcp-client` spawns the REA MCP server (matching child process), and both the server and the child stop on SIGTERM without leaving processes behind. |

Checks 1–4 are the default gate; check 5 only runs with `--full`.

## Isolation and safety

- Owns exactly `<repo>/.dsh-test/verify-home/` (gitignored). It is removed before the
  run and removed after it, unless `--keep`. `VERIFY_DSH_HOME` may point elsewhere, but
  only under `<repo>/.dsh-test/`.
- Exports `DSH_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`,
  `npm_config_cache`, `npm_config_store_dir` and `PNPM_HOME` into that directory, so the
  pnpm/npm runs of the dsh installation do not need to write under `$HOME` (the file
  sandbox used for this project denies writes outside the workspace).
- Never writes to `~/.dsh`. The only desktop-profile interaction is argument validation
  (`--help`-level), which refuses before reading anything.
- The `web` profile used by `--full` is created from the shipped template inside the
  isolated home, not in the user's `~/.dsh`.
- Cleanup runs on `EXIT`, `INT` and `TERM`; the booted server is SIGTERM'd, the MCP child
  is tracked to exit, and the script kills only processes it started (any pre-existing
  `rea-agents@6.8.0 mcp` process is excluded from the check).

## Modes

Default — fast, deterministic, offline. Typical total runtime is well under 10 s.

`--full` — additionally boots the real harness. The first run downloads the REA npm
package into the isolated npm cache (~13 s cold on this machine); later runs in the same
home cannot reuse it because the home is recreated, so treat ~20 s as normal for `--full`.
The check prints the steps and fails with the relevant log file when something does not
activate.

## Expected result

```
[6/6] summary
checks: 20 passed, 0 failed
verify: PASS
```

with `--full`:

```
[6/6] summary
checks: 26 passed, 0 failed
verify: PASS
```

Exit codes: `0` all checks passed, `1` at least one check failed (the failing log tail is
printed), `2` bad invocation/argument, missing `dsh` or `node`, or an unsafe
`VERIFY_DSH_HOME`.

## Troubleshooting

- **`dsh` not found** — put the DeepSeek Harness CLI on `PATH` or pass
  `DSH_BIN=/absolute/path/to/dsh`.
- **`--full` stays on "waiting for the server URL"** — read the printed log path
  (use `--keep` to keep it). Typical causes: the loopback port could not be bound, or the
  npm cache cannot be written.
- **`--full` fails the MCP child check** — run `npx -y rea-agents@6.8.0 mcp` once in a
  terminal to warm/download the package; check that `npx` is on `PATH` and that the npm
  cache directory is writable. The REA 6.8.0 package prints an `EBADENGINE` warning on
  Node versions it does not formally support; that warning alone does not prevent the MCP
  server from starting.
- **Lint or unit-test failures** — the package is not ready; the failing assertions name
  the offending skill or file. Do not work around them in the gate.
- **Everything else** — rerun with `--keep` and inspect
  `.dsh-test/verify-home/logs/`. Logs are numbered in run order; the file name appears in
  each failure line.

## Limits (honest scope)

- The gate never clicks the desktop app's Plugins UI and never installs into the user's
  real profiles (that would mutate `~/.dsh`). The GUI install path is documented and
  evidenced in `REPORT.md`; the CLI-equivalent install it exercises is the same profile
  package operation.
- It does not open an LLM session, so it does not assert the live model-facing skill
  catalog; the provider contract and packaged tree are covered by `test/plugin.test.mjs`,
  and `--full` proves the bundle imports and applies at boot.
- The MCP child-process check relies on `pgrep` (available on macOS/Linux); when absent the
  check is skipped with a note.
- `--full` depends on `npx`/network for the first REA download.

See `REPORT.md` for the tested install story, official REA setup comparison, desktop
profile behaviour and the bugs/risks found while building this gate.
