# Teach agents to drive the app

Agents learn a CLI from three places: a short skill that says when and how
to use it, `<cli> help`, and the errors. Write the skill; the CLI does the
rest.

## Contents

- The app's agent skill
- Where to put it
- Permissions
- MCP registration

## The app's agent skill

Save it as the target agent's skill or instruction file in the app's repo.
dsh reads a skill from `~/.agents/skills/<cli>/SKILL.md`; other harnesses
use their own skill folder. Replace the angle brackets. Keep it under 60
lines: list the five commands used most, and point at `help` for the rest.

```markdown
---
name: <cli>
description: Drive the <App> app on this Mac from the shell with the `<cli>` command: <the main jobs, like "list, add, complete, and search tasks">. Use when the user asks about their <things> or wants to change them, or names <App>.
---

# <App>

`<cli>` runs commands in the <App> app. Changes show in its window at once.
If the app is closed, the command opens it in the background.

## Rules

- Always add `--json` and read the JSON. Exit 0 is ok; otherwise read
  `error.code` and `error.message`, and do what the message says.
- Find ids with `<cli> <noun> list` or `--search`. An id is 8 characters.
- Destructive commands (<delete, send>) only report what they would do.
  Show the user that report and ask before you run it again with `--yes`.
- To try something without real data, add `APP_STORE=/tmp/<cli>-test.store`
  in front of the command.

## Main commands

| Command | Does |
| --- | --- |
| `<cli> status --json` | Is the app running, what is open, counts |
| `<cli> <noun> list [--search T] [--limit N] --json` | Find things |
| `<cli> <noun> add --title T --json` | Add one |
| `<cli> <noun> update <id> [--field value] --json` | Change one |
| `<cli> open <page>` | Show a page in the window |

Everything else: `<cli> help`, and `<cli> help <command>` for its options.
```

## Where to put it

| Place | Who sees it |
| --- | --- |
| The app's repo, as the target agent's skill or instruction file | Agents working on the app's code |
| `~/.agents/skills/<cli>/SKILL.md` | dsh in any folder: "add milk to my tasks" works everywhere |
| The harness's own global skill folder | Other harnesses, in any folder |

Copy the same file to each place the user wants. Update all of them when a
command changes.

## Permissions

Most harnesses ask before each shell command, so read commands prompt
every time unless the user allows them. Allow these read commands where
the harness has a permission or allow list: `status`, `help`,
`<noun> list`, `<noun> show`. Leave write and destructive commands out, so
the user approves each one. In dsh the session permission policy decides;
ask the user before changing their settings.

## MCP registration

Only when the user wants MCP, or the client has no shell. Always the full
path to the binary inside the app: MCP clients do not read the shell's
`PATH`.

Add a stdio server to the client's config, with that path as the command
and `["mcp"]` as the args. Most clients take an entry like this:

```json
{ "mcpServers": { "<cli>": { "command": "/Users/<you>/Applications/<App>.app/Contents/MacOS/<App>", "args": ["mcp"] } } }
```

Restart the client after editing. A dsh MCP row goes in the harness
profile; reload the session after editing it. A row that fails to connect
starts the harness without its tools, so check the harness logs first.

Tools are named like the commands with `_` for spaces (`items_add`), carry
`readOnlyHint` and `destructiveHint`, and take the same options as the CLI.
