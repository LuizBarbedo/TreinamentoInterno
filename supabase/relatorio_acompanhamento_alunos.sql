-- ============================================================================
-- RELATÓRIO: Acompanhamento de Alunos (visão geral + individual)
-- ============================================================================
-- Gera, em UMA única chamada, todos os dados necessários para montar o
-- relatório de acompanhamento de alunos em PDF: perfil, progresso em vídeo
-- aulas, quizzes (por aula e final da disciplina), Atividade Prática
-- (entrega/nota/devolutiva), Sugestões da disciplina, participação no
-- Fórum, uso do Chat de IA ("Dúvidas") e badges/ranking de gamificação.
--
-- Pré-requisitos: setup_completo.sql (ou todas as migrations individuais)
-- já aplicado, incluindo migration_practical_activity.sql,
-- migration_discipline_suggestions.sql, migration_forum.sql,
-- migration_ai_chat_history.sql, migration_badge_ranking.sql e
-- migration_publicos_3_niveis.sql / migration_publico_externo.sql.
--
-- COMO USAR
-- 1. Cole este arquivo inteiro no SQL Editor do Supabase e RUN (cria a
--    função — idempotente, pode rodar de novo quando quiser atualizar).
-- 2. Em uma nova query, rode apenas:
--
--      select get_relatorio_acompanhamento_alunos();
--
-- 3. O resultado é UMA linha / UMA coluna com um JSON gigante. Clique na
--    célula do resultado para abrir o visualizador de JSON do Supabase e
--    use o botão de copiar para copiar o conteúdo INTEGRAL (não é truncado
--    pela visualização em grade). Salve isso num arquivo `relatorio_dados.json`.
-- 4. Use esse arquivo com o script `relatorios/gerar_relatorio_pdf.py`
--    (ver `relatorios/README.md`) para gerar o PDF final.
--
-- Só o usuário master/admin pode executar esta função (mesma regra de
-- is_admin() usada no restante da plataforma).
-- ============================================================================

CREATE OR REPLACE FUNCTION get_relatorio_acompanhamento_alunos()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSON;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas o administrador pode gerar este relatório';
  END IF;

  WITH
  -- ----------------------------------------------------------------------
  -- Base para o cálculo de badges (mesma lógica de migration_badge_ranking.sql,
  -- mas SEM o LIMIT 50, para não perder nenhum aluno no relatório).
  -- ----------------------------------------------------------------------
  total_disc AS (
    SELECT COUNT(*)::BIGINT AS cnt FROM disciplines
  ),
  disc_lesson_counts AS (
    SELECT l.discipline_id, COUNT(*)::BIGINT AS total_lessons
    FROM lessons l
    GROUP BY l.discipline_id
  ),
  user_disc_progress AS (
    SELECT lp.user_id, lp.discipline_id, COUNT(DISTINCT lp.lesson_id)::BIGINT AS completed_lessons
    FROM lesson_progress lp
    GROUP BY lp.user_id, lp.discipline_id
  ),
  b_lesson_complete AS (
    SELECT lp.user_id, COUNT(*)::BIGINT AS cnt FROM lesson_progress lp GROUP BY lp.user_id
  ),
  b_quiz_done AS (
    SELECT lqr.user_id, COUNT(*)::BIGINT AS cnt FROM lesson_quiz_results lqr GROUP BY lqr.user_id
  ),
  b_quiz_perfect AS (
    SELECT lqr.user_id, COUNT(*)::BIGINT AS cnt FROM lesson_quiz_results lqr
    WHERE lqr.score = 100 GROUP BY lqr.user_id
  ),
  b_all_lessons AS (
    SELECT udp.user_id, COUNT(*)::BIGINT AS cnt
    FROM user_disc_progress udp
    JOIN disc_lesson_counts dlc ON dlc.discipline_id = udp.discipline_id
    WHERE udp.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
    GROUP BY udp.user_id
  ),
  b_final_quiz AS (
    SELECT qr.user_id, COUNT(*)::BIGINT AS cnt FROM quiz_results qr
    WHERE qr.score >= 70 GROUP BY qr.user_id
  ),
  b_disc_complete AS (
    SELECT udp.user_id, COUNT(*)::BIGINT AS cnt
    FROM user_disc_progress udp
    JOIN disc_lesson_counts dlc ON dlc.discipline_id = udp.discipline_id
    JOIN quiz_results qr ON qr.user_id = udp.user_id AND qr.discipline_id = udp.discipline_id AND qr.score >= 70
    WHERE udp.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
    GROUP BY udp.user_id
  ),
  b_all_disc AS (
    SELECT sub.user_id, 1::BIGINT AS cnt
    FROM (
      SELECT udp.user_id
      FROM user_disc_progress udp
      JOIN disc_lesson_counts dlc ON dlc.discipline_id = udp.discipline_id
      JOIN quiz_results qr ON qr.user_id = udp.user_id AND qr.discipline_id = udp.discipline_id AND qr.score >= 70
      WHERE udp.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
      GROUP BY udp.user_id
      HAVING COUNT(DISTINCT udp.discipline_id) >= (SELECT cnt FROM total_disc) AND (SELECT cnt FROM total_disc) > 0
    ) sub
  ),
  badges AS (
    SELECT
      u.id AS user_id,
      (
        COALESCE(blc.cnt, 0) + COALESCE(bqd.cnt, 0) + COALESCE(bqp.cnt, 0) +
        COALESCE(bal.cnt, 0) + COALESCE(bfq.cnt, 0) + COALESCE(bdc.cnt, 0) + COALESCE(bad.cnt, 0)
      )::BIGINT AS badge_count
    FROM auth.users u
    LEFT JOIN b_lesson_complete blc ON blc.user_id = u.id
    LEFT JOIN b_quiz_done bqd ON bqd.user_id = u.id
    LEFT JOIN b_quiz_perfect bqp ON bqp.user_id = u.id
    LEFT JOIN b_all_lessons bal ON bal.user_id = u.id
    LEFT JOIN b_final_quiz bfq ON bfq.user_id = u.id
    LEFT JOIN b_disc_complete bdc ON bdc.user_id = u.id
    LEFT JOIN b_all_disc bad ON bad.user_id = u.id
  ),
  -- ----------------------------------------------------------------------
  -- Alunos = todo usuário que não tem role 'admin' (monitores entram como
  -- aluno no relatório, já que também consomem o conteúdo).
  -- ----------------------------------------------------------------------
  students AS (
    SELECT
      u.id,
      u.email,
      u.created_at,
      u.last_sign_in_at,
      COALESCE(u.raw_user_meta_data ->> 'full_name', split_part(u.email::text, '@', 1)) AS full_name,
      ur.cpf,
      COALESCE(ur.publico::text, 'estrategico') AS publico,
      COALESCE(ur.full_access, false) AS full_access
    FROM auth.users u
    LEFT JOIN user_roles ur ON ur.user_id = u.id
    WHERE NOT EXISTS (
      SELECT 1 FROM user_roles ur2 WHERE ur2.user_id = u.id AND ur2.role = 'admin'
    )
  ),
  ranking AS (
    SELECT
      s.id AS user_id,
      s.full_name,
      COALESCE(b.badge_count, 0) AS badge_count,
      RANK() OVER (ORDER BY COALESCE(b.badge_count, 0) DESC) AS posicao
    FROM students s
    LEFT JOIN badges b ON b.user_id = s.id
  )
  SELECT json_build_object(
    'gerado_em', now(),

    -- ====================================================================
    -- VISÃO GERAL DA PLATAFORMA
    -- ====================================================================
    'plataforma', json_build_object(
      'total_alunos', (SELECT COUNT(*) FROM students),
      'total_modulos', (SELECT COUNT(*) FROM modules),
      'total_disciplinas', (SELECT COUNT(*) FROM disciplines),
      'total_aulas', (SELECT COUNT(*) FROM lessons),
      'total_atividades_praticas_cadastradas', (SELECT COUNT(*) FROM practical_activities),
      'total_submissoes_praticas', (SELECT COUNT(*) FROM practical_submissions),
      'submissoes_praticas_pendentes', (SELECT COUNT(*) FROM practical_submissions WHERE status = 'pendente'),
      'submissoes_praticas_avaliadas', (SELECT COUNT(*) FROM practical_submissions WHERE status = 'avaliada'),
      'total_sugestoes', (SELECT COUNT(*) FROM discipline_suggestions),
      'sugestoes_pendentes', (SELECT COUNT(*) FROM discipline_suggestions WHERE status = 'pendente'),
      'total_posts_forum', (SELECT COUNT(*) FROM forum_posts),
      'total_respostas_forum', (SELECT COUNT(*) FROM forum_replies),
      'total_mensagens_chat_ia', (SELECT COUNT(*) FROM discipline_chat_messages WHERE role = 'user'),
      'media_nota_quiz_final', (SELECT COALESCE(ROUND(AVG(score)::numeric, 1), 0) FROM quiz_results),
      'media_nota_quiz_aula', (SELECT COALESCE(ROUND(AVG(score)::numeric, 1), 0) FROM lesson_quiz_results),
      'alunos_que_concluiram_ao_menos_1_disciplina', (
        SELECT COUNT(DISTINCT user_id) FROM user_progress WHERE completed = true
      ),
      'alunos_sem_nenhuma_atividade_registrada', (
        SELECT COUNT(*) FROM students s WHERE NOT EXISTS (
          SELECT 1 FROM lesson_progress lp WHERE lp.user_id = s.id
          UNION ALL SELECT 1 FROM lesson_quiz_results lq WHERE lq.user_id = s.id
          UNION ALL SELECT 1 FROM quiz_results qr WHERE qr.user_id = s.id
          UNION ALL SELECT 1 FROM practical_submissions ps WHERE ps.user_id = s.id
        )
      )
    ),

    -- ====================================================================
    -- RANKING DE BADGES (gamificação) — todos os alunos com badge > 0
    -- ====================================================================
    'ranking_badges', (
      SELECT json_agg(json_build_object(
        'posicao', posicao, 'nome', full_name, 'badges', badge_count
      ) ORDER BY posicao, full_name)
      FROM ranking WHERE badge_count > 0
    ),

    -- ====================================================================
    -- VISÃO GERAL POR DISCIPLINA
    -- ====================================================================
    'disciplinas_overview', (
      SELECT json_agg(json_build_object(
        'nome', d.name,
        'total_aulas', COALESCE(dlc.total_lessons, 0),
        'alunos_com_atividade', (
          SELECT COUNT(DISTINCT uid) FROM (
            SELECT user_id AS uid FROM lesson_progress WHERE discipline_id = d.id
            UNION SELECT user_id FROM lesson_quiz_results WHERE discipline_id = d.id
            UNION SELECT user_id FROM quiz_results WHERE discipline_id = d.id
          ) x
        ),
        'alunos_concluiram', (
          SELECT COUNT(*) FROM user_progress up WHERE up.discipline_id = d.id AND up.completed = true
        ),
        'media_quiz_final', (
          SELECT COALESCE(ROUND(AVG(score)::numeric, 1), 0) FROM quiz_results WHERE discipline_id = d.id
        ),
        'taxa_aprovacao_quiz_final_pct', (
          SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                      ELSE ROUND((COUNT(*) FILTER (WHERE score >= 70))::numeric / COUNT(*) * 100, 1)
                 END
          FROM quiz_results WHERE discipline_id = d.id
        ),
        'submissoes_atividade_pratica', (
          SELECT COUNT(*) FROM practical_submissions WHERE discipline_id = d.id
        ),
        'sugestoes_recebidas', (
          SELECT COUNT(*) FROM discipline_suggestions WHERE discipline_id = d.id
        )
      ) ORDER BY d.order_index)
      FROM disciplines d
      LEFT JOIN disc_lesson_counts dlc ON dlc.discipline_id = d.id
    ),

    -- ====================================================================
    -- RELATÓRIO INDIVIDUAL POR ALUNO
    -- ====================================================================
    'alunos', (
      SELECT json_agg(student_json ORDER BY student_json -> 'perfil' ->> 'nome')
      FROM (
        SELECT json_build_object(

          'perfil', json_build_object(
            'id', s.id,
            'nome', s.full_name,
            'email', s.email,
            'cpf', s.cpf,
            'publico', s.publico,
            'acesso_irrestrito', s.full_access,
            'cadastrado_em', s.created_at,
            'ultimo_acesso', s.last_sign_in_at
          ),

          'resumo', json_build_object(
            'badges', COALESCE(b.badge_count, 0),
            'posicao_ranking_badges', r.posicao,
            'disciplinas_concluidas', (
              SELECT COUNT(*) FROM user_progress up WHERE up.user_id = s.id AND up.completed = true
            ),
            'disciplinas_com_atividade', (
              SELECT COUNT(DISTINCT uid) FROM (
                SELECT discipline_id AS uid FROM lesson_progress WHERE user_id = s.id
                UNION SELECT discipline_id FROM lesson_quiz_results WHERE user_id = s.id
                UNION SELECT discipline_id FROM quiz_results WHERE user_id = s.id
              ) x
            ),
            'total_aulas_concluidas', (SELECT COUNT(*) FROM lesson_progress WHERE user_id = s.id),
            'media_quiz_final', (SELECT ROUND(AVG(score)::numeric, 1) FROM quiz_results WHERE user_id = s.id),
            'media_quiz_aula', (SELECT ROUND(AVG(score)::numeric, 1) FROM lesson_quiz_results WHERE user_id = s.id),
            'total_submissoes_praticas', (SELECT COUNT(*) FROM practical_submissions WHERE user_id = s.id),
            'total_sugestoes_enviadas', (SELECT COUNT(*) FROM discipline_suggestions WHERE user_id = s.id),
            'total_posts_forum', (SELECT COUNT(*) FROM forum_posts WHERE user_id = s.id),
            'total_respostas_forum', (SELECT COUNT(*) FROM forum_replies WHERE user_id = s.id),
            'total_mensagens_chat_ia', (
              SELECT COUNT(*) FROM discipline_chat_messages WHERE user_id = s.id AND role = 'user'
            )
          ),

          -- Progresso detalhado, só das disciplinas em que o aluno teve
          -- QUALQUER atividade (aula, quiz, atividade prática ou sugestão).
          'disciplinas', (
            SELECT json_agg(json_build_object(
              'nome', d.name,
              'aulas_concluidas', COALESCE(udp.completed_lessons, 0),
              'total_aulas', COALESCE(dlc.total_lessons, 0),
              'quiz_final', (
                SELECT json_build_object(
                  'nota', qr.score, 'corretas', qr.correct_answers, 'total', qr.total_questions,
                  'aprovado', qr.score >= 70, 'respondido_em', qr.completed_at
                )
                FROM quiz_results qr WHERE qr.user_id = s.id AND qr.discipline_id = d.id
              ),
              'quizzes_por_aula', (
                SELECT json_agg(json_build_object(
                  'aula', l.title, 'nota', lqr.score, 'corretas', lqr.correct_answers,
                  'total', lqr.total_questions, 'respondido_em', lqr.completed_at
                ) ORDER BY l.order_index)
                FROM lesson_quiz_results lqr
                JOIN lessons l ON l.id = lqr.lesson_id
                WHERE lqr.user_id = s.id AND lqr.discipline_id = d.id
              ),
              'atividade_pratica', (
                SELECT json_build_object(
                  'titulo_atividade', pa.title,
                  'status', COALESCE(ps.status, 'nao_enviada'),
                  'tipo_entrega', ps.submission_type,
                  'nome_arquivo', ps.file_name,
                  'nota', ps.grade,
                  'devolutiva_admin', ps.feedback,
                  'enviado_em', ps.submitted_at,
                  'avaliado_em', ps.graded_at
                )
                FROM practical_activities pa
                LEFT JOIN practical_submissions ps ON ps.activity_id = pa.id AND ps.user_id = s.id
                WHERE pa.discipline_id = d.id
              ),
              'sugestoes_enviadas', (
                SELECT json_agg(json_build_object(
                  'conteudo', ds.content, 'status', ds.status,
                  'resposta_admin', ds.admin_response, 'enviado_em', ds.created_at
                ) ORDER BY ds.created_at)
                FROM discipline_suggestions ds WHERE ds.user_id = s.id AND ds.discipline_id = d.id
              ),
              'mensagens_chat_ia', (
                SELECT COUNT(*) FROM discipline_chat_messages dcm
                WHERE dcm.user_id = s.id AND dcm.discipline_id = d.id AND dcm.role = 'user'
              )
            ) ORDER BY d.order_index)
            FROM disciplines d
            LEFT JOIN disc_lesson_counts dlc ON dlc.discipline_id = d.id
            LEFT JOIN user_disc_progress udp ON udp.discipline_id = d.id AND udp.user_id = s.id
            WHERE EXISTS (SELECT 1 FROM lesson_progress WHERE user_id = s.id AND discipline_id = d.id)
               OR EXISTS (SELECT 1 FROM lesson_quiz_results WHERE user_id = s.id AND discipline_id = d.id)
               OR EXISTS (SELECT 1 FROM quiz_results WHERE user_id = s.id AND discipline_id = d.id)
               OR EXISTS (SELECT 1 FROM practical_submissions WHERE user_id = s.id AND discipline_id = d.id)
               OR EXISTS (SELECT 1 FROM discipline_suggestions WHERE user_id = s.id AND discipline_id = d.id)
          ),

          'forum', json_build_object(
            'posts_criados', (
              SELECT json_agg(json_build_object(
                'titulo', fp.title, 'categoria', fp.category, 'disciplina', d2.name,
                'criado_em', fp.created_at,
                'curtidas_recebidas', (SELECT COUNT(*) FROM forum_post_likes WHERE post_id = fp.id),
                'respostas_recebidas', (SELECT COUNT(*) FROM forum_replies WHERE post_id = fp.id)
              ) ORDER BY fp.created_at)
              FROM forum_posts fp LEFT JOIN disciplines d2 ON d2.id = fp.discipline_id
              WHERE fp.user_id = s.id
            ),
            'respostas_dadas', (
              SELECT json_agg(json_build_object(
                'post_titulo', fp2.title, 'trecho', left(fr.content, 200),
                'marcada_como_solucao', fr.is_solution, 'criado_em', fr.created_at
              ) ORDER BY fr.created_at)
              FROM forum_replies fr JOIN forum_posts fp2 ON fp2.id = fr.post_id
              WHERE fr.user_id = s.id
            ),
            'curtidas_dadas', (
              (SELECT COUNT(*) FROM forum_post_likes WHERE user_id = s.id) +
              (SELECT COUNT(*) FROM forum_reply_likes WHERE user_id = s.id)
            ),
            'curtidas_recebidas', (
              (SELECT COUNT(*) FROM forum_post_likes fpl JOIN forum_posts fp3 ON fp3.id = fpl.post_id WHERE fp3.user_id = s.id) +
              (SELECT COUNT(*) FROM forum_reply_likes frl JOIN forum_replies fr2 ON fr2.id = frl.reply_id WHERE fr2.user_id = s.id)
            )
          ),

          'chat_ia', json_build_object(
            'total_mensagens_enviadas', (
              SELECT COUNT(*) FROM discipline_chat_messages WHERE user_id = s.id AND role = 'user'
            ),
            'ultima_interacao', (SELECT MAX(created_at) FROM discipline_chat_messages WHERE user_id = s.id),
            'por_disciplina', (
              SELECT json_agg(json_build_object('disciplina', d3.name, 'mensagens', cnt) ORDER BY cnt DESC)
              FROM (
                SELECT discipline_id, COUNT(*) AS cnt FROM discipline_chat_messages
                WHERE user_id = s.id AND role = 'user'
                GROUP BY discipline_id
              ) x
              JOIN disciplines d3 ON d3.id = x.discipline_id
            )
          )

        ) AS student_json
        FROM students s
        LEFT JOIN badges b ON b.user_id = s.id
        LEFT JOIN ranking r ON r.user_id = s.id
      ) all_students
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_relatorio_acompanhamento_alunos() TO authenticated;
