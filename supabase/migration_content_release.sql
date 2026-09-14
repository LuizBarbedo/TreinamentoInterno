-- ============================================================================
-- MIGRATION: Trava geral de liberação de conteúdo (content_released)
-- ============================================================================
-- Objetivo:
-- Impedir que os alunos acessem aulas, materiais e quizzes ANTES do admin
-- autorizar — para que a turma toda comece junto, mesmo que já tenham sido
-- cadastrados/logados antes disso.
--
-- Enquanto content_released = false (padrão):
--   - lessons, materials e quiz_questions ficam INVISÍVEIS para alunos (RLS)
--   - alunos não conseguem gravar progresso/resultado de quiz (RLS)
--   - disciplines continua visível (o aluno vê o que virá, mas não abre nada)
--   - admin e usuários com full_access (coordenação) continuam vendo tudo
--
-- Quando o admin liberar (UPDATE platform_settings SET content_released = true,
-- ou pelo painel em /admin/liberacao), a trava cai para todo mundo ao mesmo
-- tempo.
--
-- Pré-requisito: migration_admin_roles.sql (função is_admin())
-- ============================================================================

-- 0. Garante a coluna full_access mesmo que migration_full_access.sql ainda
--    não tenha sido rodada neste ambiente (idempotente, não afeta ninguém).
ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS full_access BOOLEAN NOT NULL DEFAULT false;

-- 1. Tabela de configuração global (linha única, id fixo = 1)
CREATE TABLE IF NOT EXISTS public.platform_settings (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  content_released BOOLEAN NOT NULL DEFAULT false,
  released_at TIMESTAMPTZ,
  updated_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.platform_settings (id, content_released)
VALUES (1, false)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read platform settings" ON public.platform_settings;
CREATE POLICY "Authenticated users can read platform settings"
  ON public.platform_settings FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admin can update platform settings" ON public.platform_settings;
CREATE POLICY "Admin can update platform settings"
  ON public.platform_settings FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- 2. Função auxiliar: admin ou usuário com full_access (coordenação) ignora a trava
CREATE OR REPLACE FUNCTION public.has_bypass_access()
RETURNS BOOLEAN AS $$
  SELECT is_admin() OR EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND full_access = true
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 3. Função auxiliar: conteúdo já foi liberado pelo admin?
CREATE OR REPLACE FUNCTION public.is_content_released()
RETURNS BOOLEAN AS $$
  SELECT COALESCE((SELECT content_released FROM public.platform_settings WHERE id = 1), false);
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 4. RPC para o painel admin trocar a trava (mais simples que expor UPDATE direto)
CREATE OR REPLACE FUNCTION public.set_content_released(p_released BOOLEAN)
RETURNS void AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Apenas administradores podem alterar a liberação de conteúdo';
  END IF;

  UPDATE public.platform_settings
  SET content_released = p_released,
      released_at = CASE WHEN p_released THEN now() ELSE NULL END,
      updated_by = auth.uid(),
      updated_at = now()
  WHERE id = 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RLS: aulas, materiais e questões só ficam visíveis após liberação
--    (ou para admin / full_access)
DROP POLICY IF EXISTS "Authenticated users can read lessons" ON public.lessons;
CREATE POLICY "Authenticated users can read lessons"
  ON public.lessons FOR SELECT
  TO authenticated
  USING (public.is_content_released() OR public.has_bypass_access());

DROP POLICY IF EXISTS "Authenticated users can read materials" ON public.materials;
CREATE POLICY "Authenticated users can read materials"
  ON public.materials FOR SELECT
  TO authenticated
  USING (public.is_content_released() OR public.has_bypass_access());

DROP POLICY IF EXISTS "Authenticated users can read quiz_questions" ON public.quiz_questions;
CREATE POLICY "Authenticated users can read quiz_questions"
  ON public.quiz_questions FOR SELECT
  TO authenticated
  USING (public.is_content_released() OR public.has_bypass_access());

-- 6. RLS: impedir que alunos gravem progresso/resultado antes da liberação
DROP POLICY IF EXISTS "Users can insert own progress" ON public.user_progress;
CREATE POLICY "Users can insert own progress"
  ON public.user_progress FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id AND (public.is_content_released() OR public.has_bypass_access()));

DROP POLICY IF EXISTS "Users can insert own quiz results" ON public.quiz_results;
CREATE POLICY "Users can insert own quiz results"
  ON public.quiz_results FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id AND (public.is_content_released() OR public.has_bypass_access()));

DROP POLICY IF EXISTS "Users can insert own lesson quiz results" ON public.lesson_quiz_results;
CREATE POLICY "Users can insert own lesson quiz results"
  ON public.lesson_quiz_results FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id AND (public.is_content_released() OR public.has_bypass_access()));

DROP POLICY IF EXISTS "Users can insert own lesson progress" ON public.lesson_progress;
CREATE POLICY "Users can insert own lesson progress"
  ON public.lesson_progress FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id AND (public.is_content_released() OR public.has_bypass_access()));

-- 7. Habilita realtime na tabela, para a trava cair para os alunos já logados
--    assim que o admin liberar, sem precisar de refresh/relogin.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'platform_settings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.platform_settings;
  END IF;
END $$;

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================
-- Deve retornar 1 linha com content_released = false (trava ativa):
SELECT * FROM public.platform_settings;

-- ============================================================================
-- COMO LIBERAR / TRAVAR NOVAMENTE (via SQL, alternativa ao painel admin)
-- ============================================================================
-- SELECT public.set_content_released(true);   -- libera para todos os alunos
-- SELECT public.set_content_released(false);  -- trava novamente
