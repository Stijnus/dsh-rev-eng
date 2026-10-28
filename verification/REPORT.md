# Verification report — dsh-rev-eng

Status: **PASS** (final gate, 2026-10-28)
Package: `dsh-rev-eng@0.1.0` · REA `rea-agents@6.8.0` + BAMA `1.0.0` · 23 skills
Tested against: DeepSeek Harness `dsh 0.2.1-rc.3` (desktop app installation)

This report records what was actually executed, what worked, what failed and why, and
what the docs writer can safely claim. Everything ran in an isolated `DSH_HOME` under the
workspace; the user's `~/.dsh`, the `desktop` profile and the running Electron app were
never modified.

---

## 1. Final gate result

| Command | Result |
|---|---|
| `./verification/verify.sh` | **PASS** — 20 checks passed, 0 failed (offline, ~4 s) |
| `./verification/verify.sh --full` | **PASS** — 26 checks passed, 0 failed (~17 s cold, includes live boot + MCP connect) |
| `node --test test/plugin.test.mjs` | 9/9 tests pass (all 23 packaged skills list and load) |
| `node scripts/lint-skills.mjs` | 23 skills, 101 relative links, 0 errors |
| `dsh plugin --profile <test> add <repo>` (isolated) | exit 0, 189–298 ms, profile records `"dsh-rev-eng": "link:<repo>"` |
| `dsh --profile <test> --dump-config` (isolated) | exit 0, contains `# == dsh-rev-eng` → `- id: rev-eng-skills / name: dsh-rev-eng` |
| `dsh --profile <test> --patch patches/rea-mcp.yml --dump-config` | exit 0, contains the `rea-mcp` mcp-client row |
| `./verification/verify.sh --full` MCP check | live `dsh web` boot, no activation warnings, REA MCP child process connected and exited cleanly |

The single command to reproduce the gate:

```sh
cd "/Users/stijnus/Developer/GitHub/Deepseek Plugins/dsh-rev-eng" && ./verification/verify.sh --full
```

Drop `--full` for the offline gate (no network needed).

---

## 2. Environment and method

| Fact | Value |
|---|---|
| dsh CLI | `/usr/local/bin/dsh` → desktop app's bundled carrier (`runDesktopCli`), version `0.2.1-rc.3` |
| Desktop app | running at `http://127.0.0.1:49199`, profile `~/.dsh/profiles/desktop` — untouched |
| Host | macOS (REA doctor reports 27.2), Node in PATH `v24.18.0`, app runtime Node `v24.21.0` |
| Package managers | desktop-bundled pnpm `11.28.5`, npm `11.16.0` |
| Isolated home | `<repo>/.dsh-test/...` (gitignored), caches redirected inside the workspace |
| File sandbox | workspace-write: writes outside the workspace are denied, so every experiment wrote only under `<repo>/.dsh-test/` and `.npm-cache/` |

Method: install and compose the bundle in a fresh profile inside the isolated home; prove
the composed tree with `dsh --dump-config`; validate the REA overlay by parsing it through
dsh and by booting a real `dsh web` server; probe the REA MCP server directly over stdio;
repeat the official REA dsh setup/doctor path in the isolated home. No GUI state was
clicked and no real profile was installed into.

---

## 3. Tested install story

### 3.1 Bundle install into an existing profile (CLI, tested)

This is the operation the Plugins UI performs, exercised through `dsh plugin` in a fresh
profile inside the isolated home:

```sh
ROOT="$(pwd)"                                   # the package root
export DSH_HOME="$ROOT/.dsh-test/some-home"     # isolated test home only
dsh plugin --profile reveng-verify add "$ROOT"
```

Observed (exit 0):

```text
dsh: initialized profile reveng-verify at <DSH_HOME>/profiles/reveng-verify
dependencies:
+ dsh-rev-eng 0.1.0 <- ../../..
Done in 189ms using pnpm v11.28.5
```

The profile then records both the dependency and the bundle selection:

```json
{
  "dependencies": { "dsh-rev-eng": "link:/Users/stijnus/.../dsh-rev-eng" },
  "dsh": { "profile": { "bundles": ["@deepseek-ai/dsh-base", "dsh-rev-eng"] } }
}
```

Composition proof:

```sh
dsh --profile reveng-verify --dump-config
# ...
# == dsh-rev-eng
- id: rev-eng-skills
  name: dsh-rev-eng
```

No registry access is needed: a local directory install is saved as a `link:` dependency,
so the checkout must stay in place. For distribution prefer an npm registry install
(publish the package with its `dsh.bundle.patch` manifest) or a Git/tarball spec.

Notes for the README:

- Install into an **existing app profile** (`web`, `tui`, `headless`), or through the
  desktop app's Plugins page. A brand-new arbitrary profile name is initialized with only
  `@deepseek-ai/dsh-base` (no app bundle) and therefore cannot boot — `dsh plugin … add`
  alone does not give you a runnable app profile.
- `dsh plugin --profile <name> remove dsh-rev-eng` (or the Plugins page) uninstalls it.

### 3.2 Desktop app: Plugins UI vs CLI

The desktop app's profile cannot be managed by ordinary CLI commands:

```text
$ dsh --profile desktop --dump-config
error: profile "desktop" is managed exclusively by the Electron application
$ echo $?
1
```

The refusal is implemented in the launcher's argument parser (`rejectElectronProfile` in
`@deepseek-ai/dsh/lib/bin.js`), takes effect before any profile file is read, and applies
to boot/dump invocations from every `dsh` binary.

For the **Plugins page** itself (documented in the installed client's
`@deepseek-ai/dsh-client-ui-plugin-manager` README and the plugin-market guide):

- Sidebar **Plugins → Add plugin** opens the install dialog. `Add plugin` accepts a
  package name with optional version, a Git address, a tarball, or an **absolute local
  path**. The Host first reads what the spec names (`pluginManager.inspect`): a registry
  name via `pnpm view`, a local path by reading its `package.json`; it rejects a path
  without a package, a package without a bundle patch, and packages whose `engines.dsh` /
  DSH peer requirements reject the running version before anything is installed.
- Install runs the profile's package operation (bundled pnpm), streams the output, and
  offers **Enable now**; the bundle then joins the profile's selection. Uninstall is on
  the bundle's page; registry-installed bundles also get version checks/Update, while
  `link:`/git/tarball installs do not.
- `Add plugin`'s dialog explicitly says “a package name is what follows `dsh plugin add`
  in a README”. So the UI install is the same operation verified in §3.1, scoped to the
  running profile.
- Desktop package operations are owned by the Desktop shell (documented limitation of the
  plugin-manager service), and the UI is the supported way to install into the running
  desktop profile.

Evidence that third-party npm bundles are routinely installed through this UI: the user's
`~/.dsh/profiles/desktop/package.json` lists six third-party bundles installed as registry
dependencies — `dsh-composer-predictions`, `dsh-cost-meter`, `dsh-moodboard`,
`dsh-move-to-workspace`, `dsh-prompt-rewrite`, `dsh-workspace-status` (read-only
observation; the versions move as the user updates them).

**Desktop CLI nuance (recorded, not executed against the real profile).** The `dsh`
binary shipped by the desktop app passes `manageDesktopProfile: true` to the launcher
(`@deepseek-ai/dsh-desktop-host/lib/cli.js`), which skips the Electron-managed refusal
for the `plugin` subcommand only. So from this app's own CLI,
`dsh plugin --profile desktop …` is *not* refused by argument parsing — it would lock
`~/.dsh/profiles/desktop/package.json` and forward to the app's bundled pnpm; source
(`@deepseek-ai/dsh/lib/plugin-*.js`) tells the operator to open Desktop once to initialize
the profile and to fully quit it before running the command. A standalone npm-installed
`dsh` CLI would refuse it with the Electron-managed error. **Do not document
`dsh plugin --profile desktop add …` as the recommended path; use the Plugins page.** We
did not run any desktop-profile package operation, by design.

For this package (not yet published to npm), the practical desktop install paths are:

1. **Plugins page → Add plugin → Install a third-party plugin → absolute local path of the
   checkout** (installs as `link:`; the checkout must remain in place). This is the same
   inspect→pnpm→enable operation tested in §3.1.
2. Publish to npm (or host a tarball/Git repo) and install that spec through the same
   dialog — recommended for other users.
3. Skills-only drop-in via `scripts/install.sh` (copy under `~/.dsh/skills` etc.), which
   the skill-root watcher picks up without an app restart (§6).

### 3.3 One-shot trial with `--patch` (important correction)

`patches/rea-mcp.yml` is a valid one-shot overlay because it mounts an
installation-owned package (`@deepseek-ai/dsh-mcp-client`):

```sh
dsh --profile web --patch "$(pwd)/patches/rea-mcp.yml"
```

But the bundle's own layer, `cordis.patch.yml`, is **not** usable as a one-shot trial of
the skill pack. Verified:

```text
$ dsh --profile web --patch "$PWD/cordis.patch.yml" --port 0 --no-open
dsh web: http://127.0.0.1:51009/?token=…
dsh: warning: 1 entry did not activate
rev-eng-skills (dsh-rev-eng): failed to import: Error [ERR_MODULE_NOT_FOUND]:
Cannot find package 'dsh-rev-eng' imported from <DSH_HOME>/profiles/web/
```

The harness still boots, but the skills are absent. The row only resolves when the
package is installed into the profile (the bundle install enables the same layer without
`--patch`). Document the trial as: install the bundle into a profile (CLI or GUI), then
start the app; or use the drop-in copy for a no-install trial.

---

## 4. Bundle composition proof (detail)

`dsh --profile <test> --dump-config` on the isolated profile lists the composed layers in
order and ends with the bundle layer:

```text
# == @deepseek-ai/dsh-base
- id: tool-plugin-manager
…
# == dsh-rev-eng
- id: rev-eng-skills
  name: dsh-rev-eng
```

The plugin is imported and applied at boot (see the `--full` check: the web server starts
with no plugin activation warnings). The unit tests additionally exercise
`apply()`/`createProvider()` against the real packaged tree, including the rank-400
`bundled` candidates and the user-invocable router policy.

---

## 5. REA MCP overlay — findings

### 5.1 The shipped overlay

`patches/rea-mcp.yml` (rea-porter) composes a row:

```yaml
- insert:
    - id: rea-mcp
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: rea
        transport: stdio
        command: npx
        args: ['-y', 'rea-agents@6.8.0', 'mcp']
        toolCallTimeoutMs: 600000
```

Validated end to end in the isolated home:

- `--dump-config` composition: exit 0, overlay is its own last layer, all fields present.
- Malformed-overlay negative control: dsh rejects invalid YAML with exit 1
  (`failed to parse overlay … YAMLException`), so the pass is not vacuous.
- Live boot (`dsh web --port 0 --no-open --patch <overlay>` with the bundle installed into
  an isolated `web` profile): server URL printed, **no** `dsh: warning: … did not
  activate`, `dsh-mcp-client` spawned `npm exec rea-agents@6.8.0 mcp` (observed child
  process), SIGTERM shut both down cleanly.
  This is asserted by `./verification/verify.sh --full`.

### 5.2 Direct REA MCP server probe (no dsh involved)

Command run in the workspace with `npm_config_cache=<workspace>/.npm-cache`:

```sh
npx -y rea-agents@6.8.0 mcp
```

JSON-RPC over stdio (initialize + `notifications/initialized` + `tools/list`):

| Measurement | Result |
|---|---|
| Cold start with empty npm cache (downloading package) | ~12.7 s to the `initialize` result |
| Warm cache, spawn → `initialize` response | **620 ms** |
| Warm cache, `initialize` → `tools/list` response | **677 ms** |
| Server identity | `{"name":"rea","version":"6.8.0"}` |
| Protocol revision returned | `2024-11-05` |
| Tools listed | **229** (`inspect_analysis_settings`, `open_binary`, … — matches the documented count) |
| Shutdown | SIGTERM → exit 0 |

Caveat: npm prints `EBADENGINE` — `rea-agents@6.8.0` declares
`node: ^22.23.4 || ^24.22.1 || >=26.12.1`, and this machine runs Node `24.18.0`
(app runtime `24.21.0`). It is a warning for the MCP server, which starts and serves
normally; it is a hard failure for `rea setup` (see §5.4).

### 5.3 Official REA 6.8.0 support for DeepSeek Harness (verified)

REA 6.8.0 does ship a `dsh` client: `rea setup --client dsh` targets
`$DSH_HOME/cordis.patch.yml` (the home-level patch, i.e. *every* profile on the machine)
with entry id `rea-mcp`, name `@deepseek-ai/dsh-mcp-client`, `serverName: rea`,
`transport: stdio`, and a launcher command.

The exact command from the task, on this machine:

```sh
cd "/Users/stijnus/Developer/GitHub/Deepseek Plugins/dsh-rev-eng"
npm_config_cache="$PWD/.npm-cache" npx -y rea-agents@6.8.0 \
  setup --client dsh --skill=false --dry-run --json
# exit 1, status "needs_human", plannedActions []
# remediation: "Install Node.js 22.x (>=22.23.4), 24.x (>=24.22.1), or 26.12.1+ and rerun setup."
```

`--skill=false` **is** accepted (doctor scope reports `"skill": false`; no skill action is
planned). The only blocker on the first run is the Node engine gate. Nothing was written
(`--dry-run`, no `--yes`; appliedActions is empty).

To see the real plan without changing the machine's Node, run the CLI under a compliant
Node fetched into the workspace cache:

```sh
export npm_config_cache="$PWD/.npm-cache"
NODE24=$(npx -y node@24.22.1 -p process.execPath)   # v24.22.1, cached in the workspace
REA="$PWD/.npm-cache/_npx/<hash>/node_modules/rea-agents/scripts/rea.mjs"
DSH_HOME="$PWD/.dsh-test" "$NODE24" "$REA" setup --client dsh --skill=false --dry-run --json
```

Result `status: "planned"`, one action:

```json
{
  "id": "configure_client:dsh",
  "kind": "configure_client",
  "label": "DeepSeek Harness",
  "target": "<DSH_HOME>/cordis.patch.yml",
  "operation": "create",
  "detail": "Add the REA MCP registration for DeepSeek Harness; preserve unrelated configuration. … Command: \"<abs>/rea-agents/scripts/rea.mjs\" \"mcp\". No additional provider environment variables. Existing server environment overrides are retained."
}
```

The row REA would write (generated by calling REA's own serializer with the planned
command, then verified through dsh):

**Invoked via `npx`** (this is what a user gets from `npx -y rea-agents@6.8.0 setup …`;
REA detects the package runner and registers the `npx` launcher):

```yaml
- insert:
    - id: rea-mcp
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: rea
        transport: stdio
        command: npx
        args:
          - -y
          - rea-agents@6.8.0
          - mcp
```

**Invoked through a globally installed `rea` / direct entrypoint** (the plan above, run
directly under `node …/scripts/rea.mjs`): the POSIX plan registers the absolute
entrypoint script, which runs through its shebang:

```yaml
- insert:
    - id: rea-mcp
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: rea
        transport: stdio
        command: /Users/…/node_modules/rea-agents/scripts/rea.mjs
        args:
          - mcp
```

(On Windows REA registers `process.execPath` + the entrypoint script instead; on POSIX a
PATH alias `rea` that resolves to the same file is preferred when present.)

The home patch layer is real and applies to every profile, confirmed by
`dsh --profile web --dump-config` in the isolated home: the final layer header is
`# == <DSH_HOME>/cordis.patch.yml` and it contains the `rea-mcp` row.

`rea doctor --client dsh --json` (isolated `DSH_HOME`):

| Run | Exit | Salient output |
|---|---|---|
| Plain `node 24.18.0` | 1 | `scope_checks`: `node` `ok:false` (`missing_dependency`, 24.18.0) + `registration:dsh` `ok:false` (`config_drift`) ; `identity.registrations[dsh]` = `{ state: "missing", command: [], config_path: "<DSH_HOME>/cordis.patch.yml" }` ; 19 informational checks, all analysis engines missing (`hopper`, `ghidra`, `ida`, `jadx`, `kuna`) |
| `node 24.22.1` | 1 | same, but `node` check is `ok:true` (`healthy`) |
| `node 24.22.1` after writing the generated row into isolated `$DSH_HOME/cordis.patch.yml` | **0** | `healthy: true` (environment still unhealthy for missing engines), `registration:dsh` `ok:true`, `identity.registrations[dsh]` = `{ state: "aligned", command: ["npx","-y","rea-agents@6.8.0","mcp"], package_reference: "rea-agents@6.8.0" }` |

So the official row shape is what REA's own tooling expects, and it composes in dsh.

### 5.4 Overlay vs official row — divergence

| Aspect | Official `rea setup --client dsh` | Shipped `patches/rea-mcp.yml` |
|---|---|---|
| Entry id | `rea-mcp` | `rea-mcp` (matches) |
| Module name | `@deepseek-ai/dsh-mcp-client` | same |
| `serverName` / transport | `rea` / `stdio` | same |
| Launcher | `npx -y rea-agents@6.8.0 mcp` when invoked via npx, otherwise absolute `scripts/rea.mjs` + `mcp` | `npx -y rea-agents@6.8.0 mcp` |
| `toolCallTimeoutMs` | **absent** (dsh default 60 000 ms) | **600000** (preserved on purpose: REA static-analysis deadlines are 300 000 ms and cold Ghidra imports can exceed that) |
| `env` | none | none |
| Target layer | `$DSH_HOME/cordis.patch.yml` (home layer, all profiles, desktop included) | profile `cordis.patch.yml` or a one-shot `--patch` |
| Managed by REA tooling | yes (`rea doctor`, future setup runs rewrite it) | recognized by id if merged into the home patch; otherwise independent |

Only the timeout (and the target layer/launcher choice when the official setup is run from
a global install) differ. REA's own setup preserves caller-owned config fields when it
rewrites its row (`config` keys other than the launcher fields are kept), so a row using
id `rea-mcp` can carry `toolCallTimeoutMs` across official setup runs.

**Do not enable both at once.** The official setup and the overlay both register
`serverName: rea`; two entries with the same server name make the later one fail to load
with a clear error. The overlay header documents “CHOOSE ONE MOUNT”; the user README must
repeat it in the REA MCP section.

### 5.5 Operational caveats for the REA MCP row

- **`npx` must be on the harness Host's `PATH`.** dsh's stdio MCP client launches
  `command` directly and scrubs credential-looking and `DSH_*` variables (PATH is
  inherited). The macOS desktop app resolves the login-shell environment on launch, so a
  user-installed Node/npx is visible; an environment where `npx` is not on the login-shell
  PATH will fail the connection and simply show no `mcp__rea__*` tools.
- **Cold start cost**: with an empty npm cache the first connection pays the npx download
  (~13 s here); a warm cache connects in well under a second. The default MCP SDK
  connection/discovery timeout (60 s) is comfortable. `failOnStartupError` remains false,
  so a broken REA row degrades to “no REA tools” instead of aborting the harness.
- **229 tools** enter the model tool list when the row is active; enable it for
  reverse-engineering sessions rather than globally where context budget matters.
- **Node engine gate applies to `rea setup`, not to the server**: `rea setup` refuses to
  plan on Node `< 24.22.1` (and other unsupported versions) with a `needs_human` result;
  the MCP server itself starts fine on this machine's Node.
- `rea setup` also reports the REA *skill* copy at `~/.agents/skills/reverse-engineer-anything`
  as missing in its identity diagnostics even with `--skill=false`; that line is
  informational when skills are managed by this pack.

---

## 6. Skill roots and watcher behaviour (drop-in install)

Documented roots and ranks for the local skill provider (verified in the installed
`@deepseek-ai/dsh-skill-filesystem` package and the skills subsystem docs):

| Rank | Source | Root |
|---|---|---|
| 100 | `project-dsh` | `<projectRoot>/.dsh/skills` |
| 200 | `project-agents` | `<projectRoot>/.agents/skills` |
| 300 | `custom` | `customSkillDirs` config |
| 400 | `user-dsh` | `<DSH_HOME>/skills` (the `.system` child is skipped) |
| 500 | `user-agents` | `<agentsHome>/skills` |
| 600 | `bundled` | configured bundled root |

Copying skill directories into `~/.dsh/skills` (or a project root's `.dsh/skills`) is
picked up by a running session **without an app restart**: the local provider watches
existing roots with chokidar (depth 1, `ignoreInitial`, atomic writes, `awaitWriteFinish`,
polling configurable), follows a missing root from its nearest existing ancestor until the
watcher can attach, and invalidates the skill catalog on direct bundle/flat-entry
additions/removals and direct skill-entry changes. Consumers refetch the catalog and
publish a replacement catalog on the next model step; full skill bodies are re-read on
each `skill` tool call, so body edits are visible immediately while a description change or
a new skill directory appears at the next step. A fresh session is the cleanest way to
confirm the catalog.

Caveat specific to this pack's bundle-provided skills: the `rev-eng-skills` provider
rescans `skills/` on each `list()` but does not install a file watcher and emits no
invalidation, and the skill registry caches catalog snapshots. Editing an installed
skill's body is visible on the next `skill` call; adding a new skill directory to an
already-installed package mid-session needs the registry catalog to be invalidated (a
session restart is the reliable way). The drop-in copy path uses the watched local provider
and does not have this caveat.

---

## 7. Bugs / risks found

1. **Official REA setup is blocked by the Node version this app ships.** `rea setup
   --client dsh` returns `needs_human` with empty plan on Node 24.18.0 (and the desktop
   app's own runtime Node is 24.21.0, also below REA's `^24.22.1`). The MCP server itself
   runs fine. Docs for the official path must mention this and either require Node ≥
   24.22.1 or point at the overlay. Severity: medium (user-facing friction, not a
   packaging bug).
2. **Duplicate `serverName: rea` rows** if a user runs `rea setup --client dsh` *and*
   enables `patches/rea-mcp.yml`. The later row fails to load (clear dsh error), and the
   result is confusing tools-missing behaviour. The overlay documents “choose one”; the
   top-level README must say it too. Severity: medium, prevented by docs.
3. **`--patch cordis.patch.yml` is not a working trial of the skill pack** (module not
   found: the plugin must be installed into the profile). The optional overlay
   (`patches/rea-mcp.yml`) *is* valid one-shot because it mounts an installation-owned
   package. Do not advertise a “no-install one-shot trial” for the bundle. Severity:
   medium for docs accuracy; captured in `verify.sh` via the install-based proof.
4. **Desktop CLI foot-gun**: from the desktop app's own `dsh` binary,
   `dsh plugin --profile desktop …` is not blocked by the Electron-managed guard and would
   write the live desktop profile (the source asks the operator to quit Desktop first).
   The Plugins page is the supported path; README should not present the CLI command for
   the desktop profile. Severity: low (documentation/operations; not tested destructively).
5. **`dsh web --help` short-circuits mounting.** An invalid plugin configuration plus
   `--help` still exits 0 (verified with a deliberately invalid mcp-client row), so a
   `--help` smoke test proves nothing about plugin activation. The gate therefore boots a
   real server and asserts absence of activation warnings instead. Severity: low
   (verification-methodology trap, not a product bug).
6. **Fresh custom profiles are app-less.** `dsh plugin --profile <new-name> add …`
   initializes only `@deepseek-ai/dsh-base`; booting such a profile does not start an app.
   Install into a shipped app profile (`web`/`tui`/`headless`) or the desktop app.
   Severity: low (documentation nuance).
7. **Packaged-skill catalog is not watched** (see §6). Adding skills to an installed
   package requires catalog invalidation/restart; body edits are fine. Severity: low,
   documented behaviour trade-off, not a blocker for this release.

No failure was found in the bundled plugin's own contract: all 23 skills load through
`createProvider`, lint is clean, and the installed bundle applies at boot without warnings.

---

## 8. Verification limits (what was not tested)

- The desktop Plugins page was not clicked and nothing was installed into the user's real
  profiles. GUI capability is reported from the installed client's and plugin-manager's
  own documentation plus the existing registry-installed bundles in the user's desktop
  profile, and the equivalent package operation was tested through dsh in an isolated
  profile.
- No LLM session was opened, so the model-facing catalog at runtime was not asserted; the
  provider contract is covered by the unit tests and the live boot covers import/apply.
- The official REA setup was run with `--dry-run` only (as instructed, no `--yes`); the
  exact YAML was produced by calling REA's own serializer with the planned command, then
  verified through dsh and by `rea doctor` in the isolated home. No real `~/.dsh` file was
  touched.
- MCP child-process detection uses `pgrep`; on a system without it, the gate skips that
  single check with a note.
- `--full` needs network for the first REA npm download; the offline gate does not.

---

## 9. Exact command reference

Works (all in an isolated `DSH_HOME` unless noted):

```sh
# offline acceptance gate
./verification/verify.sh

# full gate incl. live boot + REA MCP connection (network on first run)
./verification/verify.sh --full

# one-shot REA MCP overlay on an existing profile (installation-owned package)
dsh --profile web --patch "$PWD/patches/rea-mcp.yml"

# bundle install into an existing non-desktop profile, then boot
dsh plugin --profile web add "$PWD"
dsh --profile web

# inspect composition without mounting
dsh --profile web --dump-config

# MCP server probe
npm_config_cache="$PWD/.npm-cache" npx -y rea-agents@6.8.0 mcp

# official REA plan (needs Node >= 24.22.1; workaround shown in §5.3)
npm_config_cache="$PWD/.npm-cache" npx -y rea-agents@6.8.0 setup --client dsh --skill=false --dry-run --json
npx -y rea-agents@6.8.0 doctor --client dsh --json
```

Fails by design (recorded here so nobody re-tries them blindly):

```text
dsh --profile desktop --dump-config
  -> error: profile "desktop" is managed exclusively by the Electron application  (exit 1)

dsh --profile web --patch "$PWD/cordis.patch.yml" --port 0 --no-open
  -> boots, but "1 entry did not activate": Cannot find package 'dsh-rev-eng'
     (the bundle must be installed into the profile first)

npm_config_cache=… npx -y rea-agents@6.8.0 setup --client dsh --skill=false --dry-run --json
  -> exit 1, status needs_human, empty plan on Node 24.18.0 (Node engine gate)

dsh --profile <new-name>            # a profile created only by `dsh plugin add`
  -> no app bundle to launch (dsh-base only)
```

---

## 10. Cleanup / reproducibility

`verify.sh` creates `<repo>/.dsh-test/verify-home`, sets `DSH_HOME` plus XDG/npm/pnpm cache
variables into it, and removes it on exit (`--keep` retains it for debugging). The only
working artifacts from this investigation were `.dsh-test/` and `.npm-cache/`, both
gitignored; they were removed after the report. No verification command wrote to `~/.dsh`
or installed anything into the `desktop` profile: every install, dump, overlay and boot
ran with `DSH_HOME` pointed inside the workspace. The desktop app kept serving throughout
(checked on `http://127.0.0.1:49199`), and no desktop-profile package operation was
executed from this session. (The user's own plugin updates to that profile are unrelated
to this verification and were not performed by it.)

---

## Addendum (2026-10-28, after publication)

The package was pushed to **https://github.com/Stijnus/dsh-rev-eng** (public,
branch `main`, topics `dsh-plugin`, `deepseek-harness`, `agent-skills`,
`reverse-engineering`, `macos`, `swiftui`). Two paths that were previously
untested are now verified:

Git spec install, isolated `DSH_HOME`:

```sh
DSH_HOME="$PWD/.git-check/home" dsh plugin --profile git-check add github:Stijnus/dsh-rev-eng
# dependencies:
# + dsh-rev-eng 0.1.0
# Done in 2.1s using pnpm v11.28.5
DSH_HOME="$PWD/.git-check/home" dsh --profile git-check --dump-config
# exit 0; "# == dsh-rev-eng" → "- id: rev-eng-skills / name: dsh-rev-eng"
```

The Plugins page `Add plugin` dialog accepts `github:Stijnus/dsh-rev-eng`
(and `https://github.com/Stijnus/dsh-rev-eng`) as a Git address, which runs the
same inspect → pnpm → enable operation shown above.

npm publishing completed after this addendum was first drafted:

- `dsh-rev-eng@0.1.0` is published: https://www.npmjs.com/package/dsh-rev-eng —
  `dist-tags.latest = 0.1.0`, tarball shasum `1e449fa2228825b65fff16e1a0a05e83cdd72582`
  (matches the locally packed tarball exactly).
- The registry accepted the publish asynchronously (`PUT 202`, "may take a few
  minutes"). During processing the name appeared only as `0.0.0-stage`
  ("Temporary package placeholder for staged publishing"); the real version
  landed about three minutes later and `latest` moved to `0.1.0`. The
  placeholder remains listed in `versions` but is not what `npm install
  dsh-rev-eng` resolves, because `latest` points at `0.1.0`.
- npm install path verified in an isolated `DSH_HOME`:
  `dsh plugin --profile npm-check add dsh-rev-eng` resolved `dsh-rev-eng 0.1.0`
  from the public registry in 1.1s, wrote `dsh-rev-eng: ^0.1.0` into the profile,
  and `--dump-config` composed `# == dsh-rev-eng → rev-eng-skills`.
- Publishing required a browser 2FA approval for the `stijnus` account. The
  non-TTY path (`EOTP` with redacted auth URLs) does not work; running
  `npm publish` under a PTY (`script -q /dev/null …`) prints a real
  `https://www.npmjs.com/auth/cli/<id>` URL and polls until approval.
