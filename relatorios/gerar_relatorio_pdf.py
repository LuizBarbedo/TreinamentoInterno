#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gera o Relatório de Acompanhamento de Alunos (PDF) a partir do JSON
produzido pela função SQL `get_relatorio_acompanhamento_alunos()`
(ver supabase/relatorio_acompanhamento_alunos.sql).

Uso:
    python gerar_relatorio_pdf.py relatorio_dados.json relatorio_acompanhamento.pdf

Dependência:
    pip install reportlab
"""

import json
import sys
from datetime import datetime
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas as pdfcanvas
from reportlab.platypus import (
    HRFlowable,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

# ============================================================================
# Identidade visual Capacita Portos
# ============================================================================
PETROLEO = colors.HexColor("#0F5E78")
PETROLEO_ESCURO = colors.HexColor("#08323F")
TURQUESA = colors.HexColor("#3AA7AF")
CINZA = colors.HexColor("#60686E")
CINZA_CLARO = colors.HexColor("#EDF2F3")
BRANCO = colors.white
VERDE_OK = colors.HexColor("#2E8B57")
VERMELHO_ALERTA = colors.HexColor("#B0392B")
AMARELO_PENDENTE = colors.HexColor("#B9830B")

PAGE_SIZE = A4
MARGIN = 1.8 * cm

NOME_PLATAFORMA = "Programa Capacita Portos — Profissional Portuário"


# ============================================================================
# Helpers de formatação
# ============================================================================
def esc(value):
    """Escapa texto livre do usuário para usar dentro de um Paragraph (XML)."""
    if value is None:
        return ""
    text = str(value)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = escape(text)
    text = text.replace("\n", "<br/>")
    return text


def dash(value):
    """Retorna '—' para None/vazio, senão o próprio valor como string."""
    if value is None or value == "":
        return "—"
    return str(value)


def fmt_dt(iso_value, with_time=True):
    if not iso_value:
        return "—"
    try:
        s = str(iso_value).replace("Z", "+00:00")
        d = datetime.fromisoformat(s)
        return d.strftime("%d/%m/%Y %H:%M" if with_time else "%d/%m/%Y")
    except Exception:
        return str(iso_value)


def fmt_pct(numerator, denominator):
    if not denominator:
        return "0%"
    return f"{round((numerator / denominator) * 100)}%"


def fmt_num(value, suffix=""):
    if value is None:
        return "—"
    return f"{value}{suffix}"


def status_atividade_pratica(status):
    mapa = {
        "pendente": "Enviada — aguardando correção",
        "avaliada": "Avaliada",
        "nao_enviada": "Ainda não enviou",
    }
    return mapa.get(status, dash(status))


def status_sugestao(status):
    mapa = {"pendente": "Pendente de resposta", "respondida": "Respondida"}
    return mapa.get(status, dash(status))


# ============================================================================
# Estilos
# ============================================================================
def build_styles():
    ss = getSampleStyleSheet()

    ss.add(
        ParagraphStyle(
            "Capa Título",
            parent=ss["Title"],
            fontName="Helvetica-Bold",
            fontSize=26,
            leading=32,
            textColor=PETROLEO,
            alignment=TA_CENTER,
        )
    )
    ss.add(
        ParagraphStyle(
            "Capa Subtítulo",
            parent=ss["Normal"],
            fontName="Helvetica",
            fontSize=14,
            leading=18,
            textColor=CINZA,
            alignment=TA_CENTER,
            spaceBefore=6,
        )
    )
    ss.add(
        ParagraphStyle(
            "TituloSecao",
            parent=ss["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=17,
            leading=21,
            textColor=colors.white,
            backColor=PETROLEO,
            borderPadding=(6, 8, 6, 8),
            spaceBefore=0,
            spaceAfter=10,
        )
    )
    ss.add(
        ParagraphStyle(
            "TituloAluno",
            parent=ss["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=18,
            leading=22,
            textColor=colors.white,
            backColor=PETROLEO_ESCURO,
            borderPadding=(8, 10, 8, 10),
            spaceBefore=0,
            spaceAfter=4,
        )
    )
    ss.add(
        ParagraphStyle(
            "TituloSub",
            parent=ss["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12.5,
            leading=16,
            textColor=PETROLEO,
            spaceBefore=12,
            spaceAfter=4,
            borderWidth=0,
            borderColor=TURQUESA,
        )
    )
    ss.add(
        ParagraphStyle(
            "Corpo",
            parent=ss["Normal"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13,
            textColor=colors.HexColor("#1C1C1C"),
        )
    )
    ss.add(
        ParagraphStyle(
            "CorpoPequeno",
            parent=ss["Normal"],
            fontName="Helvetica",
            fontSize=8.3,
            leading=11,
            textColor=colors.HexColor("#1C1C1C"),
        )
    )
    ss.add(
        ParagraphStyle(
            "Legenda",
            parent=ss["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=8,
            leading=10,
            textColor=CINZA,
        )
    )
    ss.add(
        ParagraphStyle(
            "CelulaCabecalho",
            parent=ss["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=10,
            textColor=colors.white,
        )
    )
    return ss


STYLES = build_styles()


def P(text, style="Corpo"):
    return Paragraph(text if text else "—", STYLES[style])


def header_cell(text):
    return Paragraph(esc(text), STYLES["CelulaCabecalho"])


# ============================================================================
# Tabelas reutilizáveis
# ============================================================================
def kv_table(pairs, col_widths=(5 * cm, 10.5 * cm)):
    """Tabela simples de 'rótulo: valor', uma por linha."""
    rows = []
    for label, value in pairs:
        rows.append([P(f"<b>{esc(label)}</b>", "Corpo"), P(esc(value), "Corpo")])
    t = Table(rows, colWidths=list(col_widths))
    t.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#D7E0E2")),
                ("BACKGROUND", (0, 0), (0, -1), CINZA_CLARO),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return t


def data_table(headers, rows, col_widths, small=False):
    """Tabela de dados com cabeçalho colorido e zebra striping."""
    style_name = "CorpoPequeno" if small else "Corpo"
    header_row = [header_cell(h) for h in headers]
    body_rows = [[P(esc(c), style_name) for c in row] for row in rows]
    table_data = [header_row] + body_rows

    t = Table(table_data, colWidths=col_widths, repeatRows=1)
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), TURQUESA),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#D7E0E2")),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    for i in range(1, len(table_data)):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), CINZA_CLARO))
    t.setStyle(TableStyle(cmds))
    return t


# ============================================================================
# Canvas numerado (rodapé com "Página X de Y" + barra de marca)
# ============================================================================
class NumberedCanvas(pdfcanvas.Canvas):
    def __init__(self, *args, **kwargs):
        pdfcanvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_footer(total_pages)
            pdfcanvas.Canvas.showPage(self)
        pdfcanvas.Canvas.save(self)

    def draw_footer(self, total_pages):
        width, _ = PAGE_SIZE
        self.setFillColor(PETROLEO)
        self.rect(0, 0, width, 0.6 * cm, stroke=0, fill=1)
        self.setFillColor(colors.white)
        self.setFont("Helvetica", 8)
        self.drawString(MARGIN, 0.17 * cm, NOME_PLATAFORMA)
        self.drawRightString(
            width - MARGIN, 0.17 * cm, f"Página {self._pageNumber} de {total_pages}"
        )


# ============================================================================
# Documento com marcadores (outline/bookmarks) para navegação no PDF
# ============================================================================
class RelatorioDocTemplate(SimpleDocTemplate):
    def afterFlowable(self, flowable):
        if not isinstance(flowable, Paragraph):
            return
        text = flowable.getPlainText()
        style_name = flowable.style.name
        if style_name == "TituloAluno":
            key = f"aluno-{id(flowable)}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=0, closed=True)
        elif style_name == "TituloSecao":
            key = f"secao-{id(flowable)}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=0, closed=False)


# ============================================================================
# Seções do relatório
# ============================================================================
def build_cover(story, data):
    gerado_em = fmt_dt(data.get("gerado_em"))
    total_alunos = data.get("plataforma", {}).get("total_alunos", 0)

    story.append(Spacer(1, 6 * cm))
    story.append(Paragraph(NOME_PLATAFORMA, STYLES["Capa Subtítulo"]))
    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph("Relatório de Acompanhamento de Alunos", STYLES["Capa Título"]))
    story.append(Spacer(1, 0.4 * cm))
    story.append(
        Paragraph(
            "Visão geral da plataforma e panorama individual de cada aluno em todas as "
            "funcionalidades: vídeo aulas, quizzes, Atividade Prática, Sugestões, Fórum, "
            "Chat de IA e gamificação (badges/ranking).",
            STYLES["Capa Subtítulo"],
        )
    )
    story.append(Spacer(1, 1.2 * cm))
    story.append(
        Paragraph(f"<b>{total_alunos}</b> aluno(s) cadastrado(s) analisado(s)", STYLES["Capa Subtítulo"])
    )
    story.append(Paragraph(f"Gerado em {gerado_em}", STYLES["Legenda"]))
    story.append(PageBreak())


def build_visao_geral(story, data):
    plataforma = data.get("plataforma", {}) or {}
    disciplinas_overview = data.get("disciplinas_overview") or []
    ranking = data.get("ranking_badges") or []

    story.append(Paragraph("1. Visão Geral da Plataforma", STYLES["TituloSecao"]))

    total_alunos = plataforma.get("total_alunos", 0) or 0
    sem_atividade = plataforma.get("alunos_sem_nenhuma_atividade_registrada", 0) or 0
    concluiram = plataforma.get("alunos_que_concluiram_ao_menos_1_disciplina", 0) or 0

    narrativa = (
        f"A plataforma conta hoje com <b>{total_alunos}</b> aluno(s) cadastrado(s), distribuídos em "
        f"<b>{plataforma.get('total_modulos', 0)}</b> módulo(s) e <b>{plataforma.get('total_disciplinas', 0)}</b> "
        f"disciplina(s), totalizando <b>{plataforma.get('total_aulas', 0)}</b> vídeo aulas. "
        f"Deste total, <b>{concluiram}</b> aluno(s) já concluíram ao menos uma disciplina e "
        f"<b>{sem_atividade}</b> aluno(s) ainda não registraram nenhuma atividade na plataforma "
        f"(nenhuma aula, quiz ou envio de Atividade Prática)."
    )
    story.append(P(narrativa))
    story.append(Spacer(1, 0.4 * cm))

    story.append(Paragraph("Indicadores gerais", STYLES["TituloSub"]))
    indicadores = [
        ("Total de alunos", dash(plataforma.get("total_alunos"))),
        ("Total de módulos", dash(plataforma.get("total_modulos"))),
        ("Total de disciplinas", dash(plataforma.get("total_disciplinas"))),
        ("Total de vídeo aulas", dash(plataforma.get("total_aulas"))),
        ("Nota média — Quiz final da disciplina", fmt_num(plataforma.get("media_nota_quiz_final"), "%")),
        ("Nota média — Quiz por aula", fmt_num(plataforma.get("media_nota_quiz_aula"), "%")),
        ("Atividades Práticas cadastradas", dash(plataforma.get("total_atividades_praticas_cadastradas"))),
        ("Submissões de Atividade Prática recebidas", dash(plataforma.get("total_submissoes_praticas"))),
        ("Submissões aguardando correção", dash(plataforma.get("submissoes_praticas_pendentes"))),
        ("Submissões já avaliadas", dash(plataforma.get("submissoes_praticas_avaliadas"))),
        ("Sugestões enviadas pelos alunos", dash(plataforma.get("total_sugestoes"))),
        ("Sugestões pendentes de resposta", dash(plataforma.get("sugestoes_pendentes"))),
        ("Posts criados no Fórum", dash(plataforma.get("total_posts_forum"))),
        ("Respostas dadas no Fórum", dash(plataforma.get("total_respostas_forum"))),
        ("Mensagens enviadas ao Chat de IA (Dúvidas)", dash(plataforma.get("total_mensagens_chat_ia"))),
        ("Alunos que concluíram ao menos 1 disciplina", dash(concluiram)),
        ("Alunos sem nenhuma atividade registrada", dash(sem_atividade)),
    ]
    story.append(kv_table(indicadores))
    story.append(Spacer(1, 0.5 * cm))

    story.append(Paragraph("Panorama por disciplina", STYLES["TituloSub"]))
    if disciplinas_overview:
        headers = ["Disciplina", "Aulas", "Ativos", "Concluíram", "Méd. quiz", "Aprov.", "Ativ. prática", "Sugestões"]
        rows = []
        for d in disciplinas_overview:
            taxa = d.get("taxa_aprovacao_quiz_final_pct")
            rows.append(
                [
                    d.get("nome"),
                    dash(d.get("total_aulas")),
                    dash(d.get("alunos_com_atividade")),
                    dash(d.get("alunos_concluiram")),
                    fmt_num(d.get("media_quiz_final"), "%"),
                    f"{taxa}%" if taxa is not None else "—",
                    dash(d.get("submissoes_atividade_pratica")),
                    dash(d.get("sugestoes_recebidas")),
                ]
            )
        story.append(
            data_table(
                headers,
                rows,
                col_widths=[3.2 * cm, 1.2 * cm, 1.7 * cm, 2.3 * cm, 1.8 * cm, 1.5 * cm, 2.1 * cm, 2.1 * cm],
                small=True,
            )
        )
    else:
        story.append(P("Nenhuma disciplina cadastrada."))

    story.append(Spacer(1, 0.5 * cm))
    story.append(Paragraph("Ranking de badges (gamificação)", STYLES["TituloSub"]))
    if ranking:
        headers = ["#", "Aluno", "Badges"]
        rows = [[r.get("posicao"), r.get("nome"), r.get("badges")] for r in ranking]
        story.append(data_table(headers, rows, col_widths=[1.3 * cm, 11 * cm, 2.5 * cm], small=True))
    else:
        story.append(P("Nenhum aluno conquistou badges até o momento."))

    story.append(PageBreak())


def build_disciplina_bloco(disc):
    flows = []
    nome = disc.get("nome", "Disciplina")
    aulas_concl = disc.get("aulas_concluidas", 0) or 0
    aulas_total = disc.get("total_aulas", 0) or 0

    flows.append(Paragraph(f"▸ {esc(nome)}", STYLES["TituloSub"]))
    flows.append(
        P(
            f"Vídeo aulas concluídas: <b>{aulas_concl}/{aulas_total}</b> "
            f"({fmt_pct(aulas_concl, aulas_total)})."
        )
    )

    quiz_final = disc.get("quiz_final")
    if quiz_final and quiz_final.get("nota") is not None:
        aprovado = "Aprovado" if quiz_final.get("aprovado") else "Reprovado"
        flows.append(
            P(
                f"Quiz final da disciplina: nota <b>{quiz_final.get('nota')}%</b> "
                f"({dash(quiz_final.get('corretas'))}/{dash(quiz_final.get('total'))} corretas) — "
                f"<b>{aprovado}</b> em {fmt_dt(quiz_final.get('respondido_em'))}."
            )
        )
    else:
        flows.append(P("Quiz final da disciplina: ainda não realizado."))

    quizzes_aula = disc.get("quizzes_por_aula") or []
    if quizzes_aula:
        headers = ["Aula", "Nota", "Acertos", "Respondido em"]
        rows = [
            [q.get("aula"), fmt_num(q.get("nota"), "%"), f"{dash(q.get('corretas'))}/{dash(q.get('total'))}", fmt_dt(q.get("respondido_em"))]
            for q in quizzes_aula
        ]
        flows.append(Spacer(1, 0.15 * cm))
        flows.append(data_table(headers, rows, col_widths=[7 * cm, 1.8 * cm, 2 * cm, 3.5 * cm], small=True))
    else:
        flows.append(P("Quizzes por aula: nenhum respondido ainda."))

    ap = disc.get("atividade_pratica")
    flows.append(Spacer(1, 0.15 * cm))
    if ap:
        status = status_atividade_pratica(ap.get("status"))
        linhas = [("Atividade", ap.get("titulo_atividade") or "Atividade Prática"), ("Status", status)]
        if ap.get("status") and ap.get("status") != "nao_enviada":
            linhas.append(("Tipo de entrega", "Arquivo (.docx)" if ap.get("tipo_entrega") == "file" else "Texto direto na plataforma"))
            if ap.get("nome_arquivo"):
                linhas.append(("Arquivo enviado", ap.get("nome_arquivo")))
            linhas.append(("Enviado em", fmt_dt(ap.get("enviado_em"))))
            linhas.append(("Nota/Conceito", dash(ap.get("nota"))))
            linhas.append(("Devolutiva do admin", ap.get("devolutiva_admin") or "Ainda sem devolutiva"))
            if ap.get("avaliado_em"):
                linhas.append(("Avaliado em", fmt_dt(ap.get("avaliado_em"))))
        flows.append(P("<b>Atividade Prática:</b>"))
        flows.append(kv_table(linhas, col_widths=(4.5 * cm, 11 * cm)))
    else:
        flows.append(P("Atividade Prática: esta disciplina não possui atividade prática cadastrada."))

    sugestoes = disc.get("sugestoes_enviadas") or []
    flows.append(Spacer(1, 0.15 * cm))
    if sugestoes:
        headers = ["Sugestão enviada", "Status", "Resposta do admin", "Data"]
        rows = [
            [sg.get("conteudo"), status_sugestao(sg.get("status")), sg.get("resposta_admin") or "—", fmt_dt(sg.get("enviado_em"))]
            for sg in sugestoes
        ]
        flows.append(data_table(headers, rows, col_widths=[5.5 * cm, 2.8 * cm, 4.5 * cm, 1.5 * cm], small=True))
    else:
        flows.append(P("Sugestões enviadas nesta disciplina: nenhuma."))

    msgs_ia = disc.get("mensagens_chat_ia", 0) or 0
    flows.append(Spacer(1, 0.1 * cm))
    flows.append(P(f"Mensagens enviadas ao Chat de IA sobre esta disciplina: <b>{msgs_ia}</b>."))
    flows.append(Spacer(1, 0.3 * cm))
    flows.append(HRFlowable(width="100%", thickness=0.4, color=colors.HexColor("#D7E0E2")))
    flows.append(Spacer(1, 0.2 * cm))
    return flows


def build_aluno(story, aluno, indice, total):
    perfil = aluno.get("perfil", {}) or {}
    resumo = aluno.get("resumo", {}) or {}
    disciplinas = aluno.get("disciplinas") or []
    forum = aluno.get("forum", {}) or {}
    chat = aluno.get("chat_ia", {}) or {}

    # Cada aluno sempre começa em página nova — inclusive o primeiro, para não
    # colar no parágrafo de abertura da seção 2 nem no título de outro aluno.
    story.append(PageBreak())

    nome = perfil.get("nome") or "Aluno"
    story.append(Paragraph(f"{esc(nome)}", STYLES["TituloAluno"]))
    story.append(Spacer(1, 0.2 * cm))
    story.append(Paragraph(f"Aluno {indice + 1} de {total}", STYLES["Legenda"]))
    story.append(Spacer(1, 0.3 * cm))

    publico_label = {
        "estrategico": "Estratégico",
        "tatico": "Tático",
        "operacional": "Operacional",
        "externo": "Externo",
        "geral": "Geral",
    }.get(perfil.get("publico"), dash(perfil.get("publico")))

    story.append(Paragraph("Perfil", STYLES["TituloSub"]))
    story.append(
        kv_table(
            [
                ("E-mail", perfil.get("email")),
                ("CPF", perfil.get("cpf") or "não informado"),
                ("Público", publico_label),
                ("Acesso irrestrito (full access)", "Sim" if perfil.get("acesso_irrestrito") else "Não"),
                ("Cadastrado em", fmt_dt(perfil.get("cadastrado_em"))),
                ("Último acesso", fmt_dt(perfil.get("ultimo_acesso"))),
            ]
        )
    )

    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph("Resumo executivo", STYLES["TituloSub"]))
    story.append(
        kv_table(
            [
                ("Badges conquistados", dash(resumo.get("badges"))),
                ("Posição no ranking de badges", dash(resumo.get("posicao_ranking_badges"))),
                ("Disciplinas concluídas", dash(resumo.get("disciplinas_concluidas"))),
                ("Disciplinas com atividade registrada", dash(resumo.get("disciplinas_com_atividade"))),
                ("Total de vídeo aulas concluídas", dash(resumo.get("total_aulas_concluidas"))),
                ("Nota média — Quiz final", fmt_num(resumo.get("media_quiz_final"), "%")),
                ("Nota média — Quiz por aula", fmt_num(resumo.get("media_quiz_aula"), "%")),
                ("Submissões de Atividade Prática", dash(resumo.get("total_submissoes_praticas"))),
                ("Sugestões enviadas", dash(resumo.get("total_sugestoes_enviadas"))),
                ("Posts no Fórum", dash(resumo.get("total_posts_forum"))),
                ("Respostas no Fórum", dash(resumo.get("total_respostas_forum"))),
                ("Mensagens no Chat de IA", dash(resumo.get("total_mensagens_chat_ia"))),
            ]
        )
    )

    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph("Progresso por disciplina", STYLES["TituloSub"]))
    if disciplinas:
        for disc in disciplinas:
            story.extend(build_disciplina_bloco(disc))
    else:
        story.append(P("Nenhuma atividade registrada em nenhuma disciplina até o momento."))

    story.append(Spacer(1, 0.2 * cm))
    story.append(Paragraph("Participação no Fórum", STYLES["TituloSub"]))
    posts = forum.get("posts_criados") or []
    respostas = forum.get("respostas_dadas") or []
    if posts:
        headers = ["Título do post", "Categoria", "Disciplina", "Curtidas", "Respostas", "Criado em"]
        rows = [
            [p.get("titulo"), p.get("categoria"), p.get("disciplina") or "—", p.get("curtidas_recebidas"), p.get("respostas_recebidas"), fmt_dt(p.get("criado_em"), False)]
            for p in posts
        ]
        story.append(data_table(headers, rows, col_widths=[4.3 * cm, 2.3 * cm, 3 * cm, 1.8 * cm, 1.9 * cm, 2.2 * cm], small=True))
    else:
        story.append(P("Posts criados: nenhum."))
    story.append(Spacer(1, 0.15 * cm))
    if respostas:
        headers = ["Post respondido", "Trecho da resposta", "Solução", "Criado em"]
        rows = [
            [r.get("post_titulo"), r.get("trecho"), "Sim" if r.get("marcada_como_solucao") else "Não", fmt_dt(r.get("criado_em"), False)]
            for r in respostas
        ]
        story.append(data_table(headers, rows, col_widths=[3.5 * cm, 6.5 * cm, 1.8 * cm, 2.3 * cm], small=True))
    else:
        story.append(P("Respostas dadas: nenhuma."))
    story.append(Spacer(1, 0.15 * cm))
    story.append(
        P(f"Curtidas dadas: <b>{dash(forum.get('curtidas_dadas'))}</b> &nbsp;|&nbsp; Curtidas recebidas: <b>{dash(forum.get('curtidas_recebidas'))}</b>")
    )

    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph("Uso do Chat de IA (Dúvidas)", STYLES["TituloSub"]))
    story.append(
        P(
            f"Total de mensagens enviadas: <b>{dash(chat.get('total_mensagens_enviadas'))}</b>. "
            f"Última interação: <b>{fmt_dt(chat.get('ultima_interacao'))}</b>."
        )
    )
    por_disc = chat.get("por_disciplina") or []
    if por_disc:
        headers = ["Disciplina", "Mensagens enviadas"]
        rows = [[c.get("disciplina"), c.get("mensagens")] for c in por_disc]
        story.append(Spacer(1, 0.1 * cm))
        story.append(data_table(headers, rows, col_widths=[10 * cm, 4.8 * cm], small=True))


def build_pdf(data, output_path):
    doc = RelatorioDocTemplate(
        output_path,
        pagesize=PAGE_SIZE,
        leftMargin=MARGIN,
        rightMargin=MARGIN,
        topMargin=MARGIN,
        bottomMargin=1.1 * cm,
        title="Relatório de Acompanhamento de Alunos — Capacita Portos",
        author=NOME_PLATAFORMA,
    )

    story = []
    build_cover(story, data)
    build_visao_geral(story, data)

    alunos = data.get("alunos") or []
    story.append(Paragraph("2. Relatório Individual por Aluno", STYLES["TituloSecao"]))
    story.append(
        P(
            f"A seguir, o panorama individual completo de cada um dos <b>{len(alunos)}</b> aluno(s) "
            f"cadastrado(s), cobrindo vídeo aulas, quizzes, Atividade Prática, Sugestões, Fórum, "
            f"Chat de IA e gamificação."
        )
    )
    for i, aluno in enumerate(alunos):
        build_aluno(story, aluno, i, len(alunos))

    doc.build(story, canvasmaker=NumberedCanvas)


def main():
    if len(sys.argv) < 2:
        print("Uso: python gerar_relatorio_pdf.py <relatorio_dados.json> [saida.pdf]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "relatorio_acompanhamento.pdf"

    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    build_pdf(data, output_path)
    print(f"PDF gerado em: {output_path}")


if __name__ == "__main__":
    main()
