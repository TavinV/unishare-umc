-- UniShare - roteiro de testes da Entrega 3 (MySQL 8.4)
-- Executar apos o script da Entrega 2 e o script da Entrega 3.
-- As linhas marcadas com ERRO ESPERADO devem ser barradas pelo banco.

USE unishare;

-- ---------------------------------------------------------------------
-- A. Regra de negocio RN24/RN25
-- ---------------------------------------------------------------------

-- oferta de aluguel ativa em dezembro de um equipamento de aluno disponivel
SET @disp = (SELECT d.id_disponibilizacao
             FROM disponibilizacao d
             JOIN equipamento e ON e.id_equipamento = d.id_equipamento
             JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
             WHERE e.situacao = 'DISPONIVEL' AND u.perfil = 'ALUNO' AND d.modalidade = 'ALUGUEL'
               AND d.data_inicio <= '2026-12-01' AND d.data_fim >= '2026-12-10'
             ORDER BY d.id_disponibilizacao LIMIT 1);
SET @equip = (SELECT id_equipamento FROM disponibilizacao WHERE id_disponibilizacao = @disp);
SET @dono = (SELECT id_usuario_proprietario FROM equipamento WHERE id_equipamento = @equip);
SET @aluno1 = (SELECT a.id_aluno FROM aluno a JOIN usuario u ON u.id_usuario = a.id_usuario
               WHERE u.status_conta = 'ATIVA' AND a.situacao_vinculo = 'ATIVO' AND a.id_usuario <> @dono ORDER BY a.id_aluno LIMIT 1);
SET @aluno2 = (SELECT a.id_aluno FROM aluno a JOIN usuario u ON u.id_usuario = a.id_usuario
               WHERE u.status_conta = 'ATIVA' AND a.situacao_vinculo = 'ATIVO' AND a.id_usuario <> @dono AND a.id_aluno <> @aluno1
               ORDER BY a.id_aluno LIMIT 1);

-- duas solicitacoes pendentes com periodos sobrepostos
CALL sp_solicitacao_inserir(@aluno1, @disp, '2026-12-02', '2026-12-05');
SET @sol1 = LAST_INSERT_ID();
CALL sp_solicitacao_inserir(@aluno2, @disp, '2026-12-04', '2026-12-07');
SET @sol2 = LAST_INSERT_ID();
CALL sp_pagamento_simulado_inserir(@sol2);

-- ERRO ESPERADO (RN26): quem aprova nao e o proprietario
CALL sp_aprovar_solicitacao(@sol1, (SELECT id_usuario FROM aluno WHERE id_aluno = @aluno1), '203.0.113.99', NULL, NULL);

-- aprovacao valida: cria a reserva e recusa automaticamente a sol2 (RN25)
CALL sp_aprovar_solicitacao(@sol1, @dono, '203.0.113.50', -23.519600, -46.188300);

SELECT id_solicitacao, status, justificativa_recusa FROM solicitacao WHERE id_solicitacao IN (@sol1, @sol2);
SELECT p.status AS status_pagamento_sol2 FROM pagamento_simulado p WHERE p.id_solicitacao = @sol2;
SELECT situacao AS situacao_equipamento FROM equipamento WHERE id_equipamento = @equip;
SELECT tipo, id_usuario, id_solicitacao FROM notificacao WHERE id_solicitacao IN (@sol1, @sol2) ORDER BY id_notificacao;

-- ERRO ESPERADO (RN40): a solicitacao ja foi aprovada
CALL sp_aprovar_solicitacao(@sol1, @dono, '203.0.113.50', NULL, NULL);

-- ERRO ESPERADO (RN24, trigger): aprovar direto uma terceira solicitacao sobreposta
CALL sp_solicitacao_inserir(@aluno2, @disp, '2026-12-03', '2026-12-06');
SET @sol3 = LAST_INSERT_ID();
UPDATE solicitacao SET status = 'APROVADA', respondida_em = NOW() WHERE id_solicitacao = @sol3;

-- ERRO ESPERADO (RN24 dentro da transacao): o trigger barra a aprovacao e a procedure faz ROLLBACK
CALL sp_aprovar_solicitacao(@sol3, @dono, '203.0.113.50', NULL, NULL);
SELECT s.status AS status_sol3_apos_rollback,
       (SELECT COUNT(*) FROM reserva r WHERE r.id_solicitacao = @sol3) AS reservas_sol3,
       (SELECT COUNT(*) FROM registro_operacao ro WHERE ro.tabela_afetada = 'solicitacao' AND ro.id_afetado = @sol3
          AND ro.tipo_operacao = 'APROVACAO') AS logs_aprovacao_sol3
FROM solicitacao s WHERE s.id_solicitacao = @sol3;

-- ---------------------------------------------------------------------
-- B. Procedures de insercao, atualizacao e exclusao logica
-- ---------------------------------------------------------------------
SET @inst = (SELECT id_instituicao FROM instituicao LIMIT 1);
SET @curso1 = (SELECT id_curso FROM curso ORDER BY id_curso LIMIT 1);
SET @curso2 = (SELECT id_curso FROM curso ORDER BY id_curso LIMIT 1 OFFSET 1);
SET @cat = (SELECT id_categoria FROM categoria ORDER BY id_categoria LIMIT 1);
SET @termo = (SELECT id_termo FROM termo_uso WHERE versao = '1.1');

-- usuario
CALL sp_usuario_inserir('Teste Procedures', '52998224725', 'teste.procedures@aluno.umc.br',
                        '$2b$12$abcdefghijklmnopqrstuvABCDEFGHIJKLMNOPQRSTUVWXYZ01234', 'ALUNO', '11999990000', NULL);
SET @u = LAST_INSERT_ID();
CALL sp_usuario_atualizar(@u, 'Teste Procedures Atualizado', 'teste.procedures@aluno.umc.br', '11988887777', 'ATIVA');

-- aluno e aluno_curso
CALL sp_aluno_inserir('11269999001', 'ATIVO', @u);
SET @a = LAST_INSERT_ID();
CALL sp_aluno_atualizar(@a, '11269999002', 'ATIVO');
CALL sp_aluno_curso_inserir(@a, @curso1);
CALL sp_aluno_curso_atualizar(@a, @curso1, @curso2);

-- documento_identidade
CALL sp_documento_identidade_inserir(@a, 'RG', '123456789', 'documentos/11269999002/rg.pdf');
SET @doc = LAST_INSERT_ID();
CALL sp_documento_identidade_atualizar(@doc, 'APROVADO', NULL, (SELECT id_usuario FROM usuario WHERE perfil = 'ADM' LIMIT 1));

-- biometria_facial
CALL sp_biometria_facial_inserir(@u, UNHEX(LEFT(MD5(RAND()), 24)), UNHEX(MD5(RAND())), UNHEX(REPEAT(MD5(RAND()), 128)), 1, 'arcface_r50_v1');
SET @bio = LAST_INSERT_ID();
CALL sp_biometria_facial_atualizar(@bio, UNHEX(LEFT(MD5(RAND()), 24)), UNHEX(MD5(RAND())), UNHEX(REPEAT(MD5(RAND()), 128)), 2);

-- aceite_termo
CALL sp_aceite_termo_inserir(@u, @termo);
CALL sp_aceite_termo_atualizar(@u, @termo);

-- equipamento e disponibilizacao
CALL sp_equipamento_inserir('Equipamento de Teste', 'Item criado pelo roteiro de testes.', 'BOM', @cat, @u);
SET @e = LAST_INSERT_ID();
CALL sp_equipamento_atualizar(@e, 'Equipamento de Teste', 'Descricao atualizada.', 'OTIMO', 'DISPONIVEL', @cat);
CALL sp_disponibilizacao_inserir(@e, 'ALUGUEL', 12.50, '2026-12-01', '2026-12-20', NULL);
SET @d = LAST_INSERT_ID();
CALL sp_disponibilizacao_atualizar(@d, '2026-12-01', '2026-12-22', NULL);

-- solicitacao, pagamento, reserva (o aluno1 pede o equipamento do usuario de teste)
CALL sp_solicitacao_inserir(@aluno1, @d, '2026-12-10', '2026-12-12');
SET @s = LAST_INSERT_ID();
CALL sp_solicitacao_atualizar(@s, '2026-12-10', '2026-12-13');
CALL sp_pagamento_simulado_inserir(@s);
SET @p = LAST_INSERT_ID();
CALL sp_pagamento_simulado_atualizar(@p, 'SIMULADO');
UPDATE solicitacao SET status = 'APROVADA', respondida_em = NOW() WHERE id_solicitacao = @s;
CALL sp_reserva_inserir(@s);
SET @r = LAST_INSERT_ID();
CALL sp_reserva_atualizar(@r, 'EM_USO');

-- retirada, devolucao, dano e foto
SET @bio1 = (SELECT b.id_biometria FROM biometria_facial b JOIN aluno a ON a.id_usuario = b.id_usuario WHERE a.id_aluno = @aluno1 LIMIT 1);
CALL sp_retirada_inserir(@r, @bio1, 'OTIMO', NULL);
SET @ret = LAST_INSERT_ID();
CALL sp_retirada_atualizar(@ret, 'Conferido com o aluno na entrega.');
CALL sp_devolucao_inserir(@ret, 'BOM', NULL, NULL);
SET @dev = LAST_INSERT_ID();
CALL sp_devolucao_atualizar(@dev, 'Cabo USB', 'Devolvido sem o cabo.');
CALL sp_dano_inserir(@e, @u, @r, 'Risco na tampa identificado na devolucao.');
SET @dn = LAST_INSERT_ID();
CALL sp_dano_atualizar(@dn, 'RESOLVIDO');
CALL sp_foto_dano_inserir(@dn, 'danos/teste/foto_1.jpg', 'JPG', 500000);
SET @f = LAST_INSERT_ID();
CALL sp_foto_dano_atualizar(@f, 'danos/teste/foto_1b.jpg', 'JPG', 480000);

-- avaliacao, notificacao, registro_operacao
CALL sp_avaliacao_inserir(@r, @aluno1, 5, 'Tudo certo.');
SET @av = LAST_INSERT_ID();
CALL sp_avaliacao_atualizar(@av, 'Tudo certo, recomendo.');
CALL sp_notificacao_inserir(@u, @s, 'SOLICITACAO_RECEBIDA', 'Nova solicitacao para Equipamento de Teste.');
SET @n = LAST_INSERT_ID();
CALL sp_notificacao_atualizar(@n, TRUE);
CALL sp_registro_operacao_inserir('LOGIN', 'usuario', @u, '203.0.113.200', NULL, NULL, @u);
SET @log = LAST_INSERT_ID();
CALL sp_registro_operacao_atualizar(@log, -23.519600, -46.188300);

-- ERRO ESPERADO (RN20): equipamento com reserva em uso nao pode ser excluido
CALL sp_equipamento_excluir(@e);

-- exclusoes logicas (a reserva e encerrada antes de excluir o equipamento)
CALL sp_reserva_atualizar(@r, 'CONCLUIDA');
CALL sp_registro_operacao_excluir(@log);
CALL sp_notificacao_excluir(@n);
CALL sp_avaliacao_excluir(@av);
CALL sp_foto_dano_excluir(@f);
CALL sp_dano_excluir(@dn);
CALL sp_devolucao_excluir(@dev);
CALL sp_retirada_excluir(@ret);
CALL sp_reserva_excluir(@r);
CALL sp_pagamento_simulado_excluir(@p);
CALL sp_solicitacao_excluir(@s);
CALL sp_disponibilizacao_excluir(@d);
CALL sp_equipamento_excluir(@e);
CALL sp_aceite_termo_excluir(@u, @termo);
CALL sp_biometria_facial_excluir(@bio);
CALL sp_documento_identidade_excluir(@doc);
CALL sp_aluno_curso_excluir(@a, @curso2);
CALL sp_aluno_excluir(@a);
CALL sp_usuario_excluir(@u);

-- ERRO ESPERADO: atualizar um registro excluido logicamente
CALL sp_usuario_atualizar(@u, 'Nao deve atualizar', 'x@aluno.umc.br', NULL, 'ATIVA');

-- conferencia: todos os registros de teste ficam no banco, mas inativos
SELECT 'usuario' AS tabela, ativo, excluido_em IS NOT NULL AS tem_data FROM usuario WHERE id_usuario = @u
UNION ALL SELECT 'aluno', ativo, excluido_em IS NOT NULL FROM aluno WHERE id_aluno = @a
UNION ALL SELECT 'aluno_curso', ativo, excluido_em IS NOT NULL FROM aluno_curso WHERE id_aluno = @a
UNION ALL SELECT 'documento_identidade', ativo, excluido_em IS NOT NULL FROM documento_identidade WHERE id_documento = @doc
UNION ALL SELECT 'biometria_facial', ativo, excluido_em IS NOT NULL FROM biometria_facial WHERE id_biometria = @bio
UNION ALL SELECT 'aceite_termo', ativo, excluido_em IS NOT NULL FROM aceite_termo WHERE id_usuario = @u AND id_termo = @termo
UNION ALL SELECT 'equipamento', ativo, excluido_em IS NOT NULL FROM equipamento WHERE id_equipamento = @e
UNION ALL SELECT 'disponibilizacao', ativo, excluido_em IS NOT NULL FROM disponibilizacao WHERE id_disponibilizacao = @d
UNION ALL SELECT 'solicitacao', ativo, excluido_em IS NOT NULL FROM solicitacao WHERE id_solicitacao = @s
UNION ALL SELECT 'pagamento_simulado', ativo, excluido_em IS NOT NULL FROM pagamento_simulado WHERE id_pagamento = @p
UNION ALL SELECT 'reserva', ativo, excluido_em IS NOT NULL FROM reserva WHERE id_reserva = @r
UNION ALL SELECT 'retirada', ativo, excluido_em IS NOT NULL FROM retirada WHERE id_retirada = @ret
UNION ALL SELECT 'devolucao', ativo, excluido_em IS NOT NULL FROM devolucao WHERE id_devolucao = @dev
UNION ALL SELECT 'dano', ativo, excluido_em IS NOT NULL FROM dano WHERE id_dano = @dn
UNION ALL SELECT 'foto_dano', ativo, excluido_em IS NOT NULL FROM foto_dano WHERE id_foto = @f
UNION ALL SELECT 'avaliacao', ativo, excluido_em IS NOT NULL FROM avaliacao WHERE id_avaliacao = @av
UNION ALL SELECT 'notificacao', ativo, excluido_em IS NOT NULL FROM notificacao WHERE id_notificacao = @n
UNION ALL SELECT 'registro_operacao', ativo, excluido_em IS NOT NULL FROM registro_operacao WHERE id_registro = @log;
