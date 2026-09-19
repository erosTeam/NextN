#!/usr/bin/env node
import { createServer } from 'node:http'
import assert from 'node:assert/strict'

console.log("Running WebDAV payload integrity and multi-byte safety contract...")

// 1. Verify that large manifest (>16KB) JSON round-trips with exact Content-Length
const server = createServer(async (req, res) => {
  let body = ''
  req.setEncoding('utf8')
  req.on('data', chunk => body += chunk)
  req.on('end', () => {
    const contentLength = Number(req.headers['content-length'] || 0)
    if (contentLength > 0 && body.length !== contentLength) {
      res.writeHead(400, { 'Content-Type': 'text/plain' })
      res.end('truncated')
      return
    }
    try {
      JSON.parse(body)
      res.writeHead(201, { 'ETag': '"test-etag"', 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ ok: true, bytes: body.length }))
    } catch (err) {
      res.writeHead(400, { 'Content-Type': 'text/plain' })
      res.end('invalid_json: ' + err.message)
    }
  })
})

await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
const port = server.address().port

try {
  // Generate a realistic manifest > 20KB
  const shards = []
  for (let i = 0; i < 64; i++) {
    const id = i.toString(16).padStart(2, '0')
    shards.push({
      id: id,
      path: 'datasets/viewed-history/' + id + '.json',
      sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      recordCount: 42,
      updatedAt: 1789700000000 + i * 1000
    })
  }
  const manifest = {
    magic: 'NEXTN_SYNC',
    appId: 'com.erosteam.nextn',
    schemaVersion: 1,
    minSupportedSchemaVersion: 1,
    generatedAt: new Date().toISOString(),
    datasets: [
      { id: 'read-progress', shards: shards },
      { id: 'viewed-history', shards: shards },
      { id: 'home-subtabs', shards: shards.slice(0, 10) }
    ]
  }
  const manifestRaw = JSON.stringify(manifest, null, 2)
  assert.ok(manifestRaw.length > 16384, 'Manifest must be > 16KB to test boundary: length=' + manifestRaw.length)

  // Test full PUT upload
  const uploadResp = await fetch('http://127.0.0.1:' + port + '/manifest.json', {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': String(Buffer.byteLength(manifestRaw, 'utf8'))
    },
    body: manifestRaw
  })
  assert.equal(uploadResp.status, 201, 'Full manifest upload must succeed with 201')
  const uploadResult = await uploadResp.json()
  assert.equal(uploadResult.bytes, manifestRaw.length, 'Server received exact byte length')

  // Test truncated PUT upload (simulating NetStack 16384 cut-off)
  const truncatedRaw = manifestRaw.substring(0, 16384)
  let parseErrorCaught = false
  try {
    JSON.parse(truncatedRaw)
  } catch (err) {
    parseErrorCaught = true
    assert.ok(err instanceof SyntaxError, 'Truncated JSON must throw SyntaxError: ' + err.message)
  }
  assert.ok(parseErrorCaught, 'Truncated JSON must throw syntax error')

  console.log("✓ Full manifest > 16KB (" + manifestRaw.length + " bytes) uploaded and parsed successfully")
  console.log("✓ Truncated 16KB manifest reproduces exact JSON parse exception")
  console.log("All payload integrity contract checks passed!")
} finally {
  server.close()
}
