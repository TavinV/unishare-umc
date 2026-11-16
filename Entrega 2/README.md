# Entrega 2 – Correções, views e índices

| Pasta | Arquivo | Conteúdo |
|---|---|---|
| `modelo_conceitual/` | `MER_UniShare.brM3` / `.png` | MER corrigido: o relacionamento `aceita` liga USUARIO a TERMO_USO |
| `modelo_logico/` | `MR_UniShare.brM3` / `.png` | MR corrigido: `aceite_termo` referencia `usuario` |
| `modelo_logico/` | `MR_UniShare.md` | MR em texto, sem `?` |
| `scripts/` | `UniShare_script_completo.sql` | Arquivo único da entrega |

## Conteúdo do `UniShare_script_completo.sql`
1. Identificação do grupo.
2. Criação do banco e das 22 tabelas.
3. Povoamento. As chaves primárias são geradas por `AUTO_INCREMENT`, e **todas as chaves estrangeiras são preenchidas por
   `SELECT`** sobre um dado que identifica o registro:
   - usuário pelo e-mail;
   - aluno pela matrícula;
   - instituição pelo CNPJ;
   - equipamento pelo nome;
   - retirada e devolução pelo código do comprovante.

   Por exemplo:
   ```sql
   INSERT INTO aluno (matricula, situacao_vinculo, id_usuario) VALUES
     ('11240001000', 'ATIVO', (SELECT id_usuario FROM usuario WHERE email = 'ana.souza@aluno.umc.br'));
   ```
4. **8 views** de relatório gerencial, cada uma seguida de **1 índice** que a otimiza. O uso de cada índice pela sua
   view foi confirmado com `EXPLAIN`.

| View | Índice |
|---|---|
| `vw_desempenho_equipamentos` | `ix_solicitacao_disp_status_periodo` |
| `vw_tempo_devolucao_categoria` | `ix_devolucao_retirada_data` |
| `vw_receita_proprietarios` | `ix_pagamento_status_solicitacao_valor` |
| `vw_solicitacoes_mensais` | `ix_solicitacao_criada_status_resposta` |
| `vw_reputacao_alunos` | `ix_avaliacao_reserva_avaliador_nota` |
| `vw_danos_em_aberto` | `ix_dano_status_data` |
| `vw_inventario_categoria` | `ix_equipamento_categoria_situacao` |
| `vw_auditoria_usuarios` | `ix_registro_usuario_tipo_data` |

## Como executar
Conectado como `root`, execute o arquivo inteiro como **script** (**Alt+X** no DBeaver). Se o banco já existir,
rode `DROP DATABASE unishare;` antes.
