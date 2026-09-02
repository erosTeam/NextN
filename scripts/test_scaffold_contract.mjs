#!/usr/bin/env node

import { readFile, readdir } from 'node:fs/promises'

const ROOT = new URL('../', import.meta.url)

const contracts = [
  {
    file: 'shared/src/main/ets/components/PullRefreshGridScaffold.ets',
    required: ['refreshEnabled', 'onDidScroll', 'onWillScroll', 'onScrollIndex', 'onReachEnd',
      'PinchGesture', 'onScrollEnableChange'],
  },
  {
    file: 'shared/src/main/ets/components/PullRefreshListScaffold.ets',
    required: ['refreshEnabled', 'onDidScroll', 'onWillScroll', 'onScrollIndex', 'onReachEnd',
      'onScrollEnableChange'],
    forbidden: ['PinchGesture'],
  },
  {
    file: 'shared/src/main/ets/components/PullRefreshWaterFlowScaffold.ets',
    required: ['refreshEnabled', 'onDidScroll', 'onWillScroll', 'onScrollIndex', 'onReachEnd',
      'PinchGesture', 'nearEndThreshold', 'onScrollEnableChange'],
  },
  {
    file: 'shared/src/main/ets/components/SecondaryGridScaffold.ets',
    required: ['onDidScroll', 'onWillScroll', 'onScrollIndex', 'onReachEnd', 'PinchGesture'],
  },
  {
    file: 'shared/src/main/ets/components/SecondaryListScaffold.ets',
    required: ['onDidScroll', 'onWillScroll', 'onScrollIndex', 'onReachEnd'],
    forbidden: ['PinchGesture'],
  },
  {
    file: 'shared/src/main/ets/components/SecondaryWaterFlowScaffold.ets',
    required: ['onDidScroll', 'onWillScroll', 'onScrollIndex', 'onReachEnd', 'PinchGesture',
      'nearEndThreshold'],
  },
]

for (const contract of contracts) {
  const source = await readFile(new URL(contract.file, ROOT), 'utf8')
  for (const token of contract.required) {
    if (!source.includes(token)) {
      throw new Error(`${contract.file}: missing scaffold contract token ${token}`)
    }
  }
  for (const token of contract.forbidden ?? []) {
    if (source.includes(token)) {
      throw new Error(`${contract.file}: unexpected layout capability ${token}`)
    }
  }
}

const pullRefresh = await readFile(new URL('shared/src/main/ets/components/PullRefresh.ets', ROOT), 'utf8')
for (const token of ['refreshEnabled', 'haptic.effect.soft', 'onScrollEnableChange', 'bottomRefreshState']) {
  if (!pullRefresh.includes(token)) {
    throw new Error(`shared/src/main/ets/components/PullRefresh.ets: missing ${token}`)
  }
}

const sheetOptions = await readFile(new URL('shared/src/main/ets/components/AppSheetOptions.ets', ROOT), 'utf8')
for (const token of ['options.systemMaterial = AppPrompt.modalSystemMaterial()',
  'options.scrollSizeMode = ScrollSizeMode.CONTINUOUS', 'options.enableFloatingDragBar = true']) {
  if (!sheetOptions.includes(token)) {
    throw new Error(`shared/src/main/ets/components/AppSheetOptions.ets: missing ${token}`)
  }
}

async function etsFiles(relativeDir) {
  const directory = new URL(`${relativeDir}/`, ROOT)
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const relative = `${relativeDir}/${entry.name}`
    if (entry.isDirectory()) {
      files.push(...await etsFiles(relative))
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      files.push(relative)
    }
  }
  return files
}

for (const file of [...await etsFiles('shared/src/main/ets'), ...await etsFiles('feature'),
  ...await etsFiles('entry/src/main/ets')]) {
  const source = await readFile(new URL(file, ROOT), 'utf8')
  let offset = source.indexOf('.bindSheet(')
  while (offset >= 0) {
    if (!source.substring(offset, offset + 1800).includes('appSheetOptions({')) {
      throw new Error(`${file}: bindSheet must use shared appSheetOptions for API 26 material`)
    }
    offset = source.indexOf('.bindSheet(', offset + 11)
  }
}

console.log(`OK scaffold contract passed (${contracts.length + 2} shared contracts scanned)`)
