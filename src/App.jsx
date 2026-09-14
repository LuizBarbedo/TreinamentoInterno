import { useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useLocation, useNavigate } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import AdminRoute from './components/AdminRoute'
import Layout from './components/Layout'
import Login from './pages/Login'
import Signup from './pages/Signup'
import Dashboard from './pages/Dashboard'
import Disciplines from './pages/Disciplines'
import DisciplineDetail from './pages/DisciplineDetail'
import Quiz from './pages/Quiz'
import Conquistas from './pages/Conquistas'
import AdminModules from './pages/admin/AdminModules'
import AdminDisciplines from './pages/admin/AdminDisciplines'
import AdminDisciplineEdit from './pages/admin/AdminDisciplineEdit'
import AdminReports from './pages/admin/AdminReports'
import AdminUsers from './pages/admin/AdminUsers'
import AdminLiberacao from './pages/admin/AdminLiberacao'
import ForgotPassword from './pages/ForgotPassword'
import ResetPassword from './pages/ResetPassword'
import Forum from './pages/Forum'
import ForumPost from './pages/ForumPost'

function RecoveryRedirectHandler() {
  const location = useLocation()
  const navigate = useNavigate()

  useEffect(() => {
    const hash = window.location.hash
    if (!hash) {
      return
    }

    const params = new URLSearchParams(hash.replace(/^#/, ''))
    const isRecovery = params.get('type') === 'recovery'
    const hasAccessToken = Boolean(params.get('access_token'))

    if (isRecovery && hasAccessToken && location.pathname !== '/redefinir-senha') {
      navigate({ pathname: '/redefinir-senha', hash }, { replace: true })
    }
  }, [location.pathname, navigate])

  return null
}

function App() {
  return (
    <BrowserRouter>
      <RecoveryRedirectHandler />
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/cadastro" element={<Signup />} />
          <Route path="/esqueci-senha" element={<ForgotPassword />} />
          <Route path="/redefinir-senha" element={<ResetPassword />} />

          <Route
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route path="/" element={<Dashboard />} />
            <Route path="/disciplinas" element={<Disciplines />} />
            <Route path="/disciplinas/:id" element={<DisciplineDetail />} />
            <Route path="/disciplinas/:id/quiz" element={<Quiz />} />
            <Route path="/conquistas" element={<Conquistas />} />
            <Route path="/forum" element={<Forum />} />
            <Route path="/forum/:postId" element={<ForumPost />} />

            {/* Admin Routes */}
            <Route path="/admin/modulos" element={
              <AdminRoute><AdminModules /></AdminRoute>
            } />
            <Route path="/admin/disciplinas" element={
              <AdminRoute><AdminDisciplines /></AdminRoute>
            } />
            <Route path="/admin/disciplinas/:id" element={
              <AdminRoute><AdminDisciplineEdit /></AdminRoute>
            } />
            <Route path="/admin/relatorios" element={
              <AdminRoute><AdminReports /></AdminRoute>
            } />
            <Route path="/admin/usuarios" element={
              <AdminRoute><AdminUsers /></AdminRoute>
            } />
            <Route path="/admin/liberacao" element={
              <AdminRoute><AdminLiberacao /></AdminRoute>
            } />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
