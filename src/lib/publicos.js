// Públicos da plataforma (fixos). Cada funcionário pertence a um público e
// enxerga o conteúdo do seu público + o conteúdo marcado como "geral".
export const PUBLICOS = ['geral', 'estrategico_tatico', 'gerencial_tecnico', 'operacional']

export const PUBLICO_LABELS = {
  geral: 'Geral',
  estrategico_tatico: 'Estratégico e Tático',
  gerencial_tecnico: 'Gerencial e Técnico',
  operacional: 'Operacional',
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
