-- ============================================
-- MIGRATION: Histórico do chat de IA por disciplina
-- Execute este SQL no SQL Editor do Supabase
-- ============================================
-- Guarda as mensagens trocadas entre o aluno e o assistente de IA (aba
-- "Dúvidas" / widget flutuante) por disciplina, para o aluno poder
-- consultar depois. Cada aluno só enxerga as próprias conversas.
-- ============================================

CREATE TABLE IF NOT EXISTS discipline_chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discipline_chat_messages_user_discipline
  ON discipline_chat_messages (user_id, discipline_id, created_at);

ALTER TABLE discipline_chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own chat messages" ON discipline_chat_messages;
CREATE POLICY "Users can read own chat messages"
  ON discipline_chat_messages FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own chat messages" ON discipline_chat_messages;
CREATE POLICY "Users can insert own chat messages"
  ON discipline_chat_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);
