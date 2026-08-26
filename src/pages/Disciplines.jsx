import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'
import { FiCheck } from 'react-icons/fi'
import { filterByPublico, PUBLICO_LABELS } from '../lib/publicos'
import './Disciplines.css'

export default function Disciplines() {
  const { user, publico, isAdmin, fullAccess } = useAuth()
  const [modules, setModules] = useState([])
  const [disciplines, setDisciplines] = useState([])
  const [completedDisciplines, setCompletedDisciplines] = useState(new Set())
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    const [modRes, discRes, progressRes] = await Promise.all([
      supabase.from('modules').select('*').order('order_index'),
      supabase.from('disciplines').select('*, module_disciplines(module_id)').order('order_index'),
      supabase.from('user_progress').select('discipline_id').eq('user_id', user.id).eq('completed', true)
    ])
    setModules(modRes.data || [])
    setDisciplines(discRes.data || [])
    if (progressRes.data) {
      setCompletedDisciplines(new Set(progressRes.data.map(p => p.discipline_id)))
    }
    setLoading(false)
  }

  if (loading) {
    return <div className="loading-screen"><div className="spinner"></div></div>
  }

  // O master e os perfis com acesso total veem todos os módulos;
  // o funcionário vê os do seu público + os "geral".
  const visibleModules = (isAdmin || fullAccess) ? modules : filterByPublico(modules, publico)

  return (
    <div className="disciplines-page">
      <h1>📚 Conteúdo do Programa</h1>
      <p className="page-subtitle">Módulos disponíveis para o seu perfil</p>

      {visibleModules.length === 0 && (
        <div className="empty-state">
          <p>Nenhum módulo disponível para o seu público no momento.</p>
        </div>
      )}

      {visibleModules.map(mod => {
        const moduleDisciplines = disciplines.filter(d => d.module_disciplines?.some(md => md.module_id === mod.id))
        return (
          <section key={mod.id} className="module-section">
            <div className="module-header">
              <span className="module-icon">{mod.icon || '📦'}</span>
              <div className="module-title">
                <h2>{mod.name}</h2>
                {mod.description && <p>{mod.description}</p>}
              </div>
              <span className="module-publico">{PUBLICO_LABELS[mod.publico] || mod.publico}</span>
            </div>

            <div className="disciplines-list">
              {moduleDisciplines.map(disc => {
                const isCompleted = completedDisciplines.has(disc.id)
                return (
                  <Link key={disc.id} to={`/disciplinas/${disc.id}`} className={`discipline-item ${isCompleted ? 'discipline-completed' : ''}`}>
                    <div className="disc-icon">{disc.icon || '📖'}</div>
                    <div className="disc-info">
                      <h3>{disc.name}</h3>
                      <p>{disc.description}</p>
                      {isCompleted && <span className="disc-completed-badge"><FiCheck /> Concluída</span>}
                    </div>
                    <div className="disc-arrow">{isCompleted ? <FiCheck /> : '→'}</div>
                  </Link>
                )
              })}

              {moduleDisciplines.length === 0 && (
                <div className="empty-state">
                  <p>Nenhuma disciplina neste módulo ainda.</p>
                </div>
              )}
            </div>
          </section>
        )
      })}
    </div>
  )
}
