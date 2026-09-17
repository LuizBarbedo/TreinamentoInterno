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
  const [publico, setPublico] = useState('geral') // 'geral' (conteúdo aberto) | 'estrategico' | 'tatico' | 'operacional' | 'externo' (acesso irrestrito)
  const [fullAccess, setFullAccess] = useState(false) // libera todo o conteúdo sem travas (coordenação)
  const [mustResetPassword, setMustResetPassword] = useState(false)
  const [contentReleased, setContentReleased] = useState(false) // trava geral: admin ainda não liberou as aulas para a turma

  const configuredResetRedirect = import.meta.env.VITE_PASSWORD_RESET_REDIRECT_URL?.trim()
  const passwordResetRedirectTo = configuredResetRedirect || `${window.location.origin}/redefinir-senha`

  const shouldResetPassword = (currentUser) =>
    Boolean(currentUser?.user_metadata?.must_reset_password)

  const checkRoles = async (currentUser) => {
    if (!currentUser) {
      setIsAdmin(false)
      setUserRole('user')
      setPublico('geral')
      setFullAccess(false)
      setMustResetPassword(false)
      return
    }

    setMustResetPassword(shouldResetPassword(currentUser))

    // Verifica pelo email do master admin
    if (currentUser.email === ADMIN_EMAIL) {
      setIsAdmin(true)
      setUserRole('admin')
      setPublico('geral')
      setFullAccess(true)
      return
    }
    // Verifica na tabela user_roles
    try {
      const { data } = await supabase
        .from('user_roles')
        .select('role, publico, full_access, cpf')
        .eq('user_id', currentUser.id)
        .single()

      // Autocadastro (/cadastro): no primeiro login o cpf/publico ainda não
      // está em user_roles, mas foi guardado em user_metadata pelo signUp.
      // Grava agora via RPC (a própria tabela não aceita insert direto do aluno).
      const pendingCpf = currentUser.user_metadata?.cpf
      const pendingPublico = currentUser.user_metadata?.publico
      if (!data?.cpf && pendingCpf) {
        const { error: completeError } = await supabase.rpc('complete_student_signup', {
          p_cpf: pendingCpf,
          p_publico: pendingPublico || 'estrategico',
        })
        if (!completeError) {
          setIsAdmin(false)
          setUserRole('user')
          setPublico(pendingPublico || 'estrategico')
          setFullAccess(false)
          return
        }
      }

      const role = data?.role || 'user'
      setIsAdmin(role === 'admin')
      setUserRole(role)
      setPublico(data?.publico || 'geral')
      setFullAccess(Boolean(data?.full_access))
    } catch {
      setIsAdmin(false)
      setUserRole('user')
      setPublico('geral')
      setFullAccess(false)
    }
  }

  const fetchContentReleased = async () => {
    try {
      const { data } = await supabase
        .from('platform_settings')
        .select('content_released')
        .eq('id', 1)
        .single()
      setContentReleased(Boolean(data?.content_released))
    } catch {
      setContentReleased(false)
    }
  }

  useEffect(() => {
    supabase.auth.getSession()
      .then(({ data: { session } }) => {
        const currentUser = session?.user ?? null
        setUser(currentUser)
        // Só busca a trava depois que a sessão (se houver) já foi restaurada,
        // senão a requisição sai como anônima e a RLS (só "authenticated")
        // nega a leitura, travando content_released em false pro resto da aba.
        return Promise.all([checkRoles(currentUser), fetchContentReleased()])
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
          // Reconsulta com a sessão já autenticada — cobre login e o
          // autocadastro (SIGNED_IN logo após supabase.auth.signUp()).
          fetchContentReleased()
        }
      )
      subscription = data?.subscription
    } catch (err) {
      console.warn('Erro ao configurar auth listener:', err.message)
    }

    // Escuta em tempo real para a trava cair para todo mundo assim que o
    // admin liberar, sem precisar de refresh/relogin.
    const channel = supabase
      .channel('platform_settings_changes')
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'platform_settings' },
        (payload) => setContentReleased(Boolean(payload.new?.content_released))
      )
      .subscribe()

    return () => {
      subscription?.unsubscribe()
      supabase.removeChannel(channel)
    }
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
    setFullAccess(false)
    setMustResetPassword(false)
  }

  // Trava geral: só admin e full_access (coordenação) acessam antes da liberação
  const canAccessContent = isAdmin || fullAccess || contentReleased

  return (
    <AuthContext.Provider value={{ user, loading, isAdmin, userRole, publico, fullAccess, mustResetPassword, contentReleased, canAccessContent, signIn, signUp, signOut, resetPassword, updatePassword }}>
      {children}
    </AuthContext.Provider>
  )
}
