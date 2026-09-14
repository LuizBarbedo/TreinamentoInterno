import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { FiUnlock, FiLock, FiClock } from 'react-icons/fi'
import './AdminLiberacao.css'

export default function AdminLiberacao() {
  const [released, setReleased] = useState(false)
  const [releasedAt, setReleasedAt] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    fetchSettings()
  }, [])

  const fetchSettings = async () => {
    setLoading(true)
    const { data } = await supabase
      .from('platform_settings')
      .select('content_released, released_at')
      .eq('id', 1)
      .single()
    setReleased(Boolean(data?.content_released))
    setReleasedAt(data?.released_at || null)
    setLoading(false)
  }

  const handleToggle = async (nextValue) => {
    const confirmMsg = nextValue
      ? 'Liberar as aulas para todos os alunos agora? Todo mundo poderá acessar imediatamente.'
      : 'Bloquear novamente o acesso às aulas para todos os alunos?'
    if (!window.confirm(confirmMsg)) return

    setError('')
    setSaving(true)
    const { error: rpcError } = await supabase.rpc('set_content_released', { p_released: nextValue })
    if (rpcError) {
      setError('Não foi possível atualizar: ' + rpcError.message)
    } else {
      await fetchSettings()
    }
    setSaving(false)
  }

  if (loading) {
    return <div className="admin-liberacao-page">Carregando...</div>
  }

  return (
    <div className="admin-liberacao-page">
      <div className="page-header">
        <div>
          <h1><FiUnlock /> Liberação da Turma</h1>
          <p>Controla se os alunos já podem acessar aulas, materiais e quizzes.</p>
        </div>
      </div>

      <div className="admin-liberacao-card">
        <div className={`status-banner ${released ? 'status-released' : 'status-locked'}`}>
          {released ? <FiUnlock size={22} /> : <FiLock size={22} />}
          <div>
            <strong>{released ? 'Conteúdo liberado' : 'Conteúdo bloqueado'}</strong>
            <p>
              {released
                ? 'Os alunos já conseguem acessar disciplinas, aulas e quizzes normalmente.'
                : 'Os alunos só veem a lista de disciplinas, sem conseguir abrir aulas ou quizzes.'}
            </p>
          </div>
        </div>

        {releasedAt && released && (
          <p className="released-at">
            <FiClock /> Liberado em {new Date(releasedAt).toLocaleString('pt-BR')}
          </p>
        )}

        {error && <div className="form-error">{error}</div>}

        <div className="liberacao-hint">
          Enquanto bloqueado, mesmo alunos que já tenham feito login não conseguem abrir
          nenhuma aula — use isso para garantir que a turma toda comece junto.
        </div>

        <button
          className={released ? 'btn-lock' : 'btn-release'}
          onClick={() => handleToggle(!released)}
          disabled={saving}
        >
          {released ? <FiLock /> : <FiUnlock />}
          {saving ? 'Salvando...' : released ? 'Bloquear para os alunos' : 'Liberar para os alunos'}
        </button>
      </div>
    </div>
  )
}
