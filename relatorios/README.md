# Relatório de Acompanhamento de Alunos (PDF)

Gera um relatório extensivo — visão geral da plataforma + um panorama
individual completo por aluno — cobrindo todas as funcionalidades do lado do
aluno: vídeo aulas, quizzes (por aula e final da disciplina), Atividade
Prática (entrega/nota/devolutiva), Sugestões da disciplina, Fórum, Chat de IA
("Dúvidas") e gamificação (badges/ranking).

## Passo 1 — Criar a função no Supabase

No SQL Editor do Supabase, cole e rode o arquivo:

```
supabase/relatorio_acompanhamento_alunos.sql
```

Isso cria a função `get_relatorio_acompanhamento_alunos()` (só o
admin/master consegue executá-la). Pode rodar de novo sempre que quiser —
é idempotente (`CREATE OR REPLACE FUNCTION`).

## Passo 2 — Buscar os dados

Em uma nova query, rode:

```sql
select get_relatorio_acompanhamento_alunos();
```

O resultado é **uma linha / uma coluna** com um JSON grande (todos os
alunos + visão geral). Clique na célula do resultado para abrir o
visualizador de JSON do Supabase Studio e use o botão de copiar — ele copia
o conteúdo **integral**, mesmo que a grade mostre o valor truncado. Cole o
conteúdo copiado em um arquivo chamado `relatorio_dados.json` (nesta pasta,
por exemplo).

## Passo 3 — Gerar o PDF

Requer Python 3 com a biblioteca `reportlab`:

```bash
# (opcional) crie um ambiente virtual isolado
python3 -m venv venv
source venv/bin/activate

pip install reportlab

python gerar_relatorio_pdf.py relatorio_dados.json relatorio_acompanhamento.pdf
```

O PDF final (`relatorio_acompanhamento.pdf`) terá:

1. **Capa** com data de geração e total de alunos.
2. **Visão Geral da Plataforma**: indicadores gerais, panorama por
   disciplina e ranking de badges.
3. **Relatório Individual por Aluno** (um bloco por aluno, com quebra de
   página): perfil, resumo executivo, progresso detalhado por disciplina
   (aulas, quiz final, quizzes por aula, Atividade Prática com
   nota/devolutiva, Sugestões enviadas, mensagens ao Chat de IA),
   participação no Fórum e uso do Chat de IA.

O PDF também tem marcadores (bookmarks) no painel lateral de qualquer
leitor de PDF, com um item por seção e por aluno, para navegação rápida.

## Rodar de novo no futuro

Sempre que quiser uma nova fotografia do acompanhamento dos alunos, repita
os passos 2 e 3 (o SQL do passo 1 só precisa ser recriado se você alterar a
função).

## Arquivo de exemplo

`exemplo/relatorio_dados_exemplo.json` tem um conjunto de dados fictício
(3 alunos) só para testar o script e ver o layout do PDF sem precisar de
dados reais do Supabase:

```bash
python gerar_relatorio_pdf.py exemplo/relatorio_dados_exemplo.json exemplo/relatorio_exemplo.pdf
```
