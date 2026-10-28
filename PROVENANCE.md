# Provenance

`dsh-rev-eng` packages two independently maintained MIT-licensed agent-skill
collections for [DeepSeek Harness (dsh)](https://github.com/deepseek-harness).
This file records what came from where, what changed, and how to refresh the
package when an upstream moves.

## Upstreams

| Pack | Upstream repository | Version | Pinned commit |
| --- | --- | --- | --- |
| REA | [morluto/rea](https://github.com/morluto/rea) | `rea-agents@6.8.0` (npm) | `3b242491a430b3807853436bfeb9568d606169ac` |
| BAMA | [daveebbelaar/bama](https://github.com/daveebbelaar/bama) | `1.0.0` | `15356bd8ebff408222ad21395aea09bd74b15310` |

Both upstreams ship under the MIT license:

- REA, Copyright (c) 2026 morluto. The MIT grant is reproduced in this
  package's [LICENSE](LICENSE), with the upstream copyright notice preserved;
  the upstream file is
  [REA's LICENSE](https://github.com/morluto/rea/blob/main/LICENSE) at the pinned
  commit.
- BAMA, Copyright (c) 2026 Dave Ebbelaar. The MIT grant is reproduced in this
  package's [LICENSE](LICENSE), with the upstream copyright notice preserved;
  the upstream file is
  [BAMA's LICENSE](https://github.com/daveebbelaar/bama/blob/main/LICENSE).

This package and its adaptation layer are MIT licensed too. See
[LICENSE](LICENSE). The REA project also publishes a responsible-use disclaimer;
it is reproduced verbatim in [docs/rea-disclaimer.md](docs/rea-disclaimer.md).

## What is upstream, what is new

Upstream content:

- **REA:** the `reverse-engineer-anything` skill body and its seven reference
  guides: `android-applications.md`, `connection-and-recovery.md`,
  `environments.md`, `evidence-workflows.md`, `javascript-applications.md`,
  `native-and-artifacts.md`, and `runtime-observation.md`.
- **BAMA:** all 21 skills with their `references/`, `scripts/`, and `template/`
  assets, plus the example build plans under `specs/` (shipped as
  `skills/app-brief/specs/`).

New in this package:

- The pack router skill `rev-eng` (`skills/rev-eng/`) that routes between the
  two packs.
- The plugin that registers the packaged skills as a skill provider
  (`src/`), and the bundle layer that mounts it (`cordis.patch.yml`).
- REA's dsh-specific guide `skills/reverse-engineer-anything/references/dsh-harness.md`.
- The optional REA MCP overlay `patches/rea-mcp.yml`.
- The drop-in installers `scripts/install.sh` and `scripts/install.ps1`, the
  skills linter `scripts/lint-skills.mjs`, and the test suite under `test/`.
- Documentation: [README.md](README.md), [CHANGELOG.md](CHANGELOG.md),
  [docs/adaptation.md](docs/adaptation.md), [docs/rea-disclaimer.md](docs/rea-disclaimer.md),
  and this file.
- The verification harness under `verification/`.
- The README demo animation and asciinema recording under `docs/demo/`, whose
  prompt and answer were captured from a real dsh session.

Not shipped: the staged upstream sources (`vendor/`) are a development
artifact regenerated from the pinned upstream versions, and `package.json`
`files` also excludes the adaptation logs (`notes/`). Both stay in the source
repository for review.

## What was adapted, what was preserved

The adaptation is deliberately narrow: port the harness mechanics, keep the
technical substance. The full before/after log lives in
[notes/bama-adaptations.md](notes/bama-adaptations.md) and
[notes/rea-adaptations.md](notes/rea-adaptations.md); the rules and mapping
table are in [docs/adaptation.md](docs/adaptation.md).

Preserved:

- Every skill name and directory name. BAMA's 21 names and REA's
  `reverse-engineer-anything` are unchanged, so a dsh install shadows an older
  copy of the same upstream skill instead of colliding with it.
- All upstream reference, script, template, and example-spec content, except
  the client-specific wording listed in the notes.
- Executable bits on upstream scripts.
- REA's technical method: target routing, evidence and summary-first rules,
  provider budgets, retry-once rules, and the client-versus-provider deadline
  distinction.
- BAMA's pipeline stages, tables, "Done when" lines, and writing style.

Adapted for dsh:

- Tool names (`Skill`/`Read`/`Write`/`Edit`/`Bash`/`Grep`/`Glob`/`TodoWrite`/
  `Task` and friends) and skill invocation wording.
- Path idioms: `${CLAUDE_SKILL_DIR}/...` became paths relative to the skill base
  directory that dsh prints when it loads a skill.
- `CLAUDE.md` file conventions became `AGENTS.md`.
- Client-specific setup, registration, approval, and computer-use instructions
  became dsh-native; for REA, dsh's official 6.8.0 client support replaced the
  other clients' setup flows.
- Frontmatter was flattened to the dsh subset and non-shipped keys were dropped.
- BAMA's flat layout required re-pointing cross-skill links; `specs/` moved
  under the `app-brief` skill; `agents/` metadata directories were dropped.

No upstream technical claim, command semantic, target type, or skill trigger was
intentionally removed. Where a client-neutral rewrite was impossible, the change
is recorded in the notes with its reason.

## Verification

- `node scripts/lint-skills.mjs` validates the shipped tree: frontmatter shape,
  name-to-directory match, description rules, relative links, dropped
  directories, and leftover upstream-client conventions.
- `npm test` runs syntax checks and the plugin unit tests.
- `verification/verify.sh` is the acceptance gate. It builds an isolated
  `DSH_HOME` inside the repository, installs the bundle into a fresh profile,
  proves the composed layer with `--dump-config`, validates the REA MCP overlay,
  and (with `--full`) boots an isolated `dsh web` server and checks the REA MCP
  child process. It never writes to the user's dsh home or desktop profile.

## Updating the pack from upstream

1. Re-read the upstream repository at the new commit and update the pinned
   commit in this file and in the adaptation notes.
2. Re-stage the upstream sources and diff them against the shipped `skills/`
   tree from the previous pin. Copy changed skill bodies and assets, keeping
   each skill's upstream name and directory.
3. Re-apply the adaptation rules in [docs/adaptation.md](docs/adaptation.md) to
   anything that changed: tool names, path idioms, `AGENTS.md`, client-specific
   setup sections, frontmatter flattening, cross-skill links.
4. If REA changes its dsh support (client id, generated row shape, flags), update
   `skills/reverse-engineer-anything/references/dsh-harness.md`,
   `patches/rea-mcp.yml`, and the REA section of the README together.
5. Update the "What was adapted" sections of the notes files with the new
   per-file entries and bump [CHANGELOG.md](CHANGELOG.md).
6. Run `node scripts/lint-skills.mjs`, `npm test`, and `./verification/verify.sh`
   (add `--full` when the MCP path changed). Fix every failure before releasing.

## Upstream credits beyond the code

REA's approach and BAMA's "Mac app from a screenshot" pipeline build on the
work of their maintainers and communities. BAMA's writing rules follow Matt
Pocock's `writing-for-agents` guidance. Those ideas are credited upstream; this
package only adapts the delivered skill text.
