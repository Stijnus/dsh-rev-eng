/**
 * dsh-rev-eng plugin: registers a skill provider that serves the packaged
 * skills/ directory into the dsh skill registry (rank 400, source "bundled"),
 * so both packs ride with any profile that installs this bundle.
 *
 * The provider scans skills/ on every list() call; the registry caches
 * snapshots, so live edits stay cheap. Frontmatter is the flat subset
 * dsh-skill-filesystem accepts (name, description, disable-model-invocation,
 * user-invocable, whenToUse); scripts/lint-skills.mjs enforces it at the source.
 */

import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { ALLOWED_FRONTMATTER_KEYS, parseFrontmatter } from './frontmatter.js'

const PROVIDER_NAME = 'rev-eng-skills'
const SKILLS_PATH = fileURLToPath(new URL('../skills/', import.meta.url))
/**
 * Matches user-dsh roots: shadows ~/.agents/skills (rank 500), yields to
 * project roots and custom dirs (rank 100-300).
 */
const RANK = 400
const KEBAB_CASE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/**
 * Read one skill directory into a candidate plus body pair.
 * @param {string} dir - absolute skill directory
 * @param {string} name - directory name, which must equal the frontmatter name
 * @returns {Promise<{name: string, description: string, whenToUse?: string, invocation: {modelInvocable: boolean, userInvocable: boolean}, resourceBase: {kind: 'directory', path: string}, skillPath: string, body: string}>}}
 */
async function loadSkill(dir, name) {
  const skillPath = join(dir, 'SKILL.md')
  const parsed = parseFrontmatter(await readFile(skillPath, 'utf8'))
  if (parsed === undefined) throw new Error(`${skillPath} has no frontmatter`)
  const { fields, body } = parsed
  for (const key of Object.keys(fields)) {
    if (!ALLOWED_FRONTMATTER_KEYS.includes(key)) {
      throw new Error(`${skillPath} has unsupported frontmatter key "${key}"`)
    }
  }
  if (!KEBAB_CASE.test(name)) throw new Error(`${skillPath} directory "${name}" is not kebab-case`)
  if (fields.name !== name) throw new Error(`${skillPath} name "${fields.name}" != directory "${name}"`)
  const description = fields.description?.trim()
  if (description === undefined || description === '') throw new Error(`${skillPath} has no description`)
  return {
    name,
    description,
    ...fields.whenToUse === undefined ? {} : { whenToUse: fields.whenToUse.trim() },
    invocation: {
      modelInvocable: booleanField(fields, 'disable-model-invocation', skillPath) !== true,
      userInvocable: booleanField(fields, 'user-invocable', skillPath) !== false,
    },
    resourceBase: { kind: 'directory', path: dir },
    skillPath,
    body,
  }
}

/**
 * Read one optional boolean frontmatter switch.
 * @param {Record<string, string>} fields - parsed frontmatter
 * @param {string} key - switch name
 * @param {string} skillPath - skill file path for the error message
 * @returns {boolean | undefined} the switch value, or undefined when omitted
 */
function booleanField(fields, key, skillPath) {
  const value = fields[key]
  if (value === undefined) return undefined
  if (value === 'true') return true
  if (value === 'false') return false
  throw new Error(`${skillPath} frontmatter "${key}" must be true or false, got ${JSON.stringify(value)}`)
}

/**
 * Create the provider bound to a logger for malformed-skill warnings.
 * @param {{ logger: { warn: (message: string) => void } }} ctx - plugin context
 * @returns {{name: string, list: Function, get: Function}} the skill provider
 */
export function createProvider(ctx) {
  async function scan() {
    let entries
    try {
      entries = await readdir(SKILLS_PATH, { withFileTypes: true })
    } catch (error) {
      ctx.logger.warn(`skills directory is not readable: ${error.message}`)
      return []
    }
    const skills = []
    for (const entry of entries) {
      if (!entry.isDirectory()) continue
      try {
        skills.push(await loadSkill(join(SKILLS_PATH, entry.name), entry.name))
      } catch (error) {
        ctx.logger.warn(`skill "${entry.name}" ignored: ${error.message}`)
      }
    }
    return skills.sort((left, right) => left.name.localeCompare(right.name))
  }

  return {
    name: PROVIDER_NAME,
    async list() {
      return (await scan()).map(skill => ({
        name: skill.name,
        description: skill.description,
        ...skill.whenToUse === undefined ? {} : { whenToUse: skill.whenToUse },
        invocation: skill.invocation,
        provider: PROVIDER_NAME,
        source: 'bundled',
        resourceBase: skill.resourceBase,
        rank: RANK,
        locator: skill.skillPath,
      }))
    },
    async get(candidate) {
      const skills = await scan()
      const skill = skills.find(entry => entry.name === candidate.name)
      if (skill === undefined) throw new Error(`skill "${candidate.name}" is no longer packaged`)
      return {
        name: skill.name,
        description: skill.description,
        ...skill.whenToUse === undefined ? {} : { whenToUse: skill.whenToUse },
        invocation: skill.invocation,
        provider: PROVIDER_NAME,
        source: 'bundled',
        resourceBase: skill.resourceBase,
        content: skill.body,
      }
    },
  }
}

/** Cordis plugin name; must match the id in cordis.patch.yml. */
export const name = 'rev-eng-skills'
/** Service required by the packaged skill provider. */
export const inject = ['skills']

/**
 * Register the packaged skill provider on `ctx.skills`.
 * @param {{ skills: { registerProvider: (factory: () => unknown) => unknown } }} ctx - plugin context
 */
export function apply(ctx) {
  ctx.skills.registerProvider(() => createProvider(ctx))
}
