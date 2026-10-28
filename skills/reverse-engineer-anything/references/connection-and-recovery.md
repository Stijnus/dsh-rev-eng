# Connection and task recovery

Read this guide only for an observed connection, command, approval or provider
blocker. Keep the user's target and question in view. Explain what prevented the
operation and the next useful step; after repair, continue the investigation.

Commands below use an installed `rea`. If none is available, use the package
invocation in `SKILL.md` when acquiring REA is authorized. Follow the connected
server's schemas and the installed CLI's help rather than assuming repository
main and an older release expose the same arguments. In dsh, mounted tools are
named `mcp__rea__<tool>`; find the canonical REA operation in the session's
actual tool listing before concluding that it is absent. A shared prefix alone
does not establish which server a permission rule covers. The mount, tool naming
and CLI fallback are detailed in [the dsh harness guide](dsh-harness.md).

## Choose the remedy from the observed failure

| Observation                                                     | Meaning and next step                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| No `mcp__rea__*` tools in the active session                    | Inspect registration with `rea doctor --client dsh --json`. The row is missing, failed to start, or was added after this session began; a skill installation alone does not register MCP.                                                                                                                                                                                                                                                                                                                                                                                              |
| Row registered, but no connected tools                          | Restart the harness (the dsh session or app), then read the `mcp-client(rea)` log line. Doctor checks registration; it cannot establish the current session's connection.                                                                                                                                                                                                                                                                                                                                                                                                              |
| Missing, malformed or stale registration                        | Prepare a scoped setup plan with `rea setup --client dsh`; apply only authorized changes. Setup writes the row into the home patch and preserves unrelated patches and caller-owned config fields.                                                                                                                                                                                                                                                                                                                                                                                      |
| MCP connection dropped or REA could not start                   | If the connection drops, retry that call once only when it is safe to repeat or known not to have started. If it may already have changed the target, or the same failure returns, tell the user REA's connection failed and ask them to restart the dsh session or app. If REA could not start its connection, retry once, then tell the user and ask them to restart the dsh session or app. Do not retry a startup failure that returns the same unchanged result. Run `rea doctor --client dsh` when REA could not start or tools stay missing after restart. Doctor cannot restore a live connection by itself. |
| An approval request was denied                                  | The dsh approval policy rejected the call before REA executed it. Do not install an engine or re-register to solve this host-policy decision. See the approval section below.                                                                                                                                                                                                                                                                                                                                                                                                          |
| REA returns `provider_unavailable` or an unavailable tool entry | Read that operation's provider diagnostics or `binary_session.result.tool_availability`. Expand each group's tool names and inherit the shared client requirements unless overridden. Use the operation's availability, reason, and remediation; a complete tool catalog does not imply every operation is available.                                                                                                                                                                                                                                                                   |
| `rea` is missing in a child shell, or Node is incompatible      | Inspect the actual shell PATH and launcher/runtime. A prefix installation may be absent from a login shell's PATH; this does not establish a broken MCP registration.                                                                                                                                                                                                                                                                                                                                                                                                                  |

dsh is a REA-supported client: setup writes one `rea-mcp` row into
`$DSH_HOME/cordis.patch.yml`, the home patch that applies to every profile. Do
not also mount this pack's `patches/rea-mcp.yml` row. Two rows with serverName
`rea` collide even when they sit in different layers, and the result is a
duplicate-server-name load failure. If the harness cannot launch
the stdio child, because `npx` is missing, the shell PATH lacks a usable Node, or
the registration points at a moved REA installation, the session starts without
REA tools and the failure is logged. Repair the registration or the overlay; no
engine install fixes a launch failure. Preserve the session's sandbox and
permission preset instead of silently disabling it to make an analysis command
work.

Static JavaScript and ordinary ZIP inventory need neither Hopper nor Ghidra.
HAR inspection is offline and does not require a live browser. Native
decompilation, Android analysis and firmware extraction have their own
bring-your-own prerequisites. Use supported inventory/static evidence when it
answers part of the question, and name the unavailable evidence separately.
Do not substitute another target. Label observations from ordinary shell tools
as such; only actual REA output supplies REA Evidence.

## Distinguish client and server deadlines

A dsh tool call that ends with a timeout and no REA result means the MCP row's
`toolCallTimeoutMs` expired before a result arrived. It does not establish that
REA finished, canceled successfully, or released all resources. Do not repeat
the unchanged analysis. Inspect available session/provider state and retained
Evidence only when useful; an idle `binary_session` is not proof that every
target-free operation stopped. Never invent a missing Evidence reference.

Allow the dsh tool deadline to cover execution, cancellation/cleanup, and
response delivery. The setting is `toolCallTimeoutMs` on the
`@deepseek-ai/dsh-mcp-client` row, in **milliseconds**; the shipped overlay sets
600000. The row generated by `rea setup --client dsh` omits the field, so add it
under that row's `config`; setup replaces only its own launcher fields and keeps
the caller-owned timeout. It is not a startup timeout, and the MCP SDK keeps its
own 60-second negotiation and discovery default. Select a value for the actual
operation budget and headroom, not a universal timeout. Apply configuration
changes only within the authorized scope, preserving unrelated entries and
backups; restart the harness as required. When configuration is not editable,
report the setting needed or use an authorized CLI fallback. Do
not silently broaden permissions or switch targets.

A returned REA `provider_timeout` instead means the **server/provider** reached
its deadline. Follow its `remediation.action`, reuse accessible partial Evidence,
and resolve reported incomplete cleanup before retrying. Change a request
field or a `REA_*` setting only when the returned remediation explicitly
recommends that change. Restart REA when that text says the value is read at
startup. A mention that a control does not raise the deadline is not a
recommendation to change it. Do not invent a setting the remediation does not
name. Raising only the dsh deadline does not change this server budget. For
static JavaScript,
`analysis_timeout_ms` (CLI `rea analyze-javascript-application <path>
--analysis-timeout-ms <milliseconds>`) controls each source's
startup, analysis and transfer deadline in **milliseconds**. Increase that
budget or reduce semantic work / select exact inventoried `source_paths` when
the task permits. Omit `source_paths` for all sources; `[]` is invalid.
`detail: "summary"` reduces delivery, not analysis work. A per-source budget
does not bound the elapsed time for an entire multi-source application.
Partial-Evidence inspection can avoid recomputation; an unavailable reader is
not itself a reason to block a corrected static-analysis retry.
The shorthand `rea analyze <path>` does not expose this timeout flag; use the
explicit JavaScript command when changing that budget.

For invalid arguments, use the connected tool's current input schema, or the
installed CLI's command help. Refresh the catalog if stale; do not guess fields
from an older skill or return the entire catalog to repair one field. Correct
all reported fields before retrying.

## Recovery ladder

Follow the returned remediation. Change a request field or a `REA_*` setting
only when that text explicitly recommends the change. Restart REA when it says
the value is read at startup. A mention that a control does not raise a limit
is not a recommendation to change it. Do not invent a setting. Host memory and
`NODE_OPTIONS` do not raise a REA admission unless that remediation says so.

- MCP connection dropped: retry that call once only when it is safe to repeat
  or known not to have started. If it may already have changed the target, or
  it fails again, tell the user REA's connection failed and ask them to restart
  the dsh session or app. Do not run `rea doctor` for the drop itself.
- REA could not start its connection: retry once, then tell the user and ask
  them to restart the dsh session or app. Run `rea doctor` when REA could not
  start or tools stay missing after that restart. Do not retry a startup
  failure that returns the same unchanged result.
- `cleanup_incomplete`, or retained cleanup owners in the error details: retry
  that exact cleanup owner. Do not start new work that needs those resources
  until that owner confirms release. Repeating the original call is not that
  retry.
- Capacity, when the result is `resource_constraint` and `retryable` is true:
  wait for the active admission to finish, then retry within the reported
  limits. Do not restart REA to free the slot.
- `configuration_invalid`: correct the named setting in the environment that
  starts REA (the row's `config.env`, or the shell that launches the CLI), then
  restart REA. Run `rea doctor --client dsh` to see the
  `runtime-configuration:` check. Re-run `rea setup --client dsh` when the
  registration must carry the new setting, then restart the harness.
- `invalid_request`: correct the reported fields from the current schema. Do
  not repeat the unchanged call.

## Repair registration when needed

For dsh:

```bash
rea doctor --client dsh --json
rea setup --client dsh --skill=false --dry-run --json
```

Add `--skill` to `rea doctor --client dsh --json` when the question is the
installed skill copy rather than the MCP row. Setup writes its `rea-mcp` row
into `$DSH_HOME/cordis.patch.yml`, the home patch that applies to every profile,
the desktop app included. It preserves unrelated patches and comments and
replaces only its own launcher fields (`serverName`, `transport`, `command`,
`args`); the generated row has no `toolCallTimeoutMs` and no `env`, and
caller-owned config fields such as a hand-added `toolCallTimeoutMs` stay as they
are. Show the plan's exact file, replaced launcher fields, preserved unrelated
patches and any skill change. Obtain approval for writes when that concrete
scope is not already authorized, then apply the same scope with
`rea setup --client dsh --skill=false --yes`. Pass `--skill=false` when this
pack is installed: the pack's provider exposes the adapted skill at rank 400 and
would shadow the canonical rank-500 copy setup installs, so that copy is a
redundant shadowed install. If setup reports its Node version gate, see the Node
gate in [the dsh harness guide](dsh-harness.md#node-version-gate-on-setup); the
overlay path needs no setup.

Restart the harness, verify that `mcp__rea__*` tools actually appear, and resume
the original task. If they remain absent, inspect the logged `mcp-client(rea)`
launch failure rather than looping through setup. `rea uninstall` removes the
REA row and any REA-installed skill.

When the row came from this pack's `patches/rea-mcp.yml` instead of setup, do
not run setup on top of it. Remove that overlay row first, or repair the overlay
directly. Two rows with serverName `rea` are refused by dsh even when they sit
in different layers, and the load fails as a duplicate server name.

For an overlay-based mount, the equivalent inspection is:

```bash
dsh --profile <name> --patch /absolute/path/to/patches/rea-mcp.yml --dump-config
```

The composed profile tree prints without mounting, so a row that is absent is
visible before a session starts. Merge the `insert` row into an existing
profile layer (`$DSH_HOME/profiles/<name>/cordis.patch.yml`) or the home patch
instead of replacing a file that may hold unrelated user patches. Show the
exact row fields before writing. Install an analysis engine only when it is
separately needed and explicitly approved; it is not part of the mount repair.

## dsh approval and permissions are separate from REA readiness

REA tools have no permission-grant handshake. The dsh session still applies its
own permission preset, which bundles a sandbox mode with an approval policy:
`ask` prompts the user before a gated action and fails closed when no answerer is
available; `never` rejects every approval request deterministically. An
advertised tool or a successful `rea doctor` result does not override that host
policy. A workspace preset alone does not resolve a rejection, and `never` does
not mean every MCP tool is preapproved.

The mounted REA bridge declares no per-call approval of its own; most approval
interactions around REA come from the `bash` CLI fallback and its sandbox
escalation, or from harness-native actions. When interactive approval is
available, use the harness approval flow for the requested operation. In an
unattended run, continue through an authorized CLI workflow if the execution
environment permits it, or report the blocked operation and the approval needed
to proceed. Do not retry the same rejected call, silently broaden approvals or
sandbox access, or rewrite MCP effects as read-only.

There is no per-tool preapproval list for this row in the pack. A user who wants
a session to run without prompts chooses the permission preset they accept; show
any proposed preset change and preserve unrelated settings. This is an optional
recovery choice, not a prerequisite for every REA task.

## Repair an editable REA limit

If `details.limit` names an editable setting and its bounds, call
`update_analysis_settings` directly with a `changes` entry containing `setting`,
`action: "set"` and `value`. `inspect_analysis_settings` is optional when those
facts are already present. Retry the same input after work and cleanup settle.
Runtime defaults affect new work only; explicit per-call arguments take
precedence and must be corrected directly when selected. Reset restores launch
values. Updates survive target close/open but disappear on REA restart. They do
not edit host deadlines, response buffers, the dsh row's `toolCallTimeoutMs`,
registrations or fixed limits.

## Continue through an installed CLI

Check the command environment only if the launcher fails:

```bash
command -v rea
command -v node
node --version
rea --version
```

Use the public launcher at its known installation path with a supported existing
Node on PATH when the child shell loses a prefix installation. Avoid internal
`dist/cli.js` entrypoints or global toolchain changes. MCP may have its own valid
launcher even when a shell cannot resolve `rea`.

Run these through the dsh `bash` tool. Keep output files inside the workspace so
the sandbox can write them, and remember that the tool's own approval and sandbox
rules still apply. For a user-supplied JavaScript tree or ASAR, save complete
Evidence before reading a view:

```bash
rea analyze-javascript-application /absolute/path/to/app --json > app-evidence.json
jq -c '{source: {kind: "inline", evidence: .}, view: {kind: "summary"}}' app-evidence.json > app-view.json
rea inspect-analysis-view app-view.json
```

These commands do not register MCP or install an analysis engine. CLI JavaScript
JSON is complete and can be very large; redirect it rather than loading it into
context. Use an existing JSON processor if `jq` is absent, without installing
one just for this recipe. Inspect a module page or item using the same inline
source and the [JavaScript recipes](javascript-applications.md). Preserve graph
coverage, limitations and unknowns. Native CLI analysis still requires its
selected engine, and all CLI operations retain the host's execution permissions.
