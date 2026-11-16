# Entrega 1 – Modelagem e scripts iniciais

Versão original da modelagem e dos scripts. As correções feitas depois estão na [Entrega 2](../Entrega%202).

| Pasta | Arquivo | Conteúdo |
|---|---|---|
| `modelo_conceitual/` | `MER_UniShare.brM3` / `.png` | MER no brModelo: 20 entidades e 27 relacionamentos, com cardinalidades |
| `modelo_logico/` | `MR_UniShare.brM3` / `.png` | MR no brModelo: 22 tabelas e 29 chaves estrangeiras |
| `modelo_logico/` | `MR_UniShare.md` | MR em texto: `tabela(coluna, ...)` com PK sublinhada e FK indicada |
| `scripts/` | `01_criacao_tabelas.sql` | Criação do banco e das tabelas, com constraints PK, FK, UNIQUE e CHECK |
| `scripts/` | `02_populacao.sql` | Povoamento com dados fictícios do semestre na UMC |

## Pontos corrigidos na Entrega 2
- Nesta versão, o aceite do termo de uso (`aceite_termo`) está ligado a `aluno`. Na Entrega 2, passou a ser ligado a `usuario`.
- No MR em texto, as colunas opcionais estão marcadas com `?`. A Entrega 2 remove essa marcação.
- O povoamento usa IDs fixos nas chaves estrangeiras. Na Entrega 2, as FKs passam a ser preenchidas por `SELECT`.

## Como executar
Rode os dois scripts em ordem, como **script** no DBeaver (**Alt+X**), conectado como `root`.

> As validações de formato (CPF, CNPJ, telefone e matrícula) usam `CHAR_LENGTH` e `NOT REGEXP '[^0-9]'`, em vez de
> expressões com `{n}` e `$`. Essa forma evita um erro de separação de comandos no DBeaver.
