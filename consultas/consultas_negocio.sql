-- UniShare - consultas de negocio (MySQL 8.4)

USE unishare;

-- 1. Historico de reservas de um equipamento especifico
SELECT e.nome AS equipamento,
       u.nome AS solicitante,
       s.data_inicio,
       s.data_fim,
       r.status AS status_reserva,
       rt.data_hora AS retirada,
       dv.data_hora AS devolucao,
       GREATEST(DATEDIFF(DATE(dv.data_hora), s.data_fim), 0) AS dias_atraso,
       p.valor_total
FROM equipamento e
JOIN disponibilizacao d ON d.id_equipamento = e.id_equipamento
JOIN solicitacao s ON s.id_disponibilizacao = d.id_disponibilizacao
JOIN reserva r ON r.id_solicitacao = s.id_solicitacao
JOIN aluno a ON a.id_aluno = s.id_aluno
JOIN usuario u ON u.id_usuario = a.id_usuario
LEFT JOIN retirada rt ON rt.id_reserva = r.id_reserva
LEFT JOIN devolucao dv ON dv.id_retirada = rt.id_retirada
LEFT JOIN pagamento_simulado p ON p.id_solicitacao = s.id_solicitacao
WHERE e.nome = 'Notebook Dell Inspiron 15'
ORDER BY s.data_inicio;

-- 2. Tempo medio entre retirada e devolucao por categoria
SELECT c.nome AS categoria,
       COUNT(*) AS devolucoes,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, rt.data_hora, dv.data_hora)) / 24, 1) AS media_dias_com_aluno,
       ROUND(MIN(TIMESTAMPDIFF(HOUR, rt.data_hora, dv.data_hora)) / 24, 1) AS minimo_dias,
       ROUND(MAX(TIMESTAMPDIFF(HOUR, rt.data_hora, dv.data_hora)) / 24, 1) AS maximo_dias
FROM devolucao dv
JOIN retirada rt ON rt.id_retirada = dv.id_retirada
JOIN reserva r ON r.id_reserva = rt.id_reserva
JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN categoria c ON c.id_categoria = e.id_categoria
GROUP BY c.nome
ORDER BY media_dias_com_aluno DESC;

-- 3. Tempo medio de resposta do proprietario as solicitacoes (aluno x UMC)
SELECT CASE WHEN u.perfil = 'ADM' THEN 'UMC (institucional)' ELSE 'Aluno proprietario' END AS tipo_proprietario,
       COUNT(*) AS solicitacoes_respondidas,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, s.criada_em, s.respondida_em)) / 60, 1) AS media_horas_resposta,
       SUM(s.status = 'APROVADA') AS aprovadas,
       SUM(s.status = 'RECUSADA') AS recusadas
FROM solicitacao s
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
WHERE s.respondida_em IS NOT NULL
  AND (s.justificativa_recusa IS NULL OR s.justificativa_recusa NOT LIKE 'Recusada automaticamente%')
GROUP BY tipo_proprietario;

-- 4. Ranking dos equipamentos mais reservados e dias totais de uso
SELECT e.nome AS equipamento,
       c.nome AS categoria,
       COUNT(r.id_reserva) AS reservas,
       SUM(DATEDIFF(s.data_fim, s.data_inicio)) AS dias_reservados,
       RANK() OVER (ORDER BY COUNT(r.id_reserva) DESC) AS posicao
FROM equipamento e
JOIN categoria c ON c.id_categoria = e.id_categoria
JOIN disponibilizacao d ON d.id_equipamento = e.id_equipamento
JOIN solicitacao s ON s.id_disponibilizacao = d.id_disponibilizacao
JOIN reserva r ON r.id_solicitacao = s.id_solicitacao
GROUP BY e.id_equipamento, e.nome, c.nome
ORDER BY reservas DESC, dias_reservados DESC
LIMIT 10;

-- 5. Receita simulada de aluguel por aluno proprietario
SELECT u.nome AS proprietario,
       COUNT(DISTINCT e.id_equipamento) AS equipamentos_alugados,
       COUNT(p.id_pagamento) AS alugueis,
       SUM(p.valor_total) AS receita_total,
       ROUND(AVG(p.valor_total), 2) AS ticket_medio
FROM pagamento_simulado p
JOIN solicitacao s ON s.id_solicitacao = p.id_solicitacao
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
WHERE p.status = 'SIMULADO' AND s.status = 'APROVADA'
GROUP BY u.id_usuario, u.nome
ORDER BY receita_total DESC;

-- 6. Taxa de aprovacao por proprietario
SELECT u.nome AS proprietario,
       u.perfil,
       COUNT(*) AS solicitacoes_recebidas,
       SUM(s.status = 'APROVADA') AS aprovadas,
       SUM(s.status = 'RECUSADA') AS recusadas,
       SUM(s.status = 'EXPIRADA') AS expiradas,
       ROUND(100 * SUM(s.status = 'APROVADA') / COUNT(*), 1) AS taxa_aprovacao_pct
FROM solicitacao s
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
GROUP BY u.id_usuario, u.nome, u.perfil
HAVING COUNT(*) >= 3
ORDER BY taxa_aprovacao_pct DESC, solicitacoes_recebidas DESC;

-- 7. Reputacao dos alunos (media das notas recebidas; o avaliado e a outra parte da reserva)
WITH avaliacoes_recebidas AS (
  SELECT av.nota,
         CASE WHEN av.id_aluno_avaliador = s.id_aluno THEN e.id_usuario_proprietario
              ELSE sol.id_usuario END AS id_usuario_avaliado
  FROM avaliacao av
  JOIN reserva r ON r.id_reserva = av.id_reserva
  JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
  JOIN aluno sol ON sol.id_aluno = s.id_aluno
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  JOIN equipamento e ON e.id_equipamento = d.id_equipamento
)
SELECT u.nome AS aluno,
       COUNT(*) AS avaliacoes_recebidas,
       ROUND(AVG(ar.nota), 2) AS reputacao,
       SUM(ar.nota <= 2) AS avaliacoes_negativas
FROM avaliacoes_recebidas ar
JOIN usuario u ON u.id_usuario = ar.id_usuario_avaliado
GROUP BY u.id_usuario, u.nome
ORDER BY reputacao DESC, avaliacoes_recebidas DESC;

-- 8. Alunos com devolucoes atrasadas e media de dias de atraso
SELECT u.nome AS aluno,
       a.matricula,
       COUNT(*) AS devolucoes_atrasadas,
       ROUND(AVG(DATEDIFF(DATE(dv.data_hora), s.data_fim)), 1) AS media_dias_atraso,
       MAX(DATEDIFF(DATE(dv.data_hora), s.data_fim)) AS maior_atraso
FROM devolucao dv
JOIN retirada rt ON rt.id_retirada = dv.id_retirada
JOIN reserva r ON r.id_reserva = rt.id_reserva
JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
JOIN aluno a ON a.id_aluno = s.id_aluno
JOIN usuario u ON u.id_usuario = a.id_usuario
WHERE DATE(dv.data_hora) > s.data_fim
GROUP BY a.id_aluno, u.nome, a.matricula
ORDER BY devolucoes_atrasadas DESC, media_dias_atraso DESC;

-- 9. Danos por categoria e tempo medio de reparo
SELECT c.nome AS categoria,
       COUNT(dn.id_dano) AS danos,
       SUM(dn.status_andamento = 'RESOLVIDO') AS resolvidos,
       SUM(dn.status_andamento <> 'RESOLVIDO') AS em_aberto,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, dn.data_hora, dn.resolvido_em)) / 24, 1) AS media_dias_reparo,
       SUM((SELECT COUNT(*) FROM foto_dano f WHERE f.id_dano = dn.id_dano)) AS fotos
FROM dano dn
JOIN equipamento e ON e.id_equipamento = dn.id_equipamento
JOIN categoria c ON c.id_categoria = e.id_categoria
GROUP BY c.nome
ORDER BY danos DESC;

-- 10. Equipamentos parados em manutencao hoje e ha quantos dias
SELECT e.nome AS equipamento,
       u.nome AS proprietario,
       dn.descricao,
       dn.status_andamento,
       dn.data_hora AS registrado_em,
       DATEDIFF('2026-10-28', DATE(dn.data_hora)) AS dias_parado,
       rel.nome AS relatado_por
FROM equipamento e
JOIN dano dn ON dn.id_equipamento = e.id_equipamento AND dn.status_andamento <> 'RESOLVIDO'
JOIN usuario u ON u.id_usuario = e.id_usuario_proprietario
JOIN usuario rel ON rel.id_usuario = dn.id_usuario_relator
ORDER BY dias_parado DESC;

-- 11. Taxa de ocupacao: dias reservados sobre dias ofertados ate hoje
WITH ofertado AS (
  SELECT d.id_equipamento,
         SUM(DATEDIFF(LEAST(d.data_fim, '2026-10-28'), d.data_inicio) + 1) AS dias_ofertados
  FROM disponibilizacao d
  WHERE d.data_inicio <= '2026-10-28'
  GROUP BY d.id_equipamento
), reservado AS (
  SELECT d.id_equipamento,
         SUM(DATEDIFF(LEAST(s.data_fim, '2026-10-28'), s.data_inicio)) AS dias_reservados
  FROM solicitacao s
  JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
  WHERE s.status = 'APROVADA' AND s.data_inicio <= '2026-10-28'
  GROUP BY d.id_equipamento
)
SELECT e.nome AS equipamento,
       o.dias_ofertados,
       COALESCE(rv.dias_reservados, 0) AS dias_reservados,
       ROUND(100 * COALESCE(rv.dias_reservados, 0) / o.dias_ofertados, 1) AS ocupacao_pct
FROM equipamento e
JOIN ofertado o ON o.id_equipamento = e.id_equipamento
LEFT JOIN reservado rv ON rv.id_equipamento = e.id_equipamento
ORDER BY ocupacao_pct DESC;

-- 12. Solicitacoes por mes e status
SELECT DATE_FORMAT(criada_em, '%Y-%m') AS mes,
       COUNT(*) AS total,
       SUM(status = 'APROVADA') AS aprovadas,
       SUM(status = 'RECUSADA') AS recusadas,
       SUM(status = 'CANCELADA') AS canceladas,
       SUM(status = 'EXPIRADA') AS expiradas,
       SUM(status = 'PENDENTE') AS pendentes
FROM solicitacao
GROUP BY mes
ORDER BY mes;

-- 13. Historico de precos dos equipamentos ofertados mais de uma vez
SELECT equipamento, versao, modalidade, valor_diaria, valor_anterior, data_inicio, data_fim,
       CASE WHEN valor_anterior IS NULL THEN NULL
            WHEN valor_anterior = 0 THEN NULL
            ELSE ROUND(100 * (valor_diaria - valor_anterior) / valor_anterior, 1) END AS variacao_pct
FROM (
  SELECT e.nome AS equipamento,
         ROW_NUMBER() OVER (PARTITION BY e.id_equipamento ORDER BY d.data_inicio) AS versao,
         d.modalidade, d.valor_diaria, d.data_inicio, d.data_fim,
         LAG(d.valor_diaria) OVER (PARTITION BY e.id_equipamento ORDER BY d.data_inicio) AS valor_anterior,
         COUNT(*) OVER (PARTITION BY e.id_equipamento) AS ofertas
  FROM disponibilizacao d
  JOIN equipamento e ON e.id_equipamento = d.id_equipamento
) t
WHERE ofertas > 1
ORDER BY equipamento, versao;

-- 14. Agenda: reservas vigentes e futuras
SELECT s.data_inicio, s.data_fim, e.nome AS equipamento, u.nome AS solicitante,
       r.status, dono.nome AS proprietario,
       CASE WHEN dono.perfil = 'ADM' THEN 'SIM' ELSE 'NAO' END AS institucional
FROM reserva r
JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
JOIN aluno a ON a.id_aluno = s.id_aluno
JOIN usuario u ON u.id_usuario = a.id_usuario
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
JOIN equipamento e ON e.id_equipamento = d.id_equipamento
JOIN usuario dono ON dono.id_usuario = e.id_usuario_proprietario
WHERE r.status IN ('CONFIRMADA', 'EM_USO', 'ATRASADA')
ORDER BY s.data_inicio;

-- 15. Alunos que mais usam o sistema como solicitantes
SELECT u.nome AS aluno,
       COUNT(s.id_solicitacao) AS solicitacoes,
       SUM(s.status = 'APROVADA') AS aprovadas,
       COALESCE(SUM(CASE WHEN p.status = 'SIMULADO' THEN p.valor_total END), 0) AS gasto_simulado,
       COUNT(DISTINCT d.id_equipamento) AS equipamentos_diferentes
FROM aluno a
JOIN usuario u ON u.id_usuario = a.id_usuario
JOIN solicitacao s ON s.id_aluno = a.id_aluno
JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
LEFT JOIN pagamento_simulado p ON p.id_solicitacao = s.id_solicitacao
GROUP BY a.id_aluno, u.nome
ORDER BY solicitacoes DESC
LIMIT 10;

-- 16. Uso do sistema por curso (aluno em dois cursos conta nos dois)
SELECT c.nome AS curso,
       COUNT(DISTINCT ac.id_aluno) AS alunos,
       COUNT(DISTINCT s.id_aluno) AS alunos_que_solicitaram,
       COUNT(s.id_solicitacao) AS solicitacoes,
       COUNT(r.id_reserva) AS reservas
FROM curso c
JOIN aluno_curso ac ON ac.id_curso = c.id_curso
LEFT JOIN solicitacao s ON s.id_aluno = ac.id_aluno
LEFT JOIN reserva r ON r.id_solicitacao = s.id_solicitacao
GROUP BY c.id_curso, c.nome
ORDER BY reservas DESC;

-- 17. Verificacao de identidade: tempo medio de analise e recusas por analista
SELECT u.nome AS analista,
       COUNT(*) AS documentos_analisados,
       SUM(di.status = 'APROVADO') AS aprovados,
       SUM(di.status = 'RECUSADO') AS recusados,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, di.enviado_em, di.analisado_em)) / 60, 1) AS media_horas_analise
FROM documento_identidade di
JOIN usuario u ON u.id_usuario = di.id_usuario_analista
GROUP BY u.id_usuario, u.nome
ORDER BY documentos_analisados DESC;

-- 18. Trilha de auditoria completa de uma reserva com dano
SELECT ro.data_hora, ro.tipo_operacao, ro.tabela_afetada, ro.id_afetado,
       COALESCE(u.nome, 'SISTEMA') AS usuario, ro.endereco_ip
FROM registro_operacao ro
LEFT JOIN usuario u ON u.id_usuario = ro.id_usuario
JOIN (SELECT r.id_reserva, s.id_solicitacao, rt.id_retirada, dv.id_devolucao, dn.id_dano, p.id_pagamento
      FROM dano dn
      JOIN reserva r ON r.id_reserva = dn.id_reserva
      JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
      JOIN retirada rt ON rt.id_reserva = r.id_reserva
      LEFT JOIN devolucao dv ON dv.id_retirada = rt.id_retirada
      LEFT JOIN pagamento_simulado p ON p.id_solicitacao = s.id_solicitacao
      ORDER BY dn.data_hora
      LIMIT 1) alvo
  ON (ro.tabela_afetada = 'solicitacao' AND ro.id_afetado = alvo.id_solicitacao)
  OR (ro.tabela_afetada = 'pagamento_simulado' AND ro.id_afetado = alvo.id_pagamento)
  OR (ro.tabela_afetada = 'retirada' AND ro.id_afetado = alvo.id_retirada)
  OR (ro.tabela_afetada = 'devolucao' AND ro.id_afetado = alvo.id_devolucao)
  OR (ro.tabela_afetada = 'dano' AND ro.id_afetado = alvo.id_dano)
ORDER BY ro.data_hora;

-- 19. Acessos por usuario: logins, falhas e ultimo acesso
SELECT u.nome, u.perfil, u.status_conta,
       SUM(ro.tipo_operacao = 'LOGIN') AS logins,
       (SELECT COUNT(*) FROM registro_operacao f
         WHERE f.tipo_operacao = 'LOGIN_FALHA' AND f.id_afetado = u.id_usuario) AS logins_com_falha,
       MAX(CASE WHEN ro.tipo_operacao = 'LOGIN' THEN ro.data_hora END) AS ultimo_login,
       COUNT(DISTINCT ro.endereco_ip) AS ips_diferentes
FROM usuario u
LEFT JOIN registro_operacao ro ON ro.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nome, u.perfil, u.status_conta
ORDER BY logins_com_falha DESC, logins DESC
LIMIT 15;

-- 20. Equipamentos institucionais x equipamentos de alunos
SELECT CASE WHEN u.perfil = 'ADM' THEN 'Institucional (UMC)' ELSE 'De alunos' END AS origem,
       COUNT(*) AS equipamentos,
       SUM(x.reservas) AS reservas,
       ROUND(SUM(x.dias_reservados) / NULLIF(SUM(x.reservas), 0), 1) AS media_dias_por_reserva,
       SUM(x.danos) AS danos,
       ROUND(100 * SUM(x.danos) / NULLIF(SUM(x.reservas), 0), 1) AS danos_por_100_reservas
FROM (
  SELECT e.id_equipamento, e.id_usuario_proprietario,
         (SELECT COUNT(*) FROM reserva r JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
            JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
           WHERE d.id_equipamento = e.id_equipamento) AS reservas,
         (SELECT COALESCE(SUM(DATEDIFF(s.data_fim, s.data_inicio)), 0) FROM reserva r JOIN solicitacao s ON s.id_solicitacao = r.id_solicitacao
            JOIN disponibilizacao d ON d.id_disponibilizacao = s.id_disponibilizacao
           WHERE d.id_equipamento = e.id_equipamento) AS dias_reservados,
         (SELECT COUNT(*) FROM dano dn WHERE dn.id_equipamento = e.id_equipamento) AS danos
  FROM equipamento e
) x
JOIN usuario u ON u.id_usuario = x.id_usuario_proprietario
GROUP BY origem;

-- 21. Notificacoes nao lidas por usuario e tipo
SELECT u.nome AS usuario,
       COUNT(*) AS nao_lidas,
       GROUP_CONCAT(DISTINCT n.tipo ORDER BY n.tipo SEPARATOR ', ') AS tipos,
       MIN(n.enviada_em) AS mais_antiga
FROM notificacao n
JOIN usuario u ON u.id_usuario = n.id_usuario
WHERE n.lida = FALSE
GROUP BY u.id_usuario, u.nome
ORDER BY nao_lidas DESC;

-- 22. Alunos ativos que nunca fizeram uma solicitacao
SELECT u.nome, u.email, a.matricula, u.status_conta, u.criado_em
FROM aluno a
JOIN usuario u ON u.id_usuario = a.id_usuario
WHERE a.situacao_vinculo = 'ATIVO'
  AND NOT EXISTS (SELECT 1 FROM solicitacao s WHERE s.id_aluno = a.id_aluno)
ORDER BY u.criado_em;
