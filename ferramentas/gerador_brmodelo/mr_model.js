// Modelo Relacional (MR) do UniShare — espelha banco_de_dados/sql/01_criacao_tabelas.sql (MySQL 8.4)
// Campo: [nome, tipo, flags]  flags: "PK", "FK", "NULL" (opcional), "UQ" (único)
// FK: [tabelaFilha, campoFilho, tabelaPai, cardinalidade ao lado do pai, cardinalidade ao lado da filha]
var MGX = 680, MGY = 480, MOX = 520, MOY = 200;

var TAB = {
  registro_operacao: { g:[0,4], f:[["id_registro","BIGINT UNSIGNED","PK"],["tipo_operacao","VARCHAR(30)"],["tabela_afetada","VARCHAR(30)"],["id_afetado","INT UNSIGNED"],["endereco_ip","VARCHAR(45)"],["latitude","DECIMAL(9,6)","NULL"],["longitude","DECIMAL(9,6)","NULL"],["data_hora","DATETIME"],["id_usuario","INT UNSIGNED","FK NULL"]] },
  instituicao:  { g:[1,0], f:[["id_instituicao","INT UNSIGNED","PK"],["nome","VARCHAR(150)"],["sigla","VARCHAR(20)"],["cnpj","CHAR(14)","UQ"]] },
  curso:        { g:[2,0], f:[["id_curso","INT UNSIGNED","PK"],["nome","VARCHAR(120)"],["id_instituicao","INT UNSIGNED","FK"]] },
  aceite_termo: { g:[0.5,0.5], f:[["id_usuario","INT UNSIGNED","PK FK"],["id_termo","INT UNSIGNED","PK FK"],["data_hora_aceite","DATETIME"]] },
  termo_uso:    { g:[0,0], f:[["id_termo","INT UNSIGNED","PK"],["versao","VARCHAR(10)","UQ"],["conteudo","TEXT"],["publicado_em","DATETIME"]] },
  documento_identidade: { g:[1.5,0.5], f:[["id_documento","INT UNSIGNED","PK"],["tipo_documento","VARCHAR(10)"],["numero_documento","VARCHAR(20)"],["arquivo_url","VARCHAR(255)"],["status","VARCHAR(10)"],["motivo_recusa","VARCHAR(255)","NULL"],["enviado_em","DATETIME"],["analisado_em","DATETIME","NULL"],["id_aluno","INT UNSIGNED","FK"],["id_usuario_analista","INT UNSIGNED","FK NULL"]] },
  aluno_curso:  { g:[2,0.5], f:[["id_aluno","INT UNSIGNED","PK FK"],["id_curso","INT UNSIGNED","PK FK"]] },
  notificacao:  { g:[0,1], f:[["id_notificacao","INT UNSIGNED","PK"],["tipo","VARCHAR(25)"],["mensagem","VARCHAR(500)"],["enviada_em","DATETIME"],["lida","BOOLEAN"],["id_usuario","INT UNSIGNED","FK"],["id_solicitacao","INT UNSIGNED","FK NULL"]] },
  usuario:      { g:[1,1], f:[["id_usuario","INT UNSIGNED","PK"],["nome","VARCHAR(120)"],["cpf","CHAR(11)","UQ"],["email","VARCHAR(150)","UQ"],["senha_hash","CHAR(60)"],["perfil","VARCHAR(5)"],["telefone","VARCHAR(11)","NULL"],["status_conta","VARCHAR(10)"],["criado_em","DATETIME"],["id_instituicao","INT UNSIGNED","FK NULL"]] },
  aluno:        { g:[2,1], f:[["id_aluno","INT UNSIGNED","PK"],["matricula","CHAR(11)","UQ"],["situacao_vinculo","VARCHAR(10)"],["id_usuario","INT UNSIGNED","FK UQ"]] },
  avaliacao:    { g:[3,1], f:[["id_avaliacao","INT UNSIGNED","PK"],["nota","TINYINT UNSIGNED"],["comentario","VARCHAR(500)","NULL"],["data_hora","DATETIME"],["id_aluno_avaliador","INT UNSIGNED","FK"],["id_reserva","INT UNSIGNED","FK"]] },
  pagamento_simulado: { g:[2.5,1.5], f:[["id_pagamento","INT UNSIGNED","PK"],["valor_total","DECIMAL(10,2)"],["status","VARCHAR(10)"],["data_hora","DATETIME"],["id_solicitacao","INT UNSIGNED","FK UQ"]] },
  biometria_facial: { g:[0,2], f:[["id_biometria","INT UNSIGNED","PK"],["id_usuario","INT UNSIGNED","FK"],["embedding_iv","BINARY(12)"],["embedding_tag","BINARY(16)"],["embedding_ct","VARBINARY(2048)"],["key_version","INT UNSIGNED"],["model_version","VARCHAR(50)"],["criado_em","DATETIME"]] },
  equipamento:  { g:[1,2], f:[["id_equipamento","INT UNSIGNED","PK"],["nome","VARCHAR(120)"],["descricao","VARCHAR(500)"],["estado_conservacao","VARCHAR(10)"],["situacao","VARCHAR(15)"],["criado_em","DATETIME"],["id_categoria","INT UNSIGNED","FK"],["id_usuario_proprietario","INT UNSIGNED","FK"]] },
  solicitacao:  { g:[2,2], f:[["id_solicitacao","INT UNSIGNED","PK"],["data_inicio","DATE"],["data_fim","DATE"],["status","VARCHAR(10)"],["justificativa_recusa","VARCHAR(255)","NULL"],["criada_em","DATETIME"],["respondida_em","DATETIME","NULL"],["id_aluno","INT UNSIGNED","FK"],["id_disponibilizacao","INT UNSIGNED","FK"]] },
  reserva:      { g:[3,2], f:[["id_reserva","INT UNSIGNED","PK"],["status","VARCHAR(10)"],["criada_em","DATETIME"],["id_solicitacao","INT UNSIGNED","FK UQ"]] },
  categoria:    { g:[0,3], f:[["id_categoria","INT UNSIGNED","PK"],["nome","VARCHAR(60)","UQ"]] },
  dano:         { g:[1,3], f:[["id_dano","INT UNSIGNED","PK"],["descricao","VARCHAR(500)"],["data_hora","DATETIME"],["status_andamento","VARCHAR(10)"],["resolvido_em","DATETIME","NULL"],["id_equipamento","INT UNSIGNED","FK"],["id_usuario_relator","INT UNSIGNED","FK"],["id_reserva","INT UNSIGNED","FK NULL"]] },
  disponibilizacao: { g:[2,3], f:[["id_disponibilizacao","INT UNSIGNED","PK"],["modalidade","VARCHAR(10)"],["valor_diaria","DECIMAL(10,2)"],["data_inicio","DATE"],["data_fim","DATE"],["prazo_maximo_dias","SMALLINT UNSIGNED","NULL"],["criado_em","DATETIME"],["id_equipamento","INT UNSIGNED","FK"]] },
  retirada:     { g:[3,3], f:[["id_retirada","INT UNSIGNED","PK"],["data_hora","DATETIME"],["estado_conservacao","VARCHAR(10)"],["observacao","VARCHAR(500)","NULL"],["codigo_comprovante","CHAR(13)","UQ"],["id_reserva","INT UNSIGNED","FK UQ"],["id_biometria","INT UNSIGNED","FK"]] },
  foto_dano:    { g:[1,4], f:[["id_foto","INT UNSIGNED","PK"],["url_arquivo","VARCHAR(255)"],["formato","VARCHAR(3)"],["tamanho_bytes","INT UNSIGNED"],["enviada_em","DATETIME"],["id_dano","INT UNSIGNED","FK"]] },
  devolucao:    { g:[3,4], f:[["id_devolucao","INT UNSIGNED","PK"],["data_hora","DATETIME"],["estado_conservacao","VARCHAR(10)"],["itens_faltantes","VARCHAR(255)","NULL"],["observacao","VARCHAR(500)","NULL"],["codigo_comprovante","CHAR(13)","UQ"],["id_retirada","INT UNSIGNED","FK UQ"]] }
};

// [filha, campo, pai, card. lado pai, card. lado filha, lado filha, desloc., lado pai, desloc., vias (grade [gx,gy,dx,dy])]
var FKS = [
  ["curso","id_instituicao","instituicao","1,1","1,n", "L",0, "R",0],
  ["usuario","id_instituicao","instituicao","0,1","1,n", "T",0, "B",0],
  ["aluno","id_usuario","usuario","1,1","0,1", "L",0, "R",0],
  ["aluno_curso","id_aluno","aluno","1,1","1,n", "B",0, "T",0],
  ["aluno_curso","id_curso","curso","1,1","0,n", "T",0, "B",0],
  ["documento_identidade","id_aluno","aluno","1,1","0,n", "R",60, "T",-100],
  ["documento_identidade","id_usuario_analista","usuario","0,1","0,n", "L",60, "T",100],
  ["biometria_facial","id_usuario","usuario","1,1","1,n", "T",0, "B",-100, [[0,1.5],[1,1.5,-100,0]]],
  ["aceite_termo","id_usuario","usuario","1,1","0,n", "R",0, "T",-100],
  ["aceite_termo","id_termo","termo_uso","1,1","0,n", "L",0, "B",0],
  ["equipamento","id_categoria","categoria","1,1","0,n", "B",-100, "T",0, [[1,2.5,-100,0],[0,2.5]]],
  ["equipamento","id_usuario_proprietario","usuario","1,1","0,n", "T",0, "B",0],
  ["disponibilizacao","id_equipamento","equipamento","1,1","0,n", "L",0, "R",40, [[1.5,3],[1.5,2,0,40]]],
  ["solicitacao","id_aluno","aluno","1,1","0,n", "T",0, "B",0],
  ["solicitacao","id_disponibilizacao","disponibilizacao","1,1","0,n", "B",0, "T",0],
  ["pagamento_simulado","id_solicitacao","solicitacao","1,1","0,1", "B",0, "R",-50],
  ["reserva","id_solicitacao","solicitacao","1,1","0,1", "L",0, "R",0],
  ["retirada","id_reserva","reserva","1,1","0,1", "T",0, "B",0],
  ["retirada","id_biometria","biometria_facial","1,1","0,n", "R",0, "L",0, [[3.6,3],[3.6,4.6],[-0.45,4.6],[-0.45,2]]],
  ["devolucao","id_retirada","retirada","1,1","0,1", "T",0, "B",0],
  ["dano","id_equipamento","equipamento","1,1","0,n", "T",0, "B",0],
  ["dano","id_usuario_relator","usuario","1,1","0,n", "R",-40, "R",60, [[1.5,3,60,-40],[1.5,1,60,60]]],
  ["dano","id_reserva","reserva","0,1","0,n", "B",-100, "R",0, [[1,3.55,-100,0],[3.55,3.55],[3.55,2]]],
  ["foto_dano","id_dano","dano","1,1","1,n", "T",0, "B",0],
  ["avaliacao","id_aluno_avaliador","aluno","1,1","0,n", "L",0, "R",0],
  ["avaliacao","id_reserva","reserva","1,1","0,n", "B",0, "T",0],
  ["notificacao","id_usuario","usuario","1,1","0,n", "R",0, "L",0],
  ["notificacao","id_solicitacao","solicitacao","0,1","0,n", "B",40, "L",-80, [[0,1.6,40,0],[1.75,1.6],[1.75,2,0,-80]]],
  ["registro_operacao","id_usuario","usuario","0,1","0,n", "L",0, "L",110, [[-0.35,4],[-0.35,1,0,110]]]
];
