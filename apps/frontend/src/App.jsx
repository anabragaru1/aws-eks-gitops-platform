import { useEffect, useState } from 'react'
import { createNote, getInfo, getStatus, listNotes } from './api.js'

export default function App() {
  const [info, setInfo] = useState(null)
  const [status, setStatus] = useState(null)
  const [notes, setNotes] = useState([])
  const [text, setText] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    getInfo().then(setInfo).catch((e) => setError(e.message))
    listNotes().then(setNotes).catch((e) => setError(e.message))
    refreshStatus()
  }, [])

  // Each call lands on a different replica behind the load balancer.
  function refreshStatus() {
    getStatus().then(setStatus).catch(() => setStatus(null))
  }

  async function submit(e) {
    e.preventDefault()
    if (!text.trim()) return
    setBusy(true)
    setError('')
    try {
      const note = await createNote(text.trim())
      setNotes([note, ...notes])
      setText('')
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <main>
      <header>
        <h1>Notes</h1>
        {info && (
          <p className="meta">
            {info.service} {info.version} · {info.environment}
          </p>
        )}
        {status && (
          <p className="meta">
            served by <code>{status.pod_name}</code> · db {status.db_status}{' '}
            <button type="button" className="link" onClick={refreshStatus}>
              refresh
            </button>
          </p>
        )}
      </header>

      <form onSubmit={submit}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Write a note"
          maxLength={500}
          disabled={busy}
        />
        <button type="submit" disabled={busy || !text.trim()}>
          Add
        </button>
      </form>

      {error && <p className="error">{error}</p>}

      <ul>
        {notes.map((n) => (
          <li key={n.id}>
            <span>{n.text}</span>
            {n.createdAt && <time dateTime={n.createdAt}>{new Date(n.createdAt).toLocaleString()}</time>}
          </li>
        ))}
        {notes.length === 0 && !error && <li className="empty">No notes yet.</li>}
      </ul>
    </main>
  )
}
