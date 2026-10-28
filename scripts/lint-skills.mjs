#!/usr/bin/env node
/**
 * Validate the shipped skill tree: flat frontmatter, kebab-case directory names
 * that match the frontmatter name, routing descriptions, relative markdown
 * links, no leftover upstream-client conventions, no dropped asset directories.
 *
 * Run from anywhere: node scripts/lint-skills.mjs
 */

import { readdir, readFile, stat } from 'node:fs/promises'
import { dirname, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { ALLOWED_FRONTMATTER_KEYS, parseFrontmatter } from '../src/frontmatter.js'

const ROOT = resolve(fileURLToPath(new URL('..', import.meta.url)))
const SKILLS_DIR = join(ROOT, 'skills')
const KEBAB_CASE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/
const MAX_DESCRIPTION = 500
const TEXT_EXTENSIONS = new Set(['.md', '.sh', '.ps1', '.swift', '.json', '.yaml', '.yml', '.txt'])
const DROPPED_DIRECTORIES = new Set(['agents', '.claude-plugin', '.codex-plugin'])

/** Upstream-client conventions that must not survive adaptation. */
const FORBIDDEN = [
  { pattern: /\$\{CLAUDE_SKILL_DIR\}/, label: '${CLAUDE_SKILL_DIR}' },
  { pattern: /\$\{CLAUDE_PLUGIN_ROOT\}/, label: '${CLAUDE_PLUGIN_ROOT}' },
  { pattern: /Skill tool/, label: 'Skill tool (use `skill` tool)' },
  { pattern: /mcp__computer-use__/, label: 'mcp__computer-use__ namespace' },
  { pattern: /CLAUDE\.md/, label: 'CLAUDE.md (use AGENTS.md)' },
  { pattern: /TodoWrite/, label: 'TodoWrite (use todo_write)' },
  { pattern: /\b(?:Read|Write|Edit|Bash) tool\b/, label: 'capitalized Claude tool name' },
  { pattern: /claude/i, label: 'Claude reference' },
  { pattern: /\bcodex\b/i, label: 'Codex reference' },
  { pattern: /\bCursor\b/, label: 'Cursor client reference' },
  { pattern: /\bwindsurf\b/i, label: 'Windsurf client reference' },
  { pattern: /\bgemini\b/i, label: 'Gemini client reference' },
]

/** @type {string[]} */
const errors = []
/** @type {string[]} */
const warnings = []
let skillCount = 0
let markdownLinks = 0

/**
 * Record one lint failure.
 * @param {string} message - human-readable problem
 */
function fail(message) {
  errors.push(message)
}

/**
 * Record one soft finding.
 * @param {string} message - human-readable finding
 */
function warn(message) {
  warnings.push(message)
}

/**
 * Walk a directory recursively.
 * @param {string} dir - absolute directory path
 * @param {string[]} [found] - accumulator
 * @returns {Promise<string[]>} absolute file paths (sorted for determinism)
 */
async function walk(dir, found = []) {
  const entries = await readdir(dir, { withFileTypes: true })
  for (const entry of entries) {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) await walk(path, found)
    else if (entry.isFile()) found.push(path)
  }
  return found.sort()
}

/**
 * Lint every text file inside one skill directory.
 * @param {string} skillDir - absolute skill directory
 * @param {string} name - skill directory name
 */
async function lintSkillFiles(skillDir, name) {
  for (const file of await walk(skillDir)) {
    const relative = file.slice(skillDir.length + 1)
    for (const segment of relative.split(sep)) {
      if (DROPPED_DIRECTORIES.has(segment)) {
        fail(`${name}/${relative}: dropped upstream directory "${segment}" must not ship`)
      }
    }
    const extension = relative.slice(relative.lastIndexOf('.'))
    if (!TEXT_EXTENSIONS.has(extension)) continue
    const text = await readFile(file, 'utf8')
    for (const { pattern, label } of FORBIDDEN) {
      const match = pattern.exec(text)
      if (match !== null) {
        fail(`${name}/${relative}: forbidden ${label} (matched "${match[0]}")`)
      }
    }
    if (extension !== '.md') continue
    const linkPattern = /\[[^\]]*\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)/g
    for (const match of text.matchAll(linkPattern)) {
      const target = decodeURIComponent(match[1])
      if (/^(?:https?:|mailto:)/.test(target) || target.startsWith('#')) continue
      markdownLinks++
      const [pathPart] = target.split('#')
      if (pathPart === '') continue
      const resolved = resolve(dirname(file), pathPart)
      if (!resolved.startsWith(SKILLS_DIR + sep)) {
        fail(`${name}/${relative}: link leaves the skills tree: ${target}`)
        continue
      }
      try {
        await stat(resolved)
      } catch {
        fail(`${name}/${relative}: broken relative link: ${target}`)
      }
    }
  }
}

/**
 * Run the skill lint.
 * @returns {Promise<number>} process exit code
 */
async function main() {
  let entries
  try {
    entries = await readdir(SKILLS_DIR, { withFileTypes: true })
  } catch (error) {
    console.error(`error: cannot read ${SKILLS_DIR}: ${error.message}`)
    return 1
  }

  const seen = new Set()
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      fail(`skills/${entry.name}: only skill directories may sit at the skills root`)
      continue
    }
    const name = entry.name
    if (!KEBAB_CASE.test(name)) {
      fail(`skills/${name}: directory name is not kebab-case`)
      continue
    }
    const lower = name.toLowerCase()
    if (seen.has(lower)) fail(`skills/${name}: duplicate skill directory (case-insensitive)`)
    seen.add(lower)

    const skillDir = join(SKILLS_DIR, name)
    const skillPath = join(skillDir, 'SKILL.md')
    let raw
    try {
      raw = await readFile(skillPath, 'utf8')
    } catch {
      fail(`skills/${name}: SKILL.md is missing`)
      continue
    }

    let parsed
    try {
      parsed = parseFrontmatter(raw)
    } catch (error) {
      fail(`skills/${name}/SKILL.md: ${error.message}`)
      continue
    }
    if (parsed === undefined) {
      fail(`skills/${name}/SKILL.md: frontmatter is missing`)
      continue
    }
    const { fields, body } = parsed
    for (const key of Object.keys(fields)) {
      if (!ALLOWED_FRONTMATTER_KEYS.includes(key)) {
        fail(`skills/${name}/SKILL.md: unsupported frontmatter key "${key}"`)
      }
    }
    if (fields.name !== name) {
      fail(`skills/${name}/SKILL.md: name "${fields.name ?? ''}" must equal directory "${name}"`)
    }
    const description = fields.description ?? ''
    if (description.trim() === '') {
      fail(`skills/${name}/SKILL.md: description is empty`)
    } else {
      if (description.length > MAX_DESCRIPTION) {
        fail(`skills/${name}/SKILL.md: description is ${description.length} chars (max ${MAX_DESCRIPTION})`)
      }
      if (!/\buse when\b/i.test(description)) {
        fail(`skills/${name}/SKILL.md: description must contain a "Use when ..." trigger sentence`)
      }
    }
    for (const key of ['disable-model-invocation', 'user-invocable']) {
      if (fields[key] !== undefined && fields[key] !== 'true' && fields[key] !== 'false') {
        fail(`skills/${name}/SKILL.md: "${key}" must be true or false`)
      }
    }
    if (body.trim() === '') fail(`skills/${name}/SKILL.md: body is empty`)
    if (!/^#\s/m.test(body)) warn(`skills/${name}/SKILL.md: body has no top-level heading`)

    skillCount++
    await lintSkillFiles(skillDir, name)
  }

  if (skillCount === 0) fail('skills/: no skills found')
  if (!seen.has('rev-eng')) warn('skills/rev-eng: pack router skill is missing')

  for (const message of warnings) console.warn(`warn: ${message}`)
  if (errors.length > 0) {
    for (const message of errors) console.error(`error: ${message}`)
    console.error(`\n${errors.length} error(s) across ${skillCount} skill(s)`)
    return 1
  }
  console.log(`lint-skills: ${skillCount} skill(s), ${markdownLinks} relative link(s), 0 errors`)
  return 0
}

process.exitCode = await main()
