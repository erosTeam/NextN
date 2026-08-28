#!/usr/bin/env node

import assert from 'node:assert/strict'
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { summarizeArtifact } from './summarize_nextn_account_observation.mjs'

const TARGET = '192.168.50.237:12345'
const SECRET_MARKERS = [
  'fixture-account@example.invalid',
  'access_token=fixture-access',
  'refresh_token=fixture-refresh',
  'https://fixture.invalid/private',
  'private-gallery-title',
]

function windowWith(children) {
  return {
    attributes: {},
    children: [{
      attributes: {
        hostWindowId: '1',
        focused: 'true',
        visible: 'true',
        bundleName: 'com.erosteam.nextn',
        abilityName: 'EntryAbility',
      },
      children,
    }],
  }
}

function verificationSnackBar() {
  return {
    attributes: { type: 'Dialog', clickable: 'true', visible: 'true' },
    children: [{
      attributes: { type: 'Row', visible: 'true' },
      children: [{
        attributes: { type: 'Column', visible: 'true' },
        children: [
          { attributes: { type: 'Text', text: 'Verification needed', visible: 'true' }, children: [] },
          {
            attributes: {
              type: 'Text',
              text: 'Your sign-in expired. Verify it again to continue using account features.',
              visible: 'true',
            },
            children: [],
          },
        ],
      }, {
        attributes: { type: 'Row', visible: 'true' },
        children: [{
          attributes: { type: 'Column', clickable: 'true', visible: 'true' },
          children: [{
            attributes: { type: 'Button', visible: 'true' },
            children: [{
              attributes: { type: 'Text', text: 'Verify again', visible: 'true' },
              children: [],
            }],
          }],
        }, {
          attributes: { type: 'Column', clickable: 'true', visible: 'true' },
          children: [{
            attributes: { type: 'Button', visible: 'true' },
            children: [{ attributes: { type: 'SymbolGlyph', visible: 'true' }, children: [] }],
          }],
        }],
      }],
    }],
  }
}

async function writeJson(path, value) {
  await writeFile(path, `${JSON.stringify(value)}\n`, { encoding: 'utf8', mode: 0o600 })
}

const directory = await mkdtemp(join(tmpdir(), 'nextn-safe-summary-test-'))
try {
  await mkdir(join(directory, 'diagnostics'), { mode: 0o700 })
  await writeJson(join(directory, 'run-metadata.json'), {
    status: 'completed',
    target: TARGET,
    commands: [
      { exitCode: 0, stdout: SECRET_MARKERS[1] },
      { exitCode: 0, stderr: SECRET_MARKERS[2] },
    ],
  })
  await writeJson(join(directory, 'protocol-manifest.json'), {
    target: TARGET,
    authorizedTarget: TARGET,
    context: { notes: SECRET_MARKERS[3] },
  })
  await writeJson(join(directory, 'favorites.json'), windowWith([{
    attributes: { id: 'nextn-favorites-root', visible: 'true' },
    children: [{
      attributes: { type: 'Grid', text: SECRET_MARKERS[4], visible: 'true' },
      children: [],
    }],
  }, verificationSnackBar()]))
  await writeJson(join(directory, 'account.json'), windowWith([{
    attributes: { id: 'nextn-account-list-root', visible: 'true' },
    children: [{
      attributes: {
        id: 'nextn-account-saved-row',
        text: SECRET_MARKERS[0],
        visible: 'true',
      },
      children: [{
        attributes: { type: 'Radio', checked: 'true', visible: 'true' },
        children: [],
      }],
    }],
  }]))
  await writeFile(
    join(directory, 'diagnostics', 'nextn-log-20260828-075500.txt'),
    [
      ...SECRET_MARKERS,
      'session_start',
      'account_restore_ready',
      'account_restore_verification_required_after_browser_refresh_failure',
      'account_auth_expiry_shape phase=restore;access=lt_1h;refresh=ge_7d',
      'account_auth_expiry_shape phase=refresh_checkpoint;access=lt_24h;refresh=lt_7d',
      'account_response_cookie_stored',
      'account_response_auth_cookie_applied',
      'favorites_request_success',
    ].join('\n'),
    { encoding: 'utf8', mode: 0o600 },
  )

  const summary = await summarizeArtifact(directory)
  const output = JSON.stringify(summary)
  for (const secret of SECRET_MARKERS) {
    assert.equal(output.includes(secret), false)
  }
  assert.deepEqual(summary.artifact, {
    metadataTargetMatches237: true,
    manifestTargetMatches237: true,
    authorizedTargetMatches237: true,
    runCompleted: true,
    commandCount: 2,
  })
  assert.equal(summary.favorites.authenticatedLayoutCandidate, false)
  assert.deepEqual(summary.favorites.verificationSnackBar, {
    surfaceCount: 1,
    visible: true,
    reverifyActionVisible: true,
    closeActionVisible: true,
  })
  assert.equal(summary.account.authenticatedLayoutCandidate, true)
  assert.equal(summary.account.savedAccountCount, 1)
  assert.equal(summary.account.selectedSavedAccountCount, 1)
  assert.deepEqual(summary.account.verificationSnackBar, {
    surfaceCount: 0,
    visible: false,
    reverifyActionVisible: false,
    closeActionVisible: false,
  })
  assert.equal(summary.diagnostics.responseCookieStored, true)
  assert.equal(summary.diagnostics.responseAuthCookieApplied, true)
  assert.equal(summary.diagnostics.favoritesSuccess, true)
  assert.equal(summary.diagnostics.terminal401, false)
  assert.deepEqual(summary.diagnostics.authExpiryShapes, [
    { phase: 'restore', access: 'lt_1h', refresh: 'ge_7d' },
    { phase: 'refresh_checkpoint', access: 'lt_24h', refresh: 'lt_7d' },
  ])
  assert.deepEqual(summary.diagnostics.eventSequence, [
    'session_start',
    'account_restore_ready',
    'account_restore_verification_required_after_browser_refresh_failure',
    'account_auth_expiry_shape',
    'account_auth_expiry_shape',
    'account_response_cookie_stored',
    'account_response_auth_cookie_applied',
    'favorites_request_success',
  ])
  assert.equal(summary.diagnostics.stages.some(({ stage }) =>
    stage === 'account_restore_verification_required'), false)
  assert.deepEqual(
    summary.diagnostics.stages.map(({ stage }) => stage),
    [
      'session_start',
      'account_restore_ready',
      'account_restore_verification_required_after_browser_refresh_failure',
      'account_auth_expiry_shape',
      'account_response_cookie_stored',
      'account_response_auth_cookie_applied',
      'favorites_request_success',
    ],
  )

  await writeJson(join(directory, 'favorites.json'), windowWith([{
    attributes: { id: 'nextn-favorites-root', visible: 'true' },
    children: [{ attributes: { type: 'Grid', visible: 'true' }, children: [] }],
  }]))
  await writeJson(join(directory, 'account.json'), windowWith([{
    attributes: { id: 'nextn-account-list-root', visible: 'true' },
    children: [{
      attributes: { id: 'nextn-account-saved-row', visible: 'true' },
      children: [{
        attributes: { type: 'Radio', checked: 'true', visible: 'true' },
        children: [],
      }],
    }, {
      attributes: { type: 'Column', visible: 'true' },
      children: [
        { attributes: { type: 'Text', text: 'Verification needed', visible: 'true' }, children: [] },
        {
          attributes: {
            type: 'Text',
            text: 'Your sign-in expired. Verify it again to continue using account features.',
            visible: 'true',
          },
          children: [],
        },
        { attributes: { type: 'Text', text: 'Verify again', visible: 'true' }, children: [] },
      ],
    }],
  }]))
  const accountRowOnlySummary = await summarizeArtifact(directory)
  assert.equal(accountRowOnlySummary.account.verificationRequired, true)
  assert.deepEqual(accountRowOnlySummary.account.verificationSnackBar, {
    surfaceCount: 0,
    visible: false,
    reverifyActionVisible: false,
    closeActionVisible: false,
  })
  process.stdout.write('nextn account observation summary: pass\n')
} finally {
  await rm(directory, { recursive: true, force: true })
}
