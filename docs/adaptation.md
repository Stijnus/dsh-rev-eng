# Adaptation guide

This package ships two upstream agent-skill collections adapted to run as
DeepSeek Harness (dsh) skills. The skill names, workflows, and technical content
are upstream; the changes below are harness mechanics only. This guide explains
what changed and why, so the adaptation can be reviewed, repeated, or extended
when upstream moves.

- Full before/after logs: [BAMA adaptations](../notes/bama-adaptations.md),
  [REA adaptations](../notes/rea-adaptations.md).
- Source pins, licensing, and the refresh procedure: [PROVENANCE.md](../PROVENANCE.md).
- User-facing behavior and install: [README.md](../README.md).

## Source pins

| Pack | Repository | Version | Commit |
| --- | --- | --- | --- |
| REA | https://github.com/morluto/rea | `rea-agents@6.8.0` | `3b242491a430b3807853436bfeb9568d606169ac` |
| BAMA | https://github.com/daveebbelaar/bama | `1.0.0` | `15356bd8ebff408222ad21395aea09bd74b15310` |

## Why an adaptation is needed

dsh reads the same `<name>/SKILL.md` plus YAML frontmatter shape as the upstream
clients, so the skill format itself carries over. Two other layers do not:

1. **Tool surface.** Skill bodies tell the model which tools to call. Those names
   are harness-specific. A named tool that does not exist in dsh makes the
   instruction silently skip or hallucinate.
2. **Client setup and registration.** Instructions for connecting MCP servers,
   installing skills, approving tools, and restarting a session are written
   per client. dsh has its own skill roots, patch layers, permission presets,
   and reload behavior.

Everything else (method, routing, evidence rules, templates, scripts) is
harness-neutral and was left alone.

## Harness mapping

Applied consistently to every shipped `SKILL.md`, reference, template, and
script comment:

| Upstream convention | Shipped for dsh | Why |
| --- | --- | --- |
| `Skill` tool, "call the Skill tool with `x`" | "call the `skill` tool with name `x`" | Model-side skill loading goes through dsh's `skill` tool. `/name` only fires on user input. |
| `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob` tools | `read`, `write`, `edit`, `bash`, `grep`, `glob` | dsh tool names are lowercase. |
| `TodoWrite` | `todo_write` | dsh tool name. |
| `WebSearch` / `WebFetch` | `web_search` / `web_fetch` | dsh tool names. |
| `AskUserQuestion` | `ask_user_question` | dsh tool name. |
| `Task` tool / client subagents | `subagent` tool; parallel subagents are supported | dsh exposes subagent work as the `subagent` tool. |
| `${CLAUDE_SKILL_DIR}/scripts/x` | relative path `scripts/x` | dsh prints the skill's absolute base directory on load and tells the model to resolve relative paths against it. Shipped files never contain `${...}` path variables. |
| `CLAUDE.md` file convention | `AGENTS.md` | dsh reads agent-instruction files as `AGENTS.md`. |
| `mcp__computer-use__*` tools, client `/mcp` enable steps | harness-neutral wording: use the computer-use capability when the session has it (`computer-use` skill or `computer_use` tools), otherwise ask the user for screenshots | dsh desktop sessions may expose computer use; the exact namespace is a session capability, not a fixed tool contract. |
| `argument-hint` frontmatter | dropped | dsh skills have no invocation-argument schema. The body still describes the skill's inputs. |
| `allowed-tools` frontmatter | dropped | dsh decides approval with its session permission preset, not a per-skill allow list. |
| `metadata:` frontmatter block | dropped | dsh frontmatter is flat; version/tool-count metadata now lives in the body text or in [PROVENANCE.md](../PROVENANCE.md). |
| `agents/openai.yaml` metadata directories | dropped | Display metadata for another client's plugin UI; unused in dsh. |
| `.claude-plugin/` | not shipped | Upstream packaging for other clients. |
| Relative cross-skill links | repointed for the flat `skills/<name>/` layout | BAMA upstream nests skills two levels deep; the links must resolve from the shipped location. |
| `/name` user invocation | unchanged | dsh supports `/name` for user-invocable skills. `bama` is user-invoked as `/bama`; the pack router as `/rev-eng`. |

## Frontmatter normalization

Every shipped `SKILL.md` is validated by [`scripts/lint-skills.mjs`](../scripts/lint-skills.mjs)
and by the plugin's own parser in [`src/frontmatter.js`](../src/frontmatter.js):

- Flat `key: value` YAML only. No nested mappings, no lists, no block scalars.
- `name` must be kebab-case and equal the directory name.
- `description` is one physical line of at most 500 characters, says what the
  skill is, and contains a "Use when ..." trigger sentence.
- Every scalar must be YAML-safe: no `: ` (colon-space), no ` #` (space-hash),
  and no leading YAML indicator character. dsh parses frontmatter with a real
  YAML parser while the pack's flat parser is line-oriented, so a colon-space
  would silently turn the value into a nested mapping and the whole skill would
  be ignored. The lint rejects these forms explicitly (this caught the router
  description during the build).
- `disable-model-invocation: true` only on the user-invoked `bama` router.
  `rev-eng` stays model-invocable because the model routes through it.
- The plugin serves the skills at rank 400 with source `bundled`; see
  [How it works](../README.md#how-it-works).

## REA: official dsh client support

REA 6.8.0 supports dsh as a first-class client, so the adaptation makes REA's
own setup the primary connection path rather than hand-writing a registration
for some other client:

- **Official registration is primary.** `rea setup --client dsh --skill=false
  --dry-run --json`, then `--yes`, writes the MCP row (id `rea-mcp`, serverName
  `rea`) into `$DSH_HOME/cordis.patch.yml`, the home patch for every profile.
  `rea doctor --client dsh` inspects it and `rea uninstall` removes it.
- **`--skill=false` is the pack default.** This package already ships the
  adapted REA workflow skill at provider rank 400. The canonical copy setup
  would install lands in `~/.agents/skills` at rank 500 and would be shadowed by
  a duplicate name, so installing it is redundant.
- **The pack overlay is the alternative.** `patches/rea-mcp.yml` carries the same
  id and serverName with an `npx` launcher and an explicit
  `toolCallTimeoutMs: 600000`. It needs no REA setup run, which matters because
  setup hard-gates the Node version (it accepts `^22.23.4`, `^24.22.1`, or
  `>=26.12.1`) while the MCP server itself runs on older Node.
- **The two paths are mutually exclusive.** Two MCP entries with
  `serverName: rea` conflict across patch layers, so the official registration
  and the overlay must never be enabled together.
- **Tool names and deadlines are dsh-shaped.** REA's raw tool names appear in the
  guides; dsh namespaces them as `mcp__rea__<rawName>`. dsh's per-row
  `toolCallTimeoutMs` (default 60000 ms) is too short for REA's default 300000 ms
  analysis budget and slow native provider starts, so both connection paths use
  600000 ms.

The upstream client-specific repair content was rewritten in place:
`references/connection-and-recovery.md` now diagnoses dsh rows, home-patch
scope, permission presets, restart semantics, and `mcp-client(rea)` logs, and a
new `references/dsh-harness.md` holds the full setup, overlay, CLI, timeout, and
troubleshooting detail. Client-ID lists and per-tool approval syntax for other
clients were removed because they have no dsh equivalent; the dsh replacement is
documented instead.

## BAMA adaptation

### Layout

Upstream ships `skills/<stage>/<name>/` with stages `start`, `plan`, `code`,
`design`, and `ship`. dsh discovers skill directories at a skill root, so every
skill was flattened to `skills/<name>/` and cross-skill links were re-pointed:
`../../design/mac-design/patterns.md` became `../mac-design/patterns.md`, for
example.

`vendor/bama/specs/` (12 example build plans plus a README) moved to
`skills/app-brief/specs/` because `app-brief` is the entry point that uses them.
The two references to "BAMA's `specs/` folder" now point at the shipped
examples: `specs/` from the `app-brief` skill and `../app-brief/specs/` from the
router. Spec-internal cross-links gained one directory level.

### Frontmatter and dropped metadata

- Dropped `agents/openai.yaml` from all 21 skills.
- Dropped `argument-hint` from 7 skills and `allowed-tools` from 3 (see the
  harness mapping table).
- Kept each skill's upstream `name` and description intent. Four descriptions
  whose trigger used "Use after/at/before" were reworded into "Use when"
  clauses; their triggers are unchanged.
- The router description gained a "Use when" trigger and names `/bama`.

### Client neutrality

- `new-mac-app`'s template `CLAUDE.md` became `template/AGENTS.md`, and the
  scaffold's tree listing matches.
- `clone` and `test-mac-app` describe the harness computer-use capability and
  the screenshot fallback instead of a fixed tool namespace.
- `agent-cli` was the most client-specific skill. Its diagrams, tables, install
  steps, and template comments now talk about "agents with a shell", "MCP
  clients", and a generic stdio registration, with dsh named as the default
  agent environment. The app-building technical content is unchanged.

### Per-skill map

| Skill | Upstream | Main change |
| --- | --- | --- |
| `bama` | `start/bama` | Router wording, `specs/` link, `disable-model-invocation` kept. |
| `app-brief` | `start/app-brief` | Skill calls, `specs/` reference, description. |
| `new-mac-app` | `start/new-mac-app` | Template `AGENTS.md`, relative script paths, harness wording. |
| `research` | `plan/research` | Four skill calls; placeholder link form fixed. |
| `clone` | `plan/clone` | Computer-use and browser steps made harness-neutral. |
| `user-stories` | `plan/user-stories` | Skill call, description. |
| `swift-swiftui` | `code/swift-swiftui` | Skill calls; cross-skill links repointed. |
| `os-integrations` | `code/os-integrations` | Dropped `agents/` only. |
| `performance` | `code/performance` | Dropped `agents/` only. |
| `improve-architecture` | `code/improve-architecture` | `AGENTS.md`, description. |
| `agent-cli` | `code/agent-cli` | Largest rewrite: generic CLI/MCP guidance, dsh permission notes. |
| `ux-design` | `design/ux-design` | Description, argument hint dropped. |
| `mac-design` | `design/mac-design` | Skill calls, relative script paths. |
| `design-system` | `design/design-system` | Skill calls, `AGENTS.md`. |
| `layout-grid` | `design/layout-grid` | Tool names. |
| `design-kit` | `design/design-kit` | Skill call. |
| `design-from-app` | `design/design-from-app` | Script paths, skill call, tool names. |
| `app-icon` | `design/app-icon` | Dropped `agents/` and `allowed-tools`. |
| `build-and-verify` | `ship/build-and-verify` | `AGENTS.md`, tool names, description. |
| `test-mac-app` | `ship/test-mac-app` | Computer-use wording, `AGENTS.md`, cross-skill link. |
| `improve-loop` | `ship/improve-loop` | Skill calls, tool names. |

## REA per-file map

| File | Change |
| --- | --- |
| `skills/reverse-engineer-anything/SKILL.md` | dsh connection section with the three paths, repair ladder, guide link; flat frontmatter. |
| `references/connection-and-recovery.md` | Rewritten in place for dsh: table, deadlines, repair ladder, registration repair, approval, CLI. |
| `references/dsh-harness.md` | New: exact row config, setup plan, `--skill=false`, Node gate, overlay merge, timeouts, logs, uninstall. |
| `references/environments.md` | Client wording neutralized; one note on oversized captures. |
| `references/javascript-applications.md` | Client deadline now names `toolCallTimeoutMs`; dsh notes. |
| `references/runtime-observation.md` | dsh note on tool naming and approval. |
| `references/native-and-artifacts.md` | dsh note on tool naming; timeout naming. |
| `references/evidence-workflows.md` | dsh note on tool naming and clipped tool text. |
| `references/android-applications.md` | Setup sentence made client-neutral; timeout naming. |

## Fidelity policy

- Change only what the harness requires. If a sentence is technically true in
  dsh, keep it.
- Never remove a trigger, a technical claim, a command semantic, a target type,
  or a "Done when" line to shorten the text. Description shortening is the only
  compression, and it keeps every trigger.
- Prefer a short harness-neutral rewrite over a client-specific sentence. Word
  the fallback in terms of what the agent can actually do ("ask the user for
  screenshots") instead of what a client UI used to provide.
- No path variables, no fixed external tool namespaces, no client names in
  shipped skills. The linter enforces the path, tool-name, and client-name
  rules.
- Keep upstream BAMA writing style: short sentences, positive phrasing, "Done
  when" lines, no em dashes.

## Verifying an adaptation

```sh
node scripts/lint-skills.mjs   # frontmatter, names, descriptions, links, forbidden strings
npm test                       # syntax checks + plugin unit tests
./verification/verify.sh       # isolated DSH_HOME install, layer composition, MCP overlay
```

`verify.sh --full` additionally boots an isolated `dsh web` server and checks
that the REA MCP child process connects. Never point the verification harness at
a real user profile.
