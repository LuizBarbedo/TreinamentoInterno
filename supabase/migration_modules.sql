-- ============================================================================
-- Migração: Módulos (hierarquia Público -> Módulos -> Disciplinas -> Aulas)
-- ============================================================================
-- Introduz a camada de módulos acima das disciplinas. Cada módulo pertence a
-- um público; as disciplinas passam a pertencer a um módulo e herdam o
-- público do módulo. O filtro por público é aplicado na aplicação.
--
-- Pré-requisitos: schema.sql (disciplines), migration_admin_roles.sql
-- (is_admin()) e migration_publicos.sql (publico_enum).
-- ============================================================================

-- 1. Tabela de Módulos
CREATE TABLE IF NOT EXISTS modules (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT DEFAULT '📦',
  publico publico_enum NOT NULL DEFAULT 'geral',
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Disciplinas passam a referenciar um módulo
ALTER TABLE disciplines
  ADD COLUMN IF NOT EXISTS module_id UUID REFERENCES modules(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_disciplines_module_id ON disciplines(module_id);

-- 3. RLS: qualquer autenticado lê os módulos (filtro por público na aplicação)
ALTER TABLE modules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read modules" ON modules;
CREATE POLICY "Authenticated users can read modules"
  ON modules FOR SELECT
  TO authenticated
  USING (true);

-- 4. RLS: apenas o master gerencia módulos
DROP POLICY IF EXISTS "Admins can insert modules" ON modules;
CREATE POLICY "Admins can insert modules"
  ON modules FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can update modules" ON modules;
CREATE POLICY "Admins can update modules"
  ON modules FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can delete modules" ON modules;
CREATE POLICY "Admins can delete modules"
  ON modules FOR DELETE
  TO authenticated
  USING (is_admin());
