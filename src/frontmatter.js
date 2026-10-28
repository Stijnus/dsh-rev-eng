/**
 * Flat YAML frontmatter parser for the dsh-rev-eng skill pack.
 *
 * DSH skill providers only need a small, predictable frontmatter subset:
 * `name`, `description`, `whenToUse`, and the two invocation switches. This
 * parser accepts exactly that shape — one `key: value` pair per line — and
 * rejects nested mappings so a malformed skill fails loudly instead of loading
 * with silently ignored metadata. `scripts/lint-skills.mjs` runs the same
 * parser over the shipped tree.
 */

/** Frontmatter keys the dsh-rev-eng provider understands. */
export const ALLOWED_FRONTMATTER_KEYS = Object.freeze([
  'name',
  'description',
  'whenToUse',
  'disable-model-invocation',
  'user-invocable',
])

/**
 * Parse one `SKILL.md` frontmatter block.
 * @param {string} raw - the complete `SKILL.md` text
 * @returns {{ fields: Record<string, string>, body: string } | undefined} `undefined` when the file has no frontmatter
 * @throws {Error} when the block is unterminated, contains a nested mapping, or repeats a key
 */
export function parseFrontmatter(raw) {
  const lines = raw.split(/\r?\n/)
  if (lines[0] !== '---') return undefined
  const fields = {}
  let index = 1
  for (; index < lines.length; index++) {
    const line = lines[index]
    if (line === '---') break
    if (line.trim() === '' || line.trimStart().startsWith('#')) continue
    const match = /^([A-Za-z][A-Za-z0-9_-]*):(?:\s+(.*))?$/.exec(line)
    if (match === null) {
      throw new Error(
        `unparseable frontmatter line ${index + 1} (${JSON.stringify(line)}): `
        + 'only flat "key: value" pairs are supported; move prose into the body',
      )
    }
    const key = match[1]
    if (Object.hasOwn(fields, key)) throw new Error(`duplicate frontmatter key "${key}"`)
    fields[key] = unquote(match[2] ?? '')
  }
  if (index >= lines.length) throw new Error('frontmatter is not closed with "---"')
  return { fields, body: lines.slice(index + 1).join('\n').trim() }
}

/**
 * Strip one matching pair of surrounding quotes.
 * @param {string} value - raw scalar text
 * @returns {string} unquoted scalar
 */
function unquote(value) {
  const trimmed = value.trim()
  if (trimmed.length < 2) return trimmed
  const first = trimmed[0]
  const last = trimmed[trimmed.length - 1]
  if (first !== last || (first !== '"' && first !== "'")) return trimmed
  const inner = trimmed.slice(1, -1)
  return first === '"' ? inner.replace(/\\(["\\])/g, '$1') : inner
}
