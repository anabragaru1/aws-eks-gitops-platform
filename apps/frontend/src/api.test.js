import { describe, it, expect } from 'vitest'
import { apiUrl } from './api.js'

describe('apiUrl', () => {
  it('prefixes paths with the configured base', () => {
    expect(apiUrl('/api/v1/info')).toMatch(/\/api\/v1\/info$/)
  })
})
