import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

const MAX_CHALLENGE_CHARS: number = 256
const MAX_DIFFICULTY_BITS: number = 24
const DEFAULT_MAX_ATTEMPTS: number = 3000000
const YIELD_INTERVAL: number = 2048

/** Shared solver for every official NH API v2 proof-of-work action. */
export class NhApiProofOfWork {
  static async solve(
    challenge: string,
    difficulty: number,
    maxAttempts: number = DEFAULT_MAX_ATTEMPTS,
  ): Promise<string> {
    if (!/^[0-9a-fA-F]{16,256}$/.test(challenge) ||
      challenge.length > MAX_CHALLENGE_CHARS ||
      !Number.isSafeInteger(difficulty) || difficulty <= 0 || difficulty > MAX_DIFFICULTY_BITS ||
      !Number.isSafeInteger(maxAttempts) || maxAttempts <= 0 || maxAttempts > DEFAULT_MAX_ATTEMPTS) {
      throw new Error('NH API returned an unsupported proof-of-work challenge')
    }
    for (let attempt: number = 0; attempt < maxAttempts; attempt++) {
      const nonce: string = attempt.toString()
      if (NhApiProofOfWork.leadingZeroBits(
        NhApiProofOfWork.sha256(`${challenge}${nonce}`),
      ) >= difficulty) {
        return nonce
      }
      if ((attempt + 1) % YIELD_INTERVAL === 0) {
        await new Promise<void>((resolve: () => void): void => {
          setTimeout(resolve, 0)
        })
      }
    }
    throw new Error('NH API proof-of-work could not be completed safely')
  }

  private static sha256(value: string): Uint8Array {
    const md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: new util.TextEncoder().encodeInto(value) })
    return md.digestSync().data
  }

  private static leadingZeroBits(bytes: Uint8Array): number {
    let count: number = 0
    for (let index: number = 0; index < bytes.length; index++) {
      const value: number = bytes[index]
      if (value === 0) {
        count += 8
        continue
      }
      for (let bit: number = 7; bit >= 0; bit--) {
        if ((value & (1 << bit)) !== 0) {
          return count
        }
        count += 1
      }
    }
    return count
  }
}
