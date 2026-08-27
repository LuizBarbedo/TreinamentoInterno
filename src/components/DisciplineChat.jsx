import { useEffect, useRef, useState } from 'react'
import { FiSend, FiX } from 'react-icons/fi'
import { supabase } from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'
import './DisciplineChat.css'

export default function DisciplineChat({ disciplineId, disciplineName }) {
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const [messages, setMessages] = useState([])
  const [historyLoaded, setHistoryLoaded] = useState(false)
  const [loadingHistory, setLoadingHistory] = useState(false)
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const messagesEndRef = useRef(null)

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, loading, open])

  useEffect(() => {
    if (!open || historyLoaded || !user) return

    const loadHistory = async () => {
      setLoadingHistory(true)
      const { data } = await supabase
        .from('discipline_chat_messages')
        .select('role, content')
        .eq('discipline_id', disciplineId)
        .eq('user_id', user.id)
        .order('created_at')

      setMessages(data || [])
      setHistoryLoaded(true)
      setLoadingHistory(false)
    }

    loadHistory()
  }, [open, historyLoaded, user, disciplineId])

  const saveMessage = (role, content) => {
    if (!user) return
    supabase.from('discipline_chat_messages').insert({
      user_id: user.id,
      discipline_id: disciplineId,
      role,
      content
    })
  }

  const sendMessage = async () => {
    const text = input.trim()
    if (!text || loading) return

    const nextMessages = [...messages, { role: 'user', content: text }]
    setMessages(nextMessages)
    setInput('')
    setError('')
    setLoading(true)
    saveMessage('user', text)

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
      saveMessage('assistant', data.reply)
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

  const welcomeMessage = {
    role: 'assistant',
    content: `Olá! Sou o assistente de IA da disciplina ${disciplineName}. Pergunte qualquer dúvida sobre o conteúdo! 😊`
  }
  const displayMessages = loadingHistory ? [] : [welcomeMessage, ...messages]

  return (
    <div className="discipline-chat-widget">
      {open && (
        <div className="discipline-chat-panel">
          <div className="discipline-chat-header">
            <div className="discipline-chat-header-info">
              <span className="discipline-chat-avatar">🤖</span>
              <div>
                <h4>Assistente IA</h4>
                <p>{disciplineName}</p>
              </div>
            </div>
            <button className="discipline-chat-close" onClick={() => setOpen(false)} title="Fechar">
              <FiX />
            </button>
          </div>

          <div className="discipline-chat-messages">
            {loadingHistory && (
              <div className="discipline-chat-loading">Carregando conversa…</div>
            )}

            {displayMessages.map((msg, i) => (
              <div key={i} className={`chat-row chat-row-${msg.role}`}>
                {msg.role === 'assistant' && <span className="chat-avatar">🤖</span>}
                <div className={`chat-bubble chat-bubble-${msg.role}`}>{msg.content}</div>
              </div>
            ))}

            {loading && (
              <div className="chat-row chat-row-assistant">
                <span className="chat-avatar">🤖</span>
                <div className="chat-bubble chat-bubble-assistant chat-bubble-typing">Digitando…</div>
              </div>
            )}

            {error && <div className="discipline-chat-error">{error}</div>}

            <div ref={messagesEndRef} />
          </div>

          <div className="discipline-chat-input">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Digite sua dúvida..."
              disabled={loading}
            />
            <button onClick={sendMessage} disabled={loading || !input.trim()} title="Enviar">
              <FiSend />
            </button>
          </div>
        </div>
      )}

      {!open && (
        <button
          className="discipline-chat-fab"
          onClick={() => setOpen(true)}
          title="Tire suas dúvidas com a IA"
        >
          🤖
        </button>
      )}
    </div>
  )
}
