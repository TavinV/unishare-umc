-- =====================================================================
-- UniShare - Entrega 3: regra de negocio e procedures (MySQL 8.4)
-- Banco de Dados - Universidade de Mogi das Cruzes
--
-- GRUPO 4
-- RGM          Nome completo
-- 11261104620  Daniel Matsuo Rubino
-- 11261102520  Igor Delfino Braga
-- 11261103184  Mariana Rodrigues Fonseca
-- 11261102024  Maristela Silva Siqueira
-- 11261103039  Otavio Vinicius Flauzino de Souza
-- 11261102968  Roberta da Silva Ribeiro
--
-- Pre-requisito: banco unishare criado e povoado pelo script da Entrega 2.
--
-- Conteudo:
--   1. Colunas de exclusao logica (ativo, excluido_em) nas tabelas de movimento
--   2. Regra de negocio RN24/RN25: aprovacao de solicitacao sem conflito de
--      reservas, implementada com trigger + procedure + transacao
--   3. Procedures de insercao, atualizacao e exclusao logica para cada tabela
--      que nao e de parametro/configuracao
--
-- Tabelas de parametro/configuracao (sem procedures): instituicao, curso,
-- categoria e termo_uso.
-- =====================================================================

USE unishare;

-- ---------------------------------------------------------------------
-- 1. Exclusao logica: registro inativo continua no banco para auditoria
-- ---------------------------------------------------------------------
ALTER TABLE usuario              ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE aluno                ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE aluno_curso          ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE documento_identidade ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE biometria_facial     ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE aceite_termo         ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE equipamento          ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE disponibilizacao     ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE solicitacao          ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE pagamento_simulado   ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE reserva              ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE retirada             ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE devolucao            ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE dano                 ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE foto_dano            ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE avaliacao            ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE notificacao          ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;
ALTER TABLE registro_operacao    ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD COLUMN excluido_em DATETIME NULL;

DELIMITER //

-- ---------------------------------------------------------------------
-- 2. Regra de negocio RN24/RN25 (com RN18, RN26 e RN40)
--    RN24: nao pode haver duas reservas aprovadas do mesmo equipamento
--          com periodos sobrepostos.
--    RN25: ao aprovar uma solicitacao, as pendentes sobrepostas sao
--          recusadas automaticamente e os solicitantes sao avisados.
-- ---------------------------------------------------------------------

-- Trigger: garante a RN24 em qualquer insercao de solicitacao ja aprovada
CREATE TRIGGER trg_solicitacao_bi_conflito
BEFORE INSERT ON solicitacao
FOR EACH ROW
BEGIN
  IF NEW.status = 'APROVADA' AND EXISTS (
       SELECT 1
       FROM solicitacao s
       JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
       WHERE d.id_equipamento = (SELECT d2.id_equipamento FROM disponibilizacao d2
                                 WHERE d2.id_disponibilizacao = NEW.id_disponibilizacao)
         AND s.status = 'APROVADA'
         AND s.ativo = TRUE
         AND s.data_inicio < NEW.data_fim
         AND NEW.data_inicio < s.data_fim) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN24: ja existe reserva aprovada para este equipamento no periodo';
  END IF;
END //

-- Trigger: garante a RN24 em qualquer atualizacao que aprove uma solicitacao
CREATE TRIGGER trg_solicitacao_bu_conflito
BEFORE UPDATE ON solicitacao
FOR EACH ROW
BEGIN
  IF NEW.status = 'APROVADA' AND (OLD.status <> 'APROVADA' OR NEW.data_inicio <> OLD.data_inicio OR NEW.data_fim <> OLD.data_fim)
     AND EXISTS (
       SELECT 1
       FROM solicitacao s
       JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
       WHERE d.id_equipamento = (SELECT d2.id_equipamento FROM disponibilizacao d2
                                 WHERE d2.id_disponibilizacao = NEW.id_disponibilizacao)
         AND s.id_solicitacao <> NEW.id_solicitacao
         AND s.status = 'APROVADA'
         AND s.ativo = TRUE
         AND s.data_inicio < NEW.data_fim
         AND NEW.data_inicio < s.data_fim) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN24: ja existe reserva aprovada para este equipamento no periodo';
  END IF;
END //

-- Procedure: aprova uma solicitacao dentro de uma transacao
CREATE PROCEDURE sp_aprovar_solicitacao(
  IN p_id_solicitacao INT UNSIGNED,
  IN p_id_usuario     INT UNSIGNED,
  IN p_endereco_ip    VARCHAR(45),
  IN p_latitude       DECIMAL(9,6),
  IN p_longitude      DECIMAL(9,6))
BEGIN
  DECLARE v_status      VARCHAR(10);
  DECLARE v_inicio      DATE;
  DECLARE v_fim         DATE;
  DECLARE v_equipamento INT UNSIGNED;
  DECLARE v_dono        INT UNSIGNED;
  DECLARE v_situacao    VARCHAR(15);
  DECLARE v_nome_equip  VARCHAR(120);
  DECLARE v_aluno_user  INT UNSIGNED;
  DECLARE v_agora       DATETIME DEFAULT NOW();

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  -- bloqueia a solicitacao, a oferta e o equipamento ate o fim da transacao
  SELECT s.status, s.data_inicio, s.data_fim, e.id_equipamento, e.id_usuario_proprietario, e.situacao, e.nome, a.id_usuario
    INTO v_status, v_inicio, v_fim, v_equipamento, v_dono, v_situacao, v_nome_equip, v_aluno_user
  FROM solicitacao s
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  JOIN equipamento e ON e.id_equipamento = d.id_equipamento
  JOIN aluno a ON a.id_aluno = s.id_aluno
  WHERE s.id_solicitacao = p_id_solicitacao AND s.ativo = TRUE
  FOR UPDATE;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitacao inexistente ou excluida';
  END IF;
  IF v_status <> 'PENDENTE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN40: somente solicitacao pendente pode ser aprovada';
  END IF;
  IF v_dono <> p_id_usuario THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN26: somente o proprietario do equipamento pode aprovar';
  END IF;
  IF v_situacao IN ('EM_MANUTENCAO', 'INDISPONIVEL') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN18: equipamento em manutencao ou indisponivel';
  END IF;

  -- aprova (o trigger trg_solicitacao_bu_conflito valida a RN24)
  UPDATE solicitacao SET status = 'APROVADA', respondida_em = v_agora
  WHERE id_solicitacao = p_id_solicitacao;

  INSERT INTO reserva (status, criada_em, id_solicitacao) VALUES ('CONFIRMADA', v_agora, p_id_solicitacao);

  -- RN25: identifica as pendentes sobrepostas do mesmo equipamento
  DROP TEMPORARY TABLE IF EXISTS tmp_conflitos;
  CREATE TEMPORARY TABLE tmp_conflitos AS
  SELECT s.id_solicitacao, a.id_usuario
  FROM solicitacao s
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  JOIN aluno a ON a.id_aluno = s.id_aluno
  WHERE d.id_equipamento = v_equipamento
    AND s.id_solicitacao <> p_id_solicitacao
    AND s.status = 'PENDENTE'
    AND s.ativo = TRUE
    AND s.data_inicio < v_fim
    AND v_inicio < s.data_fim;

  UPDATE solicitacao s
  JOIN tmp_conflitos t ON t.id_solicitacao = s.id_solicitacao
  SET s.status = 'RECUSADA',
      s.respondida_em = v_agora,
      s.justificativa_recusa = 'Recusada automaticamente: conflito com reserva aprovada no mesmo periodo.';

  UPDATE pagamento_simulado p
  JOIN tmp_conflitos t ON t.id_solicitacao = p.id_solicitacao
  SET p.status = 'CANCELADO';

  INSERT INTO notificacao (tipo, mensagem, enviada_em, lida, id_usuario, id_solicitacao)
  SELECT 'SOLICITACAO_RECUSADA', CONCAT('Sua solicitacao de "', v_nome_equip, '" foi recusada por conflito de periodo.'),
         v_agora, FALSE, t.id_usuario, t.id_solicitacao
  FROM tmp_conflitos t;

  INSERT INTO registro_operacao (tipo_operacao, tabela_afetada, id_afetado, endereco_ip, latitude, longitude, data_hora, id_usuario)
  SELECT 'RECUSA_AUTOMATICA', 'solicitacao', t.id_solicitacao, '10.20.0.5', NULL, NULL, v_agora, NULL
  FROM tmp_conflitos t;

  -- equipamento passa a reservado e o solicitante e avisado
  IF v_situacao = 'DISPONIVEL' THEN
    UPDATE equipamento SET situacao = 'RESERVADO' WHERE id_equipamento = v_equipamento;
  END IF;

  INSERT INTO notificacao (tipo, mensagem, enviada_em, lida, id_usuario, id_solicitacao)
  VALUES ('CONFIRMACAO_RESERVA', CONCAT('Sua reserva de "', v_nome_equip, '" foi confirmada.'), v_agora, FALSE, v_aluno_user, p_id_solicitacao);

  INSERT INTO registro_operacao (tipo_operacao, tabela_afetada, id_afetado, endereco_ip, latitude, longitude, data_hora, id_usuario)
  VALUES ('APROVACAO', 'solicitacao', p_id_solicitacao, p_endereco_ip, p_latitude, p_longitude, v_agora, p_id_usuario);

  DROP TEMPORARY TABLE IF EXISTS tmp_conflitos;
  COMMIT;

  SELECT p_id_solicitacao AS id_solicitacao_aprovada,
         (SELECT id_reserva FROM reserva WHERE id_solicitacao = p_id_solicitacao) AS id_reserva_criada;
END //

-- ---------------------------------------------------------------------
-- 3. Procedures de insercao, atualizacao e exclusao logica
-- ---------------------------------------------------------------------

-- usuario ------------------------------------------------------------
CREATE PROCEDURE sp_usuario_inserir(
  IN p_nome VARCHAR(120), IN p_cpf CHAR(11), IN p_email VARCHAR(150), IN p_senha_hash CHAR(60),
  IN p_perfil VARCHAR(5), IN p_telefone VARCHAR(11), IN p_id_instituicao INT UNSIGNED)
BEGIN
  INSERT INTO usuario (nome, cpf, email, senha_hash, perfil, telefone, status_conta, criado_em, id_instituicao)
  VALUES (p_nome, p_cpf, p_email, p_senha_hash, p_perfil, p_telefone,
          CASE WHEN p_perfil = 'ADM' THEN 'ATIVA' ELSE 'PENDENTE' END, NOW(), p_id_instituicao);
  SELECT LAST_INSERT_ID() AS id_usuario;
END //

-- RN04: cpf e perfil nao mudam; o aluno altera apenas os dados de contato
CREATE PROCEDURE sp_usuario_atualizar(
  IN p_id_usuario INT UNSIGNED, IN p_nome VARCHAR(120), IN p_email VARCHAR(150),
  IN p_telefone VARCHAR(11), IN p_status_conta VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario inexistente ou excluido';
  END IF;
  UPDATE usuario
  SET nome = p_nome, email = p_email, telefone = p_telefone, status_conta = p_status_conta
  WHERE id_usuario = p_id_usuario;
END //

CREATE PROCEDURE sp_usuario_excluir(IN p_id_usuario INT UNSIGNED)
BEGIN
  UPDATE usuario SET ativo = FALSE, excluido_em = NOW(), status_conta = 'INATIVA'
  WHERE id_usuario = p_id_usuario AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario inexistente ou ja excluido';
  END IF;
END //

-- aluno --------------------------------------------------------------
CREATE PROCEDURE sp_aluno_inserir(IN p_matricula CHAR(11), IN p_situacao_vinculo VARCHAR(10), IN p_id_usuario INT UNSIGNED)
BEGIN
  INSERT INTO aluno (matricula, situacao_vinculo, id_usuario) VALUES (p_matricula, p_situacao_vinculo, p_id_usuario);
  SELECT LAST_INSERT_ID() AS id_aluno;
END //

-- RN04: apenas o ADM altera matricula e vinculo
CREATE PROCEDURE sp_aluno_atualizar(IN p_id_aluno INT UNSIGNED, IN p_matricula CHAR(11), IN p_situacao_vinculo VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno inexistente ou excluido';
  END IF;
  UPDATE aluno SET matricula = p_matricula, situacao_vinculo = p_situacao_vinculo WHERE id_aluno = p_id_aluno;
END //

CREATE PROCEDURE sp_aluno_excluir(IN p_id_aluno INT UNSIGNED)
BEGIN
  UPDATE aluno SET ativo = FALSE, excluido_em = NOW() WHERE id_aluno = p_id_aluno AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno inexistente ou ja excluido';
  END IF;
END //

-- aluno_curso --------------------------------------------------------
CREATE PROCEDURE sp_aluno_curso_inserir(IN p_id_aluno INT UNSIGNED, IN p_id_curso INT UNSIGNED)
BEGIN
  INSERT INTO aluno_curso (id_aluno, id_curso) VALUES (p_id_aluno, p_id_curso)
  ON DUPLICATE KEY UPDATE ativo = TRUE, excluido_em = NULL;
END //

-- troca o curso de um vinculo existente
CREATE PROCEDURE sp_aluno_curso_atualizar(IN p_id_aluno INT UNSIGNED, IN p_id_curso_atual INT UNSIGNED, IN p_id_curso_novo INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM aluno_curso WHERE id_aluno = p_id_aluno AND id_curso = p_id_curso_atual AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vinculo aluno e curso inexistente ou excluido';
  END IF;
  UPDATE aluno_curso SET id_curso = p_id_curso_novo WHERE id_aluno = p_id_aluno AND id_curso = p_id_curso_atual;
END //

CREATE PROCEDURE sp_aluno_curso_excluir(IN p_id_aluno INT UNSIGNED, IN p_id_curso INT UNSIGNED)
BEGIN
  UPDATE aluno_curso SET ativo = FALSE, excluido_em = NOW() WHERE id_aluno = p_id_aluno AND id_curso = p_id_curso AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vinculo aluno e curso inexistente ou ja excluido';
  END IF;
END //

-- documento_identidade -----------------------------------------------
CREATE PROCEDURE sp_documento_identidade_inserir(
  IN p_id_aluno INT UNSIGNED, IN p_tipo_documento VARCHAR(10), IN p_numero_documento VARCHAR(20), IN p_arquivo_url VARCHAR(255))
BEGIN
  INSERT INTO documento_identidade (tipo_documento, numero_documento, arquivo_url, status, enviado_em, id_aluno)
  VALUES (p_tipo_documento, p_numero_documento, p_arquivo_url, 'PENDENTE', NOW(), p_id_aluno);
  SELECT LAST_INSERT_ID() AS id_documento;
END //

-- analise do documento pelo ADM (RN07: recusa exige motivo)
CREATE PROCEDURE sp_documento_identidade_atualizar(
  IN p_id_documento INT UNSIGNED, IN p_status VARCHAR(10), IN p_motivo_recusa VARCHAR(255), IN p_id_usuario_analista INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM documento_identidade WHERE id_documento = p_id_documento AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Documento inexistente ou excluido';
  END IF;
  UPDATE documento_identidade
  SET status = p_status,
      motivo_recusa = CASE WHEN p_status = 'RECUSADO' THEN p_motivo_recusa ELSE NULL END,
      analisado_em = CASE WHEN p_status = 'PENDENTE' THEN NULL ELSE NOW() END,
      id_usuario_analista = CASE WHEN p_status = 'PENDENTE' THEN NULL ELSE p_id_usuario_analista END
  WHERE id_documento = p_id_documento;
END //

CREATE PROCEDURE sp_documento_identidade_excluir(IN p_id_documento INT UNSIGNED)
BEGIN
  UPDATE documento_identidade SET ativo = FALSE, excluido_em = NOW() WHERE id_documento = p_id_documento AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Documento inexistente ou ja excluido';
  END IF;
END //

-- biometria_facial ---------------------------------------------------
CREATE PROCEDURE sp_biometria_facial_inserir(
  IN p_id_usuario INT UNSIGNED, IN p_embedding_iv BINARY(12), IN p_embedding_tag BINARY(16),
  IN p_embedding_ct VARBINARY(2048), IN p_key_version INT UNSIGNED, IN p_model_version VARCHAR(50))
BEGIN
  INSERT INTO biometria_facial (id_usuario, embedding_iv, embedding_tag, embedding_ct, key_version, model_version, criado_em)
  VALUES (p_id_usuario, p_embedding_iv, p_embedding_tag, p_embedding_ct, p_key_version, p_model_version, NOW());
  SELECT LAST_INSERT_ID() AS id_biometria;
END //

-- recifra o embedding com uma nova chave (rotacao de chave)
CREATE PROCEDURE sp_biometria_facial_atualizar(
  IN p_id_biometria INT UNSIGNED, IN p_embedding_iv BINARY(12), IN p_embedding_tag BINARY(16),
  IN p_embedding_ct VARBINARY(2048), IN p_key_version INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM biometria_facial WHERE id_biometria = p_id_biometria AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Biometria inexistente ou excluida';
  END IF;
  UPDATE biometria_facial
  SET embedding_iv = p_embedding_iv, embedding_tag = p_embedding_tag, embedding_ct = p_embedding_ct, key_version = p_key_version
  WHERE id_biometria = p_id_biometria;
END //

CREATE PROCEDURE sp_biometria_facial_excluir(IN p_id_biometria INT UNSIGNED)
BEGIN
  UPDATE biometria_facial SET ativo = FALSE, excluido_em = NOW() WHERE id_biometria = p_id_biometria AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Biometria inexistente ou ja excluida';
  END IF;
END //

-- aceite_termo -------------------------------------------------------
-- RNF09: data e hora do aceite sao geradas pelo sistema
CREATE PROCEDURE sp_aceite_termo_inserir(IN p_id_usuario INT UNSIGNED, IN p_id_termo INT UNSIGNED)
BEGIN
  INSERT INTO aceite_termo (id_usuario, id_termo, data_hora_aceite) VALUES (p_id_usuario, p_id_termo, NOW());
END //

-- renova o aceite da mesma versao do termo
CREATE PROCEDURE sp_aceite_termo_atualizar(IN p_id_usuario INT UNSIGNED, IN p_id_termo INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM aceite_termo WHERE id_usuario = p_id_usuario AND id_termo = p_id_termo) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aceite inexistente';
  END IF;
  UPDATE aceite_termo SET data_hora_aceite = NOW(), ativo = TRUE, excluido_em = NULL
  WHERE id_usuario = p_id_usuario AND id_termo = p_id_termo;
END //

CREATE PROCEDURE sp_aceite_termo_excluir(IN p_id_usuario INT UNSIGNED, IN p_id_termo INT UNSIGNED)
BEGIN
  UPDATE aceite_termo SET ativo = FALSE, excluido_em = NOW()
  WHERE id_usuario = p_id_usuario AND id_termo = p_id_termo AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aceite inexistente ou ja revogado';
  END IF;
END //

-- equipamento --------------------------------------------------------
CREATE PROCEDURE sp_equipamento_inserir(
  IN p_nome VARCHAR(120), IN p_descricao VARCHAR(500), IN p_estado_conservacao VARCHAR(10),
  IN p_id_categoria INT UNSIGNED, IN p_id_usuario_proprietario INT UNSIGNED)
BEGIN
  INSERT INTO equipamento (nome, descricao, estado_conservacao, situacao, criado_em, id_categoria, id_usuario_proprietario)
  VALUES (p_nome, p_descricao, p_estado_conservacao, 'INDISPONIVEL', NOW(), p_id_categoria, p_id_usuario_proprietario);
  SELECT LAST_INSERT_ID() AS id_equipamento;
END //

CREATE PROCEDURE sp_equipamento_atualizar(
  IN p_id_equipamento INT UNSIGNED, IN p_nome VARCHAR(120), IN p_descricao VARCHAR(500),
  IN p_estado_conservacao VARCHAR(10), IN p_situacao VARCHAR(15), IN p_id_categoria INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM equipamento WHERE id_equipamento = p_id_equipamento AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipamento inexistente ou excluido';
  END IF;
  UPDATE equipamento
  SET nome = p_nome, descricao = p_descricao, estado_conservacao = p_estado_conservacao,
      situacao = p_situacao, id_categoria = p_id_categoria
  WHERE id_equipamento = p_id_equipamento;
END //

-- RN20: equipamento com reserva confirmada ou em uso nao pode ser excluido
CREATE PROCEDURE sp_equipamento_excluir(IN p_id_equipamento INT UNSIGNED)
BEGIN
  IF EXISTS (SELECT 1 FROM reserva r
             JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
             JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
             WHERE d.id_equipamento = p_id_equipamento AND r.status IN ('CONFIRMADA', 'EM_USO', 'ATRASADA') AND r.ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN20: equipamento com reserva confirmada ou em uso nao pode ser excluido';
  END IF;
  UPDATE equipamento SET ativo = FALSE, excluido_em = NOW(), situacao = 'INDISPONIVEL'
  WHERE id_equipamento = p_id_equipamento AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipamento inexistente ou ja excluido';
  END IF;
END //

-- disponibilizacao ---------------------------------------------------
CREATE PROCEDURE sp_disponibilizacao_inserir(
  IN p_id_equipamento INT UNSIGNED, IN p_modalidade VARCHAR(10), IN p_valor_diaria DECIMAL(10,2),
  IN p_data_inicio DATE, IN p_data_fim DATE, IN p_prazo_maximo_dias SMALLINT UNSIGNED)
BEGIN
  INSERT INTO disponibilizacao (modalidade, valor_diaria, data_inicio, data_fim, prazo_maximo_dias, criado_em, id_equipamento)
  VALUES (p_modalidade, p_valor_diaria, p_data_inicio, p_data_fim, p_prazo_maximo_dias, NOW(), p_id_equipamento);
  SELECT LAST_INSERT_ID() AS id_disponibilizacao;
END //

-- RN19: mudanca de modalidade ou valor deve gerar nova oferta (sp_disponibilizacao_inserir);
-- aqui so se ajusta o periodo e o prazo maximo
CREATE PROCEDURE sp_disponibilizacao_atualizar(
  IN p_id_disponibilizacao INT UNSIGNED, IN p_data_inicio DATE, IN p_data_fim DATE, IN p_prazo_maximo_dias SMALLINT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM disponibilizacao WHERE id_disponibilizacao = p_id_disponibilizacao AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Oferta inexistente ou excluida';
  END IF;
  UPDATE disponibilizacao SET data_inicio = p_data_inicio, data_fim = p_data_fim, prazo_maximo_dias = p_prazo_maximo_dias
  WHERE id_disponibilizacao = p_id_disponibilizacao;
END //

CREATE PROCEDURE sp_disponibilizacao_excluir(IN p_id_disponibilizacao INT UNSIGNED)
BEGIN
  UPDATE disponibilizacao SET ativo = FALSE, excluido_em = NOW() WHERE id_disponibilizacao = p_id_disponibilizacao AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Oferta inexistente ou ja excluida';
  END IF;
END //

-- solicitacao --------------------------------------------------------
CREATE PROCEDURE sp_solicitacao_inserir(
  IN p_id_aluno INT UNSIGNED, IN p_id_disponibilizacao INT UNSIGNED, IN p_data_inicio DATE, IN p_data_fim DATE)
BEGIN
  INSERT INTO solicitacao (data_inicio, data_fim, status, criada_em, id_aluno, id_disponibilizacao)
  VALUES (p_data_inicio, p_data_fim, 'PENDENTE', NOW(), p_id_aluno, p_id_disponibilizacao);
  SELECT LAST_INSERT_ID() AS id_solicitacao;
END //

-- o periodo so pode ser alterado enquanto a solicitacao estiver pendente
CREATE PROCEDURE sp_solicitacao_atualizar(IN p_id_solicitacao INT UNSIGNED, IN p_data_inicio DATE, IN p_data_fim DATE)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM solicitacao WHERE id_solicitacao = p_id_solicitacao AND ativo = TRUE AND status = 'PENDENTE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitacao inexistente, excluida ou ja respondida';
  END IF;
  UPDATE solicitacao SET data_inicio = p_data_inicio, data_fim = p_data_fim WHERE id_solicitacao = p_id_solicitacao;
END //

CREATE PROCEDURE sp_solicitacao_excluir(IN p_id_solicitacao INT UNSIGNED)
BEGIN
  UPDATE solicitacao SET ativo = FALSE, excluido_em = NOW() WHERE id_solicitacao = p_id_solicitacao AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitacao inexistente ou ja excluida';
  END IF;
END //

-- pagamento_simulado -------------------------------------------------
-- RF015: o valor e calculado pelo sistema (valor da diaria x dias)
CREATE PROCEDURE sp_pagamento_simulado_inserir(IN p_id_solicitacao INT UNSIGNED)
BEGIN
  INSERT INTO pagamento_simulado (valor_total, status, data_hora, id_solicitacao)
  SELECT d.valor_diaria * DATEDIFF(s.data_fim, s.data_inicio), 'SIMULADO', NOW(), s.id_solicitacao
  FROM solicitacao s
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  WHERE s.id_solicitacao = p_id_solicitacao AND s.ativo = TRUE AND d.modalidade = 'ALUGUEL';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento simulado so se aplica a solicitacao de aluguel ativa';
  END IF;
  SELECT LAST_INSERT_ID() AS id_pagamento;
END //

CREATE PROCEDURE sp_pagamento_simulado_atualizar(IN p_id_pagamento INT UNSIGNED, IN p_status VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pagamento_simulado WHERE id_pagamento = p_id_pagamento AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento inexistente ou excluido';
  END IF;
  UPDATE pagamento_simulado SET status = p_status WHERE id_pagamento = p_id_pagamento;
END //

CREATE PROCEDURE sp_pagamento_simulado_excluir(IN p_id_pagamento INT UNSIGNED)
BEGIN
  UPDATE pagamento_simulado SET ativo = FALSE, excluido_em = NOW() WHERE id_pagamento = p_id_pagamento AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento inexistente ou ja excluido';
  END IF;
END //

-- reserva ------------------------------------------------------------
CREATE PROCEDURE sp_reserva_inserir(IN p_id_solicitacao INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM solicitacao WHERE id_solicitacao = p_id_solicitacao AND status = 'APROVADA' AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN40: reserva so nasce de solicitacao aprovada';
  END IF;
  INSERT INTO reserva (status, criada_em, id_solicitacao) VALUES ('CONFIRMADA', NOW(), p_id_solicitacao);
  SELECT LAST_INSERT_ID() AS id_reserva;
END //

CREATE PROCEDURE sp_reserva_atualizar(IN p_id_reserva INT UNSIGNED, IN p_status VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM reserva WHERE id_reserva = p_id_reserva AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reserva inexistente ou excluida';
  END IF;
  UPDATE reserva SET status = p_status WHERE id_reserva = p_id_reserva;
END //

CREATE PROCEDURE sp_reserva_excluir(IN p_id_reserva INT UNSIGNED)
BEGIN
  UPDATE reserva SET ativo = FALSE, excluido_em = NOW() WHERE id_reserva = p_id_reserva AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reserva inexistente ou ja excluida';
  END IF;
END //

-- retirada -----------------------------------------------------------
-- o codigo do comprovante e gerado na sequencia do ano
CREATE PROCEDURE sp_retirada_inserir(
  IN p_id_reserva INT UNSIGNED, IN p_id_biometria INT UNSIGNED, IN p_estado_conservacao VARCHAR(10), IN p_observacao VARCHAR(500))
BEGIN
  DECLARE v_seq INT;
  SELECT COUNT(*) + 1 INTO v_seq FROM retirada WHERE codigo_comprovante LIKE CONCAT('RET', YEAR(NOW()), '%');
  INSERT INTO retirada (data_hora, estado_conservacao, observacao, codigo_comprovante, id_reserva, id_biometria)
  VALUES (NOW(), p_estado_conservacao, p_observacao, CONCAT('RET', YEAR(NOW()), LPAD(v_seq, 4, '0')), p_id_reserva, p_id_biometria);
  SELECT LAST_INSERT_ID() AS id_retirada;
END //

-- RNF14: estado, data e responsaveis nao mudam; so a observacao pode ser complementada
CREATE PROCEDURE sp_retirada_atualizar(IN p_id_retirada INT UNSIGNED, IN p_observacao VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM retirada WHERE id_retirada = p_id_retirada AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retirada inexistente ou excluida';
  END IF;
  UPDATE retirada SET observacao = p_observacao WHERE id_retirada = p_id_retirada;
END //

CREATE PROCEDURE sp_retirada_excluir(IN p_id_retirada INT UNSIGNED)
BEGIN
  UPDATE retirada SET ativo = FALSE, excluido_em = NOW() WHERE id_retirada = p_id_retirada AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retirada inexistente ou ja excluida';
  END IF;
END //

-- devolucao ----------------------------------------------------------
CREATE PROCEDURE sp_devolucao_inserir(
  IN p_id_retirada INT UNSIGNED, IN p_estado_conservacao VARCHAR(10), IN p_itens_faltantes VARCHAR(255), IN p_observacao VARCHAR(500))
BEGIN
  DECLARE v_seq INT;
  SELECT COUNT(*) + 1 INTO v_seq FROM devolucao WHERE codigo_comprovante LIKE CONCAT('DEV', YEAR(NOW()), '%');
  INSERT INTO devolucao (data_hora, estado_conservacao, itens_faltantes, observacao, codigo_comprovante, id_retirada)
  VALUES (NOW(), p_estado_conservacao, p_itens_faltantes, p_observacao, CONCAT('DEV', YEAR(NOW()), LPAD(v_seq, 4, '0')), p_id_retirada);
  SELECT LAST_INSERT_ID() AS id_devolucao;
END //

-- RNF14: so itens faltantes e observacao podem ser complementados
CREATE PROCEDURE sp_devolucao_atualizar(IN p_id_devolucao INT UNSIGNED, IN p_itens_faltantes VARCHAR(255), IN p_observacao VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM devolucao WHERE id_devolucao = p_id_devolucao AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Devolucao inexistente ou excluida';
  END IF;
  UPDATE devolucao SET itens_faltantes = p_itens_faltantes, observacao = p_observacao WHERE id_devolucao = p_id_devolucao;
END //

CREATE PROCEDURE sp_devolucao_excluir(IN p_id_devolucao INT UNSIGNED)
BEGIN
  UPDATE devolucao SET ativo = FALSE, excluido_em = NOW() WHERE id_devolucao = p_id_devolucao AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Devolucao inexistente ou ja excluida';
  END IF;
END //

-- dano ---------------------------------------------------------------
CREATE PROCEDURE sp_dano_inserir(
  IN p_id_equipamento INT UNSIGNED, IN p_id_usuario_relator INT UNSIGNED, IN p_id_reserva INT UNSIGNED, IN p_descricao VARCHAR(500))
BEGIN
  INSERT INTO dano (descricao, data_hora, status_andamento, id_equipamento, id_usuario_relator, id_reserva)
  VALUES (p_descricao, NOW(), 'ABERTO', p_id_equipamento, p_id_usuario_relator, p_id_reserva);
  SELECT LAST_INSERT_ID() AS id_dano;
END //

-- RN34: descricao, data e relator nao mudam; so o andamento do reparo
CREATE PROCEDURE sp_dano_atualizar(IN p_id_dano INT UNSIGNED, IN p_status_andamento VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM dano WHERE id_dano = p_id_dano AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dano inexistente ou excluido';
  END IF;
  UPDATE dano
  SET status_andamento = p_status_andamento,
      resolvido_em = CASE WHEN p_status_andamento = 'RESOLVIDO' THEN NOW() ELSE NULL END
  WHERE id_dano = p_id_dano;
END //

CREATE PROCEDURE sp_dano_excluir(IN p_id_dano INT UNSIGNED)
BEGIN
  UPDATE dano SET ativo = FALSE, excluido_em = NOW() WHERE id_dano = p_id_dano AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dano inexistente ou ja excluido';
  END IF;
END //

-- foto_dano ----------------------------------------------------------
CREATE PROCEDURE sp_foto_dano_inserir(
  IN p_id_dano INT UNSIGNED, IN p_url_arquivo VARCHAR(255), IN p_formato VARCHAR(3), IN p_tamanho_bytes INT UNSIGNED)
BEGIN
  INSERT INTO foto_dano (url_arquivo, formato, tamanho_bytes, enviada_em, id_dano)
  VALUES (p_url_arquivo, p_formato, p_tamanho_bytes, NOW(), p_id_dano);
  SELECT LAST_INSERT_ID() AS id_foto;
END //

CREATE PROCEDURE sp_foto_dano_atualizar(
  IN p_id_foto INT UNSIGNED, IN p_url_arquivo VARCHAR(255), IN p_formato VARCHAR(3), IN p_tamanho_bytes INT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM foto_dano WHERE id_foto = p_id_foto AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Foto inexistente ou excluida';
  END IF;
  UPDATE foto_dano SET url_arquivo = p_url_arquivo, formato = p_formato, tamanho_bytes = p_tamanho_bytes WHERE id_foto = p_id_foto;
END //

CREATE PROCEDURE sp_foto_dano_excluir(IN p_id_foto INT UNSIGNED)
BEGIN
  UPDATE foto_dano SET ativo = FALSE, excluido_em = NOW() WHERE id_foto = p_id_foto AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Foto inexistente ou ja excluida';
  END IF;
END //

-- avaliacao ----------------------------------------------------------
CREATE PROCEDURE sp_avaliacao_inserir(
  IN p_id_reserva INT UNSIGNED, IN p_id_aluno_avaliador INT UNSIGNED, IN p_nota TINYINT UNSIGNED, IN p_comentario VARCHAR(500))
BEGIN
  INSERT INTO avaliacao (nota, comentario, data_hora, id_aluno_avaliador, id_reserva)
  VALUES (p_nota, p_comentario, NOW(), p_id_aluno_avaliador, p_id_reserva);
  SELECT LAST_INSERT_ID() AS id_avaliacao;
END //

-- RN37: a nota nao e editada; o comentario pode ser moderado pela administracao
CREATE PROCEDURE sp_avaliacao_atualizar(IN p_id_avaliacao INT UNSIGNED, IN p_comentario VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM avaliacao WHERE id_avaliacao = p_id_avaliacao AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Avaliacao inexistente ou excluida';
  END IF;
  UPDATE avaliacao SET comentario = p_comentario WHERE id_avaliacao = p_id_avaliacao;
END //

CREATE PROCEDURE sp_avaliacao_excluir(IN p_id_avaliacao INT UNSIGNED)
BEGIN
  UPDATE avaliacao SET ativo = FALSE, excluido_em = NOW() WHERE id_avaliacao = p_id_avaliacao AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Avaliacao inexistente ou ja excluida';
  END IF;
END //

-- notificacao --------------------------------------------------------
CREATE PROCEDURE sp_notificacao_inserir(
  IN p_id_usuario INT UNSIGNED, IN p_id_solicitacao INT UNSIGNED, IN p_tipo VARCHAR(25), IN p_mensagem VARCHAR(500))
BEGIN
  INSERT INTO notificacao (tipo, mensagem, enviada_em, lida, id_usuario, id_solicitacao)
  VALUES (p_tipo, p_mensagem, NOW(), FALSE, p_id_usuario, p_id_solicitacao);
  SELECT LAST_INSERT_ID() AS id_notificacao;
END //

-- marca a notificacao como lida ou nao lida
CREATE PROCEDURE sp_notificacao_atualizar(IN p_id_notificacao INT UNSIGNED, IN p_lida BOOLEAN)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM notificacao WHERE id_notificacao = p_id_notificacao AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notificacao inexistente ou excluida';
  END IF;
  UPDATE notificacao SET lida = p_lida WHERE id_notificacao = p_id_notificacao;
END //

CREATE PROCEDURE sp_notificacao_excluir(IN p_id_notificacao INT UNSIGNED)
BEGIN
  UPDATE notificacao SET ativo = FALSE, excluido_em = NOW() WHERE id_notificacao = p_id_notificacao AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notificacao inexistente ou ja excluida';
  END IF;
END //

-- registro_operacao --------------------------------------------------
CREATE PROCEDURE sp_registro_operacao_inserir(
  IN p_tipo_operacao VARCHAR(30), IN p_tabela_afetada VARCHAR(30), IN p_id_afetado INT UNSIGNED,
  IN p_endereco_ip VARCHAR(45), IN p_latitude DECIMAL(9,6), IN p_longitude DECIMAL(9,6), IN p_id_usuario INT UNSIGNED)
BEGIN
  INSERT INTO registro_operacao (tipo_operacao, tabela_afetada, id_afetado, endereco_ip, latitude, longitude, data_hora, id_usuario)
  VALUES (p_tipo_operacao, p_tabela_afetada, p_id_afetado, p_endereco_ip, p_latitude, p_longitude, NOW(), p_id_usuario);
  SELECT LAST_INSERT_ID() AS id_registro;
END //

-- RNF20: o log nao e reescrito; so a geolocalizacao pendente pode ser completada
CREATE PROCEDURE sp_registro_operacao_atualizar(IN p_id_registro BIGINT UNSIGNED, IN p_latitude DECIMAL(9,6), IN p_longitude DECIMAL(9,6))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM registro_operacao WHERE id_registro = p_id_registro AND ativo = TRUE AND latitude IS NULL) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registro inexistente, excluido ou ja geolocalizado';
  END IF;
  UPDATE registro_operacao SET latitude = p_latitude, longitude = p_longitude WHERE id_registro = p_id_registro;
END //

CREATE PROCEDURE sp_registro_operacao_excluir(IN p_id_registro BIGINT UNSIGNED)
BEGIN
  UPDATE registro_operacao SET ativo = FALSE, excluido_em = NOW() WHERE id_registro = p_id_registro AND ativo = TRUE;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registro inexistente ou ja excluido';
  END IF;
END //

DELIMITER ;
