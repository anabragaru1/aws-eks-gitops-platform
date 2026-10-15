// API base URL is injected at build time; empty means same origin.
export const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '')

export function apiUrl(path) {
  return `${API_BASE}${path}`
}

async function request(path, options = {}) {
  const res = await fetch(apiUrl(path), {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.error || `request failed with ${res.status}`)
  }
  return res.json()
}

export const getStatus = () => request('/')
export const getInfo = () => request('/api/v1/info')
export const listNotes = () => request('/api/v1/notes')
export const createNote = (text) =>
  request('/api/v1/notes', { method: 'POST', body: JSON.stringify({ text }) })
