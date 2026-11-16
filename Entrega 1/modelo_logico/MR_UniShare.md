# Modelo Relacional - UniShare

Notação: chave primária <u>sublinhada</u>; chave estrangeira marcada com (FK) logo após a coluna; colunas opcionais terminam com `?`.

---

instituicao(<u>id_instituicao</u>, nome, sigla, cnpj)

curso(<u>id_curso</u>, nome, id_instituicao (FK))

usuario(<u>id_usuario</u>, nome, cpf, email, senha_hash, perfil, telefone?, status_conta, criado_em, id_instituicao? (FK))

aluno(<u>id_aluno</u>, matricula, situacao_vinculo, id_usuario (FK))

aluno_curso(<u>id_aluno</u> (FK), <u>id_curso</u> (FK))

documento_identidade(<u>id_documento</u>, tipo_documento, numero_documento, arquivo_url, status, motivo_recusa?, enviado_em, analisado_em?, id_aluno (FK), id_usuario_analista? (FK))

biometria_facial(<u>id_biometria</u>, id_usuario (FK), embedding_iv, embedding_tag, embedding_ct, key_version, model_version, criado_em)

termo_uso(<u>id_termo</u>, versao, conteudo, publicado_em)

aceite_termo(<u>id_aluno</u> (FK), <u>id_termo</u> (FK), data_hora_aceite)

categoria(<u>id_categoria</u>, nome)

equipamento(<u>id_equipamento</u>, nome, descricao, estado_conservacao, situacao, criado_em, id_categoria (FK), id_usuario_proprietario (FK))

disponibilizacao(<u>id_disponibilizacao</u>, modalidade, valor_diaria, data_inicio, data_fim, prazo_maximo_dias?, criado_em, id_equipamento (FK))

solicitacao(<u>id_solicitacao</u>, data_inicio, data_fim, status, justificativa_recusa?, criada_em, respondida_em?, id_aluno (FK), id_disponibilizacao (FK))

pagamento_simulado(<u>id_pagamento</u>, valor_total, status, data_hora, id_solicitacao (FK))

reserva(<u>id_reserva</u>, status, criada_em, id_solicitacao (FK))

retirada(<u>id_retirada</u>, data_hora, estado_conservacao, observacao?, codigo_comprovante, id_reserva (FK), id_biometria (FK))

devolucao(<u>id_devolucao</u>, data_hora, estado_conservacao, itens_faltantes?, observacao?, codigo_comprovante, id_retirada (FK))

dano(<u>id_dano</u>, descricao, data_hora, status_andamento, resolvido_em?, id_equipamento (FK), id_usuario_relator (FK), id_reserva? (FK))

foto_dano(<u>id_foto</u>, url_arquivo, formato, tamanho_bytes, enviada_em, id_dano (FK))

avaliacao(<u>id_avaliacao</u>, nota, comentario?, data_hora, id_aluno_avaliador (FK), id_reserva (FK))

notificacao(<u>id_notificacao</u>, tipo, mensagem, enviada_em, lida, id_usuario (FK), id_solicitacao? (FK))

registro_operacao(<u>id_registro</u>, tipo_operacao, tabela_afetada, id_afetado, endereco_ip, latitude?, longitude?, data_hora, id_usuario? (FK))

---

## Destino das chaves estrangeiras

| Tabela | Coluna (FK) | Referencia |
|---|---|---|
| curso | id_instituicao | instituicao |
| usuario | id_instituicao | instituicao |
| aluno | id_usuario | usuario |
| aluno_curso | id_aluno | aluno |
| aluno_curso | id_curso | curso |
| documento_identidade | id_aluno | aluno |
| documento_identidade | id_usuario_analista | usuario |
| biometria_facial | id_usuario | usuario |
| aceite_termo | id_aluno | aluno |
| aceite_termo | id_termo | termo_uso |
| equipamento | id_categoria | categoria |
| equipamento | id_usuario_proprietario | usuario |
| disponibilizacao | id_equipamento | equipamento |
| solicitacao | id_aluno | aluno |
| solicitacao | id_disponibilizacao | disponibilizacao |
| pagamento_simulado | id_solicitacao | solicitacao |
| reserva | id_solicitacao | solicitacao |
| retirada | id_reserva | reserva |
| retirada | id_biometria | biometria_facial |
| devolucao | id_retirada | retirada |
| dano | id_equipamento | equipamento |
| dano | id_usuario_relator | usuario |
| dano | id_reserva | reserva |
| foto_dano | id_dano | dano |
| avaliacao | id_aluno_avaliador | aluno |
| avaliacao | id_reserva | reserva |
| notificacao | id_usuario | usuario |
| notificacao | id_solicitacao | solicitacao |
| registro_operacao | id_usuario | usuario |

Observacoes:
- `aluno_curso` e `aceite_termo` sao tabelas associativas (N:N): a chave primaria e composta por duas chaves estrangeiras.
- `registro_operacao.id_afetado` nao e FK, pois aponta para tabelas diferentes conforme `tabela_afetada`.
