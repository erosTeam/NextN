const test=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs')
const path=require('node:path')
const Module=require('node:module')
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source=path.resolve(__dirname,'../feature/reader/src/main/ets/lab/NextNReaderImageSaveDownload.ets')
function setup(overrides={}) {
  const calls={closed:0,open:[],request:[]}
  const io={OpenMode:{READ_WRITE:1,CREATE:2,TRUNC:4},openSync:(p)=>{calls.open.push(p);return {fd:7}},
    writeSync:(_,data)=>data.byteLength,closeSync:()=>calls.closed++,...overrides.io}
  const stream={get:async(...args)=>{calls.request=args;const accepted=args[5](new ArrayBuffer(4));return {
    statusCode:200,receivedBytes:4,limitExceeded:false,sinkRejected:!accepted,cancelled:false,...overrides.response
  }},...overrides.stream}
  const mod=new Module(source,module)
  mod.require=name=>name==='@kit.CoreFileKit'?{fileIo:io}:name==='shared'?{StreamingHttpClient:stream}:require(name)
  mod._compile(ts.transpileModule(fs.readFileSync(source,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,source)
  return {download:mod.exports.NextNReaderImageSaveDownload.download,calls}
}
test('writes exact URI to exact owned path with bounded existing stream policy',async()=>{
  const {download,calls}=setup();await download('https://host/image?captured=1','/owned/save.tmp')
  assert.deepEqual(calls.open,['/owned/save.tmp']);assert.equal(calls.request[0],'https://host/image?captured=1')
  assert.deepEqual(calls.request.slice(1,5),[{'Accept':'image/*','User-Agent':'NextN/1.0.0'},10000,30000,512*1024*1024])
  assert.equal(calls.closed,1)
})
test('rejects partial, empty, limited, cancelled, inconsistent and error responses; closes each FD',async()=>{
  for(const response of [{statusCode:206},{statusCode:404},{receivedBytes:0},{receivedBytes:3},{limitExceeded:true},{cancelled:true},{sinkRejected:true}]) {
    const {download,calls}=setup({response});await assert.rejects(download('https://h/i','/owned/x'));assert.equal(calls.closed,1)
  }
})
test('short writes, write exceptions and stream errors reject and close',async()=>{
  for(const overrides of [{io:{writeSync:()=>2}},{io:{writeSync:()=>{throw Error('disk')}}},{stream:{get:async()=>{throw Error('network')}}}]) {
    const {download,calls}=setup(overrides);await assert.rejects(download('https://h/i','/owned/x'));assert.equal(calls.closed,1)
  }
})
test('invalid scheme is rejected before opening a destination',async()=>{
  const {download,calls}=setup();await assert.rejects(download('http://h/i','/owned/x'));assert.deepEqual(calls.open,[])
})
