# REA in dsh

Read this guide only when the REA MCP tools are missing, the mount must be set
up or repaired, a call failed because of a timeout or approval, or the CLI
fallback is needed. The diagnostic ladder in
[connection and recovery](connection-and-recovery.md) applies to every failure
described here.

REA 6.8.0 (`rea-agents@6.8.0`) supports dsh as a client: its setup writes the
REA MCP row into dsh's own patch layer, and `rea doctor` and `rea uninstall`
understand that row. This pack ships the adapted skill instructions, an optional
overlay row for environments where the same setup flow should not be used, and
the CLI fallback. dsh does not download, install, license or repair REA, its
analysis engines, or their prerequisites.

## Three ways to connect

| Path | What it writes | Use it when |
| --- | --- | --- |
| Official registration, `rea setup --client dsh` | one root-level `insert` with id `rea-mcp` and serverName `rea` in `$DSH_HOME/cordis.patch.yml`, the home patch for every profile | default choice: REA owns the registration, `rea doctor --client dsh` and `rea uninstall` know it |
| Pack overlay, `patches/rea-mcp.yml` | one `insert` row with the same id and serverName, from `npx`, into a profile patch layer or the home patch | the home patch must stay untouched, or a profile-scoped experiment is wanted |
| CLI through `bash` | nothing | no MCP is needed, static JavaScript or offline inspection answers the question, or registration is blocked |

**Never enable the official registration and the pack overlay together.** Both
use serverName `rea`, and dsh refuses two MCP entries with the same serverName
even when they sit in different layers: a home-patch row plus a profile-patch or
`--patch` overlay row is still a duplicate-server-name load failure. Use one, not
both. The home patch applies to every profile, so a one-shot overlay on top of an
official registration is also a duplicate.

## Official registration

Review the read-only plan first, then apply it:

```sh
npx -y rea-agents@6.8.0 setup --client dsh --skill=false --dry-run --json
npx -y rea-agents@6.8.0 setup --client dsh --skill=false --yes
```

With a global install, the same commands start with `rea setup ...`.

`--skill=false` matters when this pack is installed: the pack's provider exposes
the adapted REA workflow skill at rank 400, above the canonical copy setup would
install under `~/.agents/skills` (or `$DSH_AGENTS_HOME/skills` when set) at rank
500, so that copy is a redundant shadowed install of the same skill name. If the
pack is not installed and the canonical skill is wanted, use
`rea setup --skill --dry-run` then `rea setup --skill --yes`; dsh discovers that
skill directory at rank 500. Setup resolves `DSH_HOME` and `DSH_AGENTS_HOME`
exactly as dsh does. `--client` can be repeated when more than one REA-supported
client must be configured.

The setup plan writes a root-level insert like this into
`$DSH_HOME/cordis.patch.yml` (default `~/.dsh/cordis.patch.yml`). REA's own
serializer chooses the launcher: an absolute node and `rea.mjs` path when it
resolved one, or an `npx` form when it did not. It writes `serverName`,
`transport`, `command` and `args`, and no other config by default:

```yaml
- insert:
    - id: rea-mcp
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: rea
        transport: stdio
        command: /absolute/path/to/node
        args: ['/absolute/path/to/rea/scripts/rea.mjs', 'mcp']
```

The generated row has **no `toolCallTimeoutMs` and no `env`**. dsh's default is
60000 ms, which is too short for real analyses; see [Timeouts](#timeouts). Setup
preserves unrelated patches and comments in that file and replaces only its own
launcher fields (`serverName`, `transport`, `command`, `args`). Caller-owned
config fields are preserved, so add the timeout under the row's `config` once and
later setup runs keep it:

```yaml
        toolCallTimeoutMs: 600000
```

Restart the harness after setup so the home patch is composed, then verify that
`mcp__rea__*` tools appear in a session. Check the registration with
`rea doctor --client dsh --json`; a healthy/aligned result appears once the row
exists, and `--skill` switches the check to the installed skill copy.
`rea uninstall` removes the REA row and any REA-installed skill; a row added by
hand or by this pack's overlay is not REA's to remove, so delete that row
yourself.

### Node version gate on setup

REA 6.8.0's `setup` command hard-gates the Node version. It accepts
`^22.23.4`, `^24.22.1`, or `>=26.12.1` and refuses releases such as 24.18.0 and
24.21.0. The MCP server itself runs fine on those refused versions, so only
setup is blocked, not the mounted row or the CLI analysis.

Options when setup reports the gate:

- Use an accepted Node for the setup run.
- Run the same REA entry point under a pinned accepted runtime, for example
  `npx -y node@24.22.1 /absolute/path/to/rea/scripts/rea.mjs setup --client dsh --skill=false --yes`,
  where the script path is the one `command -v rea` resolves to or the package's
  `scripts/rea.mjs`.
- Skip setup and use this pack's overlay, which needs no REA setup and no Node
  gate: a dsh MCP row starts `npx -y rea-agents@6.8.0 mcp` directly.

## Pack overlay alternative

`patches/rea-mcp.yml` in this package is one `insert` row with the same id and
serverName, an `npx` launcher instead of setup's absolute launcher, and the
generous timeout already set. The complete content minus comments:

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

One-shot, for a single run of a profile:

```sh
dsh --profile <name> --patch /absolute/path/to/patches/rea-mcp.yml
```

Permanent: merge the single `insert` row into an existing patch file instead of
replacing it. `$DSH_HOME/profiles/<name>/cordis.patch.yml` scopes it to one
profile; `$DSH_HOME/cordis.patch.yml` applies it to every profile, the desktop
app included, exactly like the row setup writes. The overlay does not write the
home patch by itself.

To confirm that a patch composed without mounting anything:

```sh
dsh --profile <name> --patch /absolute/path/to/patches/rea-mcp.yml --dump-config
```

A row missing from this dump never reached the harness; `--dump-config` without
`--patch` also shows a home-patch row. A row present here whose tools are absent
is a startup or discovery failure, not a composition failure.

Because the two launchers differ, keep a single REA install in play: setup
points at the concrete node and `rea.mjs` paths it resolved, while the overlay
resolves `npx -y rea-agents@6.8.0` again on every start. Do not switch between
them without removing the previous row.

## Tool names and what the model sees

`serverName: rea` is a local namespace, not the server's reported name. The
model calls the discovered tools as `mcp__rea__<rawName>`:

| REA operation in the guides | Tool name in dsh |
| --- | --- |
| `open_binary` | `mcp__rea__open_binary` |
| `analyze_javascript_application` | `mcp__rea__analyze_javascript_application` |
| `inspect_analysis_view` | `mcp__rea__inspect_analysis_view` |
| `binary_session` | `mcp__rea__binary_session` |
| `close_binary` | `mcp__rea__close_binary` |

Every skill guide uses the raw REA name; add the `mcp__rea__` prefix when
calling. Public names are stable while the server publishes the same raw names,
so a reconnect or reload keeps history and permission rules attached. A raw name
that needs normalization to fit the model's function-name contract gets a
deterministic hash suffix; check the session's tool list rather than guessing in
that case. A tool that a newer REA release adds appears after a re-sync; a skill
installed from repository main can describe tools an older npm release lacks.

The row also publishes the server's instructions as a labelled prompt section
and enables the shared MCP resource tools. Server instructions are literal text;
they do not extend or override this skill.

## Timeouts

dsh sets one timeout per row: `toolCallTimeoutMs`, in **milliseconds**, per
`tools/call` or resource request. Its default is 60000, which is too short for
most real analyses.

- Static JavaScript analysis: REA's own per-source budget defaults to 300000 ms,
  and a multi-source application can take longer than one source.
- Native analysis: a cold Ghidra import can take 330000 ms before the requested
  query even starts; REA exposes `ghidra.startup_timeout_ms` for new startup
  attempts.
- Both connection paths in this pack use 600000 (10 minutes). Raise it for very
  large targets, lower it for short interactive inspections. The field is
  caller-owned, so setup keeps it on a later `rea setup --client dsh` run, and
  the overlay carries it in its own row.

A dsh tool timeout means the client deadline expired: it does not prove REA
finished, cancelled, or released resources, and repeating the unchanged call is
not a repair. A returned REA `provider_timeout` is a different deadline and
follows its own remediation. Read
[client and server deadlines](connection-and-recovery.md#distinguish-client-and-server-deadlines)
before changing either. Raising `toolCallTimeoutMs` does not raise a REA
`analysis_timeout_ms` or provider budget, and lowering a REA budget does not make
a slow dsh call succeed.

## Startup, restart, and reconnect behavior

- **Initial connection.** If the server cannot start or discovery fails, the
  harness still starts: with the default `failOnStartupError: false` the row
  loads with no tools and the failure is logged. The session simply has no
  `mcp__rea__*` tools. `failOnStartupError: true` would reject plugin activation
  instead; both connection paths leave the default so an unavailable analysis
  server never blocks the whole session.
- **Restart after a configuration change.** The home patch and profile layers
  are composed when the harness boots. After setup, after adding the overlay, or
  after editing a row, restart the harness: quit and reopen the desktop app, or
  exit and relaunch the CLI profile. A session that started before the row
  loaded never gains the tools.
- **Discovery is asynchronous.** After a successful start, wait for the
  `mcp__rea__*` tools to appear before promising an analysis.
- **Dropped connection.** dsh reconnects automatically with delays that double
  from 500 ms to 30 s, then re-syncs the tool list. During an outage the last
  known tools stay listed but calls fail; after 10 consecutive failed attempts
  the tools are unregistered and reconnection stops until a reload or restart.
  A reconnect that recovers an unchanged list keeps the same tool names.
- **Edited row.** When the host reloads a changed configuration entry, the MCP
  client reloads that server connection in place and unchanged tool names stay
  unchanged. A file edit made outside a running host needs the restart above.

### Where dsh reports a failed MCP connection

The harness logger records the MCP client state with a `mcp-client(rea)` label:
initial connection and discovery failures, reconnect attempts with their attempt
count, tool re-sync failures, and the final `giving up ... tools unregistered`
line. With a terminal launch (`dsh web`, `dsh headless`, `dsh tui`) those lines
are in that process's console output. In the desktop app they are part of the
host log; the same row launched from a terminal is the fastest independent
check. `rea doctor --client dsh` can inspect the registration, the home patch
and the environment, but it cannot see or prove this session's connection.

## Approval, sandbox, and permissions

A REA row adds no approval prompt of its own: the bridge registers the discovered
tools as ordinary harness tools. The session still applies its permission
preset, which bundles a sandbox mode with an approval policy:

- `ask` (the default in the shipped `workspace-write` preset) prompts the user
  before a gated action and fails closed when no answerer is available.
- `never` (the shipped `danger-full-access` preset, and the strict unattended
  stance) rejects every approval request deterministically.

Most approval interactions around REA come from the `bash` fallback, where the
command runs under the sandbox and a sandbox escalation asks for approval, or
from harness-native actions. A REA tool result does not override that policy, and
a `rea doctor` success does not imply that the host will allow an action.

When an approval is denied: do not retry the same call, do not install an engine,
and do not rewrite a write-capable operation as read-only. Answer through the
harness prompt where possible, choose a preset that permits the intended work
when the user agrees, or continue through an authorized CLI workflow. In an
unattended run, report the blocked operation and the approval it needs.

REA target execution is real: runtime tools launch or attach to processes and
can change files, memory, and network state regardless of dsh's sandbox around
the *client*. Keep target scope and authorization explicit.

## CLI fallback through the bash tool

When the MCP row is not available, cannot be repaired in this session, or a
longer CLI timeout is wanted, run the CLI from the `bash` tool. No MCP
registration is involved, and static JavaScript, archive inventory, and the
offline inspectors need no native engine.

| Need | CLI through `bash` | Notes |
| --- | --- | --- |
| Static JavaScript tree or ASAR | `npx -y rea-agents@6.8.0 analyze-javascript-application <path> --json` | No engine; redirect JSON to a workspace file |
| Evidence view from a saved record | `rea inspect-analysis-view <view.json>` | Build the view JSON per the evidence guides |
| Exported evidence bundle | `rea inspect-evidence-bundle <bundle.json>` | Portable complete Evidence |
| Native analysis | `rea analyze <path> --provider ghidra --json` | Selected provider must be installed |
| AgentEnv from a HAR | `rea environment-build <capture.har> <dir>` | No browser needed |
| Environment server | `rea environment-serve <manifest.json> --evidence <capture.json>` | Serves replay or state |
| Registration and environment check | `rea doctor --client dsh --json` | dsh row, home patch, environment and providers |

Use `npx -y rea-agents@6.8.0` when no global `rea` is installed and package
acquisition is authorized; otherwise use `rea`. Keep output files inside the
workspace so the sandbox can write them, and prefer `--json > file` for large
results instead of loading them into context. The `bash` tool's own approval and
sandbox rules apply here, including any escalation prompt.

Configuration variables split by path:

- The **MCP row** inherits ambient variables except credential-named ones and
  `DSH_*` names; put any `REA_*` setting the server must have in the row's
  `config.env`. Setup preserves caller-owned config fields, but `env` entries
  added by hand are outside its replaced launcher fields; re-check the plan
  after a setup run.
- The **CLI fallback** takes `REA_*` variables from the `bash` tool's
  environment. A variable exported only inside a different shell does not reach
  either path.

Neither path installs Node.js, npm, Homebrew, Java, Ghidra, IDA, JADX, Kuna,
Binwalk, or Unblob. Install and license analysis engines separately, with the
user's approval, and never to repair MCP registration.
