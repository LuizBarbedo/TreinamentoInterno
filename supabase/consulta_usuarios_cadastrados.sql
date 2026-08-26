-- ============================================================================
-- CONSULTA: Quem está cadastrado na plataforma
-- ============================================================================
-- Rode no SQL Editor do Supabase. Não altera nada (somente leitura).
-- ============================================================================

-- Todos os usuários, mais recentes primeiro
SELECT
  u.email,
  COALESCE(u.raw_user_meta_data ->> 'full_name', '—') AS nome,
  r.cpf,
  COALESCE(r.publico::TEXT, 'geral') AS modulo,
  COALESCE(r.role, 'user') AS perfil,
  u.created_at AS cadastrado_em,
  u.last_sign_in_at AS ultimo_login
FROM auth.users u
LEFT JOIN public.user_roles r ON r.user_id = u.id
ORDER BY u.created_at DESC;

-- ============================================================================
-- Variante: só quem se cadastrou HOJE (ex.: pra conferir quem entrou pelo link)
-- ============================================================================
-- SELECT
--   u.email,
--   COALESCE(u.raw_user_meta_data ->> 'full_name', '—') AS nome,
--   r.cpf,
--   COALESCE(r.publico::TEXT, 'geral') AS modulo,
--   u.created_at AS cadastrado_em
-- FROM auth.users u
-- LEFT JOIN public.user_roles r ON r.user_id = u.id
-- WHERE u.created_at::date = CURRENT_DATE
-- ORDER BY u.created_at DESC;
