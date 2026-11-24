-- =====================================================================
-- GRUPO 4
-- =====================================================================
-- UniShare - Banco de Dados - Universidade de Mogi das Cruzes (UMC)
-- Entrega 3: regra de negocio e procedures (MySQL 8.4 / MariaDB 10.4)
--
-- RGM          Nome completo
-- 11261104620  Daniel Matsuo Rubino
-- 11261102520  Igor Delfino Braga
-- 11261103184  Mariana Rodrigues Fonseca
-- 11261102024  Maristela Silva Siqueira
-- 11261103039  Otavio Vinicius Flauzino de Souza
-- 11261102968  Roberta da Silva Ribeiro
-- 11251103799  Sara Santos Rodrigues de Lima
-- 11261103131  Thiago Araujo Cordeiro da Silva
--
-- Pre-requisito: banco unishare criado pelo script da Entrega 2.
-- Tabelas de parametro (sem procedures): instituicao, curso, categoria
-- e termo_uso.
-- =====================================================================

USE unishare;

-- ---------------------------------------------------------------------
-- 1. Exclusao logica: o registro fica no banco, so muda para inativo
-- ---------------------------------------------------------------------
ALTER TABLE usuario ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE aluno ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE aluno_curso ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE documento_identidade ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE biometria_facial ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE aceite_termo ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE equipamento ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE disponibilizacao ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE solicitacao ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE pagamento_simulado ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE reserva ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE retirada ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE devolucao ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE dano ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE foto_dano ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE avaliacao ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE notificacao ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;
ALTER TABLE registro_operacao ADD ativo BOOLEAN NOT NULL DEFAULT TRUE, ADD excluido_em DATETIME NULL;

DELIMITER //

-- ---------------------------------------------------------------------
-- 2. Regra de negocio RN24: nao pode haver duas reservas aprovadas do
--    mesmo equipamento com periodos sobrepostos.
--    A procedure aprova a solicitacao e cria a reserva dentro de uma
--    transacao; se houver conflito, desfaz tudo com ROLLBACK.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_aprovar_solicitacao(
  IN p_id_solicitacao INT UNSIGNED,
  OUT p_mensagem VARCHAR(200))
BEGIN
  DECLARE v_status VARCHAR(10);
  DECLARE v_inicio DATE;
  DECLARE v_fim DATE;
  DECLARE v_equipamento INT UNSIGNED;

  SELECT s.status, s.data_inicio, s.data_fim, d.id_equipamento
  INTO v_status, v_inicio, v_fim, v_equipamento
  FROM solicitacao s
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  WHERE s.id_solicitacao = p_id_solicitacao;

  IF v_status IS NULL OR v_status <> 'PENDENTE' THEN
    SET p_mensagem = 'Solicitacao inexistente ou nao pendente, nada foi feito';
  ELSE
    START TRANSACTION;

    UPDATE solicitacao
    SET status = 'APROVADA', respondida_em = NOW()
    WHERE id_solicitacao = p_id_solicitacao;

    INSERT INTO reserva (status, criada_em, id_solicitacao)
    VALUES ('CONFIRMADA', NOW(), p_id_solicitacao);

    IF (SELECT COUNT(*)
        FROM solicitacao s
        JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
        WHERE d.id_equipamento = v_equipamento
          AND s.id_solicitacao <> p_id_solicitacao
          AND s.status = 'APROVADA'
          AND s.ativo = TRUE
          AND s.data_inicio < v_fim
          AND v_inicio < s.data_fim) > 0 THEN
      ROLLBACK;
      SET p_mensagem = 'RN24: conflito de periodo com reserva aprovada, nada foi gravado';
    ELSE
      COMMIT;
      SET p_mensagem = 'Solicitacao aprovada e reserva criada';
    END IF;
  END IF;
END //

-- Exemplo de chamada:
-- CALL sp_aprovar_solicitacao(10, @msg); SELECT @msg;

-- ---------------------------------------------------------------------
-- 3. CRUD: inserir, atualizar e excluir (logico) para cada tabela
-- ---------------------------------------------------------------------

-- usuario
CREATE PROCEDURE sp_usuario_inserir(
  IN p_nome VARCHAR(120),
  IN p_cpf CHAR(11),
  IN p_email VARCHAR(150),
  IN p_senha_hash CHAR(60),
  IN p_perfil VARCHAR(5),
  IN p_telefone VARCHAR(11),
  IN p_id_instituicao INT UNSIGNED)
BEGIN
  INSERT INTO usuario (nome, cpf, email, senha_hash, perfil, telefone, id_instituicao, status_conta, criado_em)
  VALUES (p_nome, p_cpf, p_email, p_senha_hash, p_perfil, p_telefone, p_id_instituicao, 'PENDENTE', NOW());
END //

CREATE PROCEDURE sp_usuario_atualizar(
  IN p_id_usuario INT UNSIGNED,
  IN p_nome VARCHAR(120),
  IN p_email VARCHAR(150),
  IN p_senha_hash CHAR(60),
  IN p_telefone VARCHAR(11),
  IN p_status_conta VARCHAR(10))
BEGIN
  UPDATE usuario
  SET nome = p_nome, email = p_email, senha_hash = p_senha_hash, telefone = p_telefone, status_conta = p_status_conta
  WHERE id_usuario = p_id_usuario AND ativo = TRUE;
END //

CREATE PROCEDURE sp_usuario_excluir(
  IN p_id_usuario INT UNSIGNED)
BEGIN
  UPDATE usuario
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_usuario = p_id_usuario;
END //

-- aluno
CREATE PROCEDURE sp_aluno_inserir(
  IN p_matricula CHAR(11),
  IN p_situacao_vinculo VARCHAR(10),
  IN p_id_usuario INT UNSIGNED)
BEGIN
  INSERT INTO aluno (matricula, situacao_vinculo, id_usuario)
  VALUES (p_matricula, p_situacao_vinculo, p_id_usuario);
END //

CREATE PROCEDURE sp_aluno_atualizar(
  IN p_id_aluno INT UNSIGNED,
  IN p_matricula CHAR(11),
  IN p_situacao_vinculo VARCHAR(10))
BEGIN
  UPDATE aluno
  SET matricula = p_matricula, situacao_vinculo = p_situacao_vinculo
  WHERE id_aluno = p_id_aluno AND ativo = TRUE;
END //

CREATE PROCEDURE sp_aluno_excluir(
  IN p_id_aluno INT UNSIGNED)
BEGIN
  UPDATE aluno
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_aluno = p_id_aluno;
END //

-- aluno_curso
CREATE PROCEDURE sp_aluno_curso_inserir(
  IN p_id_aluno INT UNSIGNED,
  IN p_id_curso INT UNSIGNED)
BEGIN
  INSERT INTO aluno_curso (id_aluno, id_curso)
  VALUES (p_id_aluno, p_id_curso);
END //

CREATE PROCEDURE sp_aluno_curso_atualizar(
  IN p_id_aluno INT UNSIGNED,
  IN p_id_curso INT UNSIGNED,
  IN p_novo_id_curso INT UNSIGNED)
BEGIN
  UPDATE aluno_curso
  SET id_curso = p_novo_id_curso
  WHERE id_aluno = p_id_aluno AND id_curso = p_id_curso AND ativo = TRUE;
END //

CREATE PROCEDURE sp_aluno_curso_excluir(
  IN p_id_aluno INT UNSIGNED,
  IN p_id_curso INT UNSIGNED)
BEGIN
  UPDATE aluno_curso
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_aluno = p_id_aluno AND id_curso = p_id_curso;
END //

-- documento_identidade
CREATE PROCEDURE sp_documento_identidade_inserir(
  IN p_tipo_documento VARCHAR(10),
  IN p_numero_documento VARCHAR(20),
  IN p_arquivo_url VARCHAR(255),
  IN p_id_aluno INT UNSIGNED)
BEGIN
  INSERT INTO documento_identidade (tipo_documento, numero_documento, arquivo_url, id_aluno, status, enviado_em)
  VALUES (p_tipo_documento, p_numero_documento, p_arquivo_url, p_id_aluno, 'PENDENTE', NOW());
END //

CREATE PROCEDURE sp_documento_identidade_atualizar(
  IN p_id_documento INT UNSIGNED,
  IN p_tipo_documento VARCHAR(10),
  IN p_numero_documento VARCHAR(20),
  IN p_arquivo_url VARCHAR(255),
  IN p_status VARCHAR(10),
  IN p_motivo_recusa VARCHAR(255),
  IN p_analisado_em DATETIME,
  IN p_id_usuario_analista INT UNSIGNED)
BEGIN
  UPDATE documento_identidade
  SET tipo_documento = p_tipo_documento, numero_documento = p_numero_documento, arquivo_url = p_arquivo_url, status = p_status, motivo_recusa = p_motivo_recusa, analisado_em = p_analisado_em, id_usuario_analista = p_id_usuario_analista
  WHERE id_documento = p_id_documento AND ativo = TRUE;
END //

CREATE PROCEDURE sp_documento_identidade_excluir(
  IN p_id_documento INT UNSIGNED)
BEGIN
  UPDATE documento_identidade
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_documento = p_id_documento;
END //

-- biometria_facial
CREATE PROCEDURE sp_biometria_facial_inserir(
  IN p_id_usuario INT UNSIGNED,
  IN p_embedding_iv BINARY(12),
  IN p_embedding_tag BINARY(16),
  IN p_embedding_ct VARBINARY(2048))
BEGIN
  INSERT INTO biometria_facial (id_usuario, embedding_iv, embedding_tag, embedding_ct, criado_em)
  VALUES (p_id_usuario, p_embedding_iv, p_embedding_tag, p_embedding_ct, NOW());
END //

CREATE PROCEDURE sp_biometria_facial_atualizar(
  IN p_id_biometria INT UNSIGNED,
  IN p_embedding_iv BINARY(12),
  IN p_embedding_tag BINARY(16),
  IN p_embedding_ct VARBINARY(2048))
BEGIN
  UPDATE biometria_facial
  SET embedding_iv = p_embedding_iv, embedding_tag = p_embedding_tag, embedding_ct = p_embedding_ct
  WHERE id_biometria = p_id_biometria AND ativo = TRUE;
END //

CREATE PROCEDURE sp_biometria_facial_excluir(
  IN p_id_biometria INT UNSIGNED)
BEGIN
  UPDATE biometria_facial
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_biometria = p_id_biometria;
END //

-- aceite_termo
CREATE PROCEDURE sp_aceite_termo_inserir(
  IN p_id_usuario INT UNSIGNED,
  IN p_id_termo INT UNSIGNED)
BEGIN
  INSERT INTO aceite_termo (id_usuario, id_termo, data_hora_aceite)
  VALUES (p_id_usuario, p_id_termo, NOW());
END //

CREATE PROCEDURE sp_aceite_termo_atualizar(
  IN p_id_usuario INT UNSIGNED,
  IN p_id_termo INT UNSIGNED,
  IN p_data_hora_aceite DATETIME)
BEGIN
  UPDATE aceite_termo
  SET data_hora_aceite = p_data_hora_aceite
  WHERE id_usuario = p_id_usuario AND id_termo = p_id_termo AND ativo = TRUE;
END //

CREATE PROCEDURE sp_aceite_termo_excluir(
  IN p_id_usuario INT UNSIGNED,
  IN p_id_termo INT UNSIGNED)
BEGIN
  UPDATE aceite_termo
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_usuario = p_id_usuario AND id_termo = p_id_termo;
END //

-- equipamento
CREATE PROCEDURE sp_equipamento_inserir(
  IN p_nome VARCHAR(120),
  IN p_descricao VARCHAR(500),
  IN p_estado_conservacao VARCHAR(10),
  IN p_situacao VARCHAR(15),
  IN p_id_categoria INT UNSIGNED,
  IN p_id_usuario_proprietario INT UNSIGNED)
BEGIN
  INSERT INTO equipamento (nome, descricao, estado_conservacao, situacao, id_categoria, id_usuario_proprietario, criado_em)
  VALUES (p_nome, p_descricao, p_estado_conservacao, p_situacao, p_id_categoria, p_id_usuario_proprietario, NOW());
END //

CREATE PROCEDURE sp_equipamento_atualizar(
  IN p_id_equipamento INT UNSIGNED,
  IN p_nome VARCHAR(120),
  IN p_descricao VARCHAR(500),
  IN p_estado_conservacao VARCHAR(10),
  IN p_situacao VARCHAR(15),
  IN p_id_categoria INT UNSIGNED)
BEGIN
  UPDATE equipamento
  SET nome = p_nome, descricao = p_descricao, estado_conservacao = p_estado_conservacao, situacao = p_situacao, id_categoria = p_id_categoria
  WHERE id_equipamento = p_id_equipamento AND ativo = TRUE;
END //

CREATE PROCEDURE sp_equipamento_excluir(
  IN p_id_equipamento INT UNSIGNED)
BEGIN
  UPDATE equipamento
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_equipamento = p_id_equipamento;
END //

-- disponibilizacao
CREATE PROCEDURE sp_disponibilizacao_inserir(
  IN p_modalidade VARCHAR(10),
  IN p_valor_diaria DECIMAL(10,2),
  IN p_data_inicio DATE,
  IN p_data_fim DATE,
  IN p_prazo_maximo_dias SMALLINT UNSIGNED,
  IN p_id_equipamento INT UNSIGNED)
BEGIN
  INSERT INTO disponibilizacao (modalidade, valor_diaria, data_inicio, data_fim, prazo_maximo_dias, id_equipamento, criado_em)
  VALUES (p_modalidade, p_valor_diaria, p_data_inicio, p_data_fim, p_prazo_maximo_dias, p_id_equipamento, NOW());
END //

CREATE PROCEDURE sp_disponibilizacao_atualizar(
  IN p_id_disponibilizacao INT UNSIGNED,
  IN p_modalidade VARCHAR(10),
  IN p_valor_diaria DECIMAL(10,2),
  IN p_data_inicio DATE,
  IN p_data_fim DATE,
  IN p_prazo_maximo_dias SMALLINT UNSIGNED)
BEGIN
  UPDATE disponibilizacao
  SET modalidade = p_modalidade, valor_diaria = p_valor_diaria, data_inicio = p_data_inicio, data_fim = p_data_fim, prazo_maximo_dias = p_prazo_maximo_dias
  WHERE id_disponibilizacao = p_id_disponibilizacao AND ativo = TRUE;
END //

CREATE PROCEDURE sp_disponibilizacao_excluir(
  IN p_id_disponibilizacao INT UNSIGNED)
BEGIN
  UPDATE disponibilizacao
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_disponibilizacao = p_id_disponibilizacao;
END //

-- solicitacao
CREATE PROCEDURE sp_solicitacao_inserir(
  IN p_data_inicio DATE,
  IN p_data_fim DATE,
  IN p_id_aluno INT UNSIGNED,
  IN p_id_disponibilizacao INT UNSIGNED)
BEGIN
  INSERT INTO solicitacao (data_inicio, data_fim, id_aluno, id_disponibilizacao, status, criada_em)
  VALUES (p_data_inicio, p_data_fim, p_id_aluno, p_id_disponibilizacao, 'PENDENTE', NOW());
END //

CREATE PROCEDURE sp_solicitacao_atualizar(
  IN p_id_solicitacao INT UNSIGNED,
  IN p_data_inicio DATE,
  IN p_data_fim DATE,
  IN p_status VARCHAR(10),
  IN p_justificativa_recusa VARCHAR(255),
  IN p_respondida_em DATETIME)
BEGIN
  UPDATE solicitacao
  SET data_inicio = p_data_inicio, data_fim = p_data_fim, status = p_status, justificativa_recusa = p_justificativa_recusa, respondida_em = p_respondida_em
  WHERE id_solicitacao = p_id_solicitacao AND ativo = TRUE;
END //

CREATE PROCEDURE sp_solicitacao_excluir(
  IN p_id_solicitacao INT UNSIGNED)
BEGIN
  UPDATE solicitacao
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_solicitacao = p_id_solicitacao;
END //

-- pagamento_simulado
CREATE PROCEDURE sp_pagamento_simulado_inserir(
  IN p_valor_total DECIMAL(10,2),
  IN p_status VARCHAR(10),
  IN p_id_solicitacao INT UNSIGNED)
BEGIN
  INSERT INTO pagamento_simulado (valor_total, status, id_solicitacao, data_hora)
  VALUES (p_valor_total, p_status, p_id_solicitacao, NOW());
END //

CREATE PROCEDURE sp_pagamento_simulado_atualizar(
  IN p_id_pagamento INT UNSIGNED,
  IN p_valor_total DECIMAL(10,2),
  IN p_status VARCHAR(10))
BEGIN
  UPDATE pagamento_simulado
  SET valor_total = p_valor_total, status = p_status
  WHERE id_pagamento = p_id_pagamento AND ativo = TRUE;
END //

CREATE PROCEDURE sp_pagamento_simulado_excluir(
  IN p_id_pagamento INT UNSIGNED)
BEGIN
  UPDATE pagamento_simulado
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_pagamento = p_id_pagamento;
END //

-- reserva
CREATE PROCEDURE sp_reserva_inserir(
  IN p_status VARCHAR(10),
  IN p_id_solicitacao INT UNSIGNED)
BEGIN
  INSERT INTO reserva (status, id_solicitacao, criada_em)
  VALUES (p_status, p_id_solicitacao, NOW());
END //

CREATE PROCEDURE sp_reserva_atualizar(
  IN p_id_reserva INT UNSIGNED,
  IN p_status VARCHAR(10))
BEGIN
  UPDATE reserva
  SET status = p_status
  WHERE id_reserva = p_id_reserva AND ativo = TRUE;
END //

CREATE PROCEDURE sp_reserva_excluir(
  IN p_id_reserva INT UNSIGNED)
BEGIN
  UPDATE reserva
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_reserva = p_id_reserva;
END //

-- retirada
CREATE PROCEDURE sp_retirada_inserir(
  IN p_estado_conservacao VARCHAR(10),
  IN p_observacao VARCHAR(500),
  IN p_codigo_comprovante CHAR(11),
  IN p_id_reserva INT UNSIGNED,
  IN p_id_biometria INT UNSIGNED)
BEGIN
  INSERT INTO retirada (estado_conservacao, observacao, codigo_comprovante, id_reserva, id_biometria, data_hora)
  VALUES (p_estado_conservacao, p_observacao, p_codigo_comprovante, p_id_reserva, p_id_biometria, NOW());
END //

CREATE PROCEDURE sp_retirada_atualizar(
  IN p_id_retirada INT UNSIGNED,
  IN p_estado_conservacao VARCHAR(10),
  IN p_observacao VARCHAR(500))
BEGIN
  UPDATE retirada
  SET estado_conservacao = p_estado_conservacao, observacao = p_observacao
  WHERE id_retirada = p_id_retirada AND ativo = TRUE;
END //

CREATE PROCEDURE sp_retirada_excluir(
  IN p_id_retirada INT UNSIGNED)
BEGIN
  UPDATE retirada
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_retirada = p_id_retirada;
END //

-- devolucao
CREATE PROCEDURE sp_devolucao_inserir(
  IN p_estado_conservacao VARCHAR(10),
  IN p_itens_faltantes VARCHAR(255),
  IN p_observacao VARCHAR(500),
  IN p_codigo_comprovante CHAR(11),
  IN p_id_retirada INT UNSIGNED)
BEGIN
  INSERT INTO devolucao (estado_conservacao, itens_faltantes, observacao, codigo_comprovante, id_retirada, data_hora)
  VALUES (p_estado_conservacao, p_itens_faltantes, p_observacao, p_codigo_comprovante, p_id_retirada, NOW());
END //

CREATE PROCEDURE sp_devolucao_atualizar(
  IN p_id_devolucao INT UNSIGNED,
  IN p_estado_conservacao VARCHAR(10),
  IN p_itens_faltantes VARCHAR(255),
  IN p_observacao VARCHAR(500))
BEGIN
  UPDATE devolucao
  SET estado_conservacao = p_estado_conservacao, itens_faltantes = p_itens_faltantes, observacao = p_observacao
  WHERE id_devolucao = p_id_devolucao AND ativo = TRUE;
END //

CREATE PROCEDURE sp_devolucao_excluir(
  IN p_id_devolucao INT UNSIGNED)
BEGIN
  UPDATE devolucao
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_devolucao = p_id_devolucao;
END //

-- dano
CREATE PROCEDURE sp_dano_inserir(
  IN p_descricao VARCHAR(500),
  IN p_id_equipamento INT UNSIGNED,
  IN p_id_usuario_relator INT UNSIGNED,
  IN p_id_reserva INT UNSIGNED)
BEGIN
  INSERT INTO dano (descricao, id_equipamento, id_usuario_relator, id_reserva, status_andamento, data_hora)
  VALUES (p_descricao, p_id_equipamento, p_id_usuario_relator, p_id_reserva, 'ABERTO', NOW());
END //

CREATE PROCEDURE sp_dano_atualizar(
  IN p_id_dano INT UNSIGNED,
  IN p_descricao VARCHAR(500),
  IN p_status_andamento VARCHAR(10),
  IN p_resolvido_em DATETIME)
BEGIN
  UPDATE dano
  SET descricao = p_descricao, status_andamento = p_status_andamento, resolvido_em = p_resolvido_em
  WHERE id_dano = p_id_dano AND ativo = TRUE;
END //

CREATE PROCEDURE sp_dano_excluir(
  IN p_id_dano INT UNSIGNED)
BEGIN
  UPDATE dano
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_dano = p_id_dano;
END //

-- foto_dano
CREATE PROCEDURE sp_foto_dano_inserir(
  IN p_url_arquivo VARCHAR(255),
  IN p_formato VARCHAR(3),
  IN p_tamanho_bytes INT UNSIGNED,
  IN p_id_dano INT UNSIGNED)
BEGIN
  INSERT INTO foto_dano (url_arquivo, formato, tamanho_bytes, id_dano, enviada_em)
  VALUES (p_url_arquivo, p_formato, p_tamanho_bytes, p_id_dano, NOW());
END //

CREATE PROCEDURE sp_foto_dano_atualizar(
  IN p_id_foto INT UNSIGNED,
  IN p_url_arquivo VARCHAR(255),
  IN p_formato VARCHAR(3),
  IN p_tamanho_bytes INT UNSIGNED)
BEGIN
  UPDATE foto_dano
  SET url_arquivo = p_url_arquivo, formato = p_formato, tamanho_bytes = p_tamanho_bytes
  WHERE id_foto = p_id_foto AND ativo = TRUE;
END //

CREATE PROCEDURE sp_foto_dano_excluir(
  IN p_id_foto INT UNSIGNED)
BEGIN
  UPDATE foto_dano
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_foto = p_id_foto;
END //

-- avaliacao
CREATE PROCEDURE sp_avaliacao_inserir(
  IN p_nota TINYINT UNSIGNED,
  IN p_comentario VARCHAR(500),
  IN p_id_aluno_avaliador INT UNSIGNED,
  IN p_id_reserva INT UNSIGNED)
BEGIN
  INSERT INTO avaliacao (nota, comentario, id_aluno_avaliador, id_reserva, data_hora)
  VALUES (p_nota, p_comentario, p_id_aluno_avaliador, p_id_reserva, NOW());
END //

CREATE PROCEDURE sp_avaliacao_atualizar(
  IN p_id_avaliacao INT UNSIGNED,
  IN p_nota TINYINT UNSIGNED,
  IN p_comentario VARCHAR(500))
BEGIN
  UPDATE avaliacao
  SET nota = p_nota, comentario = p_comentario
  WHERE id_avaliacao = p_id_avaliacao AND ativo = TRUE;
END //

CREATE PROCEDURE sp_avaliacao_excluir(
  IN p_id_avaliacao INT UNSIGNED)
BEGIN
  UPDATE avaliacao
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_avaliacao = p_id_avaliacao;
END //

-- notificacao
CREATE PROCEDURE sp_notificacao_inserir(
  IN p_tipo VARCHAR(25),
  IN p_mensagem VARCHAR(500),
  IN p_id_usuario INT UNSIGNED,
  IN p_id_solicitacao INT UNSIGNED)
BEGIN
  INSERT INTO notificacao (tipo, mensagem, id_usuario, id_solicitacao, enviada_em, lida)
  VALUES (p_tipo, p_mensagem, p_id_usuario, p_id_solicitacao, NOW(), FALSE);
END //

CREATE PROCEDURE sp_notificacao_atualizar(
  IN p_id_notificacao INT UNSIGNED,
  IN p_mensagem VARCHAR(500),
  IN p_lida BOOLEAN)
BEGIN
  UPDATE notificacao
  SET mensagem = p_mensagem, lida = p_lida
  WHERE id_notificacao = p_id_notificacao AND ativo = TRUE;
END //

CREATE PROCEDURE sp_notificacao_excluir(
  IN p_id_notificacao INT UNSIGNED)
BEGIN
  UPDATE notificacao
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_notificacao = p_id_notificacao;
END //

-- registro_operacao
CREATE PROCEDURE sp_registro_operacao_inserir(
  IN p_tipo_operacao VARCHAR(30),
  IN p_tabela_afetada VARCHAR(30),
  IN p_id_afetado INT UNSIGNED,
  IN p_endereco_ip VARCHAR(45),
  IN p_latitude DECIMAL(9,6),
  IN p_longitude DECIMAL(9,6),
  IN p_id_usuario INT UNSIGNED)
BEGIN
  INSERT INTO registro_operacao (tipo_operacao, tabela_afetada, id_afetado, endereco_ip, latitude, longitude, id_usuario, data_hora)
  VALUES (p_tipo_operacao, p_tabela_afetada, p_id_afetado, p_endereco_ip, p_latitude, p_longitude, p_id_usuario, NOW());
END //

CREATE PROCEDURE sp_registro_operacao_atualizar(
  IN p_id_registro BIGINT UNSIGNED,
  IN p_endereco_ip VARCHAR(45),
  IN p_latitude DECIMAL(9,6),
  IN p_longitude DECIMAL(9,6))
BEGIN
  UPDATE registro_operacao
  SET endereco_ip = p_endereco_ip, latitude = p_latitude, longitude = p_longitude
  WHERE id_registro = p_id_registro AND ativo = TRUE;
END //

CREATE PROCEDURE sp_registro_operacao_excluir(
  IN p_id_registro BIGINT UNSIGNED)
BEGIN
  UPDATE registro_operacao
  SET ativo = FALSE, excluido_em = NOW()
  WHERE id_registro = p_id_registro;
END //

DELIMITER ;
