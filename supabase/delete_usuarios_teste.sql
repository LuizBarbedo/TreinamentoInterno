-- ============================================================================
-- Exclui usuários de teste específicos (por e-mail)
-- ============================================================================
-- Cole no SQL Editor do Supabase e RUN.
--
-- Deletar de auth.users é suficiente: user_roles, quiz_results, user_progress,
-- lesson_quiz_results etc. têm FK "ON DELETE CASCADE" para auth.users, então
-- todo o histórico desses 2 usuários some junto automaticamente.
-- ============================================================================

-- 1. Conferir quem vai ser excluído (rode antes e confira o resultado)
SELECT id, email, created_at
FROM auth.users
WHERE email IN ('barbedoluizfelipe@gmail.com', 'barbedoluiz@gmail.com');

-- 2. Exclusão (descomente e rode depois de confirmar acima)
-- DELETE FROM auth.users
-- WHERE email IN ('barbedoluizfelipe@gmail.com', 'barbedoluiz@gmail.com');
