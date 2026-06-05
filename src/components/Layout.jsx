import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { FiLogOut, FiUser, FiSettings, FiMessageSquare, FiMenu, FiX, FiUserPlus, FiGrid } from 'react-icons/fi'
import { HomeIcon, BookOpenIcon, MedalIcon, BarChartIcon, GraduationCapIcon } from './Icons'
import './Layout.css'

export default function Layout() {
  const { user, signOut, isAdmin } = useAuth()
  const navigate = useNavigate()
  const [collapsed, setCollapsed] = useState(true)
  const [hovering, setHovering] = useState(false)

  const expanded = !collapsed || hovering

  const handleSignOut = async () => {
    await signOut()
    navigate('/login')
  }

  const displayName = user?.user_metadata?.full_name || user?.email?.split('@')[0] || 'Usuário'

  // Fecha sidebar no mobile ao navegar
  const isMobile = () => window.innerWidth <= 768
  const handleNavClick = () => {
    if (isMobile()) setCollapsed(true)
  }

  return (
    <div className={`layout ${expanded ? 'sidebar-expanded' : 'sidebar-collapsed'}`}>
      {/* Botão de menu visível apenas no mobile */}
      <button
        className="mobile-menu-btn"
        onClick={() => setCollapsed(prev => !prev)}
        aria-label="Abrir menu"
      >
        {expanded ? <FiX /> : <FiMenu />}
      </button>

      <aside
        className={`sidebar ${expanded ? 'expanded' : 'collapsed'}`}
        onMouseEnter={() => setHovering(true)}
        onMouseLeave={() => setHovering(false)}
      >
        <div className="sidebar-header">
          <span className="sidebar-logo"><GraduationCapIcon size={28} gradient /></span>
          <h2 className="sidebar-title">Capacita Portos</h2>
          <button
            className="sidebar-toggle"
            onClick={() => setCollapsed(prev => !prev)}
            title={collapsed ? 'Fixar menu' : 'Recolher menu'}
          >
            {collapsed ? <FiMenu /> : <FiX />}
          </button>
        </div>

        <nav className="sidebar-nav">
          <NavLink to="/" end className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
            <HomeIcon size={20} /> <span>Início</span>
          </NavLink>
          <NavLink to="/disciplinas" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
            <BookOpenIcon size={20} /> <span>Disciplinas</span>
          </NavLink>
          <NavLink to="/conquistas" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
            <MedalIcon size={20} /> <span>Conquistas</span>
          </NavLink>
          <NavLink to="/forum" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
            <FiMessageSquare /> <span>Fórum</span>
          </NavLink>

          {isAdmin && (
            <>
              <div className="nav-divider" />
              <span className="nav-section-label">Admin</span>
              <NavLink to="/admin/modulos" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
                <FiGrid /> <span>Módulos</span>
              </NavLink>
              <NavLink to="/admin/disciplinas" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
                <FiSettings /> <span>Disciplinas</span>
              </NavLink>
              <NavLink to="/admin/relatorios" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
                <BarChartIcon size={20} /> <span>Relatórios</span>
              </NavLink>
              <NavLink to="/admin/usuarios" className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'} onClick={handleNavClick}>
                <FiUserPlus /> <span>Cadastrar Usuários</span>
              </NavLink>
            </>
          )}
        </nav>

        <div className="sidebar-footer">
          <div className="user-info">
            <FiUser />
            <span className="user-name">{displayName}</span>
          </div>
          <button className="btn-logout" onClick={handleSignOut}>
            <FiLogOut /> Sair
          </button>
        </div>
      </aside>

      {/* Overlay para fechar menu no mobile */}
      {expanded && (
        <div
          className="mobile-overlay"
          onClick={() => setCollapsed(true)}
        />
      )}

      <main className="main-content">
        <Outlet />
      </main>
    </div>
  )
}
