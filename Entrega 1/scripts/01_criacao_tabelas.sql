-- UniShare - script de criacao do banco (MySQL 8.4)

CREATE DATABASE unishare
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE unishare;

CREATE TABLE instituicao (
  id_instituicao INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome           VARCHAR(150) NOT NULL,
  sigla          VARCHAR(20)  NOT NULL,
  cnpj           CHAR(14)     NOT NULL,
  CONSTRAINT pk_instituicao PRIMARY KEY (id_instituicao),
  CONSTRAINT uq_instituicao_cnpj UNIQUE (cnpj),
  CONSTRAINT ck_instituicao_cnpj CHECK (CHAR_LENGTH(cnpj) = 14 AND cnpj NOT REGEXP '[^0-9]')
);

CREATE TABLE curso (
  id_curso       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome           VARCHAR(120) NOT NULL,
  id_instituicao INT UNSIGNED NOT NULL,
  CONSTRAINT pk_curso PRIMARY KEY (id_curso),
  CONSTRAINT uq_curso_nome UNIQUE (id_instituicao, nome),
  CONSTRAINT fk_curso_instituicao FOREIGN KEY (id_instituicao) REFERENCES instituicao (id_instituicao)
);

-- ADM pertence a instituicao; aluno nao
CREATE TABLE usuario (
  id_usuario     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome           VARCHAR(120) NOT NULL,
  cpf            CHAR(11)     NOT NULL,
  email          VARCHAR(150) NOT NULL,
  senha_hash     CHAR(60)     NOT NULL,
  perfil         VARCHAR(5)   NOT NULL,
  telefone       VARCHAR(11)  NULL,
  status_conta   VARCHAR(10)  NOT NULL,
  criado_em      DATETIME     NOT NULL,
  id_instituicao INT UNSIGNED NULL,
  CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
  CONSTRAINT uq_usuario_cpf UNIQUE (cpf),
  CONSTRAINT uq_usuario_email UNIQUE (email),
  CONSTRAINT fk_usuario_instituicao FOREIGN KEY (id_instituicao) REFERENCES instituicao (id_instituicao),
  CONSTRAINT ck_usuario_cpf CHECK (CHAR_LENGTH(cpf) = 11 AND cpf NOT REGEXP '[^0-9]'),
  CONSTRAINT ck_usuario_telefone CHECK (CHAR_LENGTH(telefone) BETWEEN 10 AND 11 AND telefone NOT REGEXP '[^0-9]'),
  CONSTRAINT ck_usuario_perfil CHECK (perfil IN ('ADM', 'ALUNO')),
  CONSTRAINT ck_usuario_status CHECK (status_conta IN ('PENDENTE', 'ATIVA', 'BLOQUEADA', 'INATIVA')),
  CONSTRAINT ck_usuario_email CHECK (
    (perfil = 'ADM' AND email LIKE '%@admin.umc.br') OR
    (perfil = 'ALUNO' AND email LIKE '%@aluno.umc.br')),
  CONSTRAINT ck_usuario_instituicao CHECK (
    (perfil = 'ADM' AND id_instituicao IS NOT NULL) OR
    (perfil = 'ALUNO' AND id_instituicao IS NULL))
);

CREATE TABLE aluno (
  id_aluno         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  matricula        CHAR(11)     NOT NULL,
  situacao_vinculo VARCHAR(10)  NOT NULL,
  id_usuario       INT UNSIGNED NOT NULL,
  CONSTRAINT pk_aluno PRIMARY KEY (id_aluno),
  CONSTRAINT uq_aluno_matricula UNIQUE (matricula),
  CONSTRAINT uq_aluno_usuario UNIQUE (id_usuario),
  CONSTRAINT fk_aluno_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_aluno_matricula CHECK (CHAR_LENGTH(matricula) = 11 AND matricula NOT REGEXP '[^0-9]'),
  CONSTRAINT ck_aluno_situacao CHECK (situacao_vinculo IN ('ATIVO', 'TRANCADO', 'CONCLUIDO', 'DESLIGADO'))
);

-- associativa entre aluno e curso (N:N)
CREATE TABLE aluno_curso (
  id_aluno INT UNSIGNED NOT NULL,
  id_curso INT UNSIGNED NOT NULL,
  CONSTRAINT pk_aluno_curso PRIMARY KEY (id_aluno, id_curso),
  CONSTRAINT fk_aluno_curso_aluno FOREIGN KEY (id_aluno) REFERENCES aluno (id_aluno),
  CONSTRAINT fk_aluno_curso_curso FOREIGN KEY (id_curso) REFERENCES curso (id_curso)
);

CREATE TABLE documento_identidade (
  id_documento        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tipo_documento      VARCHAR(10)  NOT NULL,
  numero_documento    VARCHAR(20)  NOT NULL,
  arquivo_url         VARCHAR(255) NOT NULL,
  status              VARCHAR(10)  NOT NULL,
  motivo_recusa       VARCHAR(255) NULL,
  enviado_em          DATETIME     NOT NULL,
  analisado_em        DATETIME     NULL,
  id_aluno            INT UNSIGNED NOT NULL,
  id_usuario_analista INT UNSIGNED NULL,
  CONSTRAINT pk_documento_identidade PRIMARY KEY (id_documento),
  CONSTRAINT fk_documento_aluno FOREIGN KEY (id_aluno) REFERENCES aluno (id_aluno),
  CONSTRAINT fk_documento_analista FOREIGN KEY (id_usuario_analista) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_documento_tipo CHECK (tipo_documento IN ('RG', 'CNH', 'RNE', 'PASSAPORTE')),
  CONSTRAINT ck_documento_numero CHECK (CHAR_LENGTH(numero_documento) BETWEEN 5 AND 20 AND numero_documento NOT REGEXP '[^0-9A-Z]'),
  CONSTRAINT ck_documento_status CHECK (status IN ('PENDENTE', 'APROVADO', 'RECUSADO')),
  CONSTRAINT ck_documento_recusa CHECK (status <> 'RECUSADO' OR motivo_recusa IS NOT NULL),
  CONSTRAINT ck_documento_analise CHECK (
    (status = 'PENDENTE' AND analisado_em IS NULL AND id_usuario_analista IS NULL) OR
    (status <> 'PENDENTE' AND analisado_em IS NOT NULL AND id_usuario_analista IS NOT NULL))
);

-- embedding facial cifrado com AES-256-GCM, sem imagem bruta
CREATE TABLE biometria_facial (
  id_biometria  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  id_usuario    INT UNSIGNED    NOT NULL,
  embedding_iv  BINARY(12)      NOT NULL,
  embedding_tag BINARY(16)      NOT NULL,
  embedding_ct  VARBINARY(2048) NOT NULL,
  key_version   INT UNSIGNED    NOT NULL DEFAULT 1,
  model_version VARCHAR(50)     NOT NULL DEFAULT 'arcface_r50_v1',
  criado_em     DATETIME        NOT NULL,
  CONSTRAINT pk_biometria_facial PRIMARY KEY (id_biometria),
  CONSTRAINT uq_biometria_usuario_modelo UNIQUE (id_usuario, model_version),
  CONSTRAINT fk_biometria_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_biometria_ct CHECK (LENGTH(embedding_ct) = 2048)
);

CREATE TABLE termo_uso (
  id_termo     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  versao       VARCHAR(10)  NOT NULL,
  conteudo     TEXT         NOT NULL,
  publicado_em DATETIME     NOT NULL,
  CONSTRAINT pk_termo_uso PRIMARY KEY (id_termo),
  CONSTRAINT uq_termo_versao UNIQUE (versao)
);

-- associativa entre aluno e termo de uso (N:N)
CREATE TABLE aceite_termo (
  id_aluno         INT UNSIGNED NOT NULL,
  id_termo         INT UNSIGNED NOT NULL,
  data_hora_aceite DATETIME     NOT NULL,
  CONSTRAINT pk_aceite_termo PRIMARY KEY (id_aluno, id_termo),
  CONSTRAINT fk_aceite_aluno FOREIGN KEY (id_aluno) REFERENCES aluno (id_aluno),
  CONSTRAINT fk_aceite_termo FOREIGN KEY (id_termo) REFERENCES termo_uso (id_termo)
);

CREATE TABLE categoria (
  id_categoria INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome         VARCHAR(60)  NOT NULL,
  CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categoria_nome UNIQUE (nome)
);

-- dono e ALP ou ADM; equipamento de ADM e institucional
CREATE TABLE equipamento (
  id_equipamento          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome                    VARCHAR(120) NOT NULL,
  descricao               VARCHAR(500) NOT NULL,
  estado_conservacao      VARCHAR(10)  NOT NULL,
  situacao                VARCHAR(15)  NOT NULL,
  criado_em               DATETIME     NOT NULL,
  id_categoria            INT UNSIGNED NOT NULL,
  id_usuario_proprietario INT UNSIGNED NOT NULL,
  CONSTRAINT pk_equipamento PRIMARY KEY (id_equipamento),
  CONSTRAINT fk_equipamento_categoria FOREIGN KEY (id_categoria) REFERENCES categoria (id_categoria),
  CONSTRAINT fk_equipamento_proprietario FOREIGN KEY (id_usuario_proprietario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_equipamento_estado CHECK (estado_conservacao IN ('NOVO', 'OTIMO', 'BOM', 'REGULAR', 'RUIM')),
  CONSTRAINT ck_equipamento_situacao CHECK (situacao IN ('DISPONIVEL', 'RESERVADO', 'EM_USO', 'EM_MANUTENCAO', 'INDISPONIVEL'))
);

-- cada alteracao de modalidade, valor ou periodo gera uma nova linha
CREATE TABLE disponibilizacao (
  id_disponibilizacao INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  modalidade          VARCHAR(10)       NOT NULL,
  valor_diaria        DECIMAL(10,2)     NOT NULL,
  data_inicio         DATE              NOT NULL,
  data_fim            DATE              NOT NULL,
  prazo_maximo_dias   SMALLINT UNSIGNED NULL,
  criado_em           DATETIME          NOT NULL,
  id_equipamento      INT UNSIGNED      NOT NULL,
  CONSTRAINT pk_disponibilizacao PRIMARY KEY (id_disponibilizacao),
  CONSTRAINT fk_disponibilizacao_equipamento FOREIGN KEY (id_equipamento) REFERENCES equipamento (id_equipamento),
  CONSTRAINT ck_disponibilizacao_modalidade CHECK (modalidade IN ('EMPRESTIMO', 'ALUGUEL')),
  CONSTRAINT ck_disponibilizacao_valor CHECK (
    (modalidade = 'EMPRESTIMO' AND valor_diaria = 0) OR
    (modalidade = 'ALUGUEL' AND valor_diaria > 0)),
  CONSTRAINT ck_disponibilizacao_periodo CHECK (data_fim >= data_inicio),
  CONSTRAINT ck_disponibilizacao_prazo CHECK (prazo_maximo_dias > 0)
);

CREATE TABLE solicitacao (
  id_solicitacao       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  data_inicio          DATE         NOT NULL,
  data_fim             DATE         NOT NULL,
  status               VARCHAR(10)  NOT NULL,
  justificativa_recusa VARCHAR(255) NULL,
  criada_em            DATETIME     NOT NULL,
  respondida_em        DATETIME     NULL,
  id_aluno             INT UNSIGNED NOT NULL,
  id_disponibilizacao  INT UNSIGNED NOT NULL,
  CONSTRAINT pk_solicitacao PRIMARY KEY (id_solicitacao),
  CONSTRAINT fk_solicitacao_aluno FOREIGN KEY (id_aluno) REFERENCES aluno (id_aluno),
  CONSTRAINT fk_solicitacao_disponibilizacao FOREIGN KEY (id_disponibilizacao) REFERENCES disponibilizacao (id_disponibilizacao),
  CONSTRAINT ck_solicitacao_status CHECK (status IN ('PENDENTE', 'APROVADA', 'RECUSADA', 'CANCELADA', 'EXPIRADA')),
  CONSTRAINT ck_solicitacao_periodo CHECK (data_fim > data_inicio),
  CONSTRAINT ck_solicitacao_resposta CHECK (
    (status IN ('APROVADA', 'RECUSADA') AND respondida_em IS NOT NULL) OR
    (status IN ('PENDENTE', 'CANCELADA', 'EXPIRADA') AND respondida_em IS NULL)),
  CONSTRAINT ck_solicitacao_recusa CHECK (status <> 'RECUSADA' OR justificativa_recusa IS NOT NULL)
);

-- simulado apenas para aluguel, antes do envio ao dono
CREATE TABLE pagamento_simulado (
  id_pagamento   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  valor_total    DECIMAL(10,2) NOT NULL,
  status         VARCHAR(10)   NOT NULL,
  data_hora      DATETIME      NOT NULL,
  id_solicitacao INT UNSIGNED  NOT NULL,
  CONSTRAINT pk_pagamento_simulado PRIMARY KEY (id_pagamento),
  CONSTRAINT uq_pagamento_solicitacao UNIQUE (id_solicitacao),
  CONSTRAINT fk_pagamento_solicitacao FOREIGN KEY (id_solicitacao) REFERENCES solicitacao (id_solicitacao),
  CONSTRAINT ck_pagamento_valor CHECK (valor_total > 0),
  CONSTRAINT ck_pagamento_status CHECK (status IN ('SIMULADO', 'CANCELADO'))
);

CREATE TABLE reserva (
  id_reserva     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  status         VARCHAR(10)  NOT NULL,
  criada_em      DATETIME     NOT NULL,
  id_solicitacao INT UNSIGNED NOT NULL,
  CONSTRAINT pk_reserva PRIMARY KEY (id_reserva),
  CONSTRAINT uq_reserva_solicitacao UNIQUE (id_solicitacao),
  CONSTRAINT fk_reserva_solicitacao FOREIGN KEY (id_solicitacao) REFERENCES solicitacao (id_solicitacao),
  CONSTRAINT ck_reserva_status CHECK (status IN ('CONFIRMADA', 'EM_USO', 'CONCLUIDA', 'ATRASADA'))
);

-- retirada confirmada pela biometria do aluno titular da reserva
CREATE TABLE retirada (
  id_retirada        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  data_hora          DATETIME     NOT NULL,
  estado_conservacao VARCHAR(10)  NOT NULL,
  observacao         VARCHAR(500) NULL,
  codigo_comprovante CHAR(13)     NOT NULL,
  id_reserva         INT UNSIGNED NOT NULL,
  id_biometria       INT UNSIGNED NOT NULL,
  CONSTRAINT pk_retirada PRIMARY KEY (id_retirada),
  CONSTRAINT uq_retirada_reserva UNIQUE (id_reserva),
  CONSTRAINT uq_retirada_comprovante UNIQUE (codigo_comprovante),
  CONSTRAINT fk_retirada_reserva FOREIGN KEY (id_reserva) REFERENCES reserva (id_reserva),
  CONSTRAINT fk_retirada_biometria FOREIGN KEY (id_biometria) REFERENCES biometria_facial (id_biometria),
  CONSTRAINT ck_retirada_estado CHECK (estado_conservacao IN ('NOVO', 'OTIMO', 'BOM', 'REGULAR', 'RUIM'))
);

CREATE TABLE devolucao (
  id_devolucao       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  data_hora          DATETIME     NOT NULL,
  estado_conservacao VARCHAR(10)  NOT NULL,
  itens_faltantes    VARCHAR(255) NULL,
  observacao         VARCHAR(500) NULL,
  codigo_comprovante CHAR(13)     NOT NULL,
  id_retirada        INT UNSIGNED NOT NULL,
  CONSTRAINT pk_devolucao PRIMARY KEY (id_devolucao),
  CONSTRAINT uq_devolucao_retirada UNIQUE (id_retirada),
  CONSTRAINT uq_devolucao_comprovante UNIQUE (codigo_comprovante),
  CONSTRAINT fk_devolucao_retirada FOREIGN KEY (id_retirada) REFERENCES retirada (id_retirada),
  CONSTRAINT ck_devolucao_estado CHECK (estado_conservacao IN ('NOVO', 'OTIMO', 'BOM', 'REGULAR', 'RUIM'))
);

CREATE TABLE dano (
  id_dano            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  descricao          VARCHAR(500) NOT NULL,
  data_hora          DATETIME     NOT NULL,
  status_andamento   VARCHAR(10)  NOT NULL,
  resolvido_em       DATETIME     NULL,
  id_equipamento     INT UNSIGNED NOT NULL,
  id_usuario_relator INT UNSIGNED NOT NULL,
  id_reserva         INT UNSIGNED NULL,
  CONSTRAINT pk_dano PRIMARY KEY (id_dano),
  CONSTRAINT fk_dano_equipamento FOREIGN KEY (id_equipamento) REFERENCES equipamento (id_equipamento),
  CONSTRAINT fk_dano_relator FOREIGN KEY (id_usuario_relator) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_dano_reserva FOREIGN KEY (id_reserva) REFERENCES reserva (id_reserva),
  CONSTRAINT ck_dano_status CHECK (status_andamento IN ('ABERTO', 'EM_REPARO', 'RESOLVIDO')),
  CONSTRAINT ck_dano_resolucao CHECK (
    (status_andamento = 'RESOLVIDO' AND resolvido_em IS NOT NULL) OR
    (status_andamento <> 'RESOLVIDO' AND resolvido_em IS NULL))
);

CREATE TABLE foto_dano (
  id_foto       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_arquivo   VARCHAR(255) NOT NULL,
  formato       VARCHAR(3)   NOT NULL,
  tamanho_bytes INT UNSIGNED NOT NULL,
  enviada_em    DATETIME     NOT NULL,
  id_dano       INT UNSIGNED NOT NULL,
  CONSTRAINT pk_foto_dano PRIMARY KEY (id_foto),
  CONSTRAINT fk_foto_dano FOREIGN KEY (id_dano) REFERENCES dano (id_dano),
  CONSTRAINT ck_foto_formato CHECK (formato IN ('JPG', 'PNG')),
  CONSTRAINT ck_foto_tamanho CHECK (tamanho_bytes BETWEEN 1 AND 5242880)
);

-- uma avaliacao por avaliador em cada reserva
CREATE TABLE avaliacao (
  id_avaliacao       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  nota               TINYINT UNSIGNED NOT NULL,
  comentario         VARCHAR(500)     NULL,
  data_hora          DATETIME         NOT NULL,
  id_aluno_avaliador INT UNSIGNED     NOT NULL,
  id_reserva         INT UNSIGNED     NOT NULL,
  CONSTRAINT pk_avaliacao PRIMARY KEY (id_avaliacao),
  CONSTRAINT uq_avaliacao_reserva_avaliador UNIQUE (id_reserva, id_aluno_avaliador),
  CONSTRAINT fk_avaliacao_avaliador FOREIGN KEY (id_aluno_avaliador) REFERENCES aluno (id_aluno),
  CONSTRAINT fk_avaliacao_reserva FOREIGN KEY (id_reserva) REFERENCES reserva (id_reserva),
  CONSTRAINT ck_avaliacao_nota CHECK (nota BETWEEN 1 AND 5)
);

CREATE TABLE notificacao (
  id_notificacao INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tipo           VARCHAR(25)  NOT NULL,
  mensagem       VARCHAR(500) NOT NULL,
  enviada_em     DATETIME     NOT NULL,
  lida           BOOLEAN      NOT NULL,
  id_usuario     INT UNSIGNED NOT NULL,
  id_solicitacao INT UNSIGNED NULL,
  CONSTRAINT pk_notificacao PRIMARY KEY (id_notificacao),
  CONSTRAINT fk_notificacao_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_notificacao_solicitacao FOREIGN KEY (id_solicitacao) REFERENCES solicitacao (id_solicitacao),
  CONSTRAINT ck_notificacao_tipo CHECK (tipo IN ('SOLICITACAO_RECEBIDA', 'CONFIRMACAO_RESERVA', 'SOLICITACAO_RECUSADA',
    'SOLICITACAO_EXPIRADA', 'LEMBRETE_DEVOLUCAO', 'ATRASO', 'IDENTIDADE', 'DANO'))
);

-- log de auditoria com IP e geolocalizacao; id_usuario nulo em acoes do sistema
CREATE TABLE registro_operacao (
  id_registro     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tipo_operacao   VARCHAR(30)     NOT NULL,
  tabela_afetada  VARCHAR(30)     NOT NULL,
  id_afetado      INT UNSIGNED    NOT NULL,
  endereco_ip     VARCHAR(45)     NOT NULL,
  latitude        DECIMAL(9,6)    NULL,
  longitude       DECIMAL(9,6)    NULL,
  data_hora       DATETIME        NOT NULL,
  id_usuario      INT UNSIGNED    NULL,
  CONSTRAINT pk_registro_operacao PRIMARY KEY (id_registro),
  CONSTRAINT fk_registro_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_registro_tipo CHECK (tipo_operacao IN ('CADASTRO_CONTA', 'LOGIN', 'LOGIN_FALHA', 'BLOQUEIO_CONTA',
    'ENVIO_DOCUMENTO', 'ANALISE_DOCUMENTO', 'CADASTRO_BIOMETRIA', 'ACEITE_TERMO', 'CADASTRO_EQUIPAMENTO',
    'DISPONIBILIZACAO', 'SOLICITACAO', 'PAGAMENTO_SIMULADO', 'APROVACAO', 'RECUSA', 'RECUSA_AUTOMATICA',
    'CANCELAMENTO', 'EXPIRACAO', 'RETIRADA', 'DEVOLUCAO', 'REGISTRO_DANO', 'RESOLUCAO_DANO', 'AVALIACAO')),
  CONSTRAINT ck_registro_tabela CHECK (tabela_afetada IN ('usuario', 'documento_identidade', 'biometria_facial',
    'aceite_termo', 'equipamento', 'disponibilizacao', 'solicitacao', 'pagamento_simulado', 'retirada',
    'devolucao', 'dano', 'avaliacao')),
  CONSTRAINT ck_registro_geo CHECK (
    (latitude IS NULL AND longitude IS NULL) OR
    (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
);
