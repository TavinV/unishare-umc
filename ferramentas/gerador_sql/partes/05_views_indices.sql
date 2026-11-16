-- Views de relatorio gerencial e um indice para otimizar cada view

USE unishare;

-- View 1: desempenho de cada equipamento (reservas, dias reservados e receita simulada)
CREATE VIEW vw_desempenho_equipamentos AS
SELECT e.id_equipamento,
       e.nome AS equipamento,
       c.nome AS categoria,
       CASE WHEN u.perfil = 'ADM' THEN 'INSTITUCIONAL' ELSE 'ALUNO' END AS origem,
       u.nome AS proprietario,
       e.situacao,
       COUNT(s.id_solicitacao) AS reservas,
       COALESCE(SUM(DATEDIFF(s.data_fim, s.data_inicio)), 0) AS dias_reservados,
       COALESCE(SUM(p.valor_total), 0) AS receita_simulada,
       MAX(s.data_inicio) AS ultima_reserva
FROM equipamento e
JOIN categoria c ON c.id_categoria = e.id_categoria
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
LEFT JOIN disponibilizacao d ON d.id_equipamento = e.id_equipamento
LEFT JOIN solicitacao s ON s.id_disponibilizacao = d.id_disponibilizacao AND s.status = 'APROVADA'
LEFT JOIN pagamento_simulado p ON p.id_solicitacao = s.id_solicitacao AND p.status = 'SIMULADO'
GROUP BY e.id_equipamento, e.nome, c.nome, u.perfil, u.nome, e.situacao;

-- Indice da view 1: liga a oferta as solicitacoes aprovadas e cobre o periodo
CREATE INDEX ix_solicitacao_disp_status_periodo ON solicitacao (id_disponibilizacao, status, data_inicio, data_fim);

-- View 2: tempo que o equipamento fica com o aluno e atrasos por categoria
CREATE VIEW vw_tempo_devolucao_categoria AS
SELECT c.nome AS categoria,
       COUNT(*) AS devolucoes,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, rt.data_hora, dv.data_hora)) / 24, 1) AS media_dias_com_aluno,
       ROUND(MIN(TIMESTAMPDIFF(HOUR, rt.data_hora, dv.data_hora)) / 24, 1) AS minimo_dias,
       ROUND(MAX(TIMESTAMPDIFF(HOUR, rt.data_hora, dv.data_hora)) / 24, 1) AS maximo_dias,
       SUM(DATE(dv.data_hora) > s.data_fim) AS devolucoes_atrasadas,
       ROUND(100 * SUM(DATE(dv.data_hora) > s.data_fim) / COUNT(*), 1) AS percentual_atraso
FROM devolucao dv
JOIN retirada rt ON rt.id_retirada = dv.id_retirada
JOIN reserva r ON r.id_reserva = rt.id_reserva
JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN categoria c ON c.id_categoria = e.id_categoria
GROUP BY c.nome;

-- Indice da view 2: cobre a juncao da devolucao com a retirada e a data da devolucao
CREATE INDEX ix_devolucao_retirada_data ON devolucao (id_retirada, data_hora);

-- View 3: receita simulada de aluguel por proprietario
CREATE VIEW vw_receita_proprietarios AS
SELECT u.id_usuario,
       u.nome AS proprietario,
       u.email,
       COUNT(DISTINCT e.id_equipamento) AS equipamentos_alugados,
       COUNT(p.id_pagamento) AS alugueis,
       SUM(p.valor_total) AS receita_total,
       ROUND(AVG(p.valor_total), 2) AS ticket_medio
FROM pagamento_simulado p
JOIN solicitacao s ON s.id_solicitacao = p.id_solicitacao AND s.status = 'APROVADA'
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
WHERE p.status = 'SIMULADO'
GROUP BY u.id_usuario, u.nome, u.email;

-- Indice da view 3: filtra pagamentos validos e cobre a solicitacao e o valor
CREATE INDEX ix_pagamento_status_solicitacao_valor ON pagamento_simulado (status, id_solicitacao, valor_total);

-- View 4: solicitacoes por mes, por status e tempo medio de resposta
CREATE VIEW vw_solicitacoes_mensais AS
SELECT DATE_FORMAT(s.criada_em, '%Y-%m') AS mes,
       COUNT(*) AS total,
       SUM(s.status = 'APROVADA') AS aprovadas,
       SUM(s.status = 'RECUSADA') AS recusadas,
       SUM(s.status = 'CANCELADA') AS canceladas,
       SUM(s.status = 'EXPIRADA') AS expiradas,
       SUM(s.status = 'PENDENTE') AS pendentes,
       ROUND(100 * SUM(s.status = 'APROVADA') / COUNT(*), 1) AS taxa_aprovacao,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, s.criada_em, s.respondida_em)) / 60, 1) AS media_horas_resposta
FROM solicitacao s
GROUP BY DATE_FORMAT(s.criada_em, '%Y-%m');

-- Indice da view 4: cobre todas as colunas usadas, sem ler a tabela
CREATE INDEX ix_solicitacao_criada_status_resposta ON solicitacao (criada_em, status, respondida_em);

-- View 5: reputacao dos alunos; o avaliado e a outra parte da reserva
CREATE VIEW vw_reputacao_alunos AS
SELECT u.id_usuario,
       u.nome AS aluno,
       a.matricula,
       COUNT(*) AS avaliacoes_recebidas,
       ROUND(AVG(x.nota), 2) AS reputacao,
       SUM(x.nota <= 2) AS avaliacoes_negativas,
       MAX(x.data_hora) AS ultima_avaliacao
FROM (
  SELECT av.nota, av.data_hora,
         CASE WHEN av.id_aluno_avaliador = s.id_aluno THEN e.id_usuario_proprietario ELSE sol.id_usuario END AS id_usuario_avaliado
  FROM avaliacao av
  JOIN reserva r ON r.id_reserva = av.id_reserva
  JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
  JOIN aluno sol ON sol.id_aluno = s.id_aluno
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  JOIN equipamento e ON e.id_equipamento = d.id_equipamento
) x
JOIN usuario u ON u.id_usuario = x.id_usuario_avaliado
JOIN aluno a ON a.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nome, a.matricula;

-- Indice da view 5: cobre a juncao da avaliacao com a reserva, o avaliador e a nota
CREATE INDEX ix_avaliacao_reserva_avaliador_nota ON avaliacao (id_reserva, id_aluno_avaliador, nota, data_hora);

-- View 6: danos ainda nao resolvidos e ha quantos dias o equipamento esta parado
CREATE VIEW vw_danos_em_aberto AS
SELECT dn.id_dano,
       e.nome AS equipamento,
       dono.nome AS proprietario,
       rel.nome AS relatado_por,
       dn.descricao,
       dn.status_andamento,
       dn.data_hora AS registrado_em,
       DATEDIFF(CURDATE(), DATE(dn.data_hora)) AS dias_parado,
       (SELECT COUNT(*) FROM foto_dano f WHERE f.id_dano = dn.id_dano) AS fotos
FROM dano dn
JOIN equipamento e ON e.id_equipamento = dn.id_equipamento
JOIN usuario dono ON dono.id_usuario = e.id_usuario_proprietario
JOIN usuario rel ON rel.id_usuario = dn.id_usuario_relator
WHERE dn.status_andamento <> 'RESOLVIDO';

-- Indice da view 6: localiza os danos pelo andamento e pela data
CREATE INDEX ix_dano_status_data ON dano (status_andamento, data_hora);

-- View 7: inventario de equipamentos por categoria e situacao
CREATE VIEW vw_inventario_categoria AS
SELECT c.nome AS categoria,
       COUNT(e.id_equipamento) AS total,
       SUM(e.situacao = 'DISPONIVEL') AS disponiveis,
       SUM(e.situacao = 'RESERVADO') AS reservados,
       SUM(e.situacao = 'EM_USO') AS em_uso,
       SUM(e.situacao = 'EM_MANUTENCAO') AS em_manutencao,
       SUM(e.situacao = 'INDISPONIVEL') AS indisponiveis,
       SUM(u.perfil = 'ADM') AS institucionais
FROM categoria c
LEFT JOIN equipamento e ON e.id_categoria = c.id_categoria
LEFT JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
GROUP BY c.id_categoria, c.nome;

-- Indice da view 7: agrupa equipamentos por categoria e situacao
CREATE INDEX ix_equipamento_categoria_situacao ON equipamento (id_categoria, situacao, id_usuario_proprietario);

-- View 8: auditoria de acesso por usuario (logins, falhas, operacoes e IPs)
CREATE VIEW vw_auditoria_usuarios AS
SELECT u.id_usuario,
       u.nome,
       u.perfil,
       u.status_conta,
       SUM(ro.tipo_operacao = 'LOGIN') AS logins,
       (SELECT COUNT(*) FROM registro_operacao f
         WHERE f.tipo_operacao = 'LOGIN_FALHA' AND f.tabela_afetada = 'usuario' AND f.id_afetado = u.id_usuario) AS logins_com_falha,
       SUM(ro.tipo_operacao NOT IN ('LOGIN', 'LOGIN_FALHA')) AS operacoes,
       MAX(CASE WHEN ro.tipo_operacao = 'LOGIN' THEN ro.data_hora END) AS ultimo_login,
       COUNT(DISTINCT ro.endereco_ip) AS ips_diferentes
FROM usuario u
LEFT JOIN registro_operacao ro ON ro.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nome, u.perfil, u.status_conta;

-- Indice da view 8: agrupa os registros por usuario e tipo de operacao
CREATE INDEX ix_registro_usuario_tipo_data ON registro_operacao (id_usuario, tipo_operacao, data_hora, endereco_ip);
