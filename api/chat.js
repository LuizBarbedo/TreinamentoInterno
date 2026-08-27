import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.VITE_SUPABASE_URL
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY
const OLLAMA_API_KEY = process.env.OLLAMA_API_KEY
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'gpt-oss:120b-cloud'

const MAX_MESSAGES = 12
const MAX_CONTENT_LENGTH = 4000

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método não permitido' })
    return
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    res.status(500).json({ error: 'Configuração do Supabase ausente no servidor' })
    return
  }

  const authHeader = req.headers.authorization || ''
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
  if (!token) {
    res.status(401).json({ error: 'Não autenticado' })
    return
  }

  const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  const { data: userData, error: authError } = await authClient.auth.getUser(token)
  if (authError || !userData?.user) {
    res.status(401).json({ error: 'Sessão inválida' })
    return
  }

  const { disciplineId, messages } = req.body || {}

  if (!disciplineId || typeof disciplineId !== 'string') {
    res.status(400).json({ error: 'disciplineId é obrigatório' })
    return
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    res.status(400).json({ error: 'messages é obrigatório' })
    return
  }

  const sanitizedMessages = messages
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string' && m.content.trim())
    .slice(-MAX_MESSAGES)
    .map((m) => ({ role: m.role, content: m.content.slice(0, MAX_CONTENT_LENGTH) }))

  if (sanitizedMessages.length === 0) {
    res.status(400).json({ error: 'Nenhuma mensagem válida' })
    return
  }

  if (!OLLAMA_API_KEY) {
    res.status(500).json({ error: 'Chat de IA não configurado no servidor' })
    return
  }

  const scopedClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  })

  const [{ data: discipline }, { data: lessons }, { data: materials }] = await Promise.all([
    scopedClient.from('disciplines').select('name, description').eq('id', disciplineId).single(),
    scopedClient.from('lessons').select('title, description').eq('discipline_id', disciplineId).order('order_index'),
    scopedClient.from('materials').select('title, type').eq('discipline_id', disciplineId)
  ])

  const lessonsList = (lessons || [])
    .map((l, i) => `${i + 1}. ${l.title}${l.description ? ' — ' + l.description : ''}`)
    .join('\n') || 'Nenhuma aula cadastrada.'

  const materialsList = (materials || [])
    .map((m) => `- ${m.title} (${m.type})`)
    .join('\n') || 'Nenhum material cadastrado.'

  const systemPrompt = `Você é um assistente de estudos da plataforma Capacita Portos, especializado na disciplina "${discipline?.name || 'desconhecida'}".
Descrição da disciplina: ${discipline?.description || 'sem descrição'}

Aulas da disciplina:
${lessonsList}

Materiais de apoio:
${materialsList}

Responda sempre em português, de forma clara e didática, apenas dúvidas relacionadas ao tema desta disciplina. Se a pergunta fugir do escopo da disciplina, oriente educadamente o aluno a perguntar algo relacionado ao conteúdo. Se não tiver informação suficiente para responder com precisão, diga isso e sugira que o aluno consulte o material da disciplina ou um administrador, em vez de inventar uma resposta.`

  try {
    const ollamaResponse = await fetch('https://ollama.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OLLAMA_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        messages: [{ role: 'system', content: systemPrompt }, ...sanitizedMessages]
      })
    })

    if (!ollamaResponse.ok) {
      console.error('Erro na Ollama Cloud:', ollamaResponse.status, await ollamaResponse.text())
      res.status(502).json({ error: 'Não foi possível obter resposta da IA no momento.' })
      return
    }

    const data = await ollamaResponse.json()
    const reply = data?.choices?.[0]?.message?.content

    if (!reply) {
      res.status(502).json({ error: 'Resposta da IA veio vazia.' })
      return
    }

    res.status(200).json({ reply })
  } catch (err) {
    console.error('Erro ao chamar Ollama Cloud:', err)
    res.status(500).json({ error: 'Erro interno ao processar a pergunta.' })
  }
}
