#!/usr/bin/env node

import { readFile } from 'node:fs/promises'

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

console.log(`OK scaffold contract passed (${contracts.length + 1} shared components scanned)`)
