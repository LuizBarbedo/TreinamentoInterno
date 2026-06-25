-- ============================================
-- MIGRATION: Atividade Prática — múltiplos arquivos de apoio
-- ============================================
-- Permite que o admin suba MAIS DE UM arquivo PDF de apoio por atividade.
-- Os arquivos passam a ser guardados em uma coluna JSONB `files`, um array de
-- objetos no formato { "path": ..., "url": ..., "name": ... }.
--
-- As colunas antigas file_path / file_url são mantidas (apontam para o
-- primeiro arquivo) por compatibilidade com dados/telas legadas.
--
-- Idempotente. Execute no SQL Editor do Supabase.
-- ============================================

-- 1. Nova coluna com o array de arquivos
ALTER TABLE practical_activities
  ADD COLUMN IF NOT EXISTS files JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2. Backfill: migra o arquivo único já existente para o novo array
UPDATE practical_activities
SET files = jsonb_build_array(
  jsonb_build_object(
    'path', file_path,
    'url', file_url,
    'name', COALESCE(NULLIF(split_part(file_path, '/', -1), ''), 'atividade.pdf')
  )
)
WHERE file_url IS NOT NULL
  AND (files IS NULL OR files = '[]'::jsonb);
