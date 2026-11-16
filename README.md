# UniShare – Banco de Dados

Banco de dados do **UniShare**, um SaaS de compartilhamento e aluguel de equipamentos entre os alunos da
**Universidade de Mogi das Cruzes (UMC)**. Os alunos emprestam ou alugam notebooks, câmeras, projetores e
outros equipamentos entre si, e a própria universidade oferece os equipamentos institucionais.

Projeto da disciplina de **Banco de Dados** da UMC (2026), desenvolvido pelo **Grupo 4**.

## Integrantes – Grupo 4

| RGM | Nome |
|---|---|
| 11261104620 | Daniel Matsuo Rubino |
| 11261102520 | Igor Delfino Braga |
| 11261103184 | Mariana Rodrigues Fonseca |
| 11261102024 | Maristela Silva Siqueira |
| 11261103039 | Otávio Vinicius Flauzino de Souza |
| 11261102968 | Roberta da Silva Ribeiro |

## Tecnologias

- **MySQL 8.4**: SGBD do projeto
- **brModelo 3.2**: modelo conceitual (MER) e modelo lógico (MR)
- **DBeaver**: cliente usado para executar os scripts
- **Docker**: ambiente local de MySQL (opcional)

## Estrutura do repositório

```
unishare/
├── Entrega 1/                MER, MR, script de criação e script de povoamento (versão original)
│   ├── modelo_conceitual/    MER no brModelo (.brM3) e imagem (.png)
│   ├── modelo_logico/        MR no brModelo, imagem e MR em texto (.md)
│   └── scripts/              01_criacao_tabelas.sql e 02_populacao.sql
├── Entrega 2/                MER e MR corrigidos e script único com views e índices
│   ├── modelo_conceitual/
│   ├── modelo_logico/
│   └── scripts/              UniShare_script_completo.sql
├── Entrega 3/                Regra de negócio e procedures de CRUD com exclusão lógica
│   └── scripts/              UniShare_entrega3_regras_procedures.sql e roteiro de testes
├── consultas/                Consultas de negócio e checagens de consistência dos dados
├── ferramentas/              Geradores dos diagramas (brModelo) e do povoamento
├── docker-compose.yml        MySQL 8.4 local para testes
└── LICENSE                   Licença MIT
```

## Entregas

### Entrega 1 – Modelagem e scripts iniciais
- **MER** com 20 entidades e 27 relacionamentos, com cardinalidade mínima e máxima.
- **MR** com 22 tabelas, chaves primárias e estrangeiras.
- **Script de criação**: banco, tabelas e constraints PK, FK, UNIQUE e CHECK.
- **Script de povoamento** com dados fictícios e consistentes do semestre da UMC.

### Entrega 2 – Correções, views e índices
- **Correções:**
  - o aceite dos termos de uso passou a ser ligado ao **usuário**, e não ao aluno;
  - o MR em texto deixou de usar `?` nas colunas opcionais.
- **Um único script** com:
  - criação do banco e das tabelas;
  - povoamento com as **chaves estrangeiras preenchidas por `SELECT`**;
  - **8 views** de relatório gerencial;
  - **1 índice** para otimizar cada view, com o uso confirmado por `EXPLAIN`.

| View | Relatório |
|---|---|
| `vw_desempenho_equipamentos` | Reservas, dias reservados e receita por equipamento |
| `vw_tempo_devolucao_categoria` | Tempo médio com o aluno e percentual de atraso por categoria |
| `vw_receita_proprietarios` | Receita simulada e ticket médio por proprietário |
| `vw_solicitacoes_mensais` | Solicitações por mês, status, taxa de aprovação e tempo de resposta |
| `vw_reputacao_alunos` | Reputação dos alunos a partir das avaliações recebidas |
| `vw_danos_em_aberto` | Danos não resolvidos e dias de equipamento parado |
| `vw_inventario_categoria` | Inventário de equipamentos por categoria e situação |
| `vw_auditoria_usuarios` | Logins, falhas, operações e IPs por usuário |

### Entrega 3 – Regra de negócio e procedures
- **Regra de negócio RN24/RN25**: aprovação de solicitação sem conflito de reservas. A implementação combina:
  - **triggers**, que impedem duas reservas aprovadas com períodos sobrepostos para o mesmo equipamento;
  - **procedure com transação** `sp_aprovar_solicitacao`. Ela bloqueia os registros, aprova a solicitação e cria a reserva. Também recusa automaticamente as solicitações pendentes conflitantes, cancela os pagamentos delas, notifica os alunos e registra a auditoria. Em caso de erro, faz `ROLLBACK`.
- **Procedures de inserção, atualização e exclusão lógica** (`sp_<tabela>_inserir`, `_atualizar` e `_excluir`) para as 18 tabelas que não são de parâmetro.
  - A exclusão lógica usa as colunas `ativo` e `excluido_em`.
  - As tabelas de parâmetro (`instituicao`, `curso`, `categoria` e `termo_uso`) não têm procedures.
- **Roteiro de testes** com os casos válidos e os casos que o banco deve barrar.

## Modelo de dados

![MER do UniShare](Entrega%202/modelo_conceitual/MER_UniShare.png)

O MR completo, em imagem e em texto, está em [`Entrega 2/modelo_logico`](Entrega%202/modelo_logico).

## Como executar

1. Suba um MySQL 8.4. Com Docker, rode na raiz do repositório:
   ```bash
   docker compose up -d
   ```
   O banco fica em `localhost:3307`, usuário `root` e senha `Root@UniShare2026`.
2. No DBeaver, crie uma conexão MySQL com esses dados. Em **Driver properties**, defina
   `allowPublicKeyRetrieval=true` e `useSSL=false`.
3. Abra `Entrega 2/scripts/UniShare_script_completo.sql` e execute como **script** (**Alt+X**), não como
   comando único (Ctrl+Enter).
4. Em seguida, execute `Entrega 3/scripts/UniShare_entrega3_regras_procedures.sql`.
5. Opcionalmente, rode `Entrega 3/scripts/testes_entrega3.sql` e as consultas da pasta `consultas/`.

> Os scripts de criação começam com `CREATE DATABASE unishare`. Para recriar o banco do zero, execute antes
> `DROP DATABASE unishare;`.

## Licença

Distribuído sob a licença MIT. Veja [LICENSE](LICENSE).
