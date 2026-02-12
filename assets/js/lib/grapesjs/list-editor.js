/**
 * GrapesJS List Editor Plugin
 *
 * Provides proper Enter key behavior for lists in the Rich Text Editor.
 * Features:
 * - Enter in middle of bullet: splits text and creates new list item
 * - Enter at end of bullet: creates new empty list item
 * - Enter on empty bullet: exits the list
 * - Works for both ordered (<ol>) and unordered (<ul>) lists
 *
 * Usage:
 *   import { initListEditor } from './lib/grapesjs/list-editor'
 *   initListEditor(editor)
 */
import { classifyListEnter } from './list-editor-logic.mjs'

/**
 * Initialize the list editor plugin for a GrapesJS instance
 * @param {Object} editor - GrapesJS editor instance
 */
export function initListEditor(editor) {
  /**
   * Persist the currently edited RTE DOM back into GrapesJS component model.
   * Use the same sync path GrapesJS text views use internally.
   */
  function syncRteToModel(view) {
    if (!view) return

    if (typeof view.syncContent === 'function') {
      view.syncContent({ force: true })
      return
    }

    if (view.model && typeof view.model.trigger === 'function') {
      view.model.trigger('sync:content', { force: true })
    }
  }

  /**
   * Emit an input event so GrapesJS text view listeners can react to edits.
   */
  function emitInputEvent(doc, el) {
    if (!el) return

    const win = doc.defaultView || window
    let event

    if (typeof win.InputEvent === 'function') {
      event = new win.InputEvent('input', { bubbles: true, inputType: 'insertParagraph' })
    } else {
      event = new win.Event('input', { bubbles: true })
    }

    el.dispatchEvent(event)
  }

  /**
   * Check whether there is non-empty content after the current cursor.
   */
  function hasContentAfterCursor(range, li) {
    const testRange = range.cloneRange()
    testRange.selectNodeContents(li)
    testRange.setStart(range.endContainer, range.endOffset)

    const fragment = testRange.cloneContents()
    if (fragment.textContent.trim() !== '') return true

    const nodes = fragment.childNodes || []
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (node.nodeType === Node.ELEMENT_NODE && node.tagName !== 'BR') {
        return true
      }
    }

    return false
  }

  /**
   * Find the closest ancestor list item (<li>) from a node
   */
  function findListItem(node) {
    while (node && node.nodeType !== Node.DOCUMENT_NODE) {
      if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'LI') {
        return node
      }
      node = node.parentNode
    }
    return null
  }

  /**
   * Find the closest ancestor list (<ul> or <ol>) from a node
   */
  function findList(node) {
    while (node && node.nodeType !== Node.DOCUMENT_NODE) {
      if (node.nodeType === Node.ELEMENT_NODE && (node.tagName === 'UL' || node.tagName === 'OL')) {
        return node
      }
      node = node.parentNode
    }
    return null
  }

  /**
   * Check if a list item is empty (contains only whitespace or <br>)
   */
  function isListItemEmpty(li) {
    const text = li.textContent.trim()
    if (text !== '') return false

    // Check if it only contains <br> elements or is truly empty
    const children = li.childNodes
    for (let i = 0; i < children.length; i++) {
      const child = children[i]
      if (child.nodeType === Node.TEXT_NODE && child.textContent.trim() !== '') {
        return false
      }
      if (child.nodeType === Node.ELEMENT_NODE && child.tagName !== 'BR') {
        // Has non-br element, check if it has content
        if (child.textContent.trim() !== '') {
          return false
        }
      }
    }
    return true
  }

  /**
   * Exit the list by replacing the current empty <li> with a <p> or <br>
   */
  function exitList(doc, li, list) {
    // Create a paragraph to place after the list
    const p = doc.createElement('p')
    p.innerHTML = '<br>'

    // If this is the only item, remove the entire list
    if (list.children.length === 1) {
      list.parentNode.replaceChild(p, list)
    } else {
      // Remove the empty li and insert paragraph after the list
      li.remove()
      list.parentNode.insertBefore(p, list.nextSibling)
    }

    // Place cursor in the new paragraph
    const sel = doc.getSelection()
    const newRange = doc.createRange()
    newRange.setStart(p, 0)
    newRange.collapse(true)
    sel.removeAllRanges()
    sel.addRange(newRange)
  }

  /**
   * Create a new list item and split content at cursor position.
   */
  function createNewListItem(doc, range, li) {
    const sel = doc.getSelection()

    // If a selection exists, delete it before splitting.
    if (!range.collapsed) {
      range.deleteContents()
      range.collapse(true)
    }

    // Copy li-level styling/classes but never duplicate IDs.
    const newLi = li.cloneNode(false)
    newLi.removeAttribute('id')

    // Move all content after cursor into the new li.
    const rangeToEnd = doc.createRange()
    rangeToEnd.setStart(range.endContainer, range.endOffset)
    rangeToEnd.setEndAfter(li.lastChild || li)
    const extractedContent = rangeToEnd.extractContents()

    if (extractedContent.childNodes.length > 0) {
      newLi.appendChild(extractedContent)
    } else {
      newLi.innerHTML = '<br>'
    }

    // Keep source li editable if it became empty.
    if (!li.textContent.trim() && li.childNodes.length === 0) {
      li.innerHTML = '<br>'
    }

    li.parentNode.insertBefore(newLi, li.nextSibling)

    // Place cursor at beginning of new li.
    const newRange = doc.createRange()
    if (newLi.firstChild && newLi.firstChild.nodeType === Node.TEXT_NODE) {
      newRange.setStart(newLi.firstChild, 0)
    } else {
      newRange.setStart(newLi, 0)
    }
    newRange.collapse(true)
    sel.removeAllRanges()
    sel.addRange(newRange)
  }

  /**
   * Handle Enter key press in the RTE
   */
  function handleEnterInList(e, rte) {
    const doc = rte.doc || document
    const sel = doc.getSelection()

    if (!sel || sel.rangeCount === 0) return false

    const range = sel.getRangeAt(0)

    // Check if we're inside a list item
    const li = findListItem(range.commonAncestorContainer)
    if (!li) return false

    const list = findList(li)
    if (!list) return false

    // Prevent default behavior and fully own Enter handling inside lists.
    e.preventDefault()
    e.stopPropagation()

    const action = classifyListEnter({
      isEmptyItem: isListItemEmpty(li),
      hasContentAfterCursor: hasContentAfterCursor(range, li)
    })

    if (action === 'exit-list') {
      const supportsOutdent =
        typeof doc.queryCommandSupported !== 'function' || doc.queryCommandSupported('outdent')

      if (supportsOutdent) {
        doc.execCommand('outdent', false, null)
      } else {
        exitList(doc, li, list)
      }
    } else {
      createNewListItem(doc, range, li)
    }

    emitInputEvent(doc, rte.el)
    return true
  }

  // Hook into RTE enable event
  editor.on('rte:enable', (view, rte) => {
    const doc = rte.doc || document

    const handleKeydown = (e) => {
      if (e.defaultPrevented) return
      if (e.isComposing || e.keyCode === 229) return
      if (e.metaKey || e.ctrlKey || e.altKey) return

      // Only handle Enter key (not Shift+Enter which should be line break)
      if (e.key === 'Enter' && !e.shiftKey) {
        const handled = handleEnterInList(e, rte)
        if (handled) {
          rte._listEditorDirty = true
        }
      }
    }

    // Add listener with capture phase to intercept before GrapesJS default handling
    doc.addEventListener('keydown', handleKeydown, true)

    // Store handler for cleanup
    rte._listEditorKeyHandler = handleKeydown
  })

  // Cleanup keyboard handler when RTE is disabled
  editor.on('rte:disable', (view, rte) => {
    if (rte && rte._listEditorDirty) {
      syncRteToModel(view)
      editor.trigger('component:update')
      delete rte._listEditorDirty
    }

    if (rte && rte._listEditorKeyHandler) {
      const doc = rte.doc || document
      doc.removeEventListener('keydown', rte._listEditorKeyHandler, true)
      delete rte._listEditorKeyHandler
    }
  })

  // Cleanup on editor destroy
  editor.on('destroy', () => {
    // No persistent DOM elements to clean up (unlike link-editor)
  })
}
