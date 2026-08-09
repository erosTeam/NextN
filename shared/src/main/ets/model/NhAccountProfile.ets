/**
 * The small, display-safe account identity extracted from ErosN's current
 * first-party HTML semantics. It intentionally excludes browser state,
 * cookies, tokens, HTML, quotas, and any account mutation capability.
 */
export class NhAccountProfile {
  username: string = ''
  userUrl: string = ''
  userId: string = ''
  avatarUrl: string = ''

  hasIdentity(): boolean {
    return this.username.length > 0 && this.userUrl.length > 0 && this.userId.length > 0
  }

  copy(): NhAccountProfile {
    const result: NhAccountProfile = new NhAccountProfile()
    result.username = this.username
    result.userUrl = this.userUrl
    result.userId = this.userId
    result.avatarUrl = this.avatarUrl
    return result
  }
}
