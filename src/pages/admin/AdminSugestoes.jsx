import { useState, useEffect, useMemo } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { FiMessageCircle, FiSend, FiSearch } from 'react-icons/fi'
import './AdminSugestoes.css'

const STATUS_LABEL = {
  pendente: 'Pendente de resposta',
  respondida: 'Respondida',
}

export default function AdminSugestoes() {
  const { user } = useAuth()
  const [disciplines, setDisciplines] = useState([])
  const [suggestions, setSuggestions] = useState([])
  const [loading, setLoading] = useState(true)

  const [filterDiscipline, setFilterDiscipline] = useState('all')
  const [filterStatus, setFilterStatus] = useState('pendente')
  const [searchTerm, setSearchTerm] = useState('')

  const [responseDrafts, setResponseDrafts] = useState({})
  const [savingId, setSavingId] = useState(null)

  useEffect(() => {
    fetchAll()
  }, [])

  const fetchAll = async () => {
    setLoading(true)
    const [{ data: discs }, { data: sugs }, { data: users }] = await Promise.all([
      supabase.from('disciplines').select('id, name, icon').order('order_index'),
      supabase
        .from('discipline_suggestions')
        .select('*, disciplines(name, icon)')
        .order('created_at', { ascending: false }),
      supabase.rpc('get_platform_users'),
    ])

    const userMap = {}
    ;(users || []).forEach(u => { userMap[u.id] = u })

    const enriched = (sugs || []).map(s => ({
      ...s,
      discipline_name: s.disciplines?.name || 'Disciplina removida',
      discipline_icon: s.disciplines?.icon || '📚',
      full_name: userMap[s.user_id]?.full_name || 'Aluno desconhecido',
      email: userMap[s.user_id]?.email || '',
    }))

    setDisciplines(discs || [])
    setSuggestions(enriched)

    const drafts = {}
    enriched.forEach(s => { drafts[s.id] = s.admin_response || '' })
    setResponseDrafts(drafts)

    setLoading(false)
  }

  const stats = useMemo(() => {
    const pendentes = suggestions.filter(s => s.status === 'pendente').length
    const respondidas = suggestions.filter(s => s.status === 'respondida').length
    return { pendentes, respondidas, total: suggestions.length }
  }, [suggestions])

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    return suggestions.filter(s => {
      if (filterDiscipline !== 'all' && s.discipline_id !== filterDiscipline) return false
      if (filterStatus !== 'all' && s.status !== filterStatus) return false
      if (term && !`${s.full_name} ${s.email} ${s.content}`.toLowerCase().includes(term)) return false
      return true
    })
  }, [suggestions, filterDiscipline, filterStatus, searchTerm])

  const respond = async (suggestion) => {
    const text = (responseDrafts[suggestion.id] || '').trim()
    if (!text) {
      alert('Escreva uma resposta antes de enviar.')
      return
    }
    setSavingId(suggestion.id)
    const { error } = await supabase
      .from('discipline_suggestions')
      .update({
        admin_response: text,
        status: 'respondida',
        responded_by: user?.id || null,
        responded_at: new Date().toISOString(),
      })
      .eq('id', suggestion.id)

    if (error) {
      console.error('Erro ao responder sugestão:', error)
      alert('Erro ao enviar a resposta. Tente novamente.')
    } else {
      setSuggestions(prev => prev.map(s => s.id === suggestion.id
        ? { ...s, admin_response: text, status: 'respondida', responded_at: new Date().toISOString() }
        : s
      ))
    }
    setSavingId(null)
  }

  const formatDate = (d) => d
    ? new Date(d).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
    : '—'

  if (loading) {
    return <div className="loading-screen"><div className="spinner"></div></div>
  }

  return (
    <div className="admin-sugestoes-page">
      <div className="page-header">
        <div>
          <h1><FiMessageCircle /> Sugestões das Disciplinas</h1>
          <p>Acompanhe e responda o que os alunos enviaram em cada disciplina.</p>
        </div>
      </div>

      <div className="sugestoes-stats">
        <div className="sugestoes-stat sugestoes-stat-pendente">
          <strong>{stats.pendentes}</strong>
          <span>Pendentes de resposta</span>
        </div>
        <div className="sugestoes-stat sugestoes-stat-respondida">
          <strong>{stats.respondidas}</strong>
          <span>Já respondidas</span>
        </div>
        <div className="sugestoes-stat">
          <strong>{stats.total}</strong>
          <span>Total de sugestões</span>
        </div>
      </div>

      <div className="sugestoes-filters">
        <select value={filterDiscipline} onChange={e => setFilterDiscipline(e.target.value)}>
          <option value="all">Todas as disciplinas</option>
          {disciplines.map(d => (
            <option key={d.id} value={d.id}>{d.icon} {d.name}</option>
          ))}
        </select>

        <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)}>
          <option value="pendente">Pendentes de resposta</option>
          <option value="respondida">Já respondidas</option>
          <option value="all">Todos os status</option>
        </select>

        <div className="sugestoes-search">
          <FiSearch />
          <input
            placeholder="Buscar por aluno ou texto da sugestão..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {filtered.length === 0 ? (
        <div className="list-empty">
          {suggestions.length === 0
            ? 'Nenhuma sugestão enviada pelos alunos ainda.'
            : 'Nenhuma sugestão encontrada para esse filtro.'}
        </div>
      ) : (
        <div className="sugestoes-list">
          {filtered.map(sug => (
            <div key={sug.id} className="suggestion-card">
              <div className="suggestion-head">
                <div className="suggestion-student">
                  <strong>{sug.full_name}</strong>
                  <small>{sug.email}</small>
                </div>
                <div className="suggestion-meta">
                  <span className="suggestion-discipline">
                    {sug.discipline_icon} {sug.discipline_name}
                  </span>
                  <span className={`sug-status sug-status-${sug.status}`}>
                    {STATUS_LABEL[sug.status] || sug.status}
                  </span>
                  <small>{formatDate(sug.created_at)}</small>
                </div>
              </div>

              <div className="suggestion-body">
                {sug.content}
              </div>

              <div className="suggestion-response">
                <label>Resposta do admin</label>
                <textarea
                  value={responseDrafts[sug.id] || ''}
                  onChange={e => setResponseDrafts(d => ({ ...d, [sug.id]: e.target.value }))}
                  rows={3}
                  placeholder="Escreva a resposta para o aluno..."
                />
                <div className="form-actions">
                  {sug.responded_at && (
                    <small className="suggestion-responded-at">
                      Respondida em {formatDate(sug.responded_at)}
                    </small>
                  )}
                  <button className="btn-primary" onClick={() => respond(sug)} disabled={savingId === sug.id}>
                    <FiSend /> {savingId === sug.id ? 'Enviando...' : sug.status === 'respondida' ? 'Atualizar Resposta' : 'Responder'}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
