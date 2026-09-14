-- ============================================
-- MIGRATION: Sugestões da Disciplina (Aba nas Disciplinas)
-- ============================================
-- Adiciona a aba "Sugestões" às disciplinas:
--   - Aluno envia sugestões/comentários sobre a matéria, conteúdo, aulas etc.
--   - As sugestões ficam vinculadas à disciplina, para que futuramente cada
--     professor (com login próprio por disciplina) possa visualizá-las e responder.
--   - Por enquanto, apenas a criação pela ponta do aluno está em uso; a
--     visualização/resposta pelo admin já fica prevista no RLS e na RPC abaixo.
--
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
-- ============================================

-- ============================================
-- 1. TABELA: discipline_suggestions
-- ============================================
CREATE TABLE IF NOT EXISTS discipline_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  discipline_id UUID NOT NULL REFERENCES disciplines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pendente',   -- 'pendente' | 'respondida'
  admin_response TEXT,                       -- resposta do professor/admin
  responded_by UUID REFERENCES auth.users(id),
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discipline_suggestions_discipline
  ON discipline_suggestions(discipline_id);
CREATE INDEX IF NOT EXISTS idx_discipline_suggestions_user
  ON discipline_suggestions(user_id);

-- ============================================
-- 2. RLS: discipline_suggestions
-- ============================================
ALTER TABLE discipline_suggestions ENABLE ROW LEVEL SECURITY;

-- O aluno lê as próprias sugestões; o admin lê todas
DROP POLICY IF EXISTS "Read own or admin suggestions" ON discipline_suggestions;
CREATE POLICY "Read own or admin suggestions"
  ON discipline_suggestions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_admin());

-- O aluno cria a própria sugestão
DROP POLICY IF EXISTS "Insert own suggestion" ON discipline_suggestions;
CREATE POLICY "Insert own suggestion"
  ON discipline_suggestions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Apenas o admin responde/atualiza sugestões
DROP POLICY IF EXISTS "Admin can update suggestions" ON discipline_suggestions;
CREATE POLICY "Admin can update suggestions"
  ON discipline_suggestions FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- O aluno apaga a própria sugestão; o admin pode apagar qualquer uma
DROP POLICY IF EXISTS "Delete own or admin suggestion" ON discipline_suggestions;
CREATE POLICY "Delete own or admin suggestion"
  ON discipline_suggestions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id OR is_admin());

-- ============================================
-- 3. RPC: listar sugestões de uma disciplina com o nome do aluno (somente admin)
-- ============================================
CREATE OR REPLACE FUNCTION get_discipline_suggestions(p_discipline_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  full_name TEXT,
  email TEXT,
  content TEXT,
  status TEXT,
  admin_response TEXT,
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores podem acessar esta função';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.user_id,
    COALESCE(u.raw_user_meta_data ->> 'full_name', u.email::TEXT)::TEXT AS full_name,
    u.email::TEXT,
    s.content,
    s.status,
    s.admin_response,
    s.responded_at,
    s.created_at
  FROM discipline_suggestions s
  JOIN auth.users u ON u.id = s.user_id
  WHERE s.discipline_id = p_discipline_id
  ORDER BY s.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
