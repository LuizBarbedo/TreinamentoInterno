-- ============================================
-- CADASTRO DE ALUNO: Paulo Borges
-- ============================================
-- Email: paulo.borges@cgu.gov.br
-- Senha: paulocgu
-- Perfil: aluno (role 'user', publico 'geral') + full_access=true
--   (mesmo padrão usado para mfreitas@ivig.coppe.ufrj.br: acesso
--   irrestrito a todo o conteúdo, mas SEM permissão de edição/admin)
--
-- Execute este SQL no SQL Editor do Supabase.
-- É idempotente: se o e-mail já existir, apenas atualiza a senha/nome
-- e garante a linha em user_roles.
--
-- Pré-requisito: migration_admin_roles.sql (cria user_roles)
--                migration_full_access.sql (cria a coluna full_access)
-- ============================================

DO $$
DECLARE
  new_user_id UUID;
BEGIN

  SELECT id INTO new_user_id FROM auth.users WHERE email = 'paulo.borges@cgu.gov.br';

  IF new_user_id IS NULL THEN
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      gen_random_uuid(),
      'authenticated',
      'authenticated',
      'paulo.borges@cgu.gov.br',
      crypt('paulocgu', gen_salt('bf')),
      NOW(),
      '{"provider": "email", "providers": ["email"]}',
      '{"full_name": "Paulo Borges"}',
      NOW(),
      NOW(),
      '', '', '', ''
    ) RETURNING id INTO new_user_id;
  ELSE
    -- Usuário já existe: redefine senha e nome
    UPDATE auth.users
    SET encrypted_password = crypt('paulocgu', gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        raw_user_meta_data = jsonb_set(
          COALESCE(raw_user_meta_data, '{}'::jsonb),
          '{full_name}',
          '"Paulo Borges"'::jsonb,
          true
        ),
        updated_at = NOW()
    WHERE id = new_user_id;
  END IF;

  -- Vincula a identidade de e-mail (necessária para login por senha no GoTrue)
  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  SELECT
    gen_random_uuid(),
    new_user_id,
    new_user_id::TEXT,
    jsonb_build_object(
      'sub', new_user_id::TEXT,
      'email', 'paulo.borges@cgu.gov.br',
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    NOW(), NOW(), NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM auth.identities
    WHERE user_id = new_user_id AND provider = 'email'
  );

  -- Perfil de aluno com acesso total ao conteúdo (não é admin)
  INSERT INTO public.user_roles (user_id, role, publico, full_access)
  VALUES (new_user_id, 'user', 'geral', true)
  ON CONFLICT (user_id) DO UPDATE SET role = 'user', full_access = true;

END $$;

-- ============================================
-- VERIFICAÇÃO
-- ============================================
SELECT
  u.email,
  u.raw_user_meta_data ->> 'full_name' AS nome,
  r.role,
  r.publico,
  r.full_access,
  u.email_confirmed_at IS NOT NULL AS email_confirmado,
  EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email') AS tem_identity
FROM auth.users u
LEFT JOIN public.user_roles r ON r.user_id = u.id
WHERE u.email = 'paulo.borges@cgu.gov.br';
