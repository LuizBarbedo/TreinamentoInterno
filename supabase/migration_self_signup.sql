-- ============================================================================
-- MIGRATION: Cadastro público de alunos (link de inscrição)
-- ============================================================================
-- Permite que o próprio aluno crie sua conta pela página /cadastro,
-- informando nome, e-mail, senha, CPF e o módulo (geral ou estratégico e
-- tático).
--
-- Como funciona:
-- 1. O front chama supabase.auth.signUp() passando cpf/publico dentro de
--    options.data (user_metadata). Isso NÃO grava em user_roles ainda.
-- 2. No primeiro login (evento SIGNED_IN — imediato se a confirmação de
--    e-mail estiver desligada no projeto, ou após o aluno confirmar o
--    e-mail), o AuthContext chama complete_student_signup() para gravar a
--    linha em user_roles com base nesse metadata.
--
-- Pré-requisitos: migration_admin_roles.sql, migration_publicos.sql,
-- migration_cadastro_alunos.sql (coluna cpf + índice único).
-- ============================================================================

-- 1. Garantir coluna/índice de CPF (idempotente, caso ainda não existam)
ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS cpf TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_roles_cpf ON user_roles (cpf) WHERE cpf IS NOT NULL;

-- 2. Verifica se um CPF já está cadastrado. Usado no formulário de
--    inscrição ANTES de criar a conta, para dar feedback amigável.
--    Callable por anon (usuário ainda não logado nessa etapa).
DROP FUNCTION IF EXISTS cpf_is_taken(TEXT);
CREATE OR REPLACE FUNCTION cpf_is_taken(p_cpf TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  digits TEXT := regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g');
BEGIN
  RETURN EXISTS (SELECT 1 FROM user_roles WHERE cpf = digits);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION cpf_is_taken(TEXT) TO anon, authenticated;

-- 3. Finaliza o cadastro do próprio usuário autenticado: grava cpf e
--    publico em user_roles a partir dos dados informados no formulário de
--    inscrição. Sempre força role = 'user' (o aluno nunca vira admin por
--    aqui) e só aceita os módulos abertos para autocadastro.
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

  IF p_publico NOT IN ('geral', 'estrategico_tatico') THEN
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
