/**
 * Public comment fields exposed by the anonymous v2 endpoint.
 *
 * This DTO deliberately excludes moderation state and every write
 * capability. Those concerns need their own authenticated/session design.
 */
export class NhComment {
  commentId: number = 0
  galleryId: number = 0
  postDate: number = 0
  body: string = ''
  posterId: number = 0
  posterName: string = ''
  posterAvatarUrl: string = ''
}
