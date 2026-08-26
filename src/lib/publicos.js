// Públicos da plataforma (fixos). Cada funcionário pertence a um público e
// enxerga o conteúdo do seu público + o conteúdo marcado como "geral".
// 'geral' é usado apenas para marcar CONTEÚDO (módulo/disciplina) visível
// para os 3 públicos abaixo — nenhuma pessoa é cadastrada como 'geral'.
export const PUBLICOS = ['geral', 'estrategico', 'tatico', 'operacional']

export const PUBLICO_LABELS = {
  geral: 'Geral',
  estrategico: 'Estratégico',
  tatico: 'Tático',
  operacional: 'Operacional',
}

// Descrição do público-alvo de cada nível (Quadro de Segmentação do Público-Alvo).
export const PUBLICO_DESCRIPTIONS = {
  estrategico: 'Superintendentes e Diretoria Executiva',
  tatico: 'Gerentes, Coordenadores e Agentes de Contratação',
  operacional: 'Técnicos, Analistas e Guarda Portuária',
}

// Opções prontas para selects no painel master ({ value, label }).
export const PUBLICO_OPTIONS = PUBLICOS.map((value) => ({ value, label: PUBLICO_LABELS[value] }))

// Conteúdo "geral" é visível para todos; senão precisa bater com o público do usuário.
export function canSeePublico(userPublico, contentPublico) {
  if (!contentPublico || contentPublico === 'geral') return true
  return contentPublico === userPublico
}

// Filtra uma lista de itens (cada um com .publico) pelo público do usuário.
export function filterByPublico(items, userPublico) {
  return (items || []).filter((item) => canSeePublico(userPublico, item.publico))
}
