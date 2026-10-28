# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-28

Initial release: two adapted agent-skill collections, packaged as one DeepSeek
Harness plugin bundle with 23 skills.

### Added

- **REA 6.8.0**, the `reverse-engineer-anything` skill, adapted for dsh: the
  skill body, 7 upstream references, and a new `references/dsh-harness.md` that
  covers the official dsh client setup, the pack-provided MCP overlay, and the
  CLI fallback. Pinned to commit `3b242491a430b3807853436bfeb9568d606169ac`.
- **BAMA 1.0.0**, all 21 skills and their references, scripts, templates, and
  example specs, adapted for dsh. Pinned to commit
  `15356bd8ebff408222ad21395aea09bd74b15310`.
- Pack router skill `rev-eng` (user-invocable as `/rev-eng`) that routes between
  the two packs.
- Plugin layer `rev-eng-skills` that registers a skill provider over the
  packaged `skills/` tree at rank 400, source `bundled`, so every profile that
  installs the bundle sees all 23 skills.
- Optional REA MCP overlay at `patches/rea-mcp.yml` (id `rea-mcp`, `npx`
  launcher, `toolCallTimeoutMs: 600000`) as an alternative to REA's own
  `rea setup --client dsh`.
- Drop-in installers for users who do not install the bundle:
  `scripts/install.sh` and `scripts/install.ps1`. Targets: `$DSH_HOME/skills`
  by default, `--project <dir>` for one project, `--user-agents` for the shared
  agent root. Flags: `--list`, `--uninstall`.
- Documentation: `README.md`, `PROVENANCE.md`, `docs/adaptation.md`, and the
  verbatim upstream disclaimer at `docs/rea-disclaimer.md`.
- README demo animation (`docs/demo/rev-eng.gif`) and asciinema recording
  (`docs/demo/rev-eng.cast`), rendered from a real `/rev-eng` session.
- Package metadata for the dsh bundle layer and the dsh compatibility range.
- Published to npm as `dsh-rev-eng@0.1.0` and to GitHub at
  https://github.com/Stijnus/dsh-rev-eng.

### Notes

- Requires DeepSeek Harness `>=0.2.1-rc.3 <0.3.0-0` and Node.js >= 22.
- Both upstream packs are MIT licensed. See [LICENSE](LICENSE) and
  [PROVENANCE.md](PROVENANCE.md).
- REA is a dual-use analysis toolkit. See `docs/rea-disclaimer.md`.
