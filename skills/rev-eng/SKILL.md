---
name: rev-eng
description: Entry point for this pack: reverse engineer shipped apps, binaries, firmware, Android packages, and bundled JavaScript with REA, or research, design, build, test, and ship native macOS apps with Swift and SwiftUI using BAMA. Use when the user asks to reverse engineer, decompile, inspect, compare, clone, or reconstruct an app or binary, or to plan, build, or polish a native Mac app.
---

# Reverse engineering and native Mac apps

This pack carries two upstream skill collections and mounts them in the session
skill catalog:

- **REA** (`reverse-engineer-anything`) explains shipped behavior from
  artifacts: native binaries, Electron and JavaScript bundles, Android apps,
  firmware, GPU code objects, and runtime evidence, with REA's MCP tools or its
  CLI.
- **BAMA** is a pipeline of 21 skills for native macOS apps: research, clone,
  brief, user stories, scaffold, Swift and SwiftUI code, macOS integrations,
  design, performance, testing, and shipping.

Load one skill at a time with the `skill` tool. Follow the loaded skill instead
of re-deriving its process here.

## Pick a pack

| The user wants to | Load |
| --- | --- |
| Explain how a shipped app or binary implements a feature | `reverse-engineer-anything` |
| Decompile, compare two versions, or recover source from a bundle | `reverse-engineer-anything` |
| Inspect an Android APK, firmware image, or runtime behavior of a target | `reverse-engineer-anything` |
| Rebuild or clone an app they named, or match its look and behavior | `reverse-engineer-anything` first for the evidence, then `clone` |
| Build a native Mac app from an idea, spec, or brief | `bama` |
| Work on Swift, SwiftUI, macOS integrations, performance, or accessibility | `bama` |
| Design screens, a design system, or an app icon for a Mac app | `bama` |
| Build, test, verify, or iterate on a running Mac app | `bama` |

`bama` is user-invocable with `/bama`; the pack router itself is `/rev-eng`.

## Check what the session can do

- **REA tools.** Look for `mcp__rea__*` tools before promising analysis that
  needs them. If they are missing, load `reverse-engineer-anything` anyway: it
  covers the CLI fallback through the `bash` tool and the exact connection-repair
  ladder. Mounting the REA MCP server is an explicit opt-in documented in that
  skill's `references/dsh-harness.md` and in this package's README; a config
  change needs a session reload or an app restart.
- **Native Mac work.** BAMA's build and verify steps expect macOS, the Xcode
  command line tools (`swift`, `xcodebuild`, `sips`), and a way to see the app:
  computer use when the session has it, otherwise screenshots the user supplies.
- **Ask before installing.** Analysis engines (Hopper, Ghidra, IDA, JADX, Java,
  pwntools), Homebrew packages, and app scaffolds are separate installs. Confirm
  with the user before changing their machine; REA never installs engines on its
  own.

## Route a reverse-engineering task

1. Load `reverse-engineer-anything` and follow its target routing. It decides
   between static JavaScript, native code, Android, and artifact inspection.
2. Establish the evidence the claim needs before decompiling broadly. Prefer the
   cheapest source that answers the question: strings and metadata before
   disassembly, static inspection before running the target.
3. Keep a short evidence trail: target path, hashes or versions, the tool calls
   used, and the exact output that supports each conclusion.
4. If the user's real goal is to rebuild the app, hand off to BAMA once the
   behavior is captured: `clone` for a native target, or `new-mac-app` plus
   `app-brief` when the evidence is still a design brief.

## Route a Mac-app task

1. Load `bama`; it is the router for the whole pipeline and names the next
   skill for the user's stage.
2. Pick the app name before research and create the app folder first, so every
   later skill writes into the same `docs/` tree.
3. Design comes right after the scaffold: tokens from the first real view, icon
   in every verification snapshot.
4. End each stage on the checkable condition the loaded skill names. Do not
   claim a build, a test, or a visual check you did not run.

## Hand-offs

- Reverse engineering first, rebuild second: capture behavior and screenshots
  with REA, then let BAMA rebuild natively.
- An Electron or JavaScript target that the user wants to rebuild natively:
  recover the structure with `reverse-engineer-anything`, then `clone` and
  `mac-design` to plan the native replacement.
- A Mac app whose integration needs a CLI or MCP server for agents: `agent-cli`
  builds it; the same interface lets a later session drive the app.

## Done when

- The loaded skill's own "Done when" line is satisfied.
- Every claim about the target or the built app is backed by a tool call or an
  artifact you produced, not by inference from the summary catalog.
- Any missing provider, engine, or display capability was reported to the user
  with the next concrete step, instead of being silently worked around.
