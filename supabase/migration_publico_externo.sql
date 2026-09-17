-- ============================================================================
-- MIGRATION: Público "Externo" (acesso irrestrito para público externo)
-- ============================================================================
-- Adiciona um 4º público de PESSOA, "externo", oferecido no autocadastro
-- (/cadastro) junto com estrategico/tatico/operacional. Diferente dos
-- demais, o público "externo" não fica restrito ao conteúdo do seu próprio
-- público: enxerga TODOS os módulos, disciplinas, aulas e quizzes da
-- plataforma (ver canSeePublico em src/lib/publicos.js, que agora dá bypass
-- total quando userPublico === 'externo').
--
-- Pré-requisito: migration_publicos_3_niveis.sql (ou setup_completo.sql) já
-- aplicada, com publico_enum = ('geral', 'estrategico', 'tatico', 'operacional').
-- ============================================================================

-- 1. Novo valor do enum. IMPORTANT: precisa rodar sozinho (sem usar o valor
--    'externo' na mesma transação) — se o seu client SQL reclamar de "unsafe
--    use of new value of enum type", rode só esta linha primeiro e o resto
--    do arquivo em seguida.
ALTER TYPE publico_enum ADD VALUE IF NOT EXISTS 'externo';

-- 2. set_user_publico (painel master): passa a aceitar 'externo' também,
--    para o master poder converter manualmente um usuário existente.
CREATE OR REPLACE FUNCTION set_user_publico(
  p_user_id UUID,
  p_publico TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas o usuário master pode alterar públicos';
  END IF;

  IF p_publico NOT IN ('geral', 'estrategico', 'tatico', 'operacional', 'externo') THEN
    RAISE EXCEPTION 'Público inválido: %', p_publico;
  END IF;

  INSERT INTO user_roles (user_id, role, publico)
  VALUES (p_user_id, 'user', p_publico::publico_enum)
  ON CONFLICT (user_id)
  DO UPDATE SET publico = EXCLUDED.publico;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. complete_student_signup (autocadastro em /cadastro): passa a aceitar
--    'externo' como um dos módulos válidos.
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

  IF p_publico NOT IN ('estrategico', 'tatico', 'operacional', 'externo') THEN
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
