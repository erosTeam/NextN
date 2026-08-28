import { taskpool } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import { effectKit } from '@kit.ArkGraphics2D'
import { AxiosBinaryResponse, AxiosHttpClient } from '../network/AxiosHttpClient'

const MAX_COVER_COLOR_MEMORY_ENTRIES: number = 512
const MAX_COVER_COLOR_CONCURRENCY: number = 2
const MAX_COVER_COLOR_PENDING: number = 32

/**
 * Direct NextE port: extract a public thumbnail's dominant color off the UI
 * thread. Failures resolve to zero so the cover itself remains independent of
 * this decorative letterbox layer.
 */
@Concurrent
async function extractCoverColor(url: string): Promise<number> {
  const decodeSize: number = 32
  const timeoutMs: number = 15000
  let source: image.ImageSource | undefined = undefined
  let pixelMap: image.PixelMap | undefined = undefined
  try {
    const headers: Record<string, string> = {}
    headers['Accept'] = 'image/*'
    const response: AxiosBinaryResponse = await AxiosHttpClient.requestBinary(
      url,
      headers,
      16 * 1024 * 1024,
      timeoutMs,
      timeoutMs,
      true,
    )
    if (response.statusCode !== 200 || response.bytes === null) {
      return 0
    }
    source = image.createImageSource(response.bytes)
    const options: image.DecodingOptions = {
      editable: false,
      desiredSize: { width: decodeSize, height: decodeSize },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
    }
    pixelMap = await source.createPixelMap(options)
    const picker: effectKit.ColorPicker = await effectKit.createColorPicker(pixelMap)
    const color: effectKit.Color = picker.getMainColorSync()
    return ((0xff << 24) | (color.red << 16) | (color.green << 8) | color.blue) >>> 0
  } catch (_error) {
    return 0
  } finally {
    if (pixelMap !== undefined) {
      await pixelMap.release()
    }
    if (source !== undefined) {
      await source.release()
    }
  }
}

class CoverColorMemoryCache {
  private entries: Map<string, number> = new Map()

  get(url: string): number | undefined {
    const color: number | undefined = this.entries.get(url)
    if (color === undefined) {
      return undefined
    }
    this.entries.delete(url)
    this.entries.set(url, color)
    return color
  }

  put(url: string, color: number): void {
    if (url.length === 0) {
      return
    }
    this.entries.delete(url)
    this.entries.set(url, color)
    while (this.entries.size > MAX_COVER_COLOR_MEMORY_ENTRIES) {
      let hasOldest: boolean = false
      let oldest: string = ''
      this.entries.forEach((_color: number, candidate: string): void => {
        if (!hasOldest) {
          hasOldest = true
          oldest = candidate
        }
      })
      if (!hasOldest) {
        return
      }
      this.entries.delete(oldest)
    }
  }
}

class CoverColorTask {
  key: string = ''
  started: boolean = false
  active: boolean = false
  private startAction: () => void = () => {}
  private cancelAction: () => void = () => {}

  constructor(key: string, startAction: () => void, cancelAction: () => void) {
    this.key = key
    this.startAction = startAction
    this.cancelAction = cancelAction
  }

  start(): void {
    this.startAction()
  }

  cancel(): void {
    this.cancelAction()
  }
}

class CoverColorQueue {
  private queue: CoverColorTask[] = []
  private running: number = 0

  schedule(task: CoverColorTask): void {
    if (task.started) {
      return
    }
    this.queue.unshift(task)
    while (this.queue.length > MAX_COVER_COLOR_PENDING) {
      const stale: CoverColorTask | undefined = this.queue.pop()
      if (stale !== undefined && !stale.started) {
        stale.cancel()
      }
    }
    this.drain()
  }

  complete(task: CoverColorTask): void {
    if (!task.active) {
      return
    }
    task.active = false
    if (this.running > 0) {
      this.running--
    }
    this.drain()
  }

  private drain(): void {
    while (this.running < MAX_COVER_COLOR_CONCURRENCY && this.queue.length > 0) {
      const next: CoverColorTask | undefined = this.queue.shift()
      if (next === undefined || next.started) {
        continue
      }
      next.started = true
      next.active = true
      this.running++
      next.start()
    }
  }
}

class CoverColorNetworkTask {
  private readonly work: () => Promise<number>
  private readonly queue: CoverColorQueue
  private completion: Promise<number>
  private resolveCompletion: (color: number) => void = (_color: number): void => {}
  private settled: boolean = false
  task: CoverColorTask

  constructor(key: string, work: () => Promise<number>, queue: CoverColorQueue) {
    this.work = work
    this.queue = queue
    this.task = new CoverColorTask(key, (): void => this.start(), (): void => this.cancel())
    this.completion = new Promise<number>((resolve: (color: number) => void): void => {
      this.resolveCompletion = resolve
    })
  }

  schedule(): Promise<number> {
    this.queue.schedule(this.task)
    return this.completion
  }

  private start(): void {
    try {
      this.work().then(
        (color: number): void => {
          this.settle(color)
          this.queue.complete(this.task)
        },
        (): void => {
          this.settle(0)
          this.queue.complete(this.task)
        },
      )
    } catch (_error) {
      this.settle(0)
      this.queue.complete(this.task)
    }
  }

  private cancel(): void {
    this.settle(0)
  }

  private settle(color: number): void {
    if (!this.settled) {
      this.settled = true
      this.resolveCompletion(color)
    }
  }
}

/** Bounded NextE-style dominant-color cache and in-flight deduplication. */
export class CoverColorService {
  private static instance: CoverColorService | null = null
  private cache: CoverColorMemoryCache = new CoverColorMemoryCache()
  private inFlight: Map<string, Promise<number>> = new Map()
  private queue: CoverColorQueue = new CoverColorQueue()

  static getInstance(): CoverColorService {
    if (CoverColorService.instance === null) {
      CoverColorService.instance = new CoverColorService()
    }
    return CoverColorService.instance
  }

  cached(url: string): number {
    const hit: number | undefined = this.cache.get(url)
    return hit === undefined ? 0 : hit
  }

  resolve(url: string): Promise<number> {
    if (url.length === 0) {
      return Promise.resolve(0)
    }
    const hit: number | undefined = this.cache.get(url)
    if (hit !== undefined) {
      return Promise.resolve(hit)
    }
    const pending: Promise<number> | undefined = this.inFlight.get(url)
    if (pending !== undefined) {
      return pending
    }
    const task: CoverColorNetworkTask = new CoverColorNetworkTask(
      url,
      (): Promise<number> => this.extract(url),
      this.queue,
    )
    const completion: Promise<number> = task.schedule()
    this.inFlight.set(url, completion)
    completion.then((): void => {
      if (this.inFlight.get(url) === completion) {
        this.inFlight.delete(url)
      }
    })
    return completion
  }

  private async extract(url: string): Promise<number> {
    let color: number = 0
    try {
      color = await taskpool.execute<[string], number>(extractCoverColor, url)
    } catch (_error) {
      color = 0
    }
    this.cache.put(url, color)
    return color
  }
}
