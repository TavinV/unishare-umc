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
| `vw_equipamentos_disponiveis` | `ix_equipamento_situacao` (equipamento: situacao) |
| `vw_solicitacoes_pendentes` | `ix_solicitacao_status` (solicitacao: status) |
| `vw_reservas_em_andamento` | `ix_reserva_status` (reserva: status) |
| `vw_receita_por_categoria` | `ix_pagamento_status` (pagamento_simulado: status) |
| `vw_danos_em_aberto` | `ix_dano_status` (dano: status_andamento) |
| `vw_avaliacoes_negativas` | `ix_avaliacao_nota` (avaliacao: nota) |
| `vw_documentos_pendentes` | `ix_documento_status` (documento_identidade: status) |
| `vw_notificacoes_nao_lidas` | `ix_notificacao_lida` (notificacao: lida) |

Cada view tem no máximo 4 `JOIN`s. Algumas usam subquery (contar fotos, pegar a disponibilização mais recente) e
funções simples (`COUNT`, `SUM`, `MIN`, `MAX`, `DATEDIFF`). O índice de cada view é a coluna pela qual ela filtra.

## Como executar
Conectado como `root`, execute o arquivo inteiro como **script** (**Alt+X** no DBeaver). Se o banco já existir,
rode `DROP DATABASE unishare;` antes.
