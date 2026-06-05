import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

const ADMIN_EMAIL = 'aplicacao.treinamento@gmail.com'

const AuthContext = createContext({})

export const useAuth = () => useContext(AuthContext)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [userRole, setUserRole] = useState('user') // 'admin' | 'user'
  const [publico, setPublico] = useState('geral') // 'geral' | 'estrategico_tatico' | 'gerencial_tecnico' | 'operacional'
  const [mustResetPassword, setMustResetPassword] = useState(false)

  const configuredResetRedirect = import.meta.env.VITE_PASSWORD_RESET_REDIRECT_URL?.trim()
  const passwordResetRedirectTo = configuredResetRedirect || `${window.location.origin}/redefinir-senha`

  const shouldResetPassword = (currentUser) =>
    Boolean(currentUser?.user_metadata?.must_reset_password)

  const checkRoles = async (currentUser) => {
    if (!currentUser) {
      setIsAdmin(false)
      setUserRole('user')
      setPublico('geral')
      setMustResetPassword(false)
      return
    }

    setMustResetPassword(shouldResetPassword(currentUser))

    // Verifica pelo email do master admin
    if (currentUser.email === ADMIN_EMAIL) {
      setIsAdmin(true)
      setUserRole('admin')
      setPublico('geral')
      return
    }
    // Verifica na tabela user_roles
    try {
      const { data } = await supabase
        .from('user_roles')
        .select('role, publico')
        .eq('user_id', currentUser.id)
        .single()
      const role = data?.role || 'user'
      setIsAdmin(role === 'admin')
      setUserRole(role)
      setPublico(data?.publico || 'geral')
    } catch {
      setIsAdmin(false)
      setUserRole('user')
      setPublico('geral')
    }
  }

  useEffect(() => {
    supabase.auth.getSession()
      .then(({ data: { session } }) => {
        const currentUser = session?.user ?? null
        setUser(currentUser)
        return checkRoles(currentUser)
      })
      .catch((err) => {
        console.warn('Erro ao obter sessão:', err.message)
      })
      .finally(() => {
        setLoading(false)
      })

    let subscription
    try {
      const { data } = supabase.auth.onAuthStateChange(
        (_event, session) => {
          const currentUser = session?.user ?? null
          setUser(currentUser)
          checkRoles(currentUser)
        }
      )
      subscription = data?.subscription
    } catch (err) {
      console.warn('Erro ao configurar auth listener:', err.message)
    }

    return () => subscription?.unsubscribe()
  }, [])

  const signIn = async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    return {
      error,
      mustResetPassword: shouldResetPassword(data?.user)
    }
  }

  const signUp = async (email, password, fullName) => {
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName,
          must_reset_password: true
        }
      }
    })

    return { error }
  }

  const resetPassword = async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: passwordResetRedirectTo
    })
    return { error }
  }

  const updatePassword = async (newPassword) => {
    const currentMetadata = user?.user_metadata || {}
    const { error } = await supabase.auth.updateUser({
      password: newPassword,
      data: {
        ...currentMetadata,
        must_reset_password: false
      }
    })

    if (!error) {
      setMustResetPassword(false)
    }

    return { error }
  }

  const signOut = async () => {
    await supabase.auth.signOut()
    setIsAdmin(false)
    setUserRole('user')
    setPublico('geral')
    setMustResetPassword(false)
  }

  return (
    <AuthContext.Provider value={{ user, loading, isAdmin, userRole, publico, mustResetPassword, signIn, signUp, signOut, resetPassword, updatePassword }}>
      {children}
    </AuthContext.Provider>
  )
}
