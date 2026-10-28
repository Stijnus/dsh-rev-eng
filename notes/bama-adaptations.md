# BAMA adaptations

- Source: https://github.com/daveebbelaar/bama
- Commit: `15356bd8ebff408222ad21395aea09bd74b15310`
- Version: `1.0.0` (from `.claude-plugin/plugin.json`)
- License: MIT
- Staged source: `vendor/bama/` (gitignored)
- Ship: 21 skills, 82 skill files, plus 13 files under `skills/app-brief/specs/`

All 21 upstream skill directories were copied from `vendor/bama/skills/<stage>/<name>/`
to `skills/<name>/`. Every `agents/openai.yaml` was dropped (21 files, Codex display
metadata). `references/`, `scripts/`, `template/`, and `specs/` content is otherwise
byte-for-byte upstream except the files listed below.

## Per-skill log

| Destination | Upstream path | Changes |
| --- | --- | --- |
| `skills/bama/` | `skills/start/bama/` | Dropped `agents/`. Router description gets a "Use when" trigger and keeps `disable-model-invocation: true`. "Call the Skill tool" -> "call the `skill` tool with the name of the skill". "Let Claude Code, Codex, or scripts drive the app" -> "Let agents or scripts drive the app". "BAMA's `specs/` folder" -> "the example specs in `../app-brief/specs/`". |
| `skills/app-brief/` | `skills/start/app-brief/` | Dropped `agents/`; dropped `argument-hint`. "BAMA's `specs/` folder" -> "the example specs in `specs/`". Skill calls rewritten. |
| `skills/new-mac-app/` | `skills/start/new-mac-app/` | Dropped `agents/`; dropped `argument-hint` and `allowed-tools`. `template/CLAUDE.md` renamed `template/AGENTS.md`; its "bama plugin" line now says "dsh-rev-eng plugin". Template tree line `CLAUDE.md` -> `AGENTS.md`. "To let Claude Code, Codex, or scripts read and change the app's data" -> "To let agents or scripts read and change the app's data". `${CLAUDE_SKILL_DIR}/scripts/new-app.sh` -> `scripts/new-app.sh`. `Snapshot.swift` comment "(your terminal, or Claude)" -> "(your terminal, or the harness app)". |
| `skills/research/` | `skills/plan/research/` | Dropped `agents/`; dropped `argument-hint`. Four Skill tool calls rewritten. Placeholder `[V](url)` inside the merge template changed to `[V] <url>` so the link linter does not read it as a relative link. |
| `skills/clone/` | `skills/plan/clone/` | Dropped `agents/`; dropped `argument-hint`. `mcp__computer-use__*` row replaced with the harness-neutral computer-use wording. Claude Desktop / Claude Code `/mcp` enable steps replaced. "Claude in Chrome" -> "`playwright-cli` skill, or Playwright". `app_*` tool names -> "the computer-use tools". `window-shot.sh` comment "(or Claude)" -> "(or harness app)". Skill call to `user-stories` rewritten. |
| `skills/user-stories/` | `skills/plan/user-stories/` | Dropped `agents/`. Description "Use after app-brief or clone" -> "Use when app-brief or clone is done". Line-split Skill tool call rewritten. |
| `skills/swift-swiftui/` | `skills/code/swift-swiftui/` | Dropped `agents/`. Skill calls rewritten. Cross-skill links repointed for the flat layout: `../../design/mac-design/patterns.md` -> `../mac-design/patterns.md`, `../../ship/build-and-verify/existing-app.md` -> `../build-and-verify/existing-app.md`. |
| `skills/os-integrations/` | `skills/code/os-integrations/` | Dropped `agents/`. `SKILL.md` and `recipes.md` unchanged. |
| `skills/performance/` | `skills/code/performance/` | Dropped `agents/`. Unchanged. |
| `skills/improve-architecture/` | `skills/code/improve-architecture/` | Dropped `agents/`. `CLAUDE.md` -> `AGENTS.md` in the survey step. Description "Use at the end of a milestone" -> "Use when a milestone ends". |
| `skills/agent-cli/` | `skills/code/agent-cli/` | Dropped `agents/`. Largest rewrite, see below. Dropped `argument-hint`. |
| `skills/ux-design/` | `skills/design/ux-design/` | Dropped `agents/`; dropped `argument-hint`. Description "Use before coding a story" -> "Use when a story adds a screen, an action, or text". |
| `skills/mac-design/` | `skills/design/mac-design/` | Dropped `agents/`. Four Skill tool call sites rewritten. `${CLAUDE_SKILL_DIR}/scripts/hig.sh` -> `scripts/hig.sh`. |
| `skills/design-system/` | `skills/design/design-system/` | Dropped `agents/`. Skill calls rewritten. `CLAUDE.md` -> `AGENTS.md` in the "Point agents at it" step. |
| `skills/layout-grid/` | `skills/design/layout-grid/` | Dropped `agents/`. "Open them with the Read tool" -> "Open them with the `read` tool". |
| `skills/design-kit/` | `skills/design/design-kit/` | Dropped `agents/`. Skill call to `design-from-app` rewritten. |
| `skills/design-from-app/` | `skills/design/design-from-app/` | Dropped `agents/`; dropped `argument-hint`. Two `${CLAUDE_SKILL_DIR}/scripts/*.swift` invocations -> `scripts/*.swift`. Skill call to `design-kit` rewritten. "Open ... with the Read tool" -> "`read` tool". |
| `skills/app-icon/` | `skills/design/app-icon/` | Dropped `agents/`; dropped `allowed-tools`. `SKILL.md` and `more-cases.md` otherwise unchanged. |
| `skills/build-and-verify/` | `skills/ship/build-and-verify/` | Dropped `agents/`; dropped `allowed-tools`. Description "Use after any UI code change" -> "Use when a UI change lands". `CLAUDE.md` -> `AGENTS.md` in `existing-app.md`. "(Terminal, Ghostty, or Claude)" -> "(Terminal, Ghostty, or the harness app)". Read tool and Skill tool call rewritten. |
| `skills/test-mac-app/` | `skills/ship/test-mac-app/` | Dropped `agents/`. `CLAUDE.md` -> `AGENTS.md`. `app_menu` / `app_click` / `app_screenshot` tool names -> "the computer-use menu action", "click a row", "screenshot". Cross-skill link `../../code/os-integrations/recipes.md` -> `../os-integrations/recipes.md`. |
| `skills/improve-loop/` | `skills/ship/improve-loop/` | Dropped `agents/`; dropped `argument-hint`. Two Skill tool calls rewritten; Read tool -> `read` tool. |
| `skills/app-brief/specs/` | `specs/` | All 13 files copied. README: "with BAMA" / "Install BAMA" / "Build ... with BAMA" replaced with dsh-rev-eng wording, and the `app-brief` skill named as the entry point. Spec cross-links changed from `../skills/code/<name>/x` to `../../<name>/x`. README links stay file-relative (`window-snapper.md`). `creator-tools.md`: "Cursor halo" -> "Pointer halo", `CursorHighlight` -> `PointerHighlight`, settings page "Cursor" -> "Pointer". `dev-toolkit.md`: editor choice "Cursor (`com.todesktop...`)" -> "a VS Code fork (`com.todesktop...`)" (product name removed, bundle id kept). |

## Global substitutions

| Upstream | Shipped |
| --- | --- |
| `swift "${CLAUDE_SKILL_DIR}/scripts/measure.swift" ...` | `swift "scripts/measure.swift" ...` |
| `"${CLAUDE_SKILL_DIR}/scripts/new-app.sh" ...` | `"scripts/new-app.sh" ...` |
| `"${CLAUDE_SKILL_DIR}/scripts/hig.sh" <topic>` | `"scripts/hig.sh" <topic>` |
| `call the Skill tool with clone` | ``call the `skill` tool with name `x``` |
| `Open every PNG with the Read tool` | ``Open every PNG with the `read` tool`` |
| `Add one line to the app's CLAUDE.md` | ``Add one line to the app's `AGENTS.md`` |
| `Computer use (mcp__computer-use__*)` | ``Computer use, when the session has it: the `computer-use` skill or the `computer_use` tools`` |
| `Claude Code, Codex, scripts, people in Terminal` | `agents with a shell, scripts, people in Terminal` |
| `Use after any UI code change` | `Use when a UI change lands` |

The frontmatter is flat everywhere: `name`, single-line `description` under 500 chars
with a "Use when" trigger, plus `disable-model-invocation: true` on `bama` only.

## Removed or shortened

- `agents/openai.yaml` in all 21 skills (dropped per contract; Codex display metadata).
- `argument-hint` frontmatter keys: `app-brief`, `agent-cli`, `clone`, `design-from-app`,
  `improve-loop`, `research`, `ux-design`. dsh's skill provider has no invocation-argument
  schema, so the hints moved nowhere; each skill's body still describes its inputs.
- `allowed-tools` frontmatter keys: `app-icon`, `build-and-verify`, `new-mac-app`.
  dsh decides tool approval with its own permission policy, not a per-skill allow list.
- Extended router description for `bama`: added "Use when the user wants to build, design,
  or ship a Mac app, asks what to do next, or invokes /bama." Kept upstream text.
- Reworded four descriptions whose trigger used "Use after/at/before" into "Use when"
  clauses (the harness description contract requires that phrase). Triggers unchanged.
- `agent-cli` was the most client-specific skill and was rewritten harness-neutrally:
  - diagram `Claude Code --bash-->` / `Claude Desktop --MCP-->` -> `agent, bash -->` / `MCP client -->`
  - table "Claude Code, Codex, scripts" -> "agents with a shell, scripts"; "Claude Desktop and other clients with no shell" -> "MCP clients with no shell"
  - step 6: `.claude/skills/<cli>/SKILL.md` and `~/.claude/skills/` -> "the target agent's
    skill or instruction file", with dsh's `~/.agents/skills/<cli>/SKILL.md` as the default;
    check line "fresh `claude -p`" -> "fresh dsh session"
  - step 7: removed `claude mcp add` / `codex mcp add` / Claude Desktop config path; replaced
    with a generic stdio MCP row (`mcpServers`, command = app binary, args = `["mcp"]`) and
    dsh's harness-profile row plus reload note; check "`claude mcp list`" -> "the client
    lists the server as connected"
  - `rules.md`: "fresh `claude -p` session" -> "fresh agent session"; "The CLI is what
    Claude Code and Codex use best" -> "The CLI is what agents use best"
  - `teach-agents.md`: "Where to put it" table now lists the app repo, `~/.agents/skills/`,
    and "the harness's own global skill folder"; the Claude settings allow-list JSON became
    a harness-neutral permission paragraph that names dsh's session policy; the Claude
    Desktop `mcpServers` block and log path became a generic stdio registration plus dsh reload
  - `template/Agent/AgentMCP.swift`: header comment now gives the generic stdio
    command/args and says agents with a shell do not need it.
- `clone`'s computer-use setup section: the "Pro or Max plan" requirement and the
  client enable steps were client-specific; the rewritten paragraph names Accessibility
  and Screen Recording and the harness computer-use capability, and falls back to asking
  the user for screenshots.

## Link scheme

Links are file-relative (the shipped linter resolves them from the containing file).
Only the spec bundle needed changes, because `specs/` adds one directory level:
`../skills/code/<name>/x` -> `../../<name>/x`, and spec README links stay `window-snapper.md`.
`skills/app-brief/SKILL.md` points at the shipped examples as `specs/`; the router
`skills/bama/SKILL.md` points at them as `../app-brief/specs/`. Both resolve from the
skill base directory.

## Verification

```sh
node scripts/lint-skills.mjs
# lint-skills: 23 skill(s), 100 relative link(s), 0 errors
```

Inventory check: upstream `skills/**` minus `agents/**` equals the shipped tree, except
`new-mac-app/template/CLAUDE.md` -> `new-mac-app/template/AGENTS.md`. Executable bits are
preserved on all 14 upstream-executable files. Every shipped `SKILL.md` was read end to end
after the substitutions; line wraps and duplicated words were fixed.

## Open questions

BLOCKER: none.
