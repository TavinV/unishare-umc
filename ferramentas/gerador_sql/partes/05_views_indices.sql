-- Views de relatorio gerencial e um indice para otimizar cada view

USE unishare;

-- View 1: equipamentos disponiveis, com categoria, dono e a disponibilizacao mais recente
CREATE VIEW vw_equipamentos_disponiveis AS
SELECT e.id_equipamento, e.nome AS equipamento, c.nome AS categoria, u.nome AS proprietario,
       d.modalidade, d.valor_diaria, d.data_fim AS disponivel_ate, e.estado_conservacao
FROM equipamento e
JOIN categoria c ON c.id_categoria = e.id_categoria
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
JOIN disponibilizacao d ON d.id_equipamento = e.id_equipamento
WHERE e.situacao = 'DISPONIVEL'
  AND d.id_disponibilizacao = (SELECT MAX(d2.id_disponibilizacao) FROM disponibilizacao d2
                               WHERE d2.id_equipamento = e.id_equipamento);

-- Indice da view 1: filtra os equipamentos pela situacao
CREATE INDEX ix_equipamento_situacao ON equipamento (situacao);

-- View 2: solicitacoes aguardando resposta, com o aluno, o equipamento e o valor estimado
CREATE VIEW vw_solicitacoes_pendentes AS
SELECT s.id_solicitacao, u.nome AS aluno, a.matricula, e.nome AS equipamento,
       s.data_inicio, s.data_fim, DATEDIFF(s.data_fim, s.data_inicio) + 1 AS dias,
       (DATEDIFF(s.data_fim, s.data_inicio) + 1) * d.valor_diaria AS valor_estimado
FROM solicitacao s
JOIN aluno a ON a.id_aluno = s.id_aluno
JOIN usuario u ON u.id_usuario = a.id_usuario
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
WHERE s.status = 'PENDENTE';

-- Indice da view 2: filtra as solicitacoes pelo status
CREATE INDEX ix_solicitacao_status ON solicitacao (status);

-- View 3: reservas em andamento (confirmadas, em uso ou atrasadas)
CREATE VIEW vw_reservas_em_andamento AS
SELECT r.id_reserva, r.status, a.matricula, e.nome AS equipamento, s.data_inicio, s.data_fim
FROM reserva r
JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
JOIN aluno a ON a.id_aluno = s.id_aluno
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
WHERE r.status IN ('CONFIRMADA', 'EM_USO', 'ATRASADA');

-- Indice da view 3: filtra as reservas pelo status
CREATE INDEX ix_reserva_status ON reserva (status);

-- View 4: quantidade de pagamentos e valor arrecadado por categoria
CREATE VIEW vw_receita_por_categoria AS
SELECT c.nome AS categoria, COUNT(*) AS pagamentos, SUM(p.valor_total) AS valor_total
FROM pagamento_simulado p
JOIN solicitacao s ON s.id_solicitacao = p.id_solicitacao
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN categoria c ON c.id_categoria = e.id_categoria
WHERE p.status = 'SIMULADO'
GROUP BY c.nome;

-- Indice da view 4: filtra os pagamentos pelo status
CREATE INDEX ix_pagamento_status ON pagamento_simulado (status);

-- View 5: danos ainda nao resolvidos, com quem relatou e a quantidade de fotos
CREATE VIEW vw_danos_em_aberto AS
SELECT d.id_dano, e.nome AS equipamento, u.nome AS relator, d.descricao, d.status_andamento, d.data_hora,
       (SELECT COUNT(*) FROM foto_dano f WHERE f.id_dano = d.id_dano) AS fotos
FROM dano d
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN usuario u ON u.id_usuario = d.id_usuario_relator
WHERE d.status_andamento IN ('ABERTO', 'EM_REPARO');

-- Indice da view 5: filtra os danos pelo andamento
CREATE INDEX ix_dano_status ON dano (status_andamento);

-- View 6: avaliacoes negativas (nota 1 ou 2), com o equipamento e o avaliador
CREATE VIEW vw_avaliacoes_negativas AS
SELECT av.id_avaliacao, e.nome AS equipamento, av.nota, av.comentario, av.data_hora,
       (SELECT a.matricula FROM aluno a WHERE a.id_aluno = av.id_aluno_avaliador) AS matricula_avaliador
FROM avaliacao av
JOIN reserva r ON r.id_reserva = av.id_reserva
JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
WHERE av.nota <= 2;

-- Indice da view 6: filtra as avaliacoes pela nota
CREATE INDEX ix_avaliacao_nota ON avaliacao (nota);

-- View 7: documentos de identidade aguardando analise do administrador
CREATE VIEW vw_documentos_pendentes AS
SELECT doc.id_documento, u.nome AS aluno, a.matricula, doc.tipo_documento, doc.enviado_em
FROM documento_identidade doc
JOIN aluno a ON a.id_aluno = doc.id_aluno
JOIN usuario u ON u.id_usuario = a.id_usuario
WHERE doc.status = 'PENDENTE';

-- Indice da view 7: filtra os documentos pelo status
CREATE INDEX ix_documento_status ON documento_identidade (status);

-- View 8: quantidade de notificacoes nao lidas por usuario
CREATE VIEW vw_notificacoes_nao_lidas AS
SELECT u.id_usuario, u.nome AS usuario, COUNT(*) AS nao_lidas, MIN(n.enviada_em) AS mais_antiga
FROM notificacao n
JOIN usuario u ON u.id_usuario = n.id_usuario
WHERE n.lida = FALSE
GROUP BY u.id_usuario, u.nome;

-- Indice da view 8: filtra as notificacoes pela leitura
CREATE INDEX ix_notificacao_lida ON notificacao (lida);
