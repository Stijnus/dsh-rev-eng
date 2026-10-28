/**
 * Tests for the dsh-rev-eng skill provider and the packaged skill tree.
 * Run: npm test
 */

import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { readdir, stat } from 'node:fs/promises'
import { join } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'
import { ALLOWED_FRONTMATTER_KEYS, parseFrontmatter } from '../src/frontmatter.js'
import { apply, createProvider, inject, name } from '../src/index.js'

const ROOT = fileURLToPath(new URL('..', import.meta.url))
const SKILLS_DIR = join(ROOT, 'skills')

/**
 * Build a minimal fake Cordis context and capture the registered provider.
 * @returns {{ ctx: object, warnings: string[], provider: () => object }}
 */
function fakeContext() {
  /** @type {string[]} */
  const warnings = []
  /** @type {(() => object) | undefined} */
  let factory
  const ctx = {
    logger: { warn: message => warnings.push(message) },
    skills: {
      registerProvider: candidate => {
        factory = candidate
        return () => {}
      },
    },
  }
  return {
    ctx,
    warnings,
    provider: () => {
      assert.ok(factory, 'apply() must register a provider')
      return factory()
    },
  }
}

test('plugin exports the contract dsh expects', () => {
  assert.equal(name, 'rev-eng-skills')
  assert.deepEqual(inject, ['skills'])
  assert.equal(typeof apply, 'function')
})

test('apply() registers exactly one provider', async () => {
  const { ctx, provider } = fakeContext()
  apply(ctx)
  assert.equal(provider().name, 'rev-eng-skills')
})

test('provider lists every packaged skill without warnings', async () => {
  const { ctx, warnings, provider } = fakeContext()
  apply(ctx)
  const listed = await provider().list({ cwd: ROOT })
  assert.deepEqual(warnings, [], 'no skill may be ignored by the provider')
  const directories = (await readdir(SKILLS_DIR, { withFileTypes: true }))
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .sort()
  assert.deepEqual(listed.map(candidate => candidate.name).sort(), directories)
  for (const candidate of listed) {
    assert.match(candidate.name, /^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    assert.ok(candidate.description.length > 0)
    assert.ok(candidate.description.length <= 500, `${candidate.name} description too long`)
    assert.equal(candidate.provider, 'rev-eng-skills')
    assert.equal(candidate.source, 'bundled')
    assert.equal(candidate.rank, 400)
    assert.equal(candidate.resourceBase.kind, 'directory')
    assert.equal(candidate.resourceBase.path, join(SKILLS_DIR, candidate.name))
    assert.ok(await stat(join(candidate.resourceBase.path, 'SKILL.md')))
  }
})

test('provider loads every skill body and repeats stable metadata', async () => {
  const { ctx, provider } = fakeContext()
  apply(ctx)
  const service = provider()
  const listed = await service.list({ cwd: ROOT })
  for (const candidate of listed) {
    const definition = await service.get(candidate, { cwd: ROOT })
    assert.equal(definition.name, candidate.name)
    assert.equal(definition.provider, 'rev-eng-skills')
    assert.ok(definition.content.trim().length > 0)
    assert.deepEqual(definition.invocation, candidate.invocation)
    assert.equal(definition.invocation.userInvocable, true)
  }
})

test('user-invoked routers stay out of the model catalog', async () => {
  const { ctx, provider } = fakeContext()
  apply(ctx)
  const listed = await provider().list({ cwd: ROOT })
  const bama = listed.find(candidate => candidate.name === 'bama')
  assert.ok(bama, 'bama router must ship')
  assert.equal(bama.invocation.modelInvocable, false)
  assert.equal(bama.invocation.userInvocable, true)
})

test('pack ships the router and the entry skill of both upstream packs', async () => {
  const { ctx, provider } = fakeContext()
  apply(ctx)
  const names = new Set((await provider().list({ cwd: ROOT })).map(candidate => candidate.name))
  for (const expected of ['rev-eng', 'reverse-engineer-anything', 'bama', 'app-brief', 'mac-design', 'test-mac-app']) {
    assert.ok(names.has(expected), `missing skill ${expected}`)
  }
})

test('skill frontmatter parses with the flat subset', async () => {
  const { readFile } = await import('node:fs/promises')
  for (const entry of await readdir(SKILLS_DIR, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue
    const parsed = parseFrontmatter(await readFile(join(SKILLS_DIR, entry.name, 'SKILL.md'), 'utf8'))
    assert.ok(parsed, `${entry.name} must have frontmatter`)
    for (const key of Object.keys(parsed.fields)) {
      assert.ok(ALLOWED_FRONTMATTER_KEYS.includes(key), `${entry.name}: unexpected key ${key}`)
    }
  }
})

test('parseFrontmatter rejects nested mappings and duplicates', () => {
  assert.throws(() => parseFrontmatter('---\nname: x\nmetadata:\n  version: "1"\n---\nbody\n'), /unparseable|metadata/)
  assert.throws(() => parseFrontmatter('---\nname: x\nname: y\n---\nbody\n'), /duplicate/)
  assert.throws(() => parseFrontmatter('---\nname: x\n'), /not closed/)
  assert.equal(parseFrontmatter('no frontmatter'), undefined)
})

test('skill tree passes the lint script', () => {
  const result = spawnSync(process.execPath, [join(ROOT, 'scripts', 'lint-skills.mjs')], {
    cwd: ROOT,
    encoding: 'utf8',
  })
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
})
