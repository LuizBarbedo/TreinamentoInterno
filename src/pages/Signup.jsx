import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatCpf, isValidCpf, onlyDigits } from '../lib/cpf'
import { PUBLICO_LABELS, PUBLICO_DESCRIPTIONS } from '../lib/publicos'
import logoImg from '../assets/logo-capacita-portos-branco.png'
import './Signup.css'

// Os públicos oficiais do programa, disponíveis para autocadastro:
// os 3 internos + "externo" (acesso irrestrito a todo o conteúdo).
const MODULOS_DISPONIVEIS = ['estrategico', 'tatico', 'operacional', 'externo']

export default function Signup() {
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [cpf, setCpf] = useState('')
  const [publico, setPublico] = useState('estrategico')
  const [error, setError] = useState('')
  const [pendingConfirmation, setPendingConfirmation] = useState(false)
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (fullName.trim().split(/\s+/).length < 2) {
      setError('Informe nome e sobrenome.')
      return
    }
    if (password.length < 6) {
      setError('A senha deve ter no mínimo 6 caracteres.')
      return
    }
    if (password !== confirmPassword) {
      setError('As senhas não coincidem.')
      return
    }
    if (!isValidCpf(cpf)) {
      setError('CPF inválido.')
      return
    }

    setLoading(true)
    try {
      const cpfDigits = onlyDigits(cpf)

      const { data: cpfTaken, error: cpfCheckError } = await supabase.rpc('cpf_is_taken', {
        p_cpf: cpfDigits,
      })
      if (cpfCheckError) {
        setError('Não foi possível validar o CPF. Tente novamente.')
        setLoading(false)
        return
      }
      if (cpfTaken) {
        setError('Este CPF já está cadastrado na plataforma.')
        setLoading(false)
        return
      }

      const { data, error: signUpError } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: {
          data: {
            full_name: fullName.trim(),
            cpf: cpfDigits,
            publico,
          },
        },
      })

      if (signUpError) {
        setError(
          signUpError.message === 'User already registered'
            ? 'Este e-mail já está cadastrado. Faça login ou recupere sua senha.'
            : signUpError.message
        )
        setLoading(false)
        return
      }

      if (data?.session) {
        // Confirmação de e-mail desligada no projeto: usuário já está
        // autenticado, AuthContext vai gravar cpf/publico no próximo checkRoles.
        navigate('/')
        return
      }

      setPendingConfirmation(true)
    } catch (err) {
      console.error(err)
      setError('Ocorreu um erro inesperado. Tente novamente.')
    } finally {
      setLoading(false)
    }
  }

  if (pendingConfirmation) {
    return (
      <div className="login-container">
        <div className="login-card">
          <div className="login-header">
            <img
              src={logoImg}
              alt="Programa Capacita Portos — Profissional Portuário"
              className="login-logo"
            />
          </div>
          <div className="login-form">
            <h2>Cadastro realizado!</h2>
            <p className="forgot-description">
              Enviamos um e-mail de confirmação para você. Depois de confirmar,
              é só entrar na plataforma com o e-mail e a senha cadastrados.
            </p>
            <button className="btn-primary" onClick={() => navigate('/login')}>
              Ir para o login
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="login-container">
      <div className="login-card signup-card">
        <div className="login-header">
          <img
            src={logoImg}
            alt="Programa Capacita Portos — Profissional Portuário"
            className="login-logo"
          />
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          <h2>Criar conta</h2>

          <div className="form-group">
            <label>Nome completo</label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Nome e sobrenome"
              required
            />
          </div>

          <div className="form-group">
            <label>E-mail</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="seu@email.com"
              required
            />
          </div>

          <div className="form-group">
            <label>CPF</label>
            <input
              type="text"
              inputMode="numeric"
              value={cpf}
              onChange={(e) => setCpf(formatCpf(e.target.value))}
              placeholder="000.000.000-00"
              maxLength={14}
              required
            />
          </div>

          <div className="form-group">
            <label>Senha</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Mínimo 6 caracteres"
              minLength={6}
              required
            />
          </div>

          <div className="form-group">
            <label>Confirmar senha</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Repita a senha"
              minLength={6}
              required
            />
          </div>

          <div className="form-group">
            <label>Módulo</label>
            <div className="signup-modulo-options">
              {MODULOS_DISPONIVEIS.map((value) => (
                <label
                  key={value}
                  className={`signup-modulo-option ${publico === value ? 'selected' : ''}`}
                >
                  <input
                    type="radio"
                    name="publico"
                    value={value}
                    checked={publico === value}
                    onChange={() => setPublico(value)}
                  />
                  <span className="signup-modulo-text">
                    <span className="signup-modulo-title">{PUBLICO_LABELS[value]}</span>
                    <span className="signup-modulo-description">{PUBLICO_DESCRIPTIONS[value]}</span>
                  </span>
                </label>
              ))}
            </div>
          </div>

          {error && <div className="form-error">{error}</div>}

          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? 'Criando conta...' : 'Criar conta'}
          </button>

          <p className="toggle-auth">
            Já tem conta? <Link to="/login" className="btn-link">Entrar</Link>
          </p>
        </form>
      </div>
    </div>
  )
}
