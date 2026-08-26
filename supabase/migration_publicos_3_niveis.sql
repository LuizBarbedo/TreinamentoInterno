-- ============================================================================
-- MIGRATION: 3 públicos oficiais (Estratégico / Tático / Operacional)
-- ============================================================================
-- Substitui a segmentação anterior de PESSOAS (geral / estrategico_tatico /
-- gerencial_tecnico / operacional) pelos 3 públicos-alvo do programa:
--
--   estrategico -> Superintendentes e Diretoria Executiva
--   tatico      -> Gerentes, Coordenadores, Agentes de Contratação
--   operacional -> Técnicos, Analistas, Guarda Portuária
--
-- 'geral' continua existindo no enum, mas só como marcação de CONTEÚDO (um
-- módulo pode ser 'geral' e fica visível para os 3 públicos acima — ver
-- canSeePublico em src/lib/publicos.js). Nenhuma pessoa é cadastrada como
-- 'geral' a partir de agora.
--
-- Sem alunos reais cadastrados até o momento (apenas usuários de teste), por
-- isso os valores antigos são simplesmente resetados em vez de migrados 1:1.
--
-- Pré-requisito: migration_publicos.sql e migration_modules.sql já aplicadas.
-- ============================================================================

-- 1. Solta as colunas do enum antigo (viram TEXT temporariamente)
ALTER TABLE user_roles ALTER COLUMN publico DROP DEFAULT;
ALTER TABLE user_roles ALTER COLUMN publico TYPE TEXT USING publico::TEXT;

ALTER TABLE modules ALTER COLUMN publico DROP DEFAULT;
ALTER TABLE modules ALTER COLUMN publico TYPE TEXT USING publico::TEXT;

-- 2. Reseta valores que deixam de existir no novo enum (só usuários de teste)
UPDATE user_roles SET publico = 'estrategico' WHERE publico IN ('estrategico_tatico', 'gerencial_tecnico');
UPDATE modules SET publico = 'estrategico' WHERE publico IN ('estrategico_tatico', 'gerencial_tecnico');

-- 3. Recria o tipo enumerado com os 3 públicos + 'geral' (conteúdo aberto a todos)
DROP TYPE publico_enum;
CREATE TYPE publico_enum AS ENUM ('geral', 'estrategico', 'tatico', 'operacional');

ALTER TABLE user_roles ALTER COLUMN publico TYPE publico_enum USING publico::publico_enum;
ALTER TABLE user_roles ALTER COLUMN publico SET DEFAULT 'estrategico';

ALTER TABLE modules ALTER COLUMN publico TYPE publico_enum USING publico::publico_enum;
ALTER TABLE modules ALTER COLUMN publico SET DEFAULT 'geral';

-- 4. get_my_publico: fallback atualizado
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

-- 5. set_user_publico: valida os 3 públicos + 'geral' (o master ainda pode
--    marcar um usuário como 'geral' manualmente se precisar, mas não é mais
--    oferecido no autocadastro)
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

-- 6. get_platform_users: fallback atualizado
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

-- 7. complete_student_signup: autocadastro agora aceita os 3 públicos oficiais
--    (sem 'geral' — 'geral' é só para marcar conteúdo, não pessoas)
DROP FUNCTION IF EXISTS complete_student_signup(TEXT, TEXT);
CREATE OR REPLACE FUNCTION complete_student_signup(p_cpf TEXT, p_publico TEXT)
RETURNS VOID AS $$
DECLARE
  digits TEXT := regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF length(digits) <> 11 THEN
    RAISE EXCEPTION 'CPF inválido';
  END IF;

  IF p_publico NOT IN ('estrategico', 'tatico', 'operacional') THEN
    RAISE EXCEPTION 'Módulo inválido: %', p_publico;
  END IF;

  IF EXISTS (SELECT 1 FROM user_roles WHERE cpf = digits AND user_id <> auth.uid()) THEN
    RAISE EXCEPTION 'CPF já cadastrado';
  END IF;

  INSERT INTO user_roles (user_id, role, cpf, publico)
  VALUES (auth.uid(), 'user', digits, p_publico::publico_enum)
  ON CONFLICT (user_id) DO UPDATE
    SET cpf = COALESCE(user_roles.cpf, EXCLUDED.cpf),
        publico = CASE WHEN user_roles.cpf IS NULL THEN EXCLUDED.publico ELSE user_roles.publico END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION complete_student_signup(TEXT, TEXT) TO authenticated;
