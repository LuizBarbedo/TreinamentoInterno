-- ============================================================================
-- Migração: Públicos (segmentação de conteúdo por público-alvo)
-- ============================================================================
-- Cada funcionário pertence a UM público e enxerga o conteúdo do seu público
-- + o conteúdo marcado como "geral".
--
-- Públicos das PESSOAS (3, conforme segmentação oficial do programa):
--   estrategico -> Superintendentes e Diretoria Executiva
--   tatico      -> Gerentes, Coordenadores, Agentes de Contratação
--   operacional -> Técnicos, Analistas, Guarda Portuária
--
-- 'geral' existe no enum apenas para marcar CONTEÚDO (módulo/disciplina)
-- visível para os 3 públicos acima — nenhuma pessoa é cadastrada como 'geral'.
--
-- Padrão: todos os usuários iniciam em 'estrategico'. O master pode alterar depois.
-- Pré-requisito: migration_admin_roles.sql (cria user_roles e is_admin()).
-- ============================================================================

-- 1. Tipo enumerado de públicos
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'publico_enum') THEN
    CREATE TYPE publico_enum AS ENUM ('geral', 'estrategico', 'tatico', 'operacional');
  END IF;
END$$;

-- 2. Coluna em user_roles (default estrategico)
ALTER TABLE user_roles
  ADD COLUMN IF NOT EXISTS publico publico_enum NOT NULL DEFAULT 'estrategico';

-- 3. Garantir que todos os usuários existentes tenham linha em user_roles
INSERT INTO user_roles (user_id, role, publico)
SELECT u.id, 'user', 'estrategico'
FROM auth.users u
LEFT JOIN user_roles r ON r.user_id = u.id
WHERE r.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

-- 4. Função para o próprio usuário ler seu público
CREATE OR REPLACE FUNCTION get_my_publico()
RETURNS TEXT AS $$
DECLARE
  p TEXT;
BEGIN
  SELECT publico::TEXT INTO p
  FROM user_roles
  WHERE user_id = auth.uid();

  RETURN COALESCE(p, 'estrategico');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Função do master para definir o público de um usuário
CREATE OR REPLACE FUNCTION set_user_publico(
  p_user_id UUID,
  p_publico TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas o usuário master pode alterar públicos';
  END IF;

  IF p_publico NOT IN ('geral', 'estrategico', 'tatico', 'operacional') THEN
    RAISE EXCEPTION 'Público inválido: %', p_publico;
  END IF;

  INSERT INTO user_roles (user_id, role, publico)
  VALUES (p_user_id, 'user', p_publico::publico_enum)
  ON CONFLICT (user_id)
  DO UPDATE SET publico = EXCLUDED.publico;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. get_platform_users passa a retornar 'publico' no lugar de 'access_level'
DROP FUNCTION IF EXISTS get_platform_users();
CREATE OR REPLACE FUNCTION get_platform_users()
RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ,
  last_sign_in_at TIMESTAMPTZ,
  role TEXT,
  publico TEXT
) AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores podem acessar esta função';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.email::TEXT,
    COALESCE(u.raw_user_meta_data ->> 'full_name', u.email::TEXT)::TEXT AS full_name,
    u.created_at,
    u.last_sign_in_at,
    COALESCE(r.role, 'user')::TEXT AS role,
    COALESCE(r.publico::TEXT, 'estrategico') AS publico
  FROM auth.users u
  LEFT JOIN user_roles r ON r.user_id = u.id
  ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
