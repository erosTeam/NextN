#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8')
let failures = 0

function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

function walk(directory) {
  const output = []
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === 'build' || entry.name === '.hvigor' || entry.name === 'oh_modules') {
      continue
    }
    const absolute = path.join(directory, entry.name)
    if (entry.isDirectory()) {
      output.push(...walk(absolute))
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      output.push(absolute)
    }
  }
  return output
}

function quotedValues(block) {
  return new Set(Array.from(block.matchAll(/'([^']+)'/g)).map((match) => match[1]))
}

function arrayValues(source, name) {
  const match = source.match(new RegExp(`${name}: string\\[\\] = \\[([\\s\\S]*?)\\n  \\]`))
  return match === null ? new Set() : quotedValues(match[1])
}

const inventoryText = read('docs/plans/active/persistence-dataset-inventory.md')
const inventory = new Map()
const allowedBackups = new Set(['plaintext', 'encrypted-only', 'localData', 'excluded'])
const allowedSyncs = new Set(['excluded', 'WebDAV', 'HuaweiCloud', 'WebDAV+HuaweiCloud', 'metadata-only', 'migration'])

for (const line of inventoryText.split('\n')) {
  const match = line.match(/^\|\s*`?([^|`]+)`?\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|/)
  if (match === null || match[1].trim() === 'Owner' || match[1].trim() === '---') {
    continue
  }
  const owner = match[1].trim()
  const backup = match[3].trim()
  const sync = match[4].trim()
  ok(`${owner} has an allowed backup classification`, allowedBackups.has(backup))
  ok(`${owner} has an allowed sync classification`, allowedSyncs.has(sync))
  ok(`${owner} appears once`, !inventory.has(owner))
  inventory.set(owner, { backup, sync })
}

const sourceFiles = [
  ...walk(path.join(root, 'shared')),
  ...walk(path.join(root, 'entry')),
  ...walk(path.join(root, 'feature')),
]

const preferenceFiles = []
for (const absolute of sourceFiles) {
  const source = fs.readFileSync(absolute, 'utf8')
  if (!/getPreferences(?:Sync)?\s*\(/.test(source)) {
    continue
  }
  const relative = path.relative(root, absolute).split(path.sep).join('/')
  const stores = Array.from(source.matchAll(
    /const\s+([A-Z0-9_]*(?:STORE|STORE_NAME)[A-Z0-9_]*)\s*:\s*string\s*=\s*'([^']+)'/g,
  ))
  const keys = Array.from(source.matchAll(
    /const\s+((?:KEY_[A-Z0-9_]+|[A-Z0-9_]+_KEY))\s*:\s*string\s*=\s*'([^']+)'/g,
  )).filter((match) => match[1] !== 'KEY_ALIAS')
  if (stores.length === 0 && keys.length === 0) {
    continue
  }
  preferenceFiles.push({ relative, source, stores, keys })
  for (const match of [...stores, ...keys]) {
    ok(`inventory covers ${relative}#${match[1]}`, inventory.has(`${relative}#${match[1]}`))
  }
}

const localStore = read('shared/src/main/ets/storage/LocalDataStore.ets')
const tableNames = Array.from(localStore.matchAll(
  /CREATE TABLE(?: IF NOT EXISTS)? ([a-zA-Z0-9_]+)/g,
)).map((match) => match[1])
for (const table of new Set(tableNames)) {
  ok(`inventory covers table ${table}`, inventory.has(table))
}

for (const absolute of sourceFiles) {
  const source = fs.readFileSync(absolute, 'utf8')
  if (!/\bfileIo\./.test(source) || !/(?:this\.)?context\.(?:cacheDir|filesDir|databaseDir)/.test(source)) {
    continue
  }
  const relative = path.relative(root, absolute).split(path.sep).join('/')
  ok(`inventory covers filesystem owner ${relative}`, inventory.has(relative))
}

const adapter = read('shared/src/main/ets/backup/BackupPreferencesAdapter.ets')
const secretsAdapter = read('shared/src/main/ets/backup/BackupSecretsAdapter.ets')
const denylist = read('shared/src/main/ets/backup/BackupSecretDenylist.ets')
const plaintextStores = arrayValues(adapter, 'PLAINTEXT_STORES')
const secretStores = arrayValues(adapter, 'SECRET_STORES')
const excludedKeys = arrayValues(adapter, 'VOLATILE_EXCLUDED_KEYS')
const sensitiveMarkers = ['cookie', 'apikey', 'token', 'password', 'secret', 'credential']

for (const file of preferenceFiles) {
  const stores = Array.from(new Set(file.stores.map((match) => match[2])))
  if (file.keys.length > 0) {
    ok(`${file.relative} has one statically discoverable Preferences store`, stores.length === 1)
  }
  if (stores.length !== 1) {
    continue
  }
  const store = stores[0]
  for (const match of file.keys) {
    const owner = `${file.relative}#${match[1]}`
    const decision = inventory.get(owner)
    if (decision === undefined) {
      continue
    }
    const fullKey = `${store}.${match[2]}`
    if (decision.backup === 'plaintext') {
      ok(`${owner} plaintext store is exported`, plaintextStores.has(store))
      ok(`${owner} is not excluded from backup`, !excludedKeys.has(fullKey))
    } else if (decision.backup === 'excluded') {
      ok(`${owner} is explicitly excluded by the adapter`, excludedKeys.has(fullKey))
    } else if (decision.backup === 'encrypted-only') {
      if (store === 'nextn_llm_secrets') {
        ok(`${owner} uses the HUKS plaintext/re-wrap adapter`, /exportPlaintextForBackup/.test(secretsAdapter))
        continue
      }
      ok(`${owner} encrypted store is scanned`, secretStores.has(store))
      const lower = fullKey.toLowerCase()
      const markerSecret = sensitiveMarkers.some((marker) => lower.includes(marker))
      const accountListSecret = fullKey.startsWith('nextn_settings.account.list.')
      const webDavSecret = fullKey.startsWith('nextn_settings.sync.webdav.')
      ok(`${owner} is recognized as a secret family`, markerSecret || accountListSecret || webDavSecret)
    }
  }
}

ok('Torii settings store is scanned for plaintext and encrypted-only values',
  plaintextStores.has('nextn_comic_visual_provider') && secretStores.has('nextn_comic_visual_provider'))
ok('generic Preferences secrets are connected to the encrypted backup adapter',
  /BackupPreferencesAdapter\.exportSecrets\(context\)/.test(secretsAdapter) &&
    /BackupPreferencesAdapter\.restore\(context, map, true\)/.test(secretsAdapter) &&
    /BackupPreferencesAdapter\.replace\(context, map, true\)/.test(secretsAdapter))
ok('saved account identities are encrypted-only',
  /ACCOUNT_LIST_PREFIX: string = 'nextn_settings\.account\.list\.'/.test(denylist) &&
    /key\.startsWith\(BackupSecretDenylist\.ACCOUNT_LIST_PREFIX\)/.test(denylist))
ok('active and saved account sessions plus profiles use complete encrypted bundles',
  /ACCOUNT_SESSIONS_KEY: string = 'account\.sessions\.v1'/.test(secretsAdapter) &&
    /exportAllSealedForBackup\(context\)/.test(secretsAdapter) &&
    /restoreAllSealedFromBackup/.test(secretsAdapter) &&
    /ACCOUNT_PROFILES_KEY: string = 'account\.profiles\.v1'/.test(secretsAdapter) &&
    /AccountProfileRepository\.exportForBackup\(context\)/.test(secretsAdapter) &&
    /AccountProfileRepository\.restoreBackup/.test(secretsAdapter))

if (failures === 0) {
  console.log('OK persistence inventory contract passed')
  process.exit(0)
}
console.error(`[FAIL] persistence inventory contract: ${failures} failure(s)`)
process.exit(1)
