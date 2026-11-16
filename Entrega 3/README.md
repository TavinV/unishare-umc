# Entrega 3 – Regra de negócio e procedures

| Arquivo | Conteúdo |
|---|---|
| `scripts/UniShare_entrega3_regras_procedures.sql` | Arquivo da entrega: regra de negócio e procedures |
| `scripts/testes_entrega3.sql` | Roteiro de testes da regra de negócio e de todas as procedures |
| `scripts/testes_entrega3_resultado.txt` | Saída da execução do roteiro de testes |

**Pré-requisito:** o banco `unishare` criado e povoado pelo script da [Entrega 2](../Entrega%202).

## 1. Regra de negócio: aprovação sem conflito de reservas (RN24/RN25)

> **RN24:** não pode haver duas reservas aprovadas do mesmo equipamento com períodos sobrepostos.
> **RN25:** ao aprovar uma solicitação, as pendentes sobrepostas são recusadas automaticamente e os solicitantes são avisados.

A implementação combina **trigger, procedure e transação**:

| Objeto | Papel |
|---|---|
| `trg_solicitacao_bi_conflito` / `trg_solicitacao_bu_conflito` | Triggers que barram qualquer `INSERT` ou `UPDATE` que deixe duas solicitações aprovadas sobrepostas para o mesmo equipamento, mesmo fora da procedure |
| `sp_aprovar_solicitacao` | Procedure com `START TRANSACTION` / `COMMIT` e `ROLLBACK` em caso de erro |

O que a `sp_aprovar_solicitacao` faz:
1. Bloqueia a solicitação, a oferta e o equipamento (`SELECT ... FOR UPDATE`).
2. Valida que a solicitação está pendente (RN40), que quem aprova é o proprietário (RN26) e que o equipamento não está em manutenção (RN18).
3. Aprova a solicitação, cria a reserva e passa o equipamento para RESERVADO.
4. Recusa automaticamente as solicitações pendentes sobrepostas, cancela os pagamentos simulados delas, notifica os alunos e registra a auditoria (RN25).
5. Em qualquer erro, como o trigger barrando a RN24, desfaz tudo com `ROLLBACK`.

## 2. Procedures de CRUD com exclusão lógica

As 18 tabelas que não são de parâmetro ganham as colunas `ativo` (`BOOLEAN`, padrão `TRUE`) e `excluido_em` (`DATETIME`).
Cada uma tem três procedures:

| Procedure | Função |
|---|---|
| `sp_<tabela>_inserir` | Insere o registro e devolve o ID gerado |
| `sp_<tabela>_atualizar` | Atualiza os campos que podem mudar. Recusa registro inexistente ou excluído |
| `sp_<tabela>_excluir` | Exclusão lógica: `ativo = FALSE` e `excluido_em = NOW()` |

**Tabelas com procedures:** `usuario`, `aluno`, `aluno_curso`, `documento_identidade`, `biometria_facial`, `aceite_termo`,
`equipamento`, `disponibilizacao`, `solicitacao`, `pagamento_simulado`, `reserva`, `retirada`, `devolucao`, `dano`,
`foto_dano`, `avaliacao`, `notificacao` e `registro_operacao`.

**Tabelas de parâmetro, sem procedures:** `instituicao`, `curso`, `categoria` e `termo_uso`.

As atualizações respeitam as regras de negócio. Por exemplo:
- **RN04:** CPF e perfil do usuário não mudam.
- **RNF14:** retirada e devolução só aceitam complemento de observação.
- **RN34:** do dano, só o andamento do reparo é atualizado.
- **RN37:** a nota da avaliação não é editada.
- **RN20:** `sp_equipamento_excluir` recusa equipamento com reserva confirmada ou em uso.

## Como executar
1. Execute o script da Entrega 2.
2. Execute `UniShare_entrega3_regras_procedures.sql` como **script** (**Alt+X** no DBeaver). O arquivo usa `DELIMITER //` para definir as rotinas.
3. Opcionalmente, execute `testes_entrega3.sql`. As linhas marcadas com `ERRO ESPERADO` devem ser barradas pelo banco. No DBeaver, configure a execução para continuar após erros, ou rode bloco a bloco.

Resultado esperado: 55 procedures (1 da regra de negócio e 54 de CRUD) e 2 triggers.
