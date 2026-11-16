# Ferramentas

Scripts usados para gerar os diagramas e o povoamento. Não são necessários para executar o banco.

## `gerador_brmodelo/`
Geram os arquivos `.brM3` e `.png` do MER e do MR usando a API interna do brModelo 3.2. Rodam com o `jjs`
(Nashorn) do Java 8.

| Arquivo | Função |
|---|---|
| `model.js` | Especificação do MER: entidades, atributos, relacionamentos, cardinalidades e layout |
| `mr_model.js` | Especificação do MR: tabelas, colunas, PKs, FKs e layout |
| `build.js` / `build_mr.js` | Geram o MER e o MR |
| `lib.js` | Funções auxiliares (abrir o brModelo, salvar PNG e XML) |
| `reload2.js` | Reabre um `.brM3` para conferir se o arquivo foi salvo corretamente |

Para gerar, rode a partir de uma pasta que contenha `tools/` (com estes arquivos) e `out/`. O caminho do jar não pode
ter acentos:

```bash
jjs -J-Djava.class.path=brModelo.jar -cp brModelo.jar tools/build.js -- <pasta>
```

## `gerador_sql/`

| Arquivo | Função |
|---|---|
| `gerar_populacao.py` | Simula o semestre na UMC dia a dia, aplicando as regras de negócio, e gera o povoamento com as FKs preenchidas por `SELECT`. Aceita uma semente opcional como segundo argumento (padrão 22) |
| `montar_entrega.py` | Junta o cabeçalho, `partes/01_criacao_tabelas.sql`, o povoamento e `partes/05_views_indices.sql` no arquivo único da Entrega 2 |

```bash
python gerar_populacao.py partes/02_populacao.sql
```

```bash
python montar_entrega.py partes ../../Entrega\ 2/scripts/UniShare_script_completo.sql
```
