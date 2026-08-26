-- ============================================================================
-- MIGRATION: Disciplina em múltiplos módulos (relação N:N)
-- ============================================================================
-- Até aqui, cada disciplina pertencia a NO MÁXIMO um módulo (disciplines.
-- module_id). Passa a ser possível a mesma disciplina aparecer em vários
-- módulos ao mesmo tempo (ex: uma disciplina de "Compliance" pode valer para
-- os módulos Estratégico e Tático).
--
-- Pré-requisitos: migration_modules.sql (tabelas modules/disciplines já
-- existem, com a coluna disciplines.module_id).
-- ============================================================================

-- 1. Tabela de junção módulo <-> disciplina
CREATE TABLE IF NOT EXISTS module_disciplines (
  module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  discipline_id UUID NOT NULL REFERENCES disciplines(id) ON DELETE CASCADE,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (module_id, discipline_id)
);

CREATE INDEX IF NOT EXISTS idx_module_disciplines_module_id ON module_disciplines(module_id);
CREATE INDEX IF NOT EXISTS idx_module_disciplines_discipline_id ON module_disciplines(discipline_id);

-- 2. Backfill: migra o vínculo único existente (disciplines.module_id) para a
--    tabela de junção antes de remover a coluna.
INSERT INTO module_disciplines (module_id, discipline_id, order_index)
SELECT module_id, id, order_index
FROM disciplines
WHERE module_id IS NOT NULL
ON CONFLICT (module_id, discipline_id) DO NOTHING;

-- 3. Coluna antiga não é mais necessária (relação agora vive só em module_disciplines)
ALTER TABLE disciplines DROP COLUMN IF EXISTS module_id;

-- 4. RLS: leitura para qualquer autenticado; escrita só para o master
ALTER TABLE module_disciplines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read module_disciplines" ON module_disciplines;
CREATE POLICY "Authenticated users can read module_disciplines"
  ON module_disciplines FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins can insert module_disciplines" ON module_disciplines;
CREATE POLICY "Admins can insert module_disciplines"
  ON module_disciplines FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can update module_disciplines" ON module_disciplines;
CREATE POLICY "Admins can update module_disciplines"
  ON module_disciplines FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can delete module_disciplines" ON module_disciplines;
CREATE POLICY "Admins can delete module_disciplines"
  ON module_disciplines FOR DELETE
  TO authenticated
  USING (is_admin());
