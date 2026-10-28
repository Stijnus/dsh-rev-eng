# REA adaptations

Port of the REA skill pack into the `dsh-rev-eng` DeepSeek Harness plugin bundle.

## Source

- Repository: https://github.com/morluto/rea
- Commit: `3b242491a430b3807853436bfeb9568d606169ac`
- Package and version: `rea-agents@6.8.0` (npm), upstream skill metadata recorded
  version 49 with 229 tools; the metadata block is not shipped.
- Staged upstream copy: `vendor/rea/` (`DISCLAIMER.md`, `LICENSE`,
  `package.json`, `skills/reverse-engineer-anything/`). `vendor/rea/README.md`
  was not present in the stage; CLI and MCP facts came from the shipped skill
  files, the staged `package.json`, and the dsh MCP client documentation.

## Destination map

| Destination | Upstream | Files dropped | Adaptation |
| --- | --- | --- | --- |
| `skills/reverse-engineer-anything/SKILL.md` | `vendor/rea/skills/reverse-engineer-anything/SKILL.md` | `metadata:` block (`version`, `tool_count`); its version information is carried by the body's pinned `rea-agents@6.8.0` | Rewrote the connection section for dsh, added the dsh mount and CLI paths, rewrote the repair ladder, added one guide link. |
| `skills/reverse-engineer-anything/references/environments.md` | same file upstream | none | Client wording made harness-neutral; one dsh note on oversized captures. |
| `skills/reverse-engineer-anything/references/javascript-applications.md` | same file upstream | none | `client's tool deadline` now names the dsh row's `toolCallTimeoutMs`; two dsh notes. |
| `skills/reverse-engineer-anything/references/runtime-observation.md` | same file upstream | none | One dsh note on tool naming and approval. |
| `skills/reverse-engineer-anything/references/native-and-artifacts.md` | same file upstream | none | One dsh note on tool naming; the Ghidra client-deadline paragraph now names `toolCallTimeoutMs`. |
| `skills/reverse-engineer-anything/references/evidence-workflows.md` | same file upstream | none | One dsh note on tool naming and clipped tool text. |
| `skills/reverse-engineer-anything/references/connection-and-recovery.md` | same file upstream | none; content rewritten in place | Deep rewrite for dsh: table, deadlines, ladder, registration repair, approval section, CLI section. |
| `skills/reverse-engineer-anything/references/android-applications.md` | same file upstream | none | `REA setup` install sentence made REA-neutral; tool timeout now names `toolCallTimeoutMs`; one dsh note. |
| `skills/reverse-engineer-anything/references/dsh-harness.md` | new file, no upstream counterpart | not applicable | Documents official setup, the pack overlay, tool naming, timeouts, reload/reconnect, home-patch scope, approval policy, logs, uninstall. |
| `patches/rea-mcp.yml` | new file | not applicable | Optional dsh MCP client overlay row with id `rea-mcp`, serverName `rea`, `npx` launcher and `toolCallTimeoutMs: 600000`; comments cover the official-setup alternative, the mutual-exclusion rule, home-patch scope and the permanent merge. |
| `docs/rea-disclaimer.md` | `vendor/rea/DISCLAIMER.md` | none; text is byte-identical after the one-line header | One header line: source URL and "reproduced verbatim". |

No upstream skill directory was renamed, and no executable scripts existed to
carry over.

## Frontmatter

- Dropped the nested `metadata:` block; dsh frontmatter is flat.
- Replaced the upstream description with one physical line under 500 characters
  that keeps the upstream trigger sentence and adds the required `Use when ...`
  clause. The final clause "Skip REA for ordinary source-repository architecture
  analysis" is preserved.

Before:

```yaml
description: Reverse engineer native, managed, Electron/JavaScript, packaged, firmware, and browser targets with REA, and build agent environments (AgentEnv bundles) of web applications from a live instance or a capture. Use shipped-artifact or requested runtime evidence to explain features, compare versions, decompile code, or guide a reconstruction. Skip REA for ordinary source-repository architecture analysis.
metadata:
  version: "49"
  tool_count: 229
```

After:

```yaml
description: Reverse engineer native, managed, Electron/JavaScript, packaged, firmware, and browser targets with REA, and build agent environments (AgentEnv bundles) of web applications from a live instance or a capture. Use when a claim needs shipped-artifact or requested runtime evidence to explain features, compare versions, decompile code, or guide a reconstruction. Skip REA for ordinary source-repository architecture analysis.
```

## Client-specific rewrites

Research finding: dsh is a supported REA 6.8.0 client. The upstream staged skill
lists `dsh` among setup client IDs and `rea-agents@6.8.0` ships
`setup --client dsh`, `doctor --client dsh`, and a dsh MCP row writer. The
adaptation therefore makes official `rea setup --client dsh` the primary path,
the package's `patches/rea-mcp.yml` the pack-provided alternative, and the CLI
through `bash` the fallback. The earlier PORTING-CONTRACT line calling dsh
unsupported is superseded; the Lead confirmed this after verifying the shipped
REA artifacts.

Verifier-confirmed details folded into the shipped text:

- The generated official row is a root-level insert with id `rea-mcp`, name
  `@deepseek-ai/dsh-mcp-client`, config `serverName: rea`, `transport: stdio`,
  and `command`/`args` (an absolute node plus `rea.mjs`, or an `npx` form,
  depending on what REA resolved). It carries **no `toolCallTimeoutMs` and no
  `env` by default**; both are documented as caller-owned additions that setup
  preserves when it rewrites its own row.
- `rea setup` hard-gates Node: it accepts `^22.23.4`, `^24.22.1`, or
  `>=26.12.1`, and refuses 24.18.0/24.21.0. The MCP server itself runs on the
  refused versions. The guide documents three ways past the gate: an accepted
  Node for setup, the same REA entry point under a pinned accepted runtime,
  or the pack overlay (no setup at all).
- Two rows with serverName `rea` collide even across different patch layers
  (home patch, profile patch, one-shot `--patch`); the result is a
  duplicate-server-name load failure, so official setup and the overlay are
  explicitly either/or in `SKILL.md`, the overlay comments and the guide.
- Skill ranking: the canonical REA-installed skill lands in `~/.agents/skills`
  (or `$DSH_AGENTS_HOME/skills`) at rank 500, below this pack's provider at
  rank 400, so `--skill=false` avoids a redundant shadowed copy.

Pattern changes, before to after:

| Before | After |
| --- | --- |
| `npx -y rea-agents@6.8.0 doctor --client codex --json` and the list of 15 client IDs to substitute | `npx -y rea-agents@6.8.0 doctor --client dsh --json`, with `--skill` for the skill copy; no other client IDs |
| `npx -y rea-agents@6.8.0 setup --client codex --dry-run --json` / `setup --client codex --yes` | `npx -y rea-agents@6.8.0 setup --client dsh --skill=false --dry-run --json` / `setup --client dsh --skill=false --yes`, with the home-patch scope, preserved caller-owned fields and `--skill=false` rationale documented |
| "Restart/reconnect the affected agent" | "Restart the harness (the dsh session or app)" |
| "The agent client can independently require approval" | "The dsh session still applies its own permission preset, with a sandbox mode and an approval policy (`ask` asks, `never` rejects)" |
| "The client's tool-call deadline" / Codex `mcp_servers.<server-id>.tool_timeout_sec` in seconds | dsh row's `toolCallTimeoutMs`, in milliseconds, default 60000, both connection paths using 600000 |
| Codex per-tool approval TOML (`[mcp_servers.rea.tools.open_binary]`) | Removed. dsh has no per-tool preapproval list here; the session permission preset decides, and an unattended run reports the blocked operation |
| Codex executor diagnostic (helper aliases refused with `CODEX_HOME` under `/tmp`) | Removed. Replaced by the dsh launch-failure diagnosis: the row starts without tools and logs `mcp-client(rea)` |
| "When parallel workers are available" | "When the session supports parallel subagents (the `subagent` tool)" |
| `references/...` list without the new guide | `references/dsh-harness.md` added to "Read only the relevant guide" and linked from the connection section |
| no dsh installation section | `patches/rea-mcp.yml` overlay plus `references/dsh-harness.md` for official setup, overlay, CLI, reload, logs, approval, uninstall |

Removed content and why:

- The client-ID lists in `SKILL.md` and `connection-and-recovery.md` (other
  agents' identifiers) were replaced with `dsh`; they only exist to choose a
  setup target and every one of them is a different client's configuration.
- The Codex executor warning about `CODEX_HOME` under `/tmp` was removed: it
  describes a Codex sandbox that does not exist in dsh. The dsh equivalent
  (row cannot launch its stdio child, session starts without tools, failure
  logged) is documented instead.
- The Codex per-tool approval example was removed and replaced with the dsh
  permission-preset and approval-policy explanation. No dsh per-tool preapproval
  list is documented here because the pack does not own one.
- The `rea setup --install-hopper` walkthrough is reduced to "install an engine
  only when separately needed and explicitly approved": engine installation is
  not part of a dsh mount repair.

Everything else keeps upstream technical substance: routing by target, evidence
and summary-first rules, budget and cleanup rules, the retry-once rule, the
client-versus-provider deadline distinction, and every reference guide.

## dsh mechanics documented

- Official setup writes row id `rea-mcp` (serverName `rea`) into
  `$DSH_HOME/cordis.patch.yml`; the home patch applies to every profile,
  including the desktop app. Setup preserves unrelated patches and comments and
  replaces only its own launcher fields. The generated row omits
  `toolCallTimeoutMs` and `env`; caller-owned fields such as a hand-added
  `toolCallTimeoutMs` survive a later setup run.
- `rea setup --skill=false` when this pack is installed: the pack's provider
  exposes the adapted skill at rank 400, above the canonical rank-500 copy, so
  the canonical answer would be a redundant shadowed install.
- `rea doctor --client dsh --json` and `rea doctor --client dsh --skill --json`
  are the registration diagnostics; `rea uninstall` removes the row and any
  REA-installed skill. A healthy/aligned doctor result appears once the row
  exists.
- Node gate: setup refuses 24.18.0/24.21.0 and similar; the MCP server and the
  pack overlay do not.
- Tool names are `mcp__rea__<rawName>`; guides use raw REA names.
- `toolCallTimeoutMs` default 60000, both connection paths 600000; rationale is
  REA's per-source 300000 ms analysis budget and the 330000 ms cold Ghidra
  import default.
- Duplicate `serverName: rea` is refused across layers, so the official
  registration and `patches/rea-mcp.yml` are mutually exclusive.
- The MCP bridge adds no per-call approval; the session permission preset
  (sandbox mode plus `ask`/`never` approval policy) governs harness tooling such
  as the `bash` fallback.
- Failed initial connection does not abort the harness (`failOnStartupError`
  defaults to false); the session starts without tools and logs
  `mcp-client(rea)` lines. Reconnect backs off 500 ms to 30 s over up to ten
  attempts, then unregisters the tools until a reload or restart.

## Verification

- `node scripts/lint-skills.mjs`: `lint-skills: 23 skill(s), 101 relative link(s), 0 errors`.
- The overlay composes through the installed dsh CLI in a throwaway `DSH_HOME`:
  `DSH_HOME=/tmp/dsh-rea-porter-test dsh --profile web --patch <abs>/patches/rea-mcp.yml --dump-config`
  exits 0, prints exactly one `rea-mcp` row, and keeps serverName `rea`,
  transport `stdio`, `command: npx`, the `-y rea-agents@6.8.0 mcp` args and
  `toolCallTimeoutMs: 600000`. The YAML also parses with PyYAML as a
  one-operation patch list. No mount was performed, so this validates
  composition only; the Lead's verifier owns the live mount check.
- The disclaimer was checked with `diff`: the text after the header line is
  byte-identical to `vendor/rea/DISCLAIMER.md`.

## Removed or shortened, with reason

- Upstream description wording "Use shipped-artifact or requested runtime
  evidence ..." was merged into the required `Use when ...` sentence; no trigger
  was dropped.
- The `metadata:` version is gone from the frontmatter, as the contract
  requires; the body still pins `rea-agents@6.8.0` in the connection and
  fallback commands.
- Guide reachability: every relative link was checked after editing; the seven
  upstream guides keep their filenames and cross-links so other guides and
  external references still resolve.

## Open items

- `BLOCKER:` none.
- The exact desktop-app host-log destination for dsh 0.2.1-rc.3 was not
  verified from inside this workspace (the running harness was reachable but
  writes outside the workspace are sandboxed). `dsh-harness.md` therefore names
  the `mcp-client(rea)` logger label, the terminal console as the live view, and
  the host log as the desktop destination. The Lead can confirm the path with a
  running dsh.
- The overlay uses `toolCallTimeoutMs: 600000` rather than the example 300000 in
  the task description: 300000 equals REA's default per-source analysis budget
  and is below the 330000 ms Ghidra cold-start default, so it would still time
  out on a native cold import. Setup preserves the field, so the same value can
  be added to a setup-written row.
