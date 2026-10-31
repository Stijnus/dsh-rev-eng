/**
 * Minimum viable dsh plugin.
 *
 * A Cordis plugin is just module exports: `name`, optional `inject`, and
 * `apply(ctx)`. This one registers a skill provider over ./skills.
 */

import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

/** Must match the patch row id in cordis.patch.yml. */
export const name = 'example-skills'
/** Wait for the skill service before applying. */
export const inject = ['skills']

const SKILLS_PATH = fileURLToPath(new URL('../skills/', import.meta.url))

/**
 * Read one `<name>/SKILL.md` with a flat `key: value` frontmatter block.
 * @param {string} dir skill directory
 * @param {string} skillName directory name, which must match frontmatter name
 */
async function loadSkill(dir, skillName) {
  const skillPath = join(dir, 'SKILL.md')
  const raw = await readFile(skillPath, 'utf8')
  const [, front = '', ...rest] = raw.split(/^---$/m)
  const fields = Object.fromEntries(
    front.split('\n')
      .filter(line => line.trim() !== '')
      .map(line => [line.slice(0, line.indexOf(':')).trim(), line.slice(line.indexOf(':') + 1).trim()]),
  )
  if (fields.name !== skillName) throw new Error(`${skillPath}: name != directory`)
  return {
    name: skillName,
    description: fields.description,
    body: rest.join('---').trim(),
    skillPath,
    dir,
  }
}

/** Create the provider bound to the plugin logger. */
function createProvider(ctx) {
  async function scan() {
    const entries = await readdir(SKILLS_PATH, { withFileTypes: true })
    const skills = []
    for (const entry of entries) {
      if (!entry.isDirectory()) continue
      try {
        skills.push(await loadSkill(join(SKILLS_PATH, entry.name), entry.name))
      } catch (error) {
        ctx.logger.warn(`skill "${entry.name}" ignored: ${error.message}`)
      }
    }
    return skills
  }

  const project = skill => ({
    name: skill.name,
    description: skill.description,
    invocation: { modelInvocable: true, userInvocable: true },
    provider: 'example-skills',
    source: 'bundled',
    resourceBase: { kind: 'directory', path: skill.dir },
  })

  return {
    name: 'example-skills',
    async list() {
      return (await scan()).map(project)
    },
    async get(candidate) {
      const skill = (await scan()).find(entry => entry.name === candidate.name)
      if (skill === undefined) throw new Error(`skill "${candidate.name}" is no longer packaged`)
      return { ...project(skill), content: skill.body, locator: skill.skillPath }
    },
  }
}

export function apply(ctx) {
  ctx.skills.registerProvider(() => createProvider(ctx))
}
