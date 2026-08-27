# Capacita Portos — Profissional Portuário

Plataforma do **Programa Capacita Portos** (capacitação profissional portuária), desenvolvida com React, Vite e Supabase. Os colaboradores acessam módulos com disciplinas e vídeo aulas, material de leitura e quizzes, com conteúdo segmentado por público (geral, estratégico/tático, gerencial/técnico e operacional).

> Projeto derivado de uma plataforma de e-learning existente, adaptado para o contexto corporativo interno.

## Funcionalidades

- **Autenticação** – cadastro, login, recuperação e redefinição de senha.
- **Módulos → Disciplinas → Aulas** – conteúdo organizado em módulos, que contêm disciplinas com vídeo aulas.
- **Material de leitura** – apostilas, PDFs e artigos por disciplina.
- **Quizzes** – quiz por aula e quiz final da disciplina.
- **Públicos** – conteúdo segmentado por público-alvo; cada funcionário pertence a um público e enxerga o conteúdo do seu público + o conteúdo geral.
- **Badges / Conquistas** – sistema de gamificação com medalhas conquistadas conforme o desempenho.
- **Fórum** – espaço de discussão entre os colaboradores.
- **Chat de IA por disciplina** – aba "Dúvidas" dentro de cada disciplina, onde o aluno conversa com um assistente (Ollama Cloud) que responde com base no conteúdo daquela disciplina.
- **Painel Master/Admin** – usuário master insere os conteúdos para os diferentes públicos e emite relatórios.

## Tecnologias

| Camada | Tecnologia |
|--------|-----------|
| Frontend | React 19 + Vite |
| Roteamento | React Router DOM v7 |
| Backend / BD | Supabase (PostgreSQL + Auth + Storage) |
| Ícones | React Icons |

## Pré-requisitos

- Node.js 18+ (ou Bun)
- Conta no [Supabase](https://supabase.com/) com o schema aplicado (`supabase/schema.sql`)

## Configuração

1. Clone o repositório e instale as dependências:

   ```bash
   npm install
   ```

2. Copie o arquivo de exemplo de variáveis de ambiente e preencha os valores:

   ```bash
   cp .env.example .env
   ```

   | Variável | Descrição |
   |----------|-----------|
   | `VITE_SUPABASE_URL` | URL do projeto Supabase |
   | `VITE_SUPABASE_ANON_KEY` | Chave anônima do Supabase |
   | `VITE_PASSWORD_RESET_REDIRECT_URL` | URL completa de redefinição de senha |
   | `OLLAMA_API_KEY` | Chave da Ollama Cloud, usada só pela function server-side `api/chat.js` (nunca vai pro bundle do frontend) |
   | `OLLAMA_MODEL` | Nome do modelo da Ollama Cloud a usar no chat de IA (ex: `gpt-oss:120b-cloud`) |

3. Aplique as migrações no Supabase executando os arquivos da pasta `supabase/` (começando por `schema.sql` e depois os arquivos `migration_*.sql`).

## Executando localmente

```bash
npm run dev
```

A aplicação estará disponível em `http://localhost:8571`.

> **Chat de IA (`api/chat.js`):** é uma Vercel Serverless Function e **não roda** com `npm run dev` puro (o Vite não serve `/api`). Para testar localmente, use `vercel dev` (com `OLLAMA_API_KEY` configurada no `.env`) ou teste em um deploy de preview na Vercel com a variável configurada no projeto.

## Build de produção

```bash
npm run build
npm run preview
```

## Estrutura do projeto

```
src/
├── components/   # Componentes reutilizáveis (Layout, Badges…)
├── contexts/     # Contexto de autenticação
├── lib/          # Clientes Supabase, lógica de badges
├── pages/        # Páginas da aplicação
│   └── admin/    # Páginas do painel administrativo (master)
└── assets/       # Recursos estáticos
```
