#!/usr/bin/env node
// Locale key-set parity + referenced-key completeness for NextN string resources.
// Extracted from the 2026-09-22 acceptance gate (item 4-2): "全部 UI 引用 key 在全部 locale
// 定义齐全且键集合一致". Every locale must define exactly the base key set, and every key a
// source file references must exist somewhere. Cross-module keys (e.g. the reader-kit
// submodule's rkit_* resources) are legitimate, so only the base-locale set and per-locale
// equality are enforced strictly.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const resources = path.join(root, 'entry/src/main/resources')
const REFERENCE = /\$r\(\s*['"]app\.string\.([A-Za-z0-9_]+)['"]/g

function localeKeys(dir) {
  const file = path.join(dir, 'string.json')
  if (!fs.existsSync(file)) return null
  const data = JSON.parse(fs.readFileSync(file, 'utf8'))
  return new Set((data.string ?? []).map(entry => entry.name).filter(Boolean))
}

function sourceRoots() {
  const roots = ['entry/src/main', 'shared/src/main', 'feature/reader/src/main', 'feature/settings/src/main']
    .map(p => path.join(root, p))
    .filter(p => fs.existsSync(p))
  return roots
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walk(full, out)
    else if (entry.name.endsWith('.ets')) out.push(full)
  }
  return out
}

const locales = new Map()
for (const entry of fs.readdirSync(resources, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue
  const keys = localeKeys(path.join(resources, entry.name, 'element'))
  if (keys) locales.set(entry.name, keys)
}

const base = locales.get('base')
if (!base || base.size === 0) {
  console.error('FAIL locale-parity: base locale string.json missing or empty')
  process.exit(1)
}

let failed = false
for (const [name, keys] of [...locales.entries()].sort()) {
  if (name === 'base') continue
  const missing = [...base].filter(key => !keys.has(key))
  const extra = [...keys].filter(key => !base.has(key))
  if (missing.length || extra.length) {
    failed = true
    console.error(`FAIL locale-parity: ${name} differs from base ` +
      `(missing ${missing.length}: ${missing.slice(0, 6).join(', ') || '-'}; ` +
      `extra ${extra.length}: ${extra.slice(0, 6).join(', ') || '-'})`)
  }
}

const defined = new Set()
for (const keys of locales.values()) for (const key of keys) defined.add(key)

const referenced = new Set()
for (const dir of sourceRoots()) {
  for (const file of walk(dir)) {
    const text = fs.readFileSync(file, 'utf8')
    for (const match of text.matchAll(REFERENCE)) referenced.add(match[1])
  }
}

// Keys owned by the reader-kit submodule resources are packaged into the same HAP, so a
// reference to them is not a host-resource gap; the built HAP check covers the rest.
const kitKeys = new Set()
const kitResources = path.join(root, 'third_party/reader-kit/reader-ui/src/main/resources')
if (fs.existsSync(kitResources)) {
  for (const entry of fs.readdirSync(kitResources, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue
    const keys = localeKeys(path.join(kitResources, entry.name, 'element'))
    if (keys) for (const key of keys) kitKeys.add(key)
  }
}

const undefinedKeys = [...referenced].filter(key => !defined.has(key) && !kitKeys.has(key)).sort()
if (undefinedKeys.length) {
  failed = true
  console.error(`FAIL locale-parity: ${undefinedKeys.length} referenced key(s) are defined nowhere: ` +
    undefinedKeys.slice(0, 12).join(', '))
}

if (failed) process.exit(1)
console.log(`locale-parity PASS: ${locales.size} locales x ${base.size} keys identical; ` +
  `${referenced.size} referenced keys defined (${kitKeys.size} from reader-kit)`)
