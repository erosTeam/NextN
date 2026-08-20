#!/usr/bin/env node
/**
 * Guard the nullable ArkUI scroll-offset boundary.
 *
 * Scroller.currentOffset() can be undefined while a route is detaching or
 * before its scrollable has attached. Only ScrollUserInput owns that read;
 * every consumer must use currentScrollOffsetY/X instead.
 *
 * The same scan rejects direct property chaining from getImageInfo() or
 * getRectangle(), which would bypass an intermediate nullable-result guard.
 * Run: node scripts/test_scroll_offset_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const sourceRoots = ['shared', 'feature', 'entry']
const helperRelative = path.join('shared', 'src', 'main', 'ets', 'utils', 'ScrollUserInput.ets')
const files = []

function collect(dir) {
  if (!fs.existsSync(dir)) return
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === 'third_party') continue
    const absolute = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      collect(absolute)
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      files.push(absolute)
    }
  }
}

for (const sourceRoot of sourceRoots) collect(path.join(repo, sourceRoot))

let failures = 0
function fail(message) {
  console.error(`[FAIL] ${message}`)
  failures += 1
}

const helper = path.join(repo, helperRelative)
if (!fs.existsSync(helper)) {
  fail(`missing shared offset helper: ${helperRelative}`)
}

for (const file of files) {
  const relative = path.relative(repo, file)
  const text = fs.readFileSync(file, 'utf8')
  const lines = text.split(/\r?\n/)
  lines.forEach((line, index) => {
    if (/\.currentOffset\(\)\s*\./.test(line) && relative !== helperRelative) {
      fail(`${relative}:${index + 1} reads currentOffset() through a property directly`)
    }
    if (/(?:getImageInfo|getRectangle)\(\)\s*\./.test(line)) {
      fail(`${relative}:${index + 1} chains a property directly from a nullable-result API`)
    }
  })
}

if (fs.existsSync(helper)) {
  const helperText = fs.readFileSync(helper, 'utf8')
  if (!/export function currentScrollOffsetY\(scroller: Scroller\): number/.test(helperText) ||
      !/currentOffset\(\)\?\.yOffset \?\? 0/.test(helperText)) {
    fail('Y offset helper does not preserve the undefined-to-zero guard')
  }
  if (!/export function currentScrollOffsetX\(scroller: Scroller\): number/.test(helperText) ||
      !/currentOffset\(\)\?\.xOffset \?\? 0/.test(helperText)) {
    fail('X offset helper does not preserve the undefined-to-zero guard')
  }
}

if (failures === 0) {
  console.log(`OK scroll offset contract passed (${files.length} ArkTS files scanned)`)
  process.exit(0)
}
console.error(`[FAIL] scroll offset contract: ${failures} failure(s)`)
process.exit(1)
