import test from 'node:test'
import assert from 'node:assert/strict'
import { classifyListEnter } from './list-editor-logic.mjs'

test('Enter in middle of bullet splits into new bullet with remaining text', () => {
  const action = classifyListEnter({ isEmptyItem: false, hasContentAfterCursor: true })
  assert.equal(action, 'split-item')
})

test('Enter at end of bullet creates a new empty bullet', () => {
  const action = classifyListEnter({ isEmptyItem: false, hasContentAfterCursor: false })
  assert.equal(action, 'new-empty-item')
})

test('Enter on empty bullet exits the list', () => {
  const action = classifyListEnter({ isEmptyItem: true, hasContentAfterCursor: false })
  assert.equal(action, 'exit-list')
})

