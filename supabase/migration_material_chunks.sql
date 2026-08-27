-- ============================================
-- MIGRATION: RAG por full-text search para o chat de IA
-- Execute este SQL no SQL Editor do Supabase
-- Pré-requisito: migration_admin_roles.sql (função is_admin())
--                migration_materials_upload.sql (tabela materials)
-- ============================================
-- Quebra o conteúdo dos materiais (PDF/Word) em pedaços pesquisáveis
-- (material_chunks) e expõe uma função de busca textual (Postgres
-- full-text search, sem embeddings vetoriais) usada pela API do chat
-- para trazer trechos relevantes do material como contexto da resposta.
-- ============================================

CREATE TABLE IF NOT EXISTS material_chunks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  material_id UUID REFERENCES materials(id) ON DELETE CASCADE,
  discipline_id UUID REFERENCES disciplines(id) ON DELETE CASCADE,
  chunk_index INT NOT NULL,
  content TEXT NOT NULL,
  search_vector TSVECTOR GENERATED ALWAYS AS (to_tsvector('portuguese', content)) STORED,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_material_chunks_material_id ON material_chunks (material_id);
CREATE INDEX IF NOT EXISTS idx_material_chunks_discipline_id ON material_chunks (discipline_id);
CREATE INDEX IF NOT EXISTS idx_material_chunks_search_vector ON material_chunks USING GIN (search_vector);

ALTER TABLE material_chunks ENABLE ROW LEVEL SECURITY;

-- Leitura: qualquer usuário autenticado (mesmo padrão de materials/lessons;
-- a API do chat consulta via RPC abaixo com o token do próprio aluno)
DROP POLICY IF EXISTS "Authenticated users can read material_chunks" ON material_chunks;
CREATE POLICY "Authenticated users can read material_chunks"
  ON material_chunks FOR SELECT
  TO authenticated
  USING (true);

-- Escrita: apenas admin (é quem cadastra/edita materiais e dispara a indexação)
DROP POLICY IF EXISTS "Admin can insert material_chunks" ON material_chunks;
CREATE POLICY "Admin can insert material_chunks"
  ON material_chunks FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admin can delete material_chunks" ON material_chunks;
CREATE POLICY "Admin can delete material_chunks"
  ON material_chunks FOR DELETE
  TO authenticated
  USING (is_admin());

-- Busca textual ranqueada (RAG sem embeddings): usada pela API do chat
-- para trazer, para a discplina em questão, os trechos mais relevantes
-- para a última pergunta do aluno.
DROP FUNCTION IF EXISTS search_material_chunks(UUID, TEXT, INT);
CREATE OR REPLACE FUNCTION search_material_chunks(
  p_discipline_id UUID,
  p_query TEXT,
  p_match_count INT DEFAULT 6
)
RETURNS TABLE (
  id UUID,
  material_id UUID,
  material_title TEXT,
  content TEXT,
  rank REAL
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    mc.id,
    mc.material_id,
    m.title AS material_title,
    mc.content,
    ts_rank(mc.search_vector, websearch_to_tsquery('portuguese', p_query)) AS rank
  FROM material_chunks mc
  JOIN materials m ON m.id = mc.material_id
  WHERE mc.discipline_id = p_discipline_id
    AND mc.search_vector @@ websearch_to_tsquery('portuguese', p_query)
  ORDER BY rank DESC
  LIMIT p_match_count;
$$;

GRANT EXECUTE ON FUNCTION search_material_chunks(UUID, TEXT, INT) TO authenticated;
