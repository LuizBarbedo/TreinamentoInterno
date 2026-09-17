// Públicos da plataforma (fixos). Cada funcionário pertence a um público e
// enxerga o conteúdo do seu público + o conteúdo marcado como "geral".
// 'geral' é usado apenas para marcar CONTEÚDO (módulo/disciplina) visível
// para os 3 públicos internos — nenhuma pessoa é cadastrada como 'geral'.
// 'externo' é o único público de PESSOA com acesso irrestrito: enxerga todo
// o conteúdo da plataforma, independente do público marcado no módulo.
export const PUBLICOS = ['geral', 'estrategico', 'tatico', 'operacional', 'externo']

export const PUBLICO_LABELS = {
  geral: 'Geral',
  estrategico: 'Estratégico',
  tatico: 'Tático',
  operacional: 'Operacional',
  externo: 'Externo',
}

// Descrição do público-alvo de cada nível (Quadro de Segmentação do Público-Alvo).
export const PUBLICO_DESCRIPTIONS = {
  estrategico: 'Superintendentes e Diretoria Executiva',
  tatico: 'Gerentes, Coordenadores e Agentes de Contratação',
  operacional: 'Técnicos, Analistas e Guarda Portuária',
  externo: 'Profissionais externos à Autoridade Portuária',
}

// Opções prontas para selects no painel master ({ value, label }).
export const PUBLICO_OPTIONS = PUBLICOS.map((value) => ({ value, label: PUBLICO_LABELS[value] }))

// Conteúdo "geral" é visível para todos; o público "externo" enxerga tudo;
// senão precisa bater com o público do usuário.
export function canSeePublico(userPublico, contentPublico) {
  if (!contentPublico || contentPublico === 'geral') return true
  if (userPublico === 'externo') return true
  return contentPublico === userPublico
}

// Filtra uma lista de itens (cada um com .publico) pelo público do usuário.
export function filterByPublico(items, userPublico) {
  return (items || []).filter((item) => canSeePublico(userPublico, item.publico))
}
