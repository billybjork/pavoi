/**
 * ProductSetsUndoKeyboard Hook
 *
 * Handles Cmd/Ctrl+Z keyboard shortcut for undo functionality on the Product Sets page.
 * Only triggers when:
 * - A product set is expanded
 * - There are undo actions available
 * - User is not typing in an input field
 * - No modal is currently open
 */

const ProductSetsUndoKeyboard = {
  mounted() {
    this.handleKeydown = this.handleKeydown.bind(this)
    window.addEventListener('keydown', this.handleKeydown)
  },

  destroyed() {
    window.removeEventListener('keydown', this.handleKeydown)
  },

  handleKeydown(event) {
    // Check for Cmd+Z (Mac) or Ctrl+Z (Windows/Linux)
    const isUndo = (event.metaKey || event.ctrlKey) && event.key === 'z' && !event.shiftKey

    if (!isUndo) return

    // Don't trigger if typing in input/textarea
    const activeElement = document.activeElement
    const isTyping = activeElement && (
      activeElement.tagName === 'INPUT' ||
      activeElement.tagName === 'TEXTAREA' ||
      activeElement.contentEditable === 'true'
    )

    if (isTyping) return

    // Don't trigger if a modal is open
    const modalOpen = document.querySelector('.modal__backdrop:not([style*="display: none"])')
    if (modalOpen) return

    // Check if we have an expanded product set with undo actions
    // Look for the undo button directly - if it exists, we can undo
    const undoBtn = document.querySelector('.product-set-card__undo-btn')
    if (!undoBtn) return

    const expandedProductSetId = undoBtn.getAttribute('phx-value-product-set-id')
    if (!expandedProductSetId) return

    // Prevent default browser undo behavior
    event.preventDefault()

    // Push the undo event
    this.pushEvent('undo_product_set_action', {
      'product-set-id': expandedProductSetId
    })
  }
}

export default ProductSetsUndoKeyboard
