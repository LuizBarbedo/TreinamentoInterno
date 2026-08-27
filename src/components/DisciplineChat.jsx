import { useEffect, useRef, useState } from 'react'
import { FiSend, FiMessageCircle } from 'react-icons/fi'
import { supabase } from '../lib/supabase'
import './DisciplineChat.css'

export default function DisciplineChat({ disciplineId }) {
  const [messages, setMessages] = useState([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const messagesEndRef = useRef(null)

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, loading])

  const sendMessage = async () => {
    const text = input.trim()
    if (!text || loading) return

    const nextMessages = [...messages, { role: 'user', content: text }]
    setMessages(nextMessages)
    setInput('')
    setError('')
    setLoading(true)

    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        setError('Sua sessão expirou. Atualize a página e faça login novamente.')
        setLoading(false)
        return
      }

      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`
        },
        body: JSON.stringify({ disciplineId, messages: nextMessages })
      })

      const data = await response.json()

      if (!response.ok) {
        setError(data?.error || 'Não consegui responder agora, tenta de novo em instantes.')
        return
      }

      setMessages([...nextMessages, { role: 'assistant', content: data.reply }])
    } catch {
      setError('Não consegui responder agora, tenta de novo em instantes.')
    } finally {
      setLoading(false)
    }
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage()
    }
  }

  return (
    <div className="discipline-chat">
      <div className="discipline-chat-messages">
        {messages.length === 0 && (
          <div className="discipline-chat-empty">
            <FiMessageCircle />
            <p>Tire suas dúvidas sobre esta disciplina com a IA. Pergunte à vontade!</p>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} className={`chat-bubble chat-bubble-${msg.role}`}>
            {msg.content}
          </div>
        ))}

        {loading && (
          <div className="chat-bubble chat-bubble-assistant chat-bubble-typing">
            Digitando…
          </div>
        )}

        {error && <div className="discipline-chat-error">{error}</div>}

        <div ref={messagesEndRef} />
      </div>

      <div className="discipline-chat-input">
        <textarea
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Digite sua dúvida sobre a disciplina…"
          rows={2}
          disabled={loading}
        />
        <button onClick={sendMessage} disabled={loading || !input.trim()} title="Enviar">
          <FiSend />
        </button>
      </div>
    </div>
  )
}
