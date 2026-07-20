-- ============================================================================
-- MIGRATION: Acesso total ao conteúdo (full_access)
-- ============================================================================
-- Objetivo:
-- Permitir que perfis específicos (coordenação) naveguem por TODO o conteúdo
-- sem as duas travas que existem hoje na plataforma:
--   1. Filtro de público (só vê módulos do seu público + os 'geral')
--   2. Travas sequenciais (aula N exige aula N-1; disciplina N exige N-1;
--      quiz final exige todas as aulas e quizzes de aula concluídos)
--
-- IMPORTANTE:
-- - O padrão é FALSE, então nenhum aluno existente é afetado.
-- - Isto NÃO torna o usuário admin: ele continua sem o painel master e
--   sem permissão de editar conteúdo.
-- - As travas são aplicadas no frontend, então esta coluna só tem efeito
--   após o deploy das alterações em src/ (AuthContext, Disciplines,
--   DisciplineDetail, Dashboard, Quiz).
--
-- Pré-requisito: migration_admin_roles.sql (cria user_roles)
--                cadastro_aluno_marcos_freitas.sql (cria o usuário)
-- ============================================================================

-- 1. Coluna de acesso total (default false = comportamento atual para todos)
ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS full_access BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.user_roles.full_access IS
  'Quando true, o usuário enxerga todos os módulos/disciplinas e ignora as travas sequenciais. Uso: coordenação que precisa revisar o conteúdo sem cursá-lo.';

-- 2. Conceder acesso total apenas ao coordenador Marcos Freitas
UPDATE public.user_roles
SET full_access = true
WHERE user_id = (
  SELECT id FROM auth.users WHERE email = 'mfreitas@ivig.coppe.ufrj.br'
);

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================
-- Deve retornar exatamente 1 linha (mfreitas@ivig.coppe.ufrj.br):
SELECT u.email, r.role, r.publico, r.full_access
FROM public.user_roles r
JOIN auth.users u ON u.id = r.user_id
WHERE r.full_access = true;

-- ============================================================================
-- COMO REVOGAR
-- ============================================================================
-- UPDATE public.user_roles SET full_access = false
-- WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mfreitas@ivig.coppe.ufrj.br');
