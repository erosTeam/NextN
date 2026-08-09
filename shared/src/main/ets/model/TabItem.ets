/**
 * Stable descriptor shared by a retained source host and its pinned selector.
 * The key is never presentation text: it is the Swiper identity and the
 * settled selection value, while the label remains locale-resolved UI.
 */
export class TabItem {
  key: string = ''
  label: ResourceStr = ''
  count: number = -1
  selectedColor: string = ''

  constructor(key: string, label: ResourceStr, count: number = -1, selectedColor: string = '') {
    this.key = key
    this.label = label
    this.count = count
    this.selectedColor = selectedColor
  }
}
