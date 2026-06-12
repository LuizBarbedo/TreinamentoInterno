-- ============================================
-- MIGRATION: Atividade Prática (Aba nas Disciplinas)
-- ============================================
-- Adiciona a aba "Atividade Prática" às disciplinas:
--   - Admin cadastra UMA atividade por disciplina (instruções + PDF de apoio)
--   - Aluno entrega a atividade enviando um arquivo .docx OU escrevendo direto na plataforma
--   - Admin visualiza as entregas e pode dar devolutiva (nota + comentário)
--
-- Execute este SQL no SQL Editor do Supabase
-- (Dashboard > SQL Editor > New query)
-- ============================================

-- ============================================
-- 1. TABELA: practical_activities
-- (uma atividade prática por disciplina)
-- ============================================
CREATE TABLE IF NOT EXISTS practical_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  discipline_id UUID NOT NULL REFERENCES disciplines(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Atividade Prática',
  instructions TEXT,            -- enunciado/instruções da atividade (texto)
  file_path TEXT,               -- caminho do PDF no Storage (para exclusão)
  file_url TEXT,                -- URL pública do PDF de apoio
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (discipline_id)        -- garante apenas uma atividade por disciplina
);

CREATE INDEX IF NOT EXISTS idx_practical_activities_discipline
  ON practical_activities(discipline_id);

-- ============================================
-- 2. TABELA: practical_submissions
-- (entrega do aluno: arquivo .docx OU texto)
-- ============================================
CREATE TABLE IF NOT EXISTS practical_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES practical_activities(id) ON DELETE CASCADE,
  discipline_id UUID NOT NULL REFERENCES disciplines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  submission_type TEXT NOT NULL DEFAULT 'text',   -- 'file' | 'text'
  content_text TEXT,                              -- preenchido quando submission_type = 'text'
  file_path TEXT,                                 -- caminho do .docx no Storage
  file_url TEXT,                                  -- URL pública do .docx
  file_name TEXT,                                 -- nome original do arquivo enviado
  status TEXT NOT NULL DEFAULT 'pendente',        -- 'pendente' | 'avaliada'
  grade TEXT,                                     -- nota/conceito dado pelo admin (livre)
  feedback TEXT,                                  -- comentário/devolutiva do admin
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  graded_at TIMESTAMPTZ,
  UNIQUE (user_id, activity_id)                   -- uma entrega por aluno por atividade (upsert)
);

CREATE INDEX IF NOT EXISTS idx_practical_submissions_activity
  ON practical_submissions(activity_id);
CREATE INDEX IF NOT EXISTS idx_practical_submissions_user
  ON practical_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_practical_submissions_discipline
  ON practical_submissions(discipline_id);

-- ============================================
-- 3. RLS: practical_activities
-- ============================================
ALTER TABLE practical_activities ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado pode ler a atividade
DROP POLICY IF EXISTS "Anyone can read practical activities" ON practical_activities;
CREATE POLICY "Anyone can read practical activities"
  ON practical_activities FOR SELECT
  TO authenticated
  USING (true);

-- Apenas admin pode criar/editar/excluir a atividade
DROP POLICY IF EXISTS "Admin can manage practical activities" ON practical_activities;
CREATE POLICY "Admin can manage practical activities"
  ON practical_activities FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================
-- 4. RLS: practical_submissions
-- ============================================
ALTER TABLE practical_submissions ENABLE ROW LEVEL SECURITY;

-- O aluno lê as próprias entregas; o admin lê todas
DROP POLICY IF EXISTS "Read own or admin submissions" ON practical_submissions;
CREATE POLICY "Read own or admin submissions"
  ON practical_submissions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_admin());

-- O aluno cria a própria entrega
DROP POLICY IF EXISTS "Insert own submission" ON practical_submissions;
CREATE POLICY "Insert own submission"
  ON practical_submissions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- O aluno atualiza a própria entrega (reenvio)
DROP POLICY IF EXISTS "Update own submission" ON practical_submissions;
CREATE POLICY "Update own submission"
  ON practical_submissions FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- O admin atualiza qualquer entrega (para dar a devolutiva: nota/comentário)
DROP POLICY IF EXISTS "Admin can grade submissions" ON practical_submissions;
CREATE POLICY "Admin can grade submissions"
  ON practical_submissions FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- O aluno apaga a própria entrega; o admin pode apagar qualquer uma
DROP POLICY IF EXISTS "Delete own or admin submission" ON practical_submissions;
CREATE POLICY "Delete own or admin submission"
  ON practical_submissions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id OR is_admin());

-- ============================================
-- 5. STORAGE: bucket para o PDF de apoio da atividade (admin)
-- ============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'practical-activities',
  'practical-activities',
  true,
  52428800, -- 50MB
  ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public can read practical-activities files" ON storage.objects;
CREATE POLICY "Public can read practical-activities files"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'practical-activities');

DROP POLICY IF EXISTS "Admin can upload practical-activities files" ON storage.objects;
CREATE POLICY "Admin can upload practical-activities files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'practical-activities' AND is_admin());

DROP POLICY IF EXISTS "Admin can delete practical-activities files" ON storage.objects;
CREATE POLICY "Admin can delete practical-activities files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'practical-activities' AND is_admin());

-- ============================================
-- 6. STORAGE: bucket para as entregas dos alunos (.docx)
-- ============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'practical-submissions',
  'practical-submissions',
  true,
  52428800, -- 50MB
  ARRAY[
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]::text[]
)
ON CONFLICT (id) DO NOTHING;

-- Leitura pública (para as URLs públicas funcionarem no download do aluno/admin)
DROP POLICY IF EXISTS "Public can read practical-submissions files" ON storage.objects;
CREATE POLICY "Public can read practical-submissions files"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'practical-submissions');

-- Usuário autenticado pode enviar a própria entrega
DROP POLICY IF EXISTS "Authenticated can upload practical-submissions files" ON storage.objects;
CREATE POLICY "Authenticated can upload practical-submissions files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'practical-submissions');

-- Usuário autenticado pode substituir/apagar arquivo de entrega (reenvio)
DROP POLICY IF EXISTS "Authenticated can update practical-submissions files" ON storage.objects;
CREATE POLICY "Authenticated can update practical-submissions files"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'practical-submissions');

DROP POLICY IF EXISTS "Authenticated can delete practical-submissions files" ON storage.objects;
CREATE POLICY "Authenticated can delete practical-submissions files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'practical-submissions');

-- ============================================
-- 7. RPC: listar entregas de uma disciplina com o nome do aluno (somente admin)
-- ============================================
CREATE OR REPLACE FUNCTION get_practical_submissions(p_discipline_id UUID)
RETURNS TABLE (
  id UUID,
  activity_id UUID,
  user_id UUID,
  full_name TEXT,
  email TEXT,
  submission_type TEXT,
  content_text TEXT,
  file_url TEXT,
  file_name TEXT,
  status TEXT,
  grade TEXT,
  feedback TEXT,
  submitted_at TIMESTAMPTZ,
  graded_at TIMESTAMPTZ
) AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores podem acessar esta função';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.activity_id,
    s.user_id,
    COALESCE(u.raw_user_meta_data ->> 'full_name', u.email::TEXT)::TEXT AS full_name,
    u.email::TEXT,
    s.submission_type,
    s.content_text,
    s.file_url,
    s.file_name,
    s.status,
    s.grade,
    s.feedback,
    s.submitted_at,
    s.graded_at
  FROM practical_submissions s
  JOIN auth.users u ON u.id = s.user_id
  WHERE s.discipline_id = p_discipline_id
  ORDER BY s.submitted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
