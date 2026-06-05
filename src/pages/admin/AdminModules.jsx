import { useEffect, useState } from 'react'
import { supabase } from '../../lib/supabase'
import { FiPlus, FiTrash2 } from 'react-icons/fi'
import { PUBLICO_OPTIONS, PUBLICO_LABELS } from '../../lib/publicos'
import './AdminDisciplines.css'

const EMPTY_FORM = { name: '', description: '', icon: '📦', publico: 'geral', order_index: 0 }

export default function AdminModules() {
  const [modules, setModules] = useState([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(EMPTY_FORM)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    fetchModules()
  }, [])

  const fetchModules = async () => {
    const { data } = await supabase
      .from('modules')
      .select('*, disciplines(count)')
      .order('order_index')
    setModules(data || [])
    setLoading(false)
  }

  const resetForm = () => {
    setForm(EMPTY_FORM)
    setEditingId(null)
    setShowForm(false)
  }

  const handleEdit = (mod) => {
    setForm({
      name: mod.name,
      description: mod.description || '',
      icon: mod.icon || '📦',
      publico: mod.publico || 'geral',
      order_index: mod.order_index || 0
    })
    setEditingId(mod.id)
    setShowForm(true)
  }

  const handleSave = async () => {
    if (!form.name.trim()) return alert('Nome é obrigatório')
    setSaving(true)

    if (editingId) {
      await supabase.from('modules').update(form).eq('id', editingId)
    } else {
      const maxOrder = modules.length > 0
        ? Math.max(...modules.map(m => m.order_index || 0))
        : 0
      await supabase.from('modules').insert({
        ...form,
        order_index: form.order_index || maxOrder + 1
      })
    }

    setSaving(false)
    resetForm()
    fetchModules()
  }

  const handleDelete = async (id, name) => {
    if (!confirm(`Tem certeza que deseja excluir o módulo "${name}"?\n\nAs disciplinas deste módulo NÃO serão excluídas, apenas ficarão sem módulo.`)) return
    await supabase.from('modules').delete().eq('id', id)
    fetchModules()
  }

  if (loading) {
    return <div className="loading-screen"><div className="spinner"></div></div>
  }

  return (
    <div className="admin-disciplines">
      <div className="admin-header">
        <div>
          <h1>📦 Gerenciar Módulos</h1>
          <p className="admin-subtitle">Organize o conteúdo em módulos por público-alvo</p>
        </div>
        <button className="btn-primary" onClick={() => { resetForm(); setShowForm(true) }}>
          <FiPlus /> Novo Módulo
        </button>
      </div>

      {showForm && (
        <div className="admin-form-card">
          <h3>{editingId ? '✏️ Editar Módulo' : '➕ Novo Módulo'}</h3>
          <div className="form-grid">
            <div className="form-group">
              <label>Ícone (emoji)</label>
              <input
                value={form.icon}
                onChange={e => setForm(f => ({ ...f, icon: e.target.value }))}
                placeholder="📦"
              />
            </div>
            <div className="form-group">
              <label>Ordem</label>
              <input
                type="number"
                value={form.order_index}
                onChange={e => setForm(f => ({ ...f, order_index: parseInt(e.target.value) || 0 }))}
              />
            </div>
            <div className="form-group form-full">
              <label>Público *</label>
              <select
                value={form.publico}
                onChange={e => setForm(f => ({ ...f, publico: e.target.value }))}
              >
                {PUBLICO_OPTIONS.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
            <div className="form-group form-full">
              <label>Nome *</label>
              <input
                value={form.name}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                placeholder="Nome do módulo"
              />
            </div>
            <div className="form-group form-full">
              <label>Descrição</label>
              <textarea
                value={form.description}
                onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                placeholder="Descrição do módulo"
                rows={3}
              />
            </div>
          </div>
          <div className="form-actions">
            <button className="btn-secondary" onClick={resetForm}>Cancelar</button>
            <button className="btn-primary" onClick={handleSave} disabled={saving}>
              {saving ? 'Salvando...' : editingId ? 'Salvar Alterações' : 'Criar Módulo'}
            </button>
          </div>
        </div>
      )}

      <div className="admin-table">
        <div className="table-header">
          <span className="col-icon">Ícone</span>
          <span className="col-name">Módulo</span>
          <span className="col-stats">Público</span>
          <span className="col-stats">Disciplinas</span>
          <span className="col-order">Ordem</span>
          <span className="col-actions">Ações</span>
        </div>

        {modules.map(mod => (
          <div key={mod.id} className="table-row">
            <span className="col-icon">{mod.icon || '📦'}</span>
            <div className="col-name">
              <strong>{mod.name}</strong>
              <small>{mod.description}</small>
            </div>
            <span className="col-stats">{PUBLICO_LABELS[mod.publico] || mod.publico}</span>
            <span className="col-stats">{mod.disciplines?.[0]?.count || 0}</span>
            <span className="col-order">{mod.order_index}</span>
            <div className="col-actions">
              <button
                className="btn-icon btn-edit-inline"
                onClick={() => handleEdit(mod)}
                title="Editar módulo"
              >
                ✏️
              </button>
              <button
                className="btn-icon btn-delete"
                onClick={() => handleDelete(mod.id, mod.name)}
                title="Excluir"
              >
                <FiTrash2 />
              </button>
            </div>
          </div>
        ))}

        {modules.length === 0 && (
          <div className="table-empty">
            <p>Nenhum módulo cadastrado.</p>
            <p>Clique em <strong>"Novo Módulo"</strong> para começar.</p>
          </div>
        )}
      </div>
    </div>
  )
}
