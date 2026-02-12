/**
 * Classify Enter behavior inside a list item.
 *
 * Returns:
 * - "exit-list": Enter on an empty bullet
 * - "split-item": Enter in the middle of bullet text/content
 * - "new-empty-item": Enter at the end of a bullet
 */
export function classifyListEnter({ isEmptyItem, hasContentAfterCursor }) {
  if (isEmptyItem) return 'exit-list'
  return hasContentAfterCursor ? 'split-item' : 'new-empty-item'
}

