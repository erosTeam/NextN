export type NextNReaderProgressWrite = (pageIndex: number) => Promise<void>

class NextNReaderProgressPending {
  id: number
  epoch: number
  promise: Promise<void>

  constructor(id: number, epoch: number, promise: Promise<void>) {
    this.id = id
    this.epoch = epoch
    this.promise = promise
  }
}

/**
 * Host-side lifecycle gate for shared-reader progress writes.
 *
 * `save` invokes the writer immediately so the production adapter can retain
 * NextN's live Detail-page publication. The writer remains responsible for
 * serializing its durable mutations; HistoryRepository already provides that
 * contract. This gate owns session identity, latest-failure retry and flush.
 */
export class NextNReaderProgressWriteGate {
  private epoch: number = 0
  private work: string = ''
  private writer: NextNReaderProgressWrite | null = null
  private accepting: boolean = false
  private lastPageIndex: number = -1
  private failedPageIndex: number = -1
  private failedMessage: string = ''
  private serial: number = 0
  private pending: NextNReaderProgressPending[] = []

  open(work: string, writer: NextNReaderProgressWrite): number {
    this.epoch += 1
    this.work = work
    this.writer = writer
    this.accepting = work.length > 0
    this.lastPageIndex = -1
    this.failedPageIndex = -1
    this.failedMessage = ''
    return this.epoch
  }

  save(epoch: number, work: string, pageIndex: number): boolean {
    return this.enqueue(epoch, work, pageIndex, false)
  }

  retryLatest(epoch: number): boolean {
    if (epoch !== this.epoch || this.failedPageIndex < 0) return false
    return this.enqueue(epoch, this.work, this.failedPageIndex, true)
  }

  seal(epoch: number): void {
    if (epoch === this.epoch) this.accepting = false
  }

  async flush(epoch: number): Promise<boolean> {
    while (epoch === this.epoch) {
      const operations = this.pending
        .filter((value: NextNReaderProgressPending): boolean => value.epoch === epoch)
        .map((value: NextNReaderProgressPending): Promise<void> => value.promise)
      if (operations.length === 0) break
      await Promise.all(operations)
    }
    return epoch === this.epoch && this.failedPageIndex < 0
  }

  failurePage(epoch: number): number {
    return epoch === this.epoch ? this.failedPageIndex : -1
  }

  failureMessage(epoch: number): string {
    return epoch === this.epoch ? this.failedMessage : ''
  }

  pendingCount(epoch: number): number {
    return this.pending.filter((value: NextNReaderProgressPending): boolean => value.epoch === epoch).length
  }

  private enqueue(epoch: number, work: string, pageIndex: number, retry: boolean): boolean {
    if (epoch !== this.epoch || !this.accepting || this.writer === null || work !== this.work ||
      !Number.isInteger(pageIndex) || pageIndex < 0 || (!retry && pageIndex === this.lastPageIndex) ||
      (retry && pageIndex !== this.failedPageIndex)) return false
    this.lastPageIndex = pageIndex
    this.failedPageIndex = -1
    this.failedMessage = ''
    let operation: Promise<void>
    try {
      operation = this.writer(pageIndex)
    } catch (error) {
      this.recordFailure(epoch, pageIndex, error as Error)
      return true
    }
    const id = ++this.serial
    const tracked = operation.then((): void => {}, (error: Error): void => {
      this.recordFailure(epoch, pageIndex, error)
    }).finally((): void => {
      this.pending = this.pending.filter((value: NextNReaderProgressPending): boolean => value.id !== id)
    })
    this.pending.push(new NextNReaderProgressPending(id, epoch, tracked))
    return true
  }

  private recordFailure(epoch: number, pageIndex: number, error: Error): void {
    if (epoch !== this.epoch || pageIndex !== this.lastPageIndex) return
    this.failedPageIndex = pageIndex
    this.failedMessage = error.message
  }
}
