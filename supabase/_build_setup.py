#!/usr/bin/env python3
# Gera setup_completo.sql idempotente a partir do schema + migrações.
# Temporário: pode ser apagado depois.
import re

# Ordem por dependencia. Pontos criticos:
#  - admin_reports define get_platform_users() com 5 colunas; publicos REDEFINE
#    com 7 colunas (+publico). publicos e mais nova e deve ser a ULTIMA a definir,
#    entao admin_reports vem ANTES de publicos.
#  - admin_reports cria policy em lesson_progress -> precisa vir depois dessa tabela.
#  - modules usa publico_enum -> depois de publicos.
ORDER = [
    "schema.sql",
    "migration_admin_roles.sql",
    "migration_lesson_progress.sql",
    "migration_lesson_quiz.sql",
    "migration_correction_comments.sql",
    "migration_admin_reports.sql",
    "migration_publicos.sql",
    "migration_modules.sql",
    "migration_badge_ranking.sql",
    "migration_forum.sql",
    "migration_forum_usernames.sql",
    "migration_forum_admin_delete.sql",
    "migration_materials_upload.sql",
]

HEADER = """-- ============================================================
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
"""

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()

def strip_sample_data(text):
    # Remove o bloco final "-- DADOS DE EXEMPLO (opcional)" ate o fim do arquivo.
    idx = text.find("-- DADOS DE EXEMPLO")
    if idx != -1:
        # recua ate o inicio do separador de comentario imediatamente acima
        head = text[:idx]
        sep = head.rfind("-- ====")
        if sep != -1 and head[sep:idx].strip().startswith("-- ===="):
            head = head[:sep]
        return head.rstrip() + "\n"
    return text

def make_idempotent(text):
    # CREATE TABLE <nome> (  ->  CREATE TABLE IF NOT EXISTS <nome> (
    text = re.sub(r"CREATE TABLE (?!IF NOT EXISTS)", "CREATE TABLE IF NOT EXISTS ", text)
    # CREATE INDEX <nome>  ->  CREATE INDEX IF NOT EXISTS <nome>
    text = re.sub(r"CREATE INDEX (?!IF NOT EXISTS)", "CREATE INDEX IF NOT EXISTS ", text)
    text = re.sub(r"CREATE UNIQUE INDEX (?!IF NOT EXISTS)", "CREATE UNIQUE INDEX IF NOT EXISTS ", text)
    # Antes de cada CREATE POLICY "nome" ON tabela -> inserir DROP POLICY IF EXISTS
    def drop_before(m):
        name, table = m.group(1), m.group(2)
        return f'DROP POLICY IF EXISTS "{name}" ON {table};\n{m.group(0)}'
    text = re.sub(r'CREATE POLICY "([^"]+)"\s+ON\s+(\S+)', drop_before, text)
    # get_platform_users() e redefinida com retorno diferente entre arquivos.
    # CREATE OR REPLACE FUNCTION nao consegue mudar o tipo de retorno -> precede
    # cada definicao com DROP FUNCTION IF EXISTS (no-op extra e inofensivo).
    text = re.sub(
        r"CREATE OR REPLACE FUNCTION get_platform_users\(",
        "DROP FUNCTION IF EXISTS get_platform_users();\nCREATE OR REPLACE FUNCTION get_platform_users(",
        text,
    )
    return text

parts = [HEADER]
for fname in ORDER:
    body = read(fname)
    if fname == "schema.sql":
        body = strip_sample_data(body)
    body = make_idempotent(body)
    parts.append(
        "\n-- ============================================================\n"
        f"-- >>> {fname}\n"
        "-- ============================================================\n"
        + body.rstrip() + "\n"
    )

# Apenas PARTE 1 (coluna CPF) da migracao de alunos
cpf = read("migration_cadastro_alunos.sql").splitlines()[:15]
cpf_text = make_idempotent("\n".join(cpf))
parts.append(
    "\n-- ============================================================\n"
    "-- >>> migration_cadastro_alunos.sql (APENAS PARTE 1 — coluna CPF)\n"
    "-- Os ~700 cadastros antigos (PARTE 2) foram intencionalmente omitidos.\n"
    "-- ============================================================\n"
    + cpf_text.rstrip() + "\n"
)

with open("setup_completo.sql", "w", encoding="utf-8") as f:
    f.write("\n".join(parts))
print("setup_completo.sql gerado.")
