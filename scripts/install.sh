#!/usr/bin/env bash
# Install the dsh-rev-eng skill pack into a dsh skill root (drop-in install, no bundle needed).
#
# Targets (choose one):
#   (default)        $DSH_HOME/skills (~/.dsh/skills), rank 400, dsh user root
#   --project <dir>  <dir>/.dsh/skills, rank 100, this project only
#   --user-agents    $DSH_AGENTS_HOME/skills (~/.agents/skills), rank 500, shared agent root
#
# Other flags:
#   --list           print the shipped skill names and the target roots
#   --uninstall      remove this pack's skill directories from the selected target
#   -h, --help       show this help
#
# dsh watches its skill roots, so a new session picks the skills up automatically.
#
# Examples:
#   bash scripts/install.sh
#   bash scripts/install.sh --project ~/code/my-app
#   bash scripts/install.sh --user-agents
#   bash scripts/install.sh --list
#   bash scripts/install.sh --uninstall
#   DSH_HOME=/tmp/dsh bash scripts/install.sh
#

set -euo pipefail

pack_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_dir="$pack_root/skills"

dsh_home="${DSH_HOME:-$HOME/.dsh}"
agents_home="${DSH_AGENTS_HOME:-${AGENTS_HOME:-$HOME/.agents}}"

mode="install"
target=""
target_kind="default"

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      shift
      [ $# -gt 0 ] || { echo "error: --project needs a directory" >&2; exit 1; }
      [ -d "$1" ] || { echo "error: project directory not found: $1" >&2; exit 1; }
      target="$(cd "$1" && pwd)/.dsh/skills"
      target_kind="--project"
      ;;
    --user-agents)
      target="$agents_home/skills"
      target_kind="--user-agents"
      ;;
    --uninstall) mode="uninstall" ;;
    --list) mode="list" ;;
    -h|--help) usage ;;
    *)
      echo "error: unknown flag: $1 (try --help)" >&2
      exit 1
      ;;
  esac
  shift
done

[ -d "$skills_dir" ] || { echo "error: skills directory not found: $skills_dir" >&2; exit 1; }

# Print the shipped skill directory names (one per line). Only directories that
# contain a SKILL.md count, and an empty result is an error: it means the pack
# is incomplete, not that there is nothing to install.
skill_names() {
  local entry name found=0
  for entry in "$skills_dir"/*/; do
    [ -d "$entry" ] || continue
    name="$(basename "$entry")"
    if [ -f "$entry/SKILL.md" ]; then
      printf '%s\n' "$name"
      found=$((found + 1))
    fi
  done
  [ "$found" -gt 0 ] || { echo "error: no skills found under $skills_dir" >&2; exit 1; }
}

case "$mode" in
  list)
    skill_count="$(skill_names | wc -l | tr -d ' ')"
    echo "dsh-rev-eng: $skill_count shipped skill(s)"
    echo ""
    skill_names | sed 's/^/  /'
    echo ""
    echo "target roots (dsh skill discovery rank):"
    printf '  default        %s  [rank 400]\n' "$dsh_home/skills"
    printf '  --project      <dir>/.dsh/skills  [rank 100]\n'
    printf '  --user-agents  %s  [rank 500]\n' "$agents_home/skills"
    if [ -n "$target" ]; then
      echo ""
      printf 'selected target: %s (%s)\n' "$target" "$target_kind"
    fi
    echo ""
    echo "install with: bash scripts/install.sh [--project <dir> | --user-agents]"
    exit 0
    ;;
  uninstall)
    [ -n "$target" ] || target="$dsh_home/skills"
    case "$target" in
      ""|"/") echo "error: refusing to uninstall from '$target'" >&2; exit 1 ;;
    esac
    if [ ! -d "$target" ]; then
      echo "nothing to uninstall: $target does not exist"
      exit 0
    fi
    echo "uninstalling this pack's skills from $target ($target_kind)"
    echo ""
    removed=0
    for name in $(skill_names); do
      if [ -d "$target/$name" ]; then
        rm -rf "$target/$name"
        echo "removed   $name"
        removed=$((removed + 1))
      fi
    done
    echo ""
    if [ "$removed" -eq 0 ]; then
      echo "nothing to uninstall: none of this pack's skills are in $target"
    else
      echo "uninstalled $removed skill(s) from $target"
    fi
    echo "left every other entry in that directory untouched"
    echo "start a new dsh session to see the skills disappear"
    exit 0
    ;;
esac

[ -n "$target" ] || target="$dsh_home/skills"
case "$target" in
  ""|"/") echo "error: refusing to install into '$target'" >&2; exit 1 ;;
esac

skill_count="$(skill_names | wc -l | tr -d ' ')"
echo "installing $skill_count skill(s) into $target ($target_kind)"
echo ""
mkdir -p "$target"

installed=0
for name in $(skill_names); do
  rm -rf "$target/$name"
  cp -R "$skills_dir/$name" "$target/$name"
  echo "installed $name"
  installed=$((installed + 1))
done

echo ""
echo "done: $installed skill(s) -> $target"
echo ""
echo "next steps:"
echo "  1. Start a new dsh session. dsh watches its skill roots, so the skills are available without a restart."
echo "  2. Type /rev-eng for this pack's router, or /bama for the Mac-app pipeline."
echo "  3. REA's MCP tools are optional. From a terminal:"
echo "       npx -y rea-agents@6.8.0 setup --client dsh --skill=false --dry-run --json"
echo "     Review the plan, then rerun with --yes and restart dsh. Do not enable this"
echo "     and patches/rea-mcp.yml at the same time: two rows with serverName rea conflict."
