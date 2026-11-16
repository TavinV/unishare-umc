// Especificação do MER UniShare (conceitual) — notação Heuser/brModelo:
// a cardinalidade ao lado de uma entidade indica quantas ocorrências DELA se associam a UMA ocorrência da outra.
// Atributos: "*" = identificador (PK), "?" = opcional.
// Coordenadas em grade: [gx, gy, dxPx, dyPx] -> centro = (OX + gx*GX + dx, OY + gy*GY + dy)
var GX = 640, GY = 420, OX = 420, OY = 150;

var ENT = {
  REGISTRO_OPERACAO:    { g:[0,4],   attrs:["id_registro*","tipo_operacao","tabela_afetada","id_afetado","endereco_ip","latitude?","longitude?","data_hora"] },
  INSTITUICAO:          { g:[1,0],   attrs:["id_instituicao*","nome","sigla","cnpj"] },
  CURSO:                { g:[2,0],   attrs:["id_curso*","nome"] },
  TERMO_USO:            { g:[0,0],   attrs:["id_termo*","versao","conteudo","publicado_em"] },
  DOCUMENTO_IDENTIDADE: { g:[1.5,0.5], attrs:["id_documento*","tipo_documento","numero_documento","arquivo_url","status","motivo_recusa?","enviado_em","analisado_em?"], side:"TR" },
  NOTIFICACAO:          { g:[0,1],   attrs:["id_notificacao*","tipo","mensagem","enviada_em","lida"] },
  USUARIO:              { g:[1,1],   attrs:["id_usuario*","nome","cpf","email","senha_hash","perfil","telefone?","status_conta","criado_em"], h:100 },
  ALUNO:                { g:[2,1],   attrs:["id_aluno*","matricula","situacao_vinculo"] },
  AVALIACAO:            { g:[3,1],   attrs:["id_avaliacao*","nota","comentario?","data_hora"] },
  PAGAMENTO_SIMULADO:   { g:[2.5,1.5], attrs:["id_pagamento*","valor_total","status","data_hora"] },
  BIOMETRIA_FACIAL:     { g:[0,2],   attrs:["id_biometria*","embedding_iv","embedding_tag","embedding_ct","key_version","model_version","criado_em"] },
  EQUIPAMENTO:          { g:[1,2],   attrs:["id_equipamento*","nome","descricao","estado_conservacao","situacao","criado_em"] },
  SOLICITACAO:          { g:[2,2],   attrs:["id_solicitacao*","data_inicio","data_fim","status","justificativa_recusa?","criada_em","respondida_em?"] },
  RESERVA:              { g:[3,2],   attrs:["id_reserva*","status","criada_em"] },
  CATEGORIA:            { g:[0,3],   attrs:["id_categoria*","nome"] },
  DANO:                 { g:[1,3],   attrs:["id_dano*","descricao","data_hora","status_andamento","resolvido_em?"] },
  DISPONIBILIZACAO:     { g:[2,3],   attrs:["id_disponibilizacao*","modalidade","valor_diaria","data_inicio","data_fim","prazo_maximo_dias?","criado_em"] },
  RETIRADA:             { g:[3,3],   attrs:["id_retirada*","data_hora","estado_conservacao","observacao?","codigo_comprovante"] },
  FOTO_DANO:            { g:[1,4],   attrs:["id_foto*","url_arquivo","formato","tamanho_bytes","enviada_em"] },
  DEVOLUCAO:            { g:[3,4],   attrs:["id_devolucao*","data_hora","estado_conservacao","itens_faltantes?","observacao?","codigo_comprovante"] }
};

// a/b: [entidade, cardinalidade ao lado dela, lado (T/B/L/R), deslocamento px ao longo do lado, vias (cantos, em grade)]
var REL = [
  { n:"oferece",       d:[1.5,0],        a:["INSTITUICAO","1,1","R",0],    b:["CURSO","1,n","L",0] },
  { n:"administra",    d:[1,0.5],        a:["INSTITUICAO","0,1","B",0],    b:["USUARIO","1,n","T",0] },
  { n:"cursa",         d:[2,0.5],        a:["CURSO","1,n","B",0],          b:["ALUNO","0,n","T",0] },
  { n:"corresponde",   d:[1.5,1],        a:["USUARIO","1,1","R",0],        b:["ALUNO","0,1","L",0] },
  { n:"analisa",       d:[1,0,85,295],   a:["USUARIO","0,1","T",85],       b:["DOCUMENTO_IDENTIDADE","0,n","L",0] },
  { n:"envia",         d:[2,0,-85,295],  a:["ALUNO","1,1","T",-85],        b:["DOCUMENTO_IDENTIDADE","0,n","R",0] },
  { n:"realiza",       d:[-0.25,2.6],    a:["USUARIO","0,1","L",-40, [[-0.25,1,0,-40]]], b:["REGISTRO_OPERACAO","0,n","L",0, [[-0.25,4]]] },
  { n:"recebe",        d:[0.5,1],        a:["USUARIO","1,1","L",0],        b:["NOTIFICACAO","0,n","R",0] },
  { n:"cadastra",      d:[0.5,1.5],      a:["USUARIO","1,1","B",-80],      b:["BIOMETRIA_FACIAL","1,n","T",0] },
  { n:"aceita",        d:[0.5,0.5],      a:["USUARIO","0,n","T",-85],      b:["TERMO_USO","0,n","B",0], attrs:["data_hora_aceite"] },
  { n:"avalia",        d:[2.5,1],        a:["ALUNO","1,1","R",0],          b:["AVALIACAO","0,n","L",0] },
  { n:"refere_a",      d:[3,1.5],        a:["RESERVA","1,1","T",0],        b:["AVALIACAO","0,n","B",0] },
  { n:"solicita",      d:[2,1.5],        a:["ALUNO","1,1","B",0],          b:["SOLICITACAO","0,n","T",0] },
  { n:"gera",          d:[2.5,1.5,-50,115], a:["SOLICITACAO","1,1","T",85], b:["PAGAMENTO_SIMULADO","0,1","B",-50] },
  { n:"origina",       d:[2.5,2],        a:["SOLICITACAO","1,1","R",0],    b:["RESERVA","0,1","L",0] },
  { n:"notifica",      d:[1.5,1.5,0,55], a:["SOLICITACAO","0,1","L",-15],  b:["NOTIFICACAO","0,n","B",40] },
  { n:"possui",        d:[1,1.5],        a:["USUARIO","1,1","B",0],        b:["EQUIPAMENTO","0,n","T",0] },
  { n:"classifica",    d:[0.5,2.5],      a:["CATEGORIA","1,1","R",0],      b:["EQUIPAMENTO","0,n","L",0] },
  { n:"disponibiliza", d:[1.5,2.5,-40,0], a:["EQUIPAMENTO","1,1","R",15],  b:["DISPONIBILIZACAO","0,n","L",0] },
  { n:"baseia",        d:[2,2.5],        a:["DISPONIBILIZACAO","1,1","T",0], b:["SOLICITACAO","0,n","B",0] },
  { n:"sofre",         d:[1,2.5],        a:["EQUIPAMENTO","1,1","B",0],    b:["DANO","0,n","T",0] },
  { n:"relata",        d:[1.5,2.2,150,0], a:["USUARIO","1,1","R",40],      b:["DANO","0,n","R",-20] },
  { n:"ocorre_em",     d:[2.5,3.62],     a:["RESERVA","0,1","R",0, [[3.6,2],[3.6,3.62]]], b:["DANO","0,n","B",-85] },
  { n:"documenta",     d:[1,3.5],        a:["DANO","1,1","B",0],           b:["FOTO_DANO","1,n","T",0] },
  { n:"inicia",        d:[3,2.5],        a:["RESERVA","1,1","B",0],        b:["RETIRADA","0,1","T",0] },
  { n:"encerra",       d:[3,3.5],        a:["RETIRADA","1,1","B",0],       b:["DEVOLUCAO","0,1","T",0] },
  { n:"confirma",      d:[2,4.5],        a:["BIOMETRIA_FACIAL","1,1","L",0, [[-0.4,2],[-0.4,4.5]]], b:["RETIRADA","0,n","R",0, [[3.75,3],[3.75,4.5]]] }
];
