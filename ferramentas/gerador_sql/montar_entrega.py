"""Junta criacao, povoamento, views e indices em um unico arquivo SQL de entrega.

Uso: python montar_entrega.py <pasta_sql> <arquivo_saida>
"""
import os
import sys

pasta, saida = sys.argv[1], sys.argv[2]

CABECALHO = """-- =====================================================================
-- UniShare - SaaS de Compartilhamento e Aluguel de Equipamentos (UMC)
-- Banco de Dados - Universidade de Mogi das Cruzes
-- Banco de dados MySQL 8.4
--
-- Integrantes:
--   Daniel Matsuo Rubino               - 11261104620
--   Igor Delfino Braga                 - 11261102520
--   Mariana Rodrigues Fonseca          - 11261103184
--   Maristela Silva Siqueira           - 11261102024
--   Otavio Vinicius Flauzino de Souza  - 11261103039
--   Roberta da Silva Ribeiro           - 11261102968
--   Sara Santos Rodrigues de Lima      - 11251103799
--   Thiago Araujo Cordeiro da Silva    - 11261103131
--
-- Conteudo:
--   1. Criacao do banco
--   2. Criacao das tabelas (aceite do termo ligado ao usuario)
--   3. Povoamento inicial (chaves estrangeiras preenchidas por SELECT)
--   4. Views de relatorio gerencial (8) e um indice para cada view (8)
-- =====================================================================
"""


def ler(nome):
    linhas = open(os.path.join(pasta, nome), encoding="utf-8").read().splitlines()
    while linhas and (linhas[0].startswith("--") or not linhas[0].strip()):
        linhas.pop(0)
    return "\n".join(linhas).strip() + "\n"


partes = [
    CABECALHO,
    "\n-- ---------------------------------------------------------------------\n-- 1 e 2. Criacao do banco e das tabelas\n-- ---------------------------------------------------------------------\n\n",
    ler("01_criacao_tabelas.sql"),
    "\n-- ---------------------------------------------------------------------\n-- 3. Povoamento inicial (FKs preenchidas por SELECT)\n-- ---------------------------------------------------------------------\n\n",
    ler("02_populacao.sql"),
    "\n-- ---------------------------------------------------------------------\n-- 4. Views de relatorio gerencial e indices\n-- ---------------------------------------------------------------------\n\n",
    ler("05_views_indices.sql"),
]
open(saida, "w", encoding="utf-8", newline="\n").write("".join(partes))
print("gerado", saida)
