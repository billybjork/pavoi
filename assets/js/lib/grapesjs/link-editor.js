/**
 * GrapesJS Link Editor Plugin
 *
 * Provides a clean popover UI for adding/editing links in the Rich Text Editor.
 * Features:
 * - Inline popover when clicking the link button or pressing Cmd+K
 * - URL input with validation
 * - "Open in new tab" toggle
 * - Edit/remove existing links
 *
 * Usage:
 *   import { initLinkEditor } from './lib/grapesjs/link-editor'
 *   initLinkEditor(editor)
 */

const POPOVER_ID = 'gjs-link-popover'

/**
 * Initialize the link editor plugin for a GrapesJS instance
 * @param {Object} editor - GrapesJS editor instance
 */
export function initLinkEditor(editor) {
  let popover = null
  let activeRte = null
  let savedSelection = null

  // Create the popover element (lazily, on first use)
  function getPopover() {
    if (popover) return popover

    popover = document.createElement('div')
    popover.id = POPOVER_ID
    popover.className = 'gjs-link-popover'
    popover.innerHTML = `
      <div class="gjs-link-popover-content">
        <input type="text" class="gjs-link-url-input" placeholder="Paste or type a URL..." />
        <div class="gjs-link-actions">
          <button type="button" class="gjs-link-btn gjs-link-btn-remove" style="display: none;">Remove</button>
          <button type="button" class="gjs-link-btn gjs-link-btn-apply">Apply</button>
        </div>
      </div>
    `
    document.body.appendChild(popover)

    // Event handlers
    const urlInput = popover.querySelector('.gjs-link-url-input')
    const applyBtn = popover.querySelector('.gjs-link-btn-apply')
    const removeBtn = popover.querySelector('.gjs-link-btn-remove')

    urlInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        applyLink()
      } else if (e.key === 'Escape') {
        e.preventDefault()
        hidePopover()
      }
    })

    applyBtn.addEventListener('click', applyLink)
    removeBtn.addEventListener('click', removeLink)

    // Close on click outside
    document.addEventListener('mousedown', (e) => {
      if (popover && popover.style.display !== 'none' && !popover.contains(e.target)) {
        hidePopover()
      }
    })

    return popover
  }

  function showPopover(rte, existingLink = null) {
    const pop = getPopover()
    activeRte = rte

    // Save selection before showing popover (input focus will clear it)
    savedSelection = saveSelection(rte)

    const urlInput = pop.querySelector('.gjs-link-url-input')
    const removeBtn = pop.querySelector('.gjs-link-btn-remove')
    const applyBtn = pop.querySelector('.gjs-link-btn-apply')

    // Pre-fill if editing existing link
    if (existingLink) {
      urlInput.value = existingLink.href || ''
      removeBtn.style.display = 'block'
      applyBtn.textContent = 'Update'
    } else {
      urlInput.value = ''
      removeBtn.style.display = 'none'
      applyBtn.textContent = 'Apply'
    }

    // Position near the RTE toolbar
    const toolbar = document.querySelector('.gjs-rte-toolbar')
    if (toolbar) {
      const rect = toolbar.getBoundingClientRect()
      pop.style.top = `${rect.bottom + 8}px`
      pop.style.left = `${rect.left}px`
    } else {
      // Fallback: center in viewport
      pop.style.top = '100px'
      pop.style.left = '50%'
      pop.style.transform = 'translateX(-50%)'
    }

    pop.style.display = 'block'

    // Focus input after a brief delay to ensure popover is visible
    setTimeout(() => urlInput.focus(), 10)
  }

  function hidePopover() {
    if (popover) {
      popover.style.display = 'none'
    }
    activeRte = null
    savedSelection = null
  }

  function saveSelection(rte) {
    // Get selection from the RTE's document (iframe)
    const doc = rte.doc || document
    const sel = doc.getSelection()
    if (sel && sel.rangeCount > 0) {
      return sel.getRangeAt(0).cloneRange()
    }
    return null
  }

  function restoreSelection(rte, range) {
    if (!range) return
    const doc = rte.doc || document
    const sel = doc.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  }

  function applyLink() {
    if (!activeRte || !savedSelection) {
      hidePopover()
      return
    }

    const urlInput = popover.querySelector('.gjs-link-url-input')

    let url = urlInput.value.trim()
    if (!url) {
      hidePopover()
      return
    }

    // Auto-add https:// if no protocol specified
    if (url && !url.match(/^[a-zA-Z]+:\/\//) && !url.startsWith('mailto:') && !url.startsWith('tel:')) {
      url = 'https://' + url
    }

    // Restore selection in the RTE
    restoreSelection(activeRte, savedSelection)

    // Get selection details
    const doc = activeRte.doc || document
    const sel = doc.getSelection()

    if (sel && sel.rangeCount > 0) {
      const range = sel.getRangeAt(0)

      // Check if we're inside an existing link
      let existingLink = findParentLink(range.commonAncestorContainer)

      if (existingLink) {
        // Update existing link
        existingLink.href = url
        existingLink.target = '_blank'
        existingLink.rel = 'noopener noreferrer'
      } else {
        // Create new link
        const selectedText = range.toString()
        if (selectedText) {
          // Wrap selected text in a link
          const link = doc.createElement('a')
          link.href = url
          link.target = '_blank'
          link.rel = 'noopener noreferrer'

          try {
            range.surroundContents(link)
          } catch (e) {
            // If surroundContents fails (complex selection), fall back to execCommand
            doc.execCommand('createLink', false, url)
            // Set target on newly created link
            const newLink = findParentLink(sel.anchorNode)
            if (newLink) {
              newLink.target = '_blank'
              newLink.rel = 'noopener noreferrer'
            }
          }
        } else {
          // No selection - insert link with URL as text
          const link = doc.createElement('a')
          link.href = url
          link.textContent = url
          link.target = '_blank'
          link.rel = 'noopener noreferrer'
          range.insertNode(link)
        }
      }
    }

    hidePopover()

    // Trigger GrapesJS update
    editor.trigger('component:update')
  }

  function removeLink() {
    if (!activeRte || !savedSelection) {
      hidePopover()
      return
    }

    // Restore selection
    restoreSelection(activeRte, savedSelection)

    const doc = activeRte.doc || document
    const sel = doc.getSelection()

    if (sel && sel.rangeCount > 0) {
      const range = sel.getRangeAt(0)
      const link = findParentLink(range.commonAncestorContainer)

      if (link) {
        // Replace link with its text content
        const text = doc.createTextNode(link.textContent)
        link.parentNode.replaceChild(text, link)
      }
    }

    hidePopover()
    editor.trigger('component:update')
  }

  function findParentLink(node) {
    while (node && node.nodeType !== Node.DOCUMENT_NODE) {
      if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'A') {
        return node
      }
      node = node.parentNode
    }
    return null
  }

  function getExistingLink(rte) {
    const doc = rte.doc || document
    const sel = doc.getSelection()
    if (sel && sel.rangeCount > 0) {
      const range = sel.getRangeAt(0)
      return findParentLink(range.commonAncestorContainer)
    }
    return null
  }

  // Override the default link action in RTE
  editor.on('rte:enable', () => {
    const rte = editor.RichTextEditor

    // Remove default link action and add our custom one
    rte.remove('link')
    rte.add('link', {
      icon: '<svg viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z"/></svg>',
      attributes: { title: 'Add/Edit Link (Cmd+K)' },
      result: (rteInstance) => {
        const existingLink = getExistingLink(rteInstance)
        showPopover(rteInstance, existingLink)
      }
    })
  })

  // Add Cmd+K / Ctrl+K keyboard shortcut
  editor.on('rte:enable', (view, rte) => {
    const doc = rte.doc || document

    const handleKeydown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        const existingLink = getExistingLink(rte)
        showPopover(rte, existingLink)
      }
    }

    doc.addEventListener('keydown', handleKeydown)

    // Store handler for cleanup
    rte._linkEditorKeyHandler = handleKeydown
  })

  // Cleanup keyboard handler when RTE is disabled
  editor.on('rte:disable', (view, rte) => {
    if (rte && rte._linkEditorKeyHandler) {
      const doc = rte.doc || document
      doc.removeEventListener('keydown', rte._linkEditorKeyHandler)
      delete rte._linkEditorKeyHandler
    }
    // Don't hide if user is interacting with the popover
    // (clicking inside the popover causes RTE to lose focus and fire rte:disable)
    if (popover && popover.contains(document.activeElement)) {
      return
    }
    hidePopover()
  })

  // Cleanup on editor destroy
  editor.on('destroy', () => {
    if (popover && popover.parentNode) {
      popover.parentNode.removeChild(popover)
    }
    popover = null
  })
}
