import { useState, useEffect, useMemo } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { FiClipboard, FiCheck, FiDownload, FiExternalLink, FiSearch } from 'react-icons/fi'
import './AdminCorrecoes.css'

const STATUS_LABEL = {
  pendente: 'Pendente',
  avaliada: 'Avaliada',
}

export default function AdminCorrecoes() {
  const [disciplines, setDisciplines] = useState([])
  const [submissions, setSubmissions] = useState([])
  const [loading, setLoading] = useState(true)

  const [filterDiscipline, setFilterDiscipline] = useState('all')
  const [filterStatus, setFilterStatus] = useState('pendente')
  const [searchTerm, setSearchTerm] = useState('')

  const [gradeDrafts, setGradeDrafts] = useState({})
  const [savingId, setSavingId] = useState(null)

  useEffect(() => {
    fetchAll()
  }, [])

  const fetchAll = async () => {
    setLoading(true)
    const [{ data: discs }, { data: subs }, { data: users }] = await Promise.all([
      supabase.from('disciplines').select('id, name, icon').order('order_index'),
      supabase
        .from('practical_submissions')
        .select('*, disciplines(name, icon), practical_activities(title)')
        .order('submitted_at', { ascending: false }),
      supabase.rpc('get_platform_users'),
    ])

    const userMap = {}
    ;(users || []).forEach(u => { userMap[u.id] = u })

    const enriched = (subs || []).map(s => ({
      ...s,
      discipline_name: s.disciplines?.name || 'Disciplina removida',
      discipline_icon: s.disciplines?.icon || '📚',
      activity_title: s.practical_activities?.title || 'Atividade Prática',
      full_name: userMap[s.user_id]?.full_name || 'Aluno desconhecido',
      email: userMap[s.user_id]?.email || '',
    }))

    setDisciplines(discs || [])
    setSubmissions(enriched)

    const drafts = {}
    enriched.forEach(s => { drafts[s.id] = { grade: s.grade || '', feedback: s.feedback || '' } })
    setGradeDrafts(drafts)

    setLoading(false)
  }

  const stats = useMemo(() => {
    const pendentes = submissions.filter(s => s.status === 'pendente').length
    const avaliadas = submissions.filter(s => s.status === 'avaliada').length
    return { pendentes, avaliadas, total: submissions.length }
  }, [submissions])

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    return submissions.filter(s => {
      if (filterDiscipline !== 'all' && s.discipline_id !== filterDiscipline) return false
      if (filterStatus !== 'all' && s.status !== filterStatus) return false
      if (term && !`${s.full_name} ${s.email}`.toLowerCase().includes(term)) return false
      return true
    })
  }, [submissions, filterDiscipline, filterStatus, searchTerm])

  const saveGrade = async (submission) => {
    const draft = gradeDrafts[submission.id] || {}
    setSavingId(submission.id)
    const { error } = await supabase
      .from('practical_submissions')
      .update({
        grade: draft.grade?.trim() || null,
        feedback: draft.feedback?.trim() || null,
        status: 'avaliada',
        graded_at: new Date().toISOString(),
      })
      .eq('id', submission.id)

    if (error) {
      console.error('Erro ao salvar devolutiva:', error)
      alert('Erro ao salvar a devolutiva. Tente novamente.')
    } else {
      setSubmissions(prev => prev.map(s => s.id === submission.id
        ? { ...s, grade: draft.grade?.trim() || null, feedback: draft.feedback?.trim() || null, status: 'avaliada', graded_at: new Date().toISOString() }
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
    <div className="admin-correcoes-page">
      <div className="page-header">
        <div>
          <h1><FiClipboard /> Correção de Atividades Práticas</h1>
          <p>Todas as entregas de todos os alunos, de todas as disciplinas, em um só lugar.</p>
        </div>
      </div>

      <div className="correcoes-stats">
        <div className="correcoes-stat correcoes-stat-pendente">
          <strong>{stats.pendentes}</strong>
          <span>Aguardando correção</span>
        </div>
        <div className="correcoes-stat correcoes-stat-avaliada">
          <strong>{stats.avaliadas}</strong>
          <span>Já avaliadas</span>
        </div>
        <div className="correcoes-stat">
          <strong>{stats.total}</strong>
          <span>Total de entregas</span>
        </div>
      </div>

      <div className="correcoes-filters">
        <select value={filterDiscipline} onChange={e => setFilterDiscipline(e.target.value)}>
          <option value="all">Todas as disciplinas</option>
          {disciplines.map(d => (
            <option key={d.id} value={d.id}>{d.icon} {d.name}</option>
          ))}
        </select>

        <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)}>
          <option value="pendente">Aguardando correção</option>
          <option value="avaliada">Já avaliadas</option>
          <option value="all">Todos os status</option>
        </select>

        <div className="correcoes-search">
          <FiSearch />
          <input
            placeholder="Buscar por nome ou e-mail do aluno..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {filtered.length === 0 ? (
        <div className="list-empty">
          {submissions.length === 0
            ? 'Nenhuma entrega de Atividade Prática recebida ainda.'
            : 'Nenhuma entrega encontrada para esse filtro.'}
        </div>
      ) : (
        <div className="correcoes-list">
          {filtered.map(sub => (
            <div key={sub.id} className="submission-card">
              <div className="submission-head">
                <div className="submission-student">
                  <strong>{sub.full_name}</strong>
                  <small>{sub.email}</small>
                </div>
                <div className="submission-meta">
                  <span className="submission-discipline">
                    {sub.discipline_icon} {sub.discipline_name}
                  </span>
                  <span className={`pa-status pa-status-${sub.status}`}>
                    {STATUS_LABEL[sub.status] || sub.status}
                  </span>
                  <small>{formatDate(sub.submitted_at)}</small>
                </div>
              </div>

              <div className="submission-body">
                <small className="submission-activity-title">{sub.activity_title}</small>
                {sub.submission_type === 'file' ? (
                  <a href={sub.file_url} target="_blank" rel="noopener noreferrer" download={sub.file_name} className="submission-file-link">
                    <FiDownload /> Baixar arquivo: {sub.file_name || 'documento.docx'}
                  </a>
                ) : (
                  <div className="submission-text">{sub.content_text}</div>
                )}
              </div>

              <div className="submission-grade">
                <div className="form-grid">
                  <div className="form-group">
                    <label>Nota / Conceito</label>
                    <input
                      value={gradeDrafts[sub.id]?.grade || ''}
                      onChange={e => setGradeDrafts(d => ({ ...d, [sub.id]: { ...d[sub.id], grade: e.target.value } }))}
                      placeholder="Ex: 9,0 ou Aprovado"
                    />
                  </div>
                  <div className="form-group form-full">
                    <label>Devolutiva / Comentário ao aluno</label>
                    <textarea
                      value={gradeDrafts[sub.id]?.feedback || ''}
                      onChange={e => setGradeDrafts(d => ({ ...d, [sub.id]: { ...d[sub.id], feedback: e.target.value } }))}
                      rows={2}
                      placeholder="Escreva um comentário de devolutiva para o aluno (opcional)"
                    />
                  </div>
                </div>
                <div className="form-actions">
                  <Link to={`/admin/disciplinas/${sub.discipline_id}`} className="btn-secondary">
                    <FiExternalLink /> Ver disciplina
                  </Link>
                  <button className="btn-primary" onClick={() => saveGrade(sub)} disabled={savingId === sub.id}>
                    <FiCheck /> {savingId === sub.id ? 'Salvando...' : sub.status === 'avaliada' ? 'Atualizar Devolutiva' : 'Salvar Devolutiva'}
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
