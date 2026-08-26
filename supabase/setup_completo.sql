-- ============================================================
-- SETUP COMPLETO — Plataforma de Treinamento Interno
-- ============================================================
-- Instalacao limpa (banco NOVO, SEM alunos e SEM dados de exemplo).
-- Como usar: cole este arquivo inteiro no SQL Editor do Supabase e RUN.
--
-- IDEMPOTENTE: pode ser re-executado sem erro (DROP POLICY IF EXISTS
-- antes de cada CREATE POLICY; IF NOT EXISTS em tabelas/indices).
-- NAO inclui: ~700 alunos antigos nem dados de exemplo. Apenas a coluna
-- CPF e criada (cadastro futuro: login = email, senha = CPF).
-- ============================================================


-- ============================================================
-- >>> schema.sql
-- ============================================================
-- ============================================
-- SCHEMA DO SUPABASE - Plataforma de Treinamento
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
-- ============================================

-- 1. Tabela de Disciplinas
CREATE TABLE IF NOT EXISTS disciplines (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT DEFAULT '📚',
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabela de Aulas (vídeos)
CREATE TABLE IF NOT EXISTS lessons (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  video_url TEXT,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabela de Materiais (livros, artigos, PDFs)
CREATE TABLE IF NOT EXISTS materials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  type TEXT DEFAULT 'link',  -- 'livro', 'artigo', 'pdf', 'link'
  url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabela de Questões do Quiz
-- Se lesson_id for NULL = questão do quiz geral da disciplina (10 perguntas)
-- Se lesson_id preenchido = questão do quiz da aula (3 perguntas)
CREATE TABLE IF NOT EXISTS quiz_questions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE, -- NULL = quiz geral, preenchido = quiz da aula
  question TEXT NOT NULL,
  options JSONB NOT NULL,       -- Array de strings: ["Opção A", "Opção B", "Opção C", "Opção D"]
  correct_option INTEGER NOT NULL, -- Índice da resposta correta (0, 1, 2, 3)
  correction_comment TEXT,      -- Comentário de correção exibido após o quiz ser finalizado
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Tabela de Resultados do Quiz
CREATE TABLE IF NOT EXISTS quiz_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  score INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  correct_answers INTEGER NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, discipline_id)
);

-- 6. Tabela de Progresso do Aluno
CREATE TABLE IF NOT EXISTS user_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, discipline_id)
);

-- 7. Tabela de Resultados do Quiz por Aula
CREATE TABLE IF NOT EXISTS lesson_quiz_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  score INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  correct_answers INTEGER NOT NULL,
  passed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE disciplines ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_quiz_results ENABLE ROW LEVEL SECURITY;

-- Disciplinas, aulas, materiais e questões: qualquer usuário autenticado pode ler
DROP POLICY IF EXISTS "Authenticated users can read disciplines" ON disciplines;
CREATE POLICY "Authenticated users can read disciplines"
  ON disciplines FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can read lessons" ON lessons;
CREATE POLICY "Authenticated users can read lessons"
  ON lessons FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can read materials" ON materials;
CREATE POLICY "Authenticated users can read materials"
  ON materials FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can read quiz_questions" ON quiz_questions;
CREATE POLICY "Authenticated users can read quiz_questions"
  ON quiz_questions FOR SELECT
  TO authenticated
  USING (true);

-- Quiz results: usuário só vê/edita os seus próprios
DROP POLICY IF EXISTS "Users can read own quiz results" ON quiz_results;
CREATE POLICY "Users can read own quiz results"
  ON quiz_results FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own quiz results" ON quiz_results;
CREATE POLICY "Users can insert own quiz results"
  ON quiz_results FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own quiz results" ON quiz_results;
CREATE POLICY "Users can update own quiz results"
  ON quiz_results FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Progress: usuário só vê/edita o seu próprio progresso
DROP POLICY IF EXISTS "Users can read own progress" ON user_progress;
CREATE POLICY "Users can read own progress"
  ON user_progress FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own progress" ON user_progress;
CREATE POLICY "Users can insert own progress"
  ON user_progress FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own progress" ON user_progress;
CREATE POLICY "Users can update own progress"
  ON user_progress FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Lesson quiz results: usuário só vê/edita os seus próprios
DROP POLICY IF EXISTS "Users can read own lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Users can read own lesson quiz results"
  ON lesson_quiz_results FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Users can insert own lesson quiz results"
  ON lesson_quiz_results FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Users can update own lesson quiz results"
  ON lesson_quiz_results FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);


-- ============================================================
-- >>> migration_admin_roles.sql
-- ============================================================
-- ============================================
-- MIGRATION: Sistema de Roles (Admin/User)
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- APÓS ter executado o schema.sql principal
-- ============================================

-- 1. Tabela de Roles de Usuário
CREATE TABLE IF NOT EXISTS user_roles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- 2. Função helper para verificar se o usuário é admin
--    Verifica o email do master admin OU a role na tabela user_roles
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    (auth.jwt() ->> 'email') = 'aplicacao.treinamento@gmail.com'
    OR EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Políticas de leitura para user_roles
DROP POLICY IF EXISTS "Users can read own role" ON user_roles;
CREATE POLICY "Users can read own role"
  ON user_roles FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin can read all roles" ON user_roles;
CREATE POLICY "Admin can read all roles"
  ON user_roles FOR SELECT
  TO authenticated
  USING (is_admin());

DROP POLICY IF EXISTS "Admin can manage roles" ON user_roles;
CREATE POLICY "Admin can manage roles"
  ON user_roles FOR ALL
  TO authenticated
  USING (is_admin());

-- 4. Se o usuário master já existe, inserir role admin agora
-- (Se ele ainda não existir, a função is_admin() já reconhece pelo email)
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin' FROM auth.users WHERE email = 'aplicacao.treinamento@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET role = 'admin';

-- ============================================
-- POLÍTICAS DE ADMIN PARA GERENCIAR CONTEÚDO
-- ============================================

-- DISCIPLINAS: Admin pode INSERT, UPDATE, DELETE
DROP POLICY IF EXISTS "Admin can insert disciplines" ON disciplines;
CREATE POLICY "Admin can insert disciplines"
  ON disciplines FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admin can update disciplines" ON disciplines;
CREATE POLICY "Admin can update disciplines"
  ON disciplines FOR UPDATE
  TO authenticated
  USING (is_admin());

DROP POLICY IF EXISTS "Admin can delete disciplines" ON disciplines;
CREATE POLICY "Admin can delete disciplines"
  ON disciplines FOR DELETE
  TO authenticated
  USING (is_admin());

-- AULAS: Admin pode INSERT, UPDATE, DELETE
DROP POLICY IF EXISTS "Admin can insert lessons" ON lessons;
CREATE POLICY "Admin can insert lessons"
  ON lessons FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admin can update lessons" ON lessons;
CREATE POLICY "Admin can update lessons"
  ON lessons FOR UPDATE
  TO authenticated
  USING (is_admin());

DROP POLICY IF EXISTS "Admin can delete lessons" ON lessons;
CREATE POLICY "Admin can delete lessons"
  ON lessons FOR DELETE
  TO authenticated
  USING (is_admin());

-- MATERIAIS: Admin pode INSERT, UPDATE, DELETE
DROP POLICY IF EXISTS "Admin can insert materials" ON materials;
CREATE POLICY "Admin can insert materials"
  ON materials FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admin can update materials" ON materials;
CREATE POLICY "Admin can update materials"
  ON materials FOR UPDATE
  TO authenticated
  USING (is_admin());

DROP POLICY IF EXISTS "Admin can delete materials" ON materials;
CREATE POLICY "Admin can delete materials"
  ON materials FOR DELETE
  TO authenticated
  USING (is_admin());

-- QUESTÕES DO QUIZ: Admin pode INSERT, UPDATE, DELETE
DROP POLICY IF EXISTS "Admin can insert quiz_questions" ON quiz_questions;
CREATE POLICY "Admin can insert quiz_questions"
  ON quiz_questions FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admin can update quiz_questions" ON quiz_questions;
CREATE POLICY "Admin can update quiz_questions"
  ON quiz_questions FOR UPDATE
  TO authenticated
  USING (is_admin());

DROP POLICY IF EXISTS "Admin can delete quiz_questions" ON quiz_questions;
CREATE POLICY "Admin can delete quiz_questions"
  ON quiz_questions FOR DELETE
  TO authenticated
  USING (is_admin());


-- ============================================================
-- >>> migration_lesson_progress.sql
-- ============================================================
-- ============================================
-- MIGRATION: Tabela de progresso por aula
-- Execute no SQL Editor do Supabase
-- ============================================

-- Tabela para rastrear quais aulas o aluno completou
CREATE TABLE IF NOT EXISTS lesson_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

-- Habilitar RLS
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;

-- Políticas: usuário só vê/edita o seu próprio progresso
DROP POLICY IF EXISTS "Users can read own lesson progress" ON lesson_progress;
CREATE POLICY "Users can read own lesson progress"
  ON lesson_progress FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own lesson progress" ON lesson_progress;
CREATE POLICY "Users can insert own lesson progress"
  ON lesson_progress FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own lesson progress" ON lesson_progress;
CREATE POLICY "Users can delete own lesson progress"
  ON lesson_progress FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);


-- ============================================================
-- >>> migration_lesson_quiz.sql
-- ============================================================
-- ============================================
-- MIGRATION: Quiz por aula + Quiz geral da disciplina
-- Execute no SQL Editor do Supabase
-- ============================================

-- 1. Adicionar lesson_id à tabela quiz_questions
-- Perguntas com lesson_id = quiz da aula (3 perguntas)
-- Perguntas sem lesson_id (NULL) = quiz geral da disciplina (10 perguntas)
ALTER TABLE quiz_questions ADD COLUMN IF NOT EXISTS lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE;

-- 2. Tabela de resultados do quiz por aula
CREATE TABLE IF NOT EXISTS lesson_quiz_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  score INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  correct_answers INTEGER NOT NULL,
  passed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

-- Habilitar RLS
ALTER TABLE lesson_quiz_results ENABLE ROW LEVEL SECURITY;

-- Políticas: usuário só vê/edita os seus próprios resultados
DROP POLICY IF EXISTS "Users can read own lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Users can read own lesson quiz results"
  ON lesson_quiz_results FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Users can insert own lesson quiz results"
  ON lesson_quiz_results FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Users can update own lesson quiz results"
  ON lesson_quiz_results FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================
-- EXEMPLO: Quiz por aula (3 perguntas cada)
-- ============================================
-- Para adicionar perguntas a uma aula específica:
--
-- INSERT INTO quiz_questions (discipline_id, lesson_id, question, options, correct_option, order_index)
-- SELECT d.id, l.id,
--   'Qual é o conceito principal desta aula?',
--   '["Opção A", "Opção B", "Opção C", "Opção D"]',
--   0, 1
-- FROM disciplines d
-- JOIN lessons l ON l.discipline_id = d.id
-- WHERE d.name = 'Nome da Disciplina'
-- AND l.title = 'Título da Aula';
--
-- Para o quiz geral da disciplina (10 perguntas), insira SEM lesson_id:
--
-- INSERT INTO quiz_questions (discipline_id, question, options, correct_option, order_index)
-- VALUES ('discipline-uuid', 'Pergunta?', '["A","B","C","D"]', 0, 1);


-- ============================================================
-- >>> migration_correction_comments.sql
-- ============================================================
-- ============================================
-- MIGRATION: Comentários de correção nas questões do quiz
-- Execute no SQL Editor do Supabase
-- ============================================

-- Adicionar coluna correction_comment à tabela quiz_questions
-- Este campo armazena o comentário de correção que aparece
-- ao aluno quando ele finaliza o quiz (apenas após enviar respostas)
ALTER TABLE quiz_questions ADD COLUMN IF NOT EXISTS correction_comment TEXT;


-- ============================================================
-- >>> migration_admin_reports.sql
-- ============================================================
-- ============================================
-- MIGRATION: Relatórios Admin (Visão Master)
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- APÓS ter executado as migrations anteriores
-- ============================================

-- 1. Políticas para Admin ler TODOS os dados de progresso/resultados
-- (Necessário para o relatório geral de usuários)

-- Admin pode ler todo o progresso de usuários
DROP POLICY IF EXISTS "Admin can read all user progress" ON user_progress;
CREATE POLICY "Admin can read all user progress"
  ON user_progress FOR SELECT
  TO authenticated
  USING (is_admin());

-- Admin pode ler todos os resultados de quiz
DROP POLICY IF EXISTS "Admin can read all quiz results" ON quiz_results;
CREATE POLICY "Admin can read all quiz results"
  ON quiz_results FOR SELECT
  TO authenticated
  USING (is_admin());

-- Admin pode ler todos os resultados de quiz por aula
DROP POLICY IF EXISTS "Admin can read all lesson quiz results" ON lesson_quiz_results;
CREATE POLICY "Admin can read all lesson quiz results"
  ON lesson_quiz_results FOR SELECT
  TO authenticated
  USING (is_admin());

-- Admin pode ler todo o progresso de aulas
DROP POLICY IF EXISTS "Admin can read all lesson progress" ON lesson_progress;
CREATE POLICY "Admin can read all lesson progress"
  ON lesson_progress FOR SELECT
  TO authenticated
  USING (is_admin());

-- 2. Função segura para obter lista de usuários (somente admin)
-- Retorna dados básicos dos usuários da plataforma
DROP FUNCTION IF EXISTS get_platform_users();
CREATE OR REPLACE FUNCTION get_platform_users()
RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ,
  last_sign_in_at TIMESTAMPTZ
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
    u.last_sign_in_at
  FROM auth.users u
  ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Função para obter estatísticas gerais da plataforma (somente admin)
CREATE OR REPLACE FUNCTION get_platform_stats()
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores podem acessar esta função';
  END IF;

  SELECT json_build_object(
    'total_users', (SELECT COUNT(*) FROM auth.users),
    'total_disciplines', (SELECT COUNT(*) FROM disciplines),
    'total_lessons', (SELECT COUNT(*) FROM lessons),
    'total_quiz_questions', (SELECT COUNT(*) FROM quiz_questions),
    'completed_disciplines', (SELECT COUNT(*) FROM user_progress WHERE completed = true),
    'quiz_attempts', (SELECT COUNT(*) FROM quiz_results),
    'lesson_quiz_attempts', (SELECT COUNT(*) FROM lesson_quiz_results),
    'avg_quiz_score', (SELECT COALESCE(ROUND(AVG(score)::numeric, 1), 0) FROM quiz_results),
    'avg_lesson_quiz_score', (SELECT COALESCE(ROUND(AVG(score)::numeric, 1), 0) FROM lesson_quiz_results)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- >>> migration_publicos.sql
-- ============================================================
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


-- ============================================================
-- >>> migration_modules.sql
-- ============================================================
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
DROP POLICY IF EXISTS "Authenticated users can read modules" ON modules;
CREATE POLICY "Authenticated users can read modules"
  ON modules FOR SELECT
  TO authenticated
  USING (true);

-- 4. RLS: apenas o master gerencia módulos
DROP POLICY IF EXISTS "Admins can insert modules" ON modules;
DROP POLICY IF EXISTS "Admins can insert modules" ON modules;
CREATE POLICY "Admins can insert modules"
  ON modules FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can update modules" ON modules;
DROP POLICY IF EXISTS "Admins can update modules" ON modules;
CREATE POLICY "Admins can update modules"
  ON modules FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can delete modules" ON modules;
DROP POLICY IF EXISTS "Admins can delete modules" ON modules;
CREATE POLICY "Admins can delete modules"
  ON modules FOR DELETE
  TO authenticated
  USING (is_admin());


-- ============================================================
-- >>> migration_module_disciplines_many.sql
-- ============================================================
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
DROP POLICY IF EXISTS "Authenticated users can read module_disciplines" ON module_disciplines;
CREATE POLICY "Authenticated users can read module_disciplines"
  ON module_disciplines FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins can insert module_disciplines" ON module_disciplines;
DROP POLICY IF EXISTS "Admins can insert module_disciplines" ON module_disciplines;
CREATE POLICY "Admins can insert module_disciplines"
  ON module_disciplines FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can update module_disciplines" ON module_disciplines;
DROP POLICY IF EXISTS "Admins can update module_disciplines" ON module_disciplines;
CREATE POLICY "Admins can update module_disciplines"
  ON module_disciplines FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can delete module_disciplines" ON module_disciplines;
DROP POLICY IF EXISTS "Admins can delete module_disciplines" ON module_disciplines;
CREATE POLICY "Admins can delete module_disciplines"
  ON module_disciplines FOR DELETE
  TO authenticated
  USING (is_admin());


-- ============================================================
-- >>> migration_badge_ranking.sql
-- ============================================================
-- ============================================
-- MIGRATION: Ranking de Badges dos Alunos
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- APÓS ter executado as migrations anteriores
-- ============================================

-- Função para calcular o ranking de badges de todos os alunos
-- Pode ser chamada por qualquer usuário autenticado
CREATE OR REPLACE FUNCTION get_badge_ranking()
RETURNS TABLE (
  user_id UUID,
  user_name TEXT,
  badge_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH
  -- Total de disciplinas na plataforma
  total_disc AS (
    SELECT COUNT(*)::BIGINT AS cnt FROM disciplines
  ),
  -- Contagem de aulas por disciplina
  disc_lesson_counts AS (
    SELECT l.discipline_id, COUNT(*)::BIGINT AS total_lessons
    FROM lessons l
    GROUP BY l.discipline_id
  ),
  -- Progresso por disciplina por usuário
  user_disc_progress AS (
    SELECT lp.user_id, lp.discipline_id, COUNT(DISTINCT lp.lesson_id)::BIGINT AS completed_lessons
    FROM lesson_progress lp
    GROUP BY lp.user_id, lp.discipline_id
  ),
  -- 1. lesson_complete: 1 badge por aula concluída
  b_lesson_complete AS (
    SELECT lp.user_id, COUNT(*)::BIGINT AS cnt
    FROM lesson_progress lp
    GROUP BY lp.user_id
  ),
  -- 2. lesson_quiz_done: 1 badge por quiz de aula respondido
  b_quiz_done AS (
    SELECT lqr.user_id, COUNT(*)::BIGINT AS cnt
    FROM lesson_quiz_results lqr
    GROUP BY lqr.user_id
  ),
  -- 3. lesson_quiz_perfect: 1 badge por quiz de aula com 100%
  b_quiz_perfect AS (
    SELECT lqr.user_id, COUNT(*)::BIGINT AS cnt
    FROM lesson_quiz_results lqr
    WHERE lqr.score = 100
    GROUP BY lqr.user_id
  ),
  -- 4. all_lessons_complete: 1 badge por disciplina com todas as aulas concluídas
  b_all_lessons AS (
    SELECT udp.user_id, COUNT(*)::BIGINT AS cnt
    FROM user_disc_progress udp
    JOIN disc_lesson_counts dlc ON dlc.discipline_id = udp.discipline_id
    WHERE udp.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
    GROUP BY udp.user_id
  ),
  -- 5. final_quiz_complete: 1 badge por quiz geral aprovado (score >= 70)
  b_final_quiz AS (
    SELECT qr.user_id, COUNT(*)::BIGINT AS cnt
    FROM quiz_results qr
    WHERE qr.score >= 70
    GROUP BY qr.user_id
  ),
  -- 6. discipline_complete: 1 badge por disciplina com todas as aulas + quiz geral aprovado
  b_disc_complete AS (
    SELECT udp.user_id, COUNT(*)::BIGINT AS cnt
    FROM user_disc_progress udp
    JOIN disc_lesson_counts dlc ON dlc.discipline_id = udp.discipline_id
    JOIN quiz_results qr ON qr.user_id = udp.user_id AND qr.discipline_id = udp.discipline_id AND qr.score >= 70
    WHERE udp.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
    GROUP BY udp.user_id
  ),
  -- 7. all_disciplines_complete: 1 badge se completou TODAS as disciplinas
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
  -- Unir todos os usuários que têm pelo menos 1 badge
  all_users AS (
    SELECT DISTINCT u_id AS uid FROM (
      SELECT blc.user_id AS u_id FROM b_lesson_complete blc
      UNION SELECT bqd.user_id FROM b_quiz_done bqd
      UNION SELECT bqp.user_id FROM b_quiz_perfect bqp
      UNION SELECT bal.user_id FROM b_all_lessons bal
      UNION SELECT bfq.user_id FROM b_final_quiz bfq
      UNION SELECT bdc.user_id FROM b_disc_complete bdc
      UNION SELECT bad.user_id FROM b_all_disc bad
    ) sub
  )
  SELECT
    au.uid AS user_id,
    COALESCE(u.raw_user_meta_data ->> 'full_name', split_part(u.email::TEXT, '@', 1))::TEXT AS user_name,
    (
      COALESCE(blc.cnt, 0) + COALESCE(bqd.cnt, 0) + COALESCE(bqp.cnt, 0) +
      COALESCE(bal.cnt, 0) + COALESCE(bfq.cnt, 0) + COALESCE(bdc.cnt, 0) + COALESCE(bad.cnt, 0)
    )::BIGINT AS badge_count
  FROM all_users au
  JOIN auth.users u ON u.id = au.uid
  LEFT JOIN b_lesson_complete blc ON blc.user_id = au.uid
  LEFT JOIN b_quiz_done bqd ON bqd.user_id = au.uid
  LEFT JOIN b_quiz_perfect bqp ON bqp.user_id = au.uid
  LEFT JOIN b_all_lessons bal ON bal.user_id = au.uid
  LEFT JOIN b_final_quiz bfq ON bfq.user_id = au.uid
  LEFT JOIN b_disc_complete bdc ON bdc.user_id = au.uid
  LEFT JOIN b_all_disc bad ON bad.user_id = au.uid
  -- Excluir admins e monitores
  WHERE NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id = au.uid AND ur.role IN ('admin', 'monitor')
  )
  ORDER BY badge_count DESC, user_name ASC
  LIMIT 50;
END;
$$;

-- Permitir que usuários autenticados chamem a função
GRANT EXECUTE ON FUNCTION get_badge_ranking() TO authenticated;

-- ============================================
-- Função para ranking de badges por disciplina
-- Desempate por qualidade dos badges (diamond=4, gold=3, silver=2, bronze=1)
-- ============================================
CREATE OR REPLACE FUNCTION get_discipline_badge_ranking(p_discipline_id UUID)
RETURNS TABLE (
  user_id UUID,
  user_name TEXT,
  badge_count BIGINT,
  tier_score BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH
  -- Contagem de aulas da disciplina
  disc_lesson_count AS (
    SELECT COUNT(*)::BIGINT AS total_lessons
    FROM lessons l
    WHERE l.discipline_id = p_discipline_id
  ),
  -- Progresso por usuário nesta disciplina
  user_progress AS (
    SELECT lp.user_id, COUNT(DISTINCT lp.lesson_id)::BIGINT AS completed_lessons
    FROM lesson_progress lp
    WHERE lp.discipline_id = p_discipline_id
    GROUP BY lp.user_id
  ),
  -- 1. lesson_complete (bronze=1): 1 por aula concluída
  b_lesson_complete AS (
    SELECT lp.user_id, COUNT(*)::BIGINT AS cnt, COUNT(*)::BIGINT * 1 AS score
    FROM lesson_progress lp
    WHERE lp.discipline_id = p_discipline_id
    GROUP BY lp.user_id
  ),
  -- 2. lesson_quiz_done (bronze=1): 1 por quiz de aula respondido
  b_quiz_done AS (
    SELECT lqr.user_id, COUNT(*)::BIGINT AS cnt, COUNT(*)::BIGINT * 1 AS score
    FROM lesson_quiz_results lqr
    WHERE lqr.discipline_id = p_discipline_id
    GROUP BY lqr.user_id
  ),
  -- 3. lesson_quiz_perfect (gold=3): 1 por quiz com 100%
  b_quiz_perfect AS (
    SELECT lqr.user_id, COUNT(*)::BIGINT AS cnt, COUNT(*)::BIGINT * 3 AS score
    FROM lesson_quiz_results lqr
    WHERE lqr.discipline_id = p_discipline_id AND lqr.score = 100
    GROUP BY lqr.user_id
  ),
  -- 4. all_lessons_complete (silver=2): 1 se completou todas as aulas
  b_all_lessons AS (
    SELECT up.user_id, 1::BIGINT AS cnt, 2::BIGINT AS score
    FROM user_progress up, disc_lesson_count dlc
    WHERE up.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
  ),
  -- 5. final_quiz_complete (silver=2): 1 se aprovado no quiz geral
  b_final_quiz AS (
    SELECT qr.user_id, 1::BIGINT AS cnt, 2::BIGINT AS score
    FROM quiz_results qr
    WHERE qr.discipline_id = p_discipline_id AND qr.score >= 70
  ),
  -- 6. discipline_complete (gold=3): 1 se completou aulas + quiz geral
  b_disc_complete AS (
    SELECT up.user_id, 1::BIGINT AS cnt, 3::BIGINT AS score
    FROM user_progress up
    JOIN disc_lesson_count dlc ON true
    JOIN quiz_results qr ON qr.user_id = up.user_id AND qr.discipline_id = p_discipline_id AND qr.score >= 70
    WHERE up.completed_lessons >= dlc.total_lessons AND dlc.total_lessons > 0
  ),
  -- Juntar todos os usuários com atividade nesta disciplina
  all_users AS (
    SELECT DISTINCT u_id AS uid FROM (
      SELECT blc.user_id AS u_id FROM b_lesson_complete blc
      UNION SELECT bqd.user_id FROM b_quiz_done bqd
      UNION SELECT bqp.user_id FROM b_quiz_perfect bqp
      UNION SELECT bal.user_id FROM b_all_lessons bal
      UNION SELECT bfq.user_id FROM b_final_quiz bfq
      UNION SELECT bdc.user_id FROM b_disc_complete bdc
    ) sub
  )
  SELECT
    au.uid AS user_id,
    COALESCE(u.raw_user_meta_data ->> 'full_name', split_part(u.email::TEXT, '@', 1))::TEXT AS user_name,
    (
      COALESCE(blc.cnt, 0) + COALESCE(bqd.cnt, 0) + COALESCE(bqp.cnt, 0) +
      COALESCE(bal.cnt, 0) + COALESCE(bfq.cnt, 0) + COALESCE(bdc.cnt, 0)
    )::BIGINT AS badge_count,
    (
      COALESCE(blc.score, 0) + COALESCE(bqd.score, 0) + COALESCE(bqp.score, 0) +
      COALESCE(bal.score, 0) + COALESCE(bfq.score, 0) + COALESCE(bdc.score, 0)
    )::BIGINT AS tier_score
  FROM all_users au
  JOIN auth.users u ON u.id = au.uid
  LEFT JOIN b_lesson_complete blc ON blc.user_id = au.uid
  LEFT JOIN b_quiz_done bqd ON bqd.user_id = au.uid
  LEFT JOIN b_quiz_perfect bqp ON bqp.user_id = au.uid
  LEFT JOIN b_all_lessons bal ON bal.user_id = au.uid
  LEFT JOIN b_final_quiz bfq ON bfq.user_id = au.uid
  LEFT JOIN b_disc_complete bdc ON bdc.user_id = au.uid
  -- Excluir admins e monitores
  WHERE NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id = au.uid AND ur.role IN ('admin', 'monitor')
  )
  ORDER BY badge_count DESC, tier_score DESC, user_name ASC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION get_discipline_badge_ranking(UUID) TO authenticated;


-- ============================================================
-- >>> migration_forum.sql
-- ============================================================
-- ============================================
-- MIGRATION: Fórum de Discussão
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
-- ============================================

-- 1. Tabela de Posts do Fórum
CREATE TABLE IF NOT EXISTS forum_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT DEFAULT 'discussao', -- 'pergunta', 'discussao', 'insight'
  is_pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabela de Respostas/Comentários do Fórum
CREATE TABLE IF NOT EXISTS forum_replies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  is_solution BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabela de Curtidas em Posts
CREATE TABLE IF NOT EXISTS forum_post_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- 4. Tabela de Curtidas em Respostas
CREATE TABLE IF NOT EXISTS forum_reply_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reply_id UUID REFERENCES forum_replies(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(reply_id, user_id)
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_reply_likes ENABLE ROW LEVEL SECURITY;

-- Forum Posts: todos autenticados podem ler
DROP POLICY IF EXISTS "Authenticated users can read forum posts" ON forum_posts;
CREATE POLICY "Authenticated users can read forum posts"
  ON forum_posts FOR SELECT
  TO authenticated
  USING (true);

-- Forum Posts: autenticados podem criar
DROP POLICY IF EXISTS "Authenticated users can create forum posts" ON forum_posts;
CREATE POLICY "Authenticated users can create forum posts"
  ON forum_posts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Forum Posts: autor pode atualizar
DROP POLICY IF EXISTS "Users can update own forum posts" ON forum_posts;
CREATE POLICY "Users can update own forum posts"
  ON forum_posts FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Forum Posts: autor pode deletar
DROP POLICY IF EXISTS "Users can delete own forum posts" ON forum_posts;
CREATE POLICY "Users can delete own forum posts"
  ON forum_posts FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Forum Replies: todos autenticados podem ler
DROP POLICY IF EXISTS "Authenticated users can read forum replies" ON forum_replies;
CREATE POLICY "Authenticated users can read forum replies"
  ON forum_replies FOR SELECT
  TO authenticated
  USING (true);

-- Forum Replies: autenticados podem criar
DROP POLICY IF EXISTS "Authenticated users can create forum replies" ON forum_replies;
CREATE POLICY "Authenticated users can create forum replies"
  ON forum_replies FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Forum Replies: autor pode atualizar
DROP POLICY IF EXISTS "Users can update own forum replies" ON forum_replies;
CREATE POLICY "Users can update own forum replies"
  ON forum_replies FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Forum Replies: autor pode deletar
DROP POLICY IF EXISTS "Users can delete own forum replies" ON forum_replies;
CREATE POLICY "Users can delete own forum replies"
  ON forum_replies FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Post Likes: todos autenticados podem ler
DROP POLICY IF EXISTS "Authenticated users can read post likes" ON forum_post_likes;
CREATE POLICY "Authenticated users can read post likes"
  ON forum_post_likes FOR SELECT
  TO authenticated
  USING (true);

-- Post Likes: autenticados podem criar
DROP POLICY IF EXISTS "Authenticated users can like posts" ON forum_post_likes;
CREATE POLICY "Authenticated users can like posts"
  ON forum_post_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Post Likes: autor pode remover like
DROP POLICY IF EXISTS "Users can remove own post likes" ON forum_post_likes;
CREATE POLICY "Users can remove own post likes"
  ON forum_post_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Reply Likes: todos autenticados podem ler
DROP POLICY IF EXISTS "Authenticated users can read reply likes" ON forum_reply_likes;
CREATE POLICY "Authenticated users can read reply likes"
  ON forum_reply_likes FOR SELECT
  TO authenticated
  USING (true);

-- Reply Likes: autenticados podem criar
DROP POLICY IF EXISTS "Authenticated users can like replies" ON forum_reply_likes;
CREATE POLICY "Authenticated users can like replies"
  ON forum_reply_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Reply Likes: autor pode remover like
DROP POLICY IF EXISTS "Users can remove own reply likes" ON forum_reply_likes;
CREATE POLICY "Users can remove own reply likes"
  ON forum_reply_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================
-- ÍNDICES para performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_forum_posts_discipline ON forum_posts(discipline_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_user ON forum_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_created ON forum_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_replies_post ON forum_replies(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_replies_user ON forum_replies(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_post_likes_post ON forum_post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_reply_likes_reply ON forum_reply_likes(reply_id);


-- ============================================================
-- >>> migration_forum_usernames.sql
-- ============================================================
-- ============================================
-- MIGRATION: Função para buscar nomes de usuários no fórum
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
-- ============================================

-- Função que retorna nomes de usuários a partir de seus IDs
-- Qualquer usuário autenticado pode chamar (apenas expõe nomes)
CREATE OR REPLACE FUNCTION get_user_names(p_user_ids UUID[])
RETURNS TABLE (
  user_id UUID,
  full_name TEXT
) AS $$
BEGIN
  -- Apenas usuários autenticados
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    COALESCE(u.raw_user_meta_data ->> 'full_name', u.email::TEXT)::TEXT AS full_name
  FROM auth.users u
  WHERE u.id = ANY(p_user_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- >>> migration_forum_admin_delete.sql
-- ============================================================
-- ============================================
-- MIGRATION: Permitir que admin exclua posts e respostas do fórum
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
--
-- Pré-requisitos:
--   - migration_forum.sql       (cria forum_posts / forum_replies)
--   - migration_admin_roles.sql (cria a função is_admin())
-- ============================================

-- Forum Posts: admin pode deletar qualquer post
DROP POLICY IF EXISTS "Admin can delete any forum post" ON forum_posts;
DROP POLICY IF EXISTS "Admin can delete any forum post" ON forum_posts;
CREATE POLICY "Admin can delete any forum post"
  ON forum_posts FOR DELETE
  TO authenticated
  USING (is_admin());

-- Forum Replies: admin pode deletar qualquer resposta
DROP POLICY IF EXISTS "Admin can delete any forum reply" ON forum_replies;
DROP POLICY IF EXISTS "Admin can delete any forum reply" ON forum_replies;
CREATE POLICY "Admin can delete any forum reply"
  ON forum_replies FOR DELETE
  TO authenticated
  USING (is_admin());


-- ============================================================
-- >>> migration_materials_upload.sql
-- ============================================================
-- ============================================
-- MIGRATION: Suporte a Upload de Arquivos em Materiais
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
-- ============================================

-- 1. Adicionar coluna file_path à tabela materials
-- (armazena o caminho do arquivo no Supabase Storage para possibilitar exclusão)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS file_path TEXT;

-- 2. Criar bucket de Storage para materiais
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'materials',
  'materials',
  true,
  52428800, -- 50MB limite
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]::text[]
)
ON CONFLICT (id) DO NOTHING;

-- 3. Políticas de Storage

-- Qualquer usuário autenticado pode LER (download) os materiais
DROP POLICY IF EXISTS "Authenticated users can read materials files" ON storage.objects;
CREATE POLICY "Authenticated users can read materials files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'materials');

-- Qualquer usuário autenticado pode fazer UPLOAD
-- (Na prática, apenas admins terão acesso à tela de upload)
DROP POLICY IF EXISTS "Authenticated users can upload materials files" ON storage.objects;
CREATE POLICY "Authenticated users can upload materials files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'materials');

-- Qualquer usuário autenticado pode DELETAR
-- (Na prática, apenas admins terão acesso à funcionalidade de deletar)
DROP POLICY IF EXISTS "Authenticated users can delete materials files" ON storage.objects;
CREATE POLICY "Authenticated users can delete materials files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'materials');

-- Acesso público para leitura (para URLs públicas funcionarem)
DROP POLICY IF EXISTS "Public can read materials files" ON storage.objects;
CREATE POLICY "Public can read materials files"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'materials');


-- ============================================================
-- >>> migration_self_signup.sql
-- ============================================================
-- ============================================================================
-- MIGRATION: Cadastro público de alunos (link de inscrição)
-- ============================================================================
-- Permite que o próprio aluno crie sua conta pela página /cadastro,
-- informando nome, e-mail, senha, CPF e o módulo (estratégico, tático ou
-- operacional).
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


-- ============================================================
-- >>> migration_cadastro_alunos.sql (APENAS PARTE 1 — coluna CPF)
-- Os ~700 cadastros antigos (PARTE 2) foram intencionalmente omitidos.
-- ============================================================
-- ============================================
-- MIGRATION: Adicionar campo CPF e cadastrar alunos
-- ============================================
-- Execute este SQL no SQL Editor do Supabase
-- APÓS ter executado as migrations anteriores
-- ============================================

-- ============================================
-- PARTE 1: Adicionar coluna CPF à tabela user_roles
-- ============================================

ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS cpf TEXT;

-- Índice único para evitar CPFs duplicados (ignora NULLs)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_roles_cpf ON user_roles (cpf) WHERE cpf IS NOT NULL;
