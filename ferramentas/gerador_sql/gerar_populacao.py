"""Gera banco_de_dados/sql/02_populacao.sql simulando o semestre da UMC dia a dia.

A simulacao aplica as regras de negocio (RN01-RN40) e registra cada acao no log de
auditoria (registro_operacao) com o mesmo horario, usuario e registro afetado.
Uso: python gerar_populacao.py <saida.sql>
"""
import datetime as dt
import random
import sys
import unicodedata

R = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 22)
NOW = dt.datetime(2026, 10, 28, 8, 0)
SEM_INI = dt.date(2026, 8, 1)
T11 = dt.datetime(2026, 10, 1, 0, 0)          # publicacao do termo 1.1
CAMPUS = (-23.519600, -46.188300)
SERVIDOR_IP = "10.20.0.5"
D = dt.timedelta


def mins(a, b):
    return D(minutes=R.randint(a, b))


def at(day, h1, h2):
    return dt.datetime(day.year, day.month, day.day) + D(minutes=R.randint(h1 * 60, h2 * 60))


def humano(t):
    """Acoes de pessoas acontecem entre 7h e 23h."""
    if t.hour < 7:
        return t.replace(hour=7 + R.randint(0, 2), minute=R.randint(0, 59))
    if t.hour >= 23:
        return t.replace(hour=22, minute=R.randint(0, 59))
    return t


def slug(nome):
    s = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode().lower().split()
    return s[0] + "." + s[-1]


def cpf_valido(base9):
    d = [int(x) for x in base9]
    for n in (10, 11):
        s = sum(v * (n - i) for i, v in enumerate(d))
        r = (s * 10) % 11
        d.append(0 if r == 10 else r)
    return "".join(map(str, d))


def cnpj_valido(base12):
    d = [int(x) for x in base12]
    for pesos in ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]):
        s = sum(v * p for v, p in zip(d, pesos))
        r = s % 11
        d.append(0 if r < 2 else 11 - r)
    return "".join(map(str, d))


def hash_fake(i):
    chars = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    rr = random.Random(1000 + i)
    return "$2b$12$" + "".join(rr.choice(chars) for _ in range(53))


class Obj:
    def __init__(self, **kw):
        self.__dict__.update(kw)
        self.id = None


# ----------------------------------------------------------------------------
# Instituicao, cursos, categorias, termos
# ----------------------------------------------------------------------------
inst = Obj(nome="Universidade de Mogi das Cruzes", sigla="UMC", cnpj=cnpj_valido("524186370001"))
inst.id = 1
CURSOS = ["Engenharia de Software", "Ciência da Computação", "Sistemas de Informação",
          "Análise e Desenvolvimento de Sistemas", "Design Gráfico", "Arquitetura e Urbanismo",
          "Administração", "Engenharia Civil"]
CATEGORIAS = ["Notebook", "Câmera fotográfica", "Projetor", "Tablet", "Equipamento de áudio",
              "Calculadora", "Kit eletrônico", "Acessórios de foto e vídeo", "Drone", "Mesa digitalizadora"]
TERMOS = [
    Obj(versao="1.0", publicado=dt.datetime(2026, 7, 15, 0, 0),
        conteudo="Termo de Uso e Responsabilidade do UniShare, versão 1.0. O usuário se responsabiliza pela "
                 "guarda, pelo uso adequado e pela devolução dos equipamentos no prazo e nas condições recebidas."),
    Obj(versao="1.1", publicado=T11,
        conteudo="Termo de Uso e Responsabilidade do UniShare, versão 1.1. Inclui o registro de IP e de "
                 "geolocalização das operações para fins de rastreabilidade, conforme a LGPD."),
]
for i, t in enumerate(TERMOS, 1):
    t.id = i

# ----------------------------------------------------------------------------
# Usuarios: administradores e alunos
# ----------------------------------------------------------------------------
ADMS = ["Pablo Chagas", "Carla Mendes", "Ricardo Alves", "Juliana Prado"]
ALUNOS = ["Ana Beatriz Souza", "Bruno Henrique Lima", "Camila Ferreira", "Diego Martins", "Eduarda Rocha",
          "Felipe Santos", "Gabriela Nunes", "Henrique Oliveira", "Isabela Carvalho", "João Pedro Ribeiro",
          "Larissa Gomes", "Lucas Almeida", "Mariana Costa", "Matheus Pereira", "Natália Barbosa",
          "Otávio Freitas", "Paula Vieira", "Rafael Moreira", "Renata Cardoso", "Rodrigo Teixeira",
          "Sabrina Lopes", "Thiago Monteiro", "Vanessa Araújo", "Vinícius Batista", "Yasmin Correia",
          "André Fonseca", "Beatriz Duarte", "Caio Ramos", "Daniela Pinto", "Eduardo Macedo",
          "Fernanda Castro", "Gustavo Rezende", "Helena Moura", "Igor Tavares", "Jéssica Campos",
          "Leonardo Farias"]

usuarios, alunos, biometrias, documentos, aceites, logs, notifs = [], [], [], [], [], [], []
home = {}


def novo_usuario(nome, perfil, criado):
    u = Obj(nome=nome, perfil=perfil, criado=criado, status="ATIVA", bloqueado_em=None, aceite10=None, aluno=None)
    n = len(usuarios) + 1
    u.id = n
    u.cpf = cpf_valido("%09d" % (R.randint(100000000, 999999999)))
    u.email = slug(nome) + ("@admin.umc.br" if perfil == "ADM" else "@aluno.umc.br")
    u.telefone = ("1147987%03d" % (100 + n)) if perfil == "ADM" else ("119%08d" % R.randint(10000000, 99999999))
    if perfil == "ALUNO" and n % 9 == 0:
        u.telefone = None
    u.hash = hash_fake(n)
    rede = "203.0.113." if n % 2 else "198.51.100."
    home[n] = (rede + str(10 + n * 3), round(CAMPUS[0] + R.uniform(-0.06, 0.06), 6),
               round(CAMPUS[1] + R.uniform(-0.06, 0.06), 6))
    usuarios.append(u)
    return u


def log(tipo, tabela, alvo, user, quando, onde="casa"):
    logs.append(Obj(tipo=tipo, tabela=tabela, alvo=alvo, user=user, quando=quando, onde=onde))


def notificar(tipo, user, msg, quando, solic=None):
    notifs.append(Obj(tipo=tipo, user=user, msg=msg, quando=quando, solic=solic))


def biometria(user, quando, modelo="arcface_r50_v1", key=1):
    b = Obj(user=user, quando=quando, modelo=modelo, key=key)
    biometrias.append(b)
    log("CADASTRO_BIOMETRIA", "biometria_facial", b, user, quando)
    return b


adms = []
for i, nome in enumerate(ADMS):
    u = novo_usuario(nome, "ADM", dt.datetime(2026, 7, 20, 9, 0) + D(minutes=25 * i))
    adms.append(u)
    log("CADASTRO_CONTA", "usuario", u, u, u.criado, "campus")
    biometria(u, u.criado + D(minutes=8))
    u.aceite10 = u.criado + D(minutes=12)
    ac = Obj(user=u, termo=TERMOS[0], quando=u.aceite10)
    aceites.append(ac)
    log("ACEITE_TERMO", "aceite_termo", ac, u, ac.quando, "campus")
pablo, carla, ricardo, juliana = adms

# papeis especiais por indice de aluno
PENDENTES = {34, 35}          # documento ainda pendente (contas criadas em outubro)
RECUSADO_ATUAL = {33}         # documento recusado aguardando reenvio
RECUSA_REENVIO = {7, 21}      # primeiro documento recusado e segundo aprovado
TRANCADOS = {18, 29}          # vinculo trancado em 30/09
BLOQUEADO = 26                # conta bloqueada por tentativas de login
ESTRANGEIRO = 30              # usa RNE
MOTIVOS_RECUSA = ["Imagem ilegível: não é possível conferir os dados do documento.",
                  "Documento vencido. Envie um documento dentro da validade.",
                  "Os dados do documento não conferem com o cadastro do aluno."]

for i, nome in enumerate(ALUNOS):
    if i in PENDENTES:
        criado = at(dt.date(2026, 10, 24 if i == 34 else 26), 9, 21)
    elif i in RECUSADO_ATUAL:
        criado = at(dt.date(2026, 10, 19), 9, 21)
    elif i >= 31:
        criado = at(dt.date(2026, 9, R.randint(2, 20)), 9, 21)
    else:
        criado = at(SEM_INI + D(days=R.randint(0, 24)), 8, 22)
    u = novo_usuario(nome, "ALUNO", criado)
    a = Obj(user=u, idx=i, matricula="1124%07d" % (1000 + i * 37), situacao="ATIVO", cursos=[],
            aprovado_em=None, aceite10=None, ativo_ate=dt.datetime(2099, 1, 1), bloqueios=[])
    a.id = i + 1
    alunos.append(a)
    u.aluno = a
    log("CADASTRO_CONTA", "usuario", u, u, criado)
    biometria(u, criado + mins(4, 12))
    a.cursos = [1 + (i * 5) % len(CURSOS)]
    if i % 6 == 1:
        a.cursos.append(1 + (i * 5 + 3) % len(CURSOS))
    # documentos de identidade
    tipo = "RNE" if i == ESTRANGEIRO else ("CNH" if i % 3 == 0 else "RG")
    numero = ("V%07d" % R.randint(1000000, 9999999)) if tipo == "RNE" else (
        "%011d" % R.randint(10 ** 10, 10 ** 11 - 1) if tipo == "CNH" else "%09d" % R.randint(10 ** 8, 10 ** 9 - 1))
    envio = criado + mins(15, 70)
    analista = [juliana, juliana, carla, ricardo][i % 4]
    if i in PENDENTES:
        u.status = "PENDENTE"
        d0 = Obj(aluno=a, tipo=tipo, numero=numero, status="PENDENTE", motivo=None, envio=envio, analise=None, analista=None)
        documentos.append(d0)
        log("ENVIO_DOCUMENTO", "documento_identidade", d0, u, envio)
        continue
    analise = at((envio + D(days=1)).date(), 9, 17)
    if i in RECUSADO_ATUAL or i in RECUSA_REENVIO:
        d0 = Obj(aluno=a, tipo=tipo, numero=numero, status="RECUSADO", motivo=MOTIVOS_RECUSA[i % 3],
                 envio=envio, analise=analise, analista=analista)
        documentos.append(d0)
        log("ENVIO_DOCUMENTO", "documento_identidade", d0, u, envio)
        log("ANALISE_DOCUMENTO", "documento_identidade", d0, analista, analise, "campus")
        notificar("IDENTIDADE", u, "Documento recusado: " + d0.motivo, analise)
        if i in RECUSADO_ATUAL:
            u.status = "PENDENTE"
            continue
        envio = humano(analise + D(hours=R.randint(3, 20)))
        analise = at((envio + D(days=1)).date(), 9, 17)
    d1 = Obj(aluno=a, tipo=tipo, numero=numero, status="APROVADO", motivo=None, envio=envio, analise=analise,
             analista=analista)
    documentos.append(d1)
    log("ENVIO_DOCUMENTO", "documento_identidade", d1, u, envio)
    log("ANALISE_DOCUMENTO", "documento_identidade", d1, analista, analise, "campus")
    notificar("IDENTIDADE", u, "Sua identidade foi verificada. Aceite o termo de uso para começar a usar o UniShare.", analise)
    a.aprovado_em = analise
    a.aceite10 = humano(analise + mins(40, 600))
    u.aceite10 = a.aceite10
    ac = Obj(user=u, termo=TERMOS[0], quando=a.aceite10)
    aceites.append(ac)
    log("ACEITE_TERMO", "aceite_termo", ac, u, ac.quando)
    if i in TRANCADOS:
        a.ativo_ate = dt.datetime(2026, 9, 10)
    if i == BLOQUEADO:
        a.ativo_ate = dt.datetime(2026, 10, 12)

# reenvolvimento biometrico com o modelo novo (lado n da cardinalidade)
for u in [usuarios[0], usuarios[5], usuarios[9], usuarios[14], usuarios[28], usuarios[27]]:
    biometria(u, at(dt.date(2026, 10, R.randint(3, 15)), 9, 20), "arcface_r100_v2", 2)

# ----------------------------------------------------------------------------
# Equipamentos e disponibilizacoes
# ----------------------------------------------------------------------------
EQUIP_UMC = [
    ("Projetor Epson PowerLite X49", "Projetor institucional de 3.600 lumens com cabo HDMI e controle remoto.", 3, "BOM", 3, pablo),
    ("Projetor portátil LG CineBeam", "Projetor institucional portátil, ideal para apresentações em sala.", 3, "OTIMO", 3, pablo),
    ("Notebook Lenovo ThinkPad E14", "Notebook do laboratório de informática, Core i7, 16 GB RAM, SSD 512 GB.", 1, "OTIMO", 7, carla),
    ("Notebook Dell Latitude 3420", "Notebook do laboratório de informática, Core i5, 8 GB RAM, SSD 256 GB.", 1, "BOM", 7, carla),
    ("Câmera Nikon D3500", "Câmera institucional do curso de Design, lente 18-55 mm e bolsa.", 2, "BOM", 5, ricardo),
    ("Kit Arduino Uno Avançado", "Kit com Arduino Uno, protoboard, sensores e jumpers.", 7, "BOM", 10, ricardo),
    ("Tripé Manfrotto com iluminação LED", "Tripé profissional com dois painéis de LED do estúdio da UMC.", 8, "OTIMO", 5, pablo),
    ("Tablet Samsung Galaxy Tab S6 Lite", "Tablet institucional com caneta S Pen e capa.", 4, "BOM", 5, carla),
]
EQUIP_ALUNO = [
    ("Notebook Dell Inspiron 15", "Core i5, 16 GB RAM, SSD 512 GB, com carregador.", 1, "BOM", 25.0),
    ("MacBook Air M1", "8 GB RAM, SSD 256 GB, com carregador original.", 1, "OTIMO", 45.0),
    ("Notebook Acer Aspire 5", "Core i5, 8 GB RAM, ideal para trabalhos e pesquisas.", 1, "REGULAR", 0.0),
    ("Câmera Canon EOS Rebel T7", "Lente 18-55 mm, duas baterias e cartão SD de 64 GB.", 2, "OTIMO", 40.0),
    ("Câmera GoPro Hero 10", "Câmera de ação com suporte de capacete e bastão.", 2, "BOM", 30.0),
    ("Câmera Sony ZV-E10", "Câmera mirrorless para vídeo, lente 16-50 mm.", 2, "NOVO", 50.0),
    ("iPad 9ª geração", "iPad 64 GB com capa protetora.", 4, "BOM", 0.0),
    ("Tablet Lenovo Tab M10", "Tablet 10 polegadas, 64 GB.", 4, "BOM", 15.0),
    ("Microfone Rode NT-USB", "Microfone condensador USB com tripé de mesa.", 5, "NOVO", 15.0),
    ("Fone Sony WH-1000XM4", "Fone com cancelamento de ruído e estojo.", 5, "OTIMO", 12.0),
    ("Caixa de som JBL Flip 5", "Caixa de som bluetooth à prova d'água.", 5, "BOM", 0.0),
    ("Interface de áudio Behringer UMC22", "Interface USB com entrada XLR para gravação.", 5, "BOM", 10.0),
    ("Drone DJI Mini 2", "Drone com câmera 4K, três baterias e maleta.", 9, "OTIMO", 60.0),
    ("Calculadora HP 50g", "Calculadora gráfica com manual e cabo USB.", 6, "BOM", 0.0),
    ("Calculadora Casio fx-991ES Plus", "Calculadora científica permitida nas provas.", 6, "BOM", 0.0),
    ("Kit Raspberry Pi 4", "Raspberry Pi 4 com 4 GB, fonte, case e cartão de 32 GB.", 7, "OTIMO", 18.0),
    ("Ring light 18 polegadas", "Ring light com tripé e suporte para celular.", 8, "BOM", 8.0),
    ("Tripé Velbon EX-440", "Tripé para câmera com cabeça de três eixos.", 8, "REGULAR", 0.0),
    ("Projetor Samsung Freestyle", "Projetor portátil com ajuste automático de foco.", 3, "OTIMO", 35.0),
    ("Mesa digitalizadora Wacom One", "Mesa digitalizadora com caneta e cabo USB.", 10, "BOM", 20.0),
    ("Notebook Samsung Book", "Core i3, 8 GB RAM, SSD 256 GB.", 1, "REGULAR", 22.0),
    ("Lente Canon EF 50mm f/1.8", "Lente prime para câmeras Canon com encaixe EF.", 8, "OTIMO", 20.0),
]
DONOS_IDX = [0, 1, 2, 3, 4, 5, 8, 9, 11, 12, 15, 16, 19, 23]
equipamentos, disps = [], []


def cadastra_equip(nome, desc, cat, estado, dono, criado):
    e = Obj(nome=nome, desc=desc, cat=cat, estado=estado, dono=dono, criado=criado, disps=[],
            ocupado_ate=None, manut=[], reservas=[])
    equipamentos.append(e)
    log("CADASTRO_EQUIPAMENTO", "equipamento", e, dono, criado, "campus" if dono.perfil == "ADM" else "casa")
    return e


def disponibiliza(e, modalidade, valor, ini, fim, prazo, criado):
    p = Obj(eq=e, modalidade=modalidade, valor=valor, ini=ini, fim=fim, prazo=prazo, criado=criado)
    disps.append(p)
    e.disps.append(p)
    log("DISPONIBILIZACAO", "disponibilizacao", p, e.dono, criado, "campus" if e.dono.perfil == "ADM" else "casa")
    return p


for k, (nome, desc, cat, estado, prazo, dono) in enumerate(EQUIP_UMC):
    criado = at(dt.date(2026, 8, 3) + D(days=k * 2), 9, 17)
    e = cadastra_equip(nome, desc, cat, estado, dono, criado)
    e.institucional = True
    if k in (0, 3):     # prazo alterado no meio do semestre: nova versao
        troca = dt.date(2026, 9, 21 + k)
        disponibiliza(e, "EMPRESTIMO", 0.0, dt.date(2026, 8, 10), troca - D(days=1), prazo, criado + mins(5, 20))
        disponibiliza(e, "EMPRESTIMO", 0.0, troca, dt.date(2026, 12, 15), prazo + 2, at(troca - D(days=1), 10, 16))
    else:
        disponibiliza(e, "EMPRESTIMO", 0.0, dt.date(2026, 8, 10), dt.date(2026, 12, 15), prazo, criado + mins(5, 20))

for k, (nome, desc, cat, estado, valor) in enumerate(EQUIP_ALUNO):
    dono_al = alunos[DONOS_IDX[k % len(DONOS_IDX)]]
    base = max(dono_al.aceite10 + D(hours=2), dt.datetime(2026, 8, 6))
    criado = humano(base + D(days=R.randint(0, 25), minutes=R.randint(0, 600)))
    if criado <= dono_al.aceite10:
        criado = dono_al.aceite10 + mins(30, 90)
    if criado.hour >= 22:
        criado = criado.replace(hour=21)
    e = cadastra_equip(nome, desc, cat, estado, dono_al.user, criado)
    e.institucional = False
    e.dono_aluno = dono_al
    modo = "ALUGUEL" if valor > 0 else "EMPRESTIMO"
    ini = criado.date() + D(days=1)
    padrao = ["preco", "reoferta", "simples", "simples", "encerrada", "preco", "simples", "reoferta"][k % 8]
    if padrao == "preco" and modo == "ALUGUEL":
        troca = dt.date(2026, 9, 25) + D(days=R.randint(0, 12))
        novo = round(valor * R.choice([0.8, 0.9, 1.2]), 0)
        disponibiliza(e, modo, valor, ini, troca - D(days=1), None, criado + mins(3, 15))
        disponibiliza(e, modo, novo, troca, dt.date(2026, 12, 18), None, at(troca - D(days=1), 18, 22))
    elif padrao == "reoferta":
        fim1 = ini + D(days=R.randint(28, 38))
        volta = fim1 + D(days=R.randint(8, 16))
        disponibiliza(e, modo, valor, ini, fim1, None, criado + mins(3, 15))
        modo2, valor2 = (("ALUGUEL", 10.0) if modo == "EMPRESTIMO" else (modo, valor))
        disponibiliza(e, modo2, valor2, volta, dt.date(2026, 12, 12), None, at(volta - D(days=1), 18, 22))
    elif padrao == "encerrada":
        disponibiliza(e, modo, valor, ini, dt.date(2026, 10, 16), None, criado + mins(3, 15))
    else:
        disponibiliza(e, modo, valor, ini, dt.date(2026, 12, 20), None, criado + mins(3, 15))

# ----------------------------------------------------------------------------
# Simulacao das solicitacoes, reservas, retiradas, devolucoes, danos
# ----------------------------------------------------------------------------
solics, pagamentos, reservas, retiradas, devolucoes, danos, fotos, avaliacoes = [], [], [], [], [], [], [], []
JUST_RECUSA = ["O equipamento será usado pelo proprietário no período solicitado.",
               "Período muito longo para o uso descrito. Solicite menos dias.",
               "Equipamento reservado para atividade do curso nesse período.",
               "Não poderei fazer a entrega nesse dia."]
DANOS_TXT = [
    ("Tela com risco profundo no canto inferior direito.", "Película protetora"),
    ("Dobradiça esquerda solta, a tampa não fica firme.", None),
    ("Lente com arranhão visível na parte frontal.", "Tampa da lente"),
    ("Carregador não liga, cabo rompido próximo ao conector.", None),
    ("Botão de liga e desliga afundado, aciona com dificuldade.", None),
    ("Carcaça trincada após queda, funcionando parcialmente.", "Capa protetora"),
]
DANO_ALS_TXT = ["Bateria descarregando em menos de uma hora de uso.",
                "Entrada USB com mau contato durante o uso."]
EST_PIOR = {"NOVO": "OTIMO", "OTIMO": "BOM", "BOM": "REGULAR", "REGULAR": "RUIM", "RUIM": "RUIM"}
COMENT_BOM_ALS = ["Equipamento em ótimo estado e entrega pontual.", "Proprietário muito atencioso, recomendo.",
                  "Tudo certo, funcionou perfeitamente no trabalho da disciplina.", None]
COMENT_BOM_DONO = ["Devolveu no prazo e em ótimo estado.", "Muito cuidadoso com o equipamento.", None,
                   "Comunicação fácil, recomendo."]
COMENT_RUIM_DONO = ["O equipamento voltou danificado e o aluno não avisou antes.",
                    "Devolução atrasada e sem resposta às mensagens.",
                    "Equipamento devolvido com avaria, precisei mandar para conserto."]
COMENT_RUIM_ALS = ["O equipamento apresentou defeito durante o uso.",
                   "Retirada atrasou e o equipamento veio sem um acessório."]


def dias(s):
    return (s.fim - s.ini).days


def elegivel(a, t, eq):
    if a.aprovado_em is None or a.aceite10 is None or a.aceite10 > t or a.ativo_ate < t:
        return False
    if eq.dono is a.user:
        return False
    for (b0, b1) in a.bloqueios:          # RN27: atraso ou dano pendente
        if b0 <= t < b1:
            return False
    return True


def em_manutencao(eq, t):
    return any(m0 <= t < m1 for (m0, m1) in eq.manut)


def disp_vigente(eq, dia):
    for p in eq.disps:
        if p.ini <= dia <= p.fim:
            return p
    return None


def resposta_dono(eq):
    return eq.dono


def nova_solic(a, p, ini, fim, criada):
    s = Obj(aluno=a, disp=p, ini=ini, fim=fim, criada=criada, status="PENDENTE", just=None, resp=None)
    solics.append(s)
    log("SOLICITACAO", "solicitacao", s, a.user, criada)
    if p.modalidade == "ALUGUEL":
        pg = Obj(s=s, valor=round(p.valor * (fim - ini).days, 2), status="SIMULADO", quando=criada + mins(1, 3))
        pagamentos.append(pg)
        s.pag = pg
        log("PAGAMENTO_SIMULADO", "pagamento_simulado", pg, a.user, pg.quando)
        aviso = pg.quando + D(minutes=1)
    else:
        s.pag = None
        aviso = criada + D(minutes=1)
    notificar("SOLICITACAO_RECEBIDA", p.eq.dono, "Nova solicitação para \"%s\" de %s a %s." %
              (p.eq.nome, ini.strftime("%d/%m"), fim.strftime("%d/%m")), aviso, s)
    return s


def recusar(s, quando, just, automatica=False):
    s.status, s.resp, s.just = "RECUSADA", quando, just
    if s.pag:
        s.pag.status = "CANCELADO"
    if automatica:
        log("RECUSA_AUTOMATICA", "solicitacao", s, None, quando, "sistema")
    else:
        log("RECUSA", "solicitacao", s, s.disp.eq.dono, quando)
    notificar("SOLICITACAO_RECUSADA", s.aluno.user, "Sua solicitação de \"%s\" foi recusada. %s" %
              (s.disp.eq.nome, just), quando + D(minutes=1), s)


def ciclo_reserva(s, eq):
    """Retirada, devolucao, atraso e dano de uma solicitacao aprovada."""
    r = Obj(s=s, criada=s.resp, status="CONFIRMADA", ret=None, dev=None)
    reservas.append(r)
    eq.reservas.append(r)
    dono, a = eq.dono, s.aluno
    lugar = "campus"
    ret_t = at(s.ini, 8, 11)
    if ret_t > NOW:
        eq.ocupado_ate = dt.datetime.combine(s.fim, dt.time(23, 59))
        return r
    bio = max((b for b in biometrias if b.user is a.user and b.quando <= ret_t), key=lambda b: b.quando)
    ret = Obj(r=r, quando=ret_t, estado=eq.estado, obs=R.choice([None, None, None, "Acessórios conferidos na entrega.",
                                                                    "Aluno conferiu o funcionamento na hora."]), bio=bio)
    retiradas.append(ret)
    r.ret = ret
    log("RETIRADA", "retirada", ret, dono, ret_t, lugar)
    # dano relatado pelo proprio aluno durante o uso
    dano_als = (not eq.institucional) and R.random() < 0.06 and (s.fim - s.ini).days >= 2
    if dano_als:
        t_d = at(s.ini + D(days=1), 10, 21)
        if t_d < NOW:
            dn = Obj(eq=eq, desc=R.choice(DANO_ALS_TXT), quando=t_d, relator=a.user, r=r, faltante=None,
                     status="ABERTO", resolvido=None)
            danos.append(dn)
            log("REGISTRO_DANO", "dano", dn, a.user, t_d)
            notificar("DANO", dono, "O aluno relatou um problema em \"%s\": %s" % (eq.nome, dn.desc), t_d + D(minutes=1), s)
        else:
            dano_als = False
    if R.random() < 0.10:
        dev_t = at(s.fim + D(days=R.randint(1, 3)), 9, 19)      # atraso
    else:
        dev_t = at(s.fim, 14, 19)
    lembrete = at(s.fim - D(days=1), 9, 9)
    if ret_t < lembrete <= NOW:
        notificar("LEMBRETE_DEVOLUCAO", a.user, "Lembrete: devolva \"%s\" até %s." % (eq.nome, s.fim.strftime("%d/%m")), lembrete, s)
    fim_prazo = dt.datetime.combine(s.fim + D(days=1), dt.time(0, 0))
    if dev_t > fim_prazo:
        aviso = fim_prazo + D(hours=9)
        if aviso <= NOW:
            notificar("ATRASO", a.user, "A devolução de \"%s\" está em atraso desde %s." % (eq.nome, s.fim.strftime("%d/%m")), aviso, s)
            notificar("ATRASO", dono, "O aluno %s está com \"%s\" em atraso." % (a.user.nome, eq.nome), aviso, s)
        a.bloqueios.append((fim_prazo, min(dev_t, dt.datetime(2099, 1, 1)) if dev_t <= NOW else dt.datetime(2099, 1, 1)))
    if dev_t > NOW:
        r.status = "ATRASADA" if s.fim < NOW.date() else "EM_USO"
        eq.ocupado_ate = dt.datetime(2099, 1, 1)
        return r
    # devolucao
    tem_dano = dano_als or ((R.random() < 0.13) and len(danos) < 9)
    estado_dev = EST_PIOR[eq.estado] if tem_dano else eq.estado
    txt, falt = R.choice(DANOS_TXT)
    dev = Obj(ret=ret, quando=dev_t, estado=estado_dev, faltante=(falt if tem_dano and not dano_als and R.random() < 0.5 else None),
              obs=("Devolvido com atraso." if dev_t > fim_prazo else None))
    devolucoes.append(dev)
    r.dev, r.status = dev, "CONCLUIDA"
    log("DEVOLUCAO", "devolucao", dev, dono, dev_t, lugar)
    eq.ocupado_ate = dev_t
    if tem_dano:
        if dano_als:
            dn = [x for x in danos if x.r is r][0]
            dev.obs = "Problema relatado pelo aluno durante o uso confirmado na devolução."
        else:
            dn = Obj(eq=eq, desc=txt, quando=dev_t + mins(5, 25), relator=dono, r=r, faltante=dev.faltante)
            danos.append(dn)
            log("REGISTRO_DANO", "dano", dn, dono, dn.quando, lugar)
            notificar("DANO", a.user, "Foi registrado um dano em \"%s\" na devolução: %s" % (eq.nome, dn.desc), dn.quando + D(minutes=1), s)
        conserto = at((dn.quando + D(days=R.randint(4, 12))).date(), 9, 18)
        if conserto <= NOW and R.random() < 0.75:
            dn.status, dn.resolvido = "RESOLVIDO", conserto
            log("RESOLUCAO_DANO", "dano", dn, dono, conserto, lugar)
            eq.manut.append((dn.quando, conserto))
            eq.estado = EST_PIOR[eq.estado] if eq.estado in ("NOVO", "OTIMO") else eq.estado
        else:
            dn.status = "EM_REPARO" if (NOW - dn.quando).days >= 2 else "ABERTO"
            dn.resolvido = None
            eq.manut.append((dn.quando, dt.datetime(2099, 1, 1)))
            eq.estado = EST_PIOR[eq.estado]
        a.bloqueios.append((dn.quando, dn.resolvido or dt.datetime(2099, 1, 1)))
        for n in range(R.randint(1, 3)):
            fotos.append(Obj(dano=dn, n=n, fmt=R.choice(["JPG", "JPG", "PNG"]), tam=R.randint(350000, 4800000),
                             quando=dn.quando + D(minutes=1 + n)))
    # avaliacoes (apenas entre alunos)
    if not eq.institucional:
        problema = tem_dano or dev_t > fim_prazo
        if R.random() < 0.85:
            t_av = humano(dev_t + D(hours=R.randint(2, 40)))
            if t_av <= NOW:
                nota = R.choice([3, 4]) if dano_als else (R.choice([4, 5, 5]) if not problema else R.choice([4, 5]))
                com = R.choice(COMENT_RUIM_ALS) if dano_als else R.choice(COMENT_BOM_ALS)
                av = Obj(r=r, avaliador=a, nota=nota, com=com, quando=t_av)
                avaliacoes.append(av)
                log("AVALIACAO", "avaliacao", av, a.user, t_av)
        if R.random() < 0.8:
            t_av = humano(dev_t + D(hours=R.randint(1, 30)))
            if t_av <= NOW:
                nota = R.choice([1, 2, 2, 3]) if (problema and not dano_als) else R.choice([4, 5, 5])
                com = R.choice(COMENT_RUIM_DONO) if (problema and not dano_als) else R.choice(COMENT_BOM_DONO)
                av = Obj(r=r, avaliador=eq.dono_aluno, nota=nota, com=com, quando=t_av)
                avaliacoes.append(av)
                log("AVALIACAO", "avaliacao", av, eq.dono, t_av)
    return r


dia = dt.date(2026, 8, 10)
while dia <= NOW.date():
    ordem = equipamentos[:]
    R.shuffle(ordem)
    for eq in ordem:
        criada = at(dia, 8, 22)
        if criada > NOW or R.random() > 0.11:
            continue
        if eq.ocupado_ate and criada < eq.ocupado_ate:
            continue
        if em_manutencao(eq, criada):
            continue
        ini = dia + D(days=R.randint(1, 5))
        p = disp_vigente(eq, ini)
        if p is None or p.criado > criada:
            continue
        dur = R.randint(1, min(p.prazo or 7, 7))
        fim = ini + D(days=dur)
        if fim > p.fim:
            continue
        cand = [a for a in alunos if elegivel(a, criada, eq)]
        if not cand:
            continue
        a = R.choice(cand)
        s = nova_solic(a, p, ini, fim, criada)
        recente = criada > NOW - D(hours=48)
        limite = dt.datetime.combine(ini, dt.time(8, 0)) - D(hours=1)
        x = R.random()
        if recente and x < 0.55:
            continue                                   # segue pendente
        if x < 0.07:                                   # aluno cancela antes da resposta
            t = humano(criada + mins(30, 600))
            if criada < t < NOW:
                s.status = "CANCELADA"
                if s.pag:
                    s.pag.status = "CANCELADO"
                log("CANCELAMENTO", "solicitacao", s, a.user, t)
            continue
        if x < 0.14 and not recente:                   # sem resposta em 48h (RN26)
            t = criada + D(hours=48)
            s.status = "EXPIRADA"
            if s.pag:
                s.pag.status = "CANCELADO"
            log("EXPIRACAO", "solicitacao", s, None, t, "sistema")
            notificar("SOLICITACAO_EXPIRADA", a.user, "Sua solicitação de \"%s\" expirou sem resposta em 48 horas." % eq.nome, t + D(minutes=1), s)
            continue
        dec = min(criada + D(minutes=R.randint(40, 1500)), limite, NOW - D(minutes=30))
        dec_h = humano(dec)
        if criada < dec_h <= min(limite, NOW - D(minutes=30)):
            dec = dec_h
        elif dec.hour < 7:                             # responde na noite anterior
            alt = at(dec.date() - D(days=1), 20, 22)
            dec = alt if criada < alt else criada + mins(10, 30)
        if dec <= criada:
            continue
        if x < 0.27:                                   # recusa pelo proprietario
            recusar(s, dec, R.choice(JUST_RECUSA))
            continue
        # concorrente no mesmo periodo, recusado automaticamente na aprovacao (RN25)
        if R.random() < 0.2 and (dec - criada) > D(hours=2):
            outros = [b for b in alunos if b is not a and elegivel(b, criada + D(minutes=60), eq)]
            if outros:
                b = R.choice(outros)
                c_t = humano(criada + mins(30, int((dec - criada).total_seconds() // 60) - 20))
                if not (criada < c_t < dec):
                    c_t = criada + mins(10, 20)
                c = nova_solic(b, p, ini, fim, c_t)
                recusar(c, dec + D(minutes=1), "Recusada automaticamente: conflito com reserva aprovada no mesmo período.", True)
        for o in solics:                               # pendentes sobrepostas recusadas (RN25)
            if o is not s and o.status == "PENDENTE" and o.disp.eq is eq and o.criada < dec and o.ini < fim and ini < o.fim:
                recusar(o, dec + D(minutes=1), "Recusada automaticamente: conflito com reserva aprovada no mesmo período.", True)
        s.status, s.resp = "APROVADA", dec
        log("APROVACAO", "solicitacao", s, eq.dono, dec)
        notificar("CONFIRMACAO_RESERVA", a.user, "Sua reserva de \"%s\" de %s a %s foi confirmada." %
                  (eq.nome, ini.strftime("%d/%m"), fim.strftime("%d/%m")), dec + D(minutes=1), s)
        ciclo_reserva(s, eq)
    dia += D(days=1)

# dano encontrado pelo proprio dono fora de uma reserva
eq_vist = equipamentos[5]
t_v = dt.datetime(2026, 9, 2, 14, 30)
if not any(x.disp.eq is eq_vist and t_v - D(days=7) <= x.criada <= t_v + D(days=3) for x in solics) and not any(m0 <= t_v < m1 for m0, m1 in eq_vist.manut) and not any(
        r.ret and r.ret.quando <= t_v <= (r.dev.quando if r.dev else NOW) for r in eq_vist.reservas):
    dv = Obj(eq=eq_vist, desc="Sensor ultrassônico do kit com defeito, identificado em vistoria do laboratório.",
             quando=t_v, relator=eq_vist.dono, r=None, faltante=None, status="RESOLVIDO", resolvido=t_v + D(days=3))
    danos.append(dv)
    log("REGISTRO_DANO", "dano", dv, eq_vist.dono, t_v, "campus")
    log("RESOLUCAO_DANO", "dano", dv, eq_vist.dono, dv.resolvido, "campus")
    fotos.append(Obj(dano=dv, n=0, fmt="JPG", tam=912345, quando=t_v + D(minutes=1)))

# solicitacoes recentes ainda aguardando resposta do proprietario (menos de 48h)
livres = [e for e in equipamentos if not (e.ocupado_ate and NOW < e.ocupado_ate) and not em_manutencao(e, NOW)
          and not any(x.status == "PENDENTE" and x.disp.eq is e for x in solics)]
R.shuffle(livres)
for eq in livres[:4]:
    criada = humano(NOW - D(hours=R.randint(2, 40), minutes=R.randint(0, 59)))
    ini = NOW.date() + D(days=R.randint(3, 9))
    p = disp_vigente(eq, ini)
    if p is None or p.criado > criada:
        continue
    fim = ini + D(days=R.randint(1, min(p.prazo or 5, 5)))
    cand = [a for a in alunos if elegivel(a, criada, eq)]
    if fim <= p.fim and cand:
        nova_solic(R.choice(cand), p, ini, fim, criada)

# ----------------------------------------------------------------------------
# Situacao atual dos equipamentos e aceite do termo 1.1 (RN13)
# ----------------------------------------------------------------------------
for eq in equipamentos:
    hoje = NOW.date()
    if any(m0 <= NOW < m1 for m0, m1 in eq.manut):
        eq.situacao = "EM_MANUTENCAO"
    elif any(r.status in ("EM_USO", "ATRASADA") for r in eq.reservas):
        eq.situacao = "EM_USO"
    elif any(r.status == "CONFIRMADA" for r in eq.reservas):
        eq.situacao = "RESERVADO"
    elif disp_vigente(eq, hoje):
        eq.situacao = "DISPONIVEL"
    else:
        eq.situacao = "INDISPONIVEL"

for u in usuarios:
    if u.aceite10 is None:
        continue
    a = u.aluno
    acoes = [l.quando for l in logs if l.user is u and l.quando >= T11 and l.tipo != "ACEITE_TERMO"]
    acoes += [r.ret.quando for r in reservas if a is not None and r.ret and r.s.aluno is a and r.ret.quando >= T11]
    if acoes:
        t = max(min(acoes) - mins(5, 50), T11 + D(minutes=1))
        if t.hour < 7 <= min(acoes).hour:
            t = max(min(acoes).replace(hour=7, minute=0), min(acoes) - D(minutes=2))
    elif (a is None or a.ativo_ate > NOW) and R.random() < 0.6:
        t = at(dt.date(2026, 10, R.randint(2, 25)), 8, 22)
    else:
        continue
    ac = Obj(user=u, termo=TERMOS[1], quando=t)
    aceites.append(ac)
    log("ACEITE_TERMO", "aceite_termo", ac, u, t, "campus" if u.perfil == "ADM" else "casa")

# bloqueio por tentativas de login (RNF03)
ub = alunos[BLOQUEADO].user
t_b = dt.datetime(2026, 10, 26, 23, 4)
for n in range(5):
    log("LOGIN_FALHA", "usuario", ub, None, t_b + D(minutes=n), "casa_bloq")
log("BLOQUEIO_CONTA", "usuario", ub, None, t_b + D(minutes=5), "sistema")
ub.status = "BLOQUEADA"
for (uu, tf) in [(alunos[4].user, dt.datetime(2026, 9, 14, 7, 51)), (alunos[12].user, dt.datetime(2026, 10, 9, 19, 20))]:
    log("LOGIN_FALHA", "usuario", uu, None, tf, "casa_do:%d" % uu.id)
    log("LOGIN", "usuario", uu, uu, tf + D(minutes=2))

for a in alunos:
    if a.ativo_ate < NOW and a.idx in TRANCADOS:
        a.situacao = "TRANCADO"

# login antes da primeira acao de cada usuario em cada dia
primeira = {}
for l in logs:
    if l.user is None or l.tipo in ("LOGIN", "CADASTRO_CONTA"):
        continue
    k = (l.user.id, l.quando.date())
    if k not in primeira or l.quando < primeira[k].quando:
        primeira[k] = l
for k, l in primeira.items():
    if not any(x.tipo == "LOGIN" and x.user is l.user and x.quando.date() == l.quando.date() for x in logs):
        lt = l.quando - mins(1, 6)
        if l.quando.hour >= 7 and lt.hour < 7:
            lt = l.quando.replace(minute=0)
        logs.append(Obj(tipo="LOGIN", tabela="usuario", alvo=l.user, user=l.user, quando=lt, onde=l.onde))

# ----------------------------------------------------------------------------
# Atribuicao de ids em ordem cronologica e geracao do SQL
# ----------------------------------------------------------------------------
def ordena(lista, chave):
    lista.sort(key=chave)
    for i, o in enumerate(lista, 1):
        o.id = i


ordena(documentos, lambda o: o.envio)
ordena(biometrias, lambda o: o.quando)
ordena(equipamentos, lambda o: o.criado)
ordena(disps, lambda o: o.criado)
ordena(solics, lambda o: o.criada)
ordena(pagamentos, lambda o: o.quando)
ordena(reservas, lambda o: o.criada)
ordena(retiradas, lambda o: o.quando)
ordena(devolucoes, lambda o: o.quando)
ordena(danos, lambda o: o.quando)
fotos.sort(key=lambda o: (o.quando, o.n))
for i, f in enumerate(fotos, 1):
    f.id = i
ordena(avaliacoes, lambda o: o.quando)
ordena(notifs, lambda o: o.quando)
ordena(logs, lambda o: (o.quando, o.tipo != "LOGIN"))
for ac in aceites:
    ac.id = ac.termo.id
for i, r in enumerate(retiradas, 1):
    r.cod = "RET2026%04d" % i
for i, d_ in enumerate(devolucoes, 1):
    d_.cod = "DEV2026%04d" % i


def q(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return ("%.2f" % v) if isinstance(v, float) else str(v)
    if isinstance(v, dt.datetime):
        return "'" + v.strftime("%Y-%m-%d %H:%M:%S") + "'"
    if isinstance(v, dt.date):
        return "'" + v.strftime("%Y-%m-%d") + "'"
    return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"


out = []


def insert(tabela, colunas, linhas, comentario):
    out.append("\n-- " + comentario)
    out.append("INSERT INTO %s (%s) VALUES" % (tabela, ", ".join(colunas)))
    out.append(",\n".join("  (" + ", ".join(x if isinstance(x, Raw) else q(x) for x in l) + ")" for l in linhas) + ";")


class Raw(str):
    pass


def geo(l):
    if l.onde == "sistema":
        return SERVIDOR_IP, None, None
    if l.onde == "campus":
        return "192.0.2.%d" % (20 + (l.user.id if l.user else 0) % 30), CAMPUS[0], CAMPUS[1]
    if l.onde == "casa_bloq":
        return "192.0.2.201", None, None
    if l.onde.startswith("casa_do:"):
        h = home[int(l.onde.split(":")[1])]
        return h
    return home[l.user.id]


def S(sql):
    return Raw("(" + sql + ")")


def s_inst():
    return S("SELECT id_instituicao FROM instituicao WHERE cnpj = %s" % q(inst.cnpj))


def s_curso(n):
    return S("SELECT id_curso FROM curso WHERE nome = %s" % q(CURSOS[n - 1]))


def s_user(u):
    return S("SELECT id_usuario FROM usuario WHERE email = %s" % q(u.email))


def s_aluno(a):
    return S("SELECT id_aluno FROM aluno WHERE matricula = %s" % q(a.matricula))


def s_termo(t):
    return S("SELECT id_termo FROM termo_uso WHERE versao = %s" % q(t.versao))


def s_cat(n):
    return S("SELECT id_categoria FROM categoria WHERE nome = %s" % q(CATEGORIAS[n - 1]))


def s_equip(e):
    return S("SELECT id_equipamento FROM equipamento WHERE nome = %s" % q(e.nome))


def s_disp(p):
    return S("SELECT id_disponibilizacao FROM disponibilizacao WHERE id_equipamento = %s AND data_inicio = %s"
             % (s_equip(p.eq), q(p.ini)))


def s_solic(x):
    return S("SELECT id_solicitacao FROM solicitacao WHERE id_aluno = %s AND criada_em = %s" % (s_aluno(x.aluno), q(x.criada)))


def s_pag(pg):
    return S("SELECT id_pagamento FROM pagamento_simulado WHERE id_solicitacao = %s" % s_solic(pg.s))


def s_res(r):
    return S("SELECT id_reserva FROM reserva WHERE id_solicitacao = %s" % s_solic(r.s))


def s_bio(b):
    return S("SELECT id_biometria FROM biometria_facial WHERE id_usuario = %s AND model_version = %s" % (s_user(b.user), q(b.modelo)))


def s_ret(x):
    return S("SELECT id_retirada FROM retirada WHERE codigo_comprovante = %s" % q(x.cod))


def s_dev(x):
    return S("SELECT id_devolucao FROM devolucao WHERE codigo_comprovante = %s" % q(x.cod))


def s_dano(x):
    return S("SELECT id_dano FROM dano WHERE id_equipamento = %s AND data_hora = %s" % (s_equip(x.eq), q(x.quando)))


def s_doc(x):
    return S("SELECT id_documento FROM documento_identidade WHERE numero_documento = %s AND enviado_em = %s" % (q(x.numero), q(x.envio)))


def s_aval(x):
    return S("SELECT id_avaliacao FROM avaliacao WHERE id_reserva = %s AND id_aluno_avaliador = %s" % (s_res(x.r), s_aluno(x.avaliador)))


ALVO = {"usuario": s_user, "documento_identidade": s_doc, "biometria_facial": s_bio, "aceite_termo": lambda ac: s_termo(ac.termo),
        "equipamento": s_equip, "disponibilizacao": s_disp, "solicitacao": s_solic, "pagamento_simulado": s_pag,
        "retirada": s_ret, "devolucao": s_dev, "dano": s_dano, "avaliacao": s_aval}


def unico(nome, chaves):
    assert len(chaves) == len(set(chaves)), "chave natural repetida em " + nome


unico("equipamento", [e.nome for e in equipamentos])
unico("disponibilizacao", [(p.eq.nome, p.ini) for p in disps])
unico("solicitacao", [(x.aluno.matricula, x.criada) for x in solics])
unico("dano", [(x.eq.nome, x.quando) for x in danos])
unico("documento", [(x.numero, x.envio) for x in documentos])
unico("aceite", [(ac.user.email, ac.termo.versao) for ac in aceites])

out.append("-- Povoamento inicial: chaves primarias geradas por AUTO_INCREMENT e chaves estrangeiras preenchidas por SELECT.")
out.append("-- Cenario simulado do semestre na UMC ate 28/10/2026 08:00. Dados ficticios.")
out.append("\nUSE unishare;")
insert("instituicao", ["nome", "sigla", "cnpj"], [(inst.nome, inst.sigla, inst.cnpj)], "instituicao")
insert("curso", ["nome", "id_instituicao"], [(n, s_inst()) for n in CURSOS], "cursos")
insert("usuario", ["nome", "cpf", "email", "senha_hash", "perfil", "telefone", "status_conta", "criado_em", "id_instituicao"],
       [(u.nome, u.cpf, u.email, u.hash, u.perfil, u.telefone, u.status, u.criado, s_inst() if u.perfil == "ADM" else None) for u in usuarios],
       "usuarios: administradores e alunos")
insert("aluno", ["matricula", "situacao_vinculo", "id_usuario"], [(a.matricula, a.situacao, s_user(a.user)) for a in alunos], "alunos")
insert("aluno_curso", ["id_aluno", "id_curso"], [(s_aluno(a), s_curso(c)) for a in alunos for c in a.cursos], "cursos de cada aluno")
insert("documento_identidade", ["tipo_documento", "numero_documento", "arquivo_url", "status", "motivo_recusa",
                                "enviado_em", "analisado_em", "id_aluno", "id_usuario_analista"],
       [(d_.tipo, d_.numero, "documentos/%s/documento_%d.pdf" % (d_.aluno.matricula, d_.id), d_.status, d_.motivo,
         d_.envio, d_.analise, s_aluno(d_.aluno), s_user(d_.analista) if d_.analista else None) for d_ in documentos],
       "documentos de identidade")
insert("biometria_facial", ["id_usuario", "embedding_iv", "embedding_tag", "embedding_ct", "key_version", "model_version", "criado_em"],
       [(s_user(b.user), Raw("RANDOM_BYTES(12)"), Raw("RANDOM_BYTES(16)"), Raw("CONCAT(RANDOM_BYTES(1024), RANDOM_BYTES(1024))"),
         b.key, b.modelo, b.quando) for b in biometrias],
       "biometria facial obrigatoria; embeddings simulados com bytes aleatorios")
insert("termo_uso", ["versao", "conteudo", "publicado_em"], [(t.versao, t.conteudo, t.publicado) for t in TERMOS], "termos de uso")
insert("aceite_termo", ["id_usuario", "id_termo", "data_hora_aceite"],
       [(s_user(ac.user), s_termo(ac.termo), ac.quando) for ac in sorted(aceites, key=lambda x: x.quando)], "aceites do termo por usuario")
insert("categoria", ["nome"], [(n,) for n in CATEGORIAS], "categorias")
insert("equipamento", ["nome", "descricao", "estado_conservacao", "situacao", "criado_em", "id_categoria", "id_usuario_proprietario"],
       [(e.nome, e.desc, e.estado, e.situacao, e.criado, s_cat(e.cat), s_user(e.dono)) for e in equipamentos], "equipamentos")
insert("disponibilizacao", ["modalidade", "valor_diaria", "data_inicio", "data_fim", "prazo_maximo_dias", "criado_em", "id_equipamento"],
       [(p.modalidade, float(p.valor), p.ini, p.fim, p.prazo, p.criado, s_equip(p.eq)) for p in disps], "disponibilizacoes")
insert("solicitacao", ["data_inicio", "data_fim", "status", "justificativa_recusa", "criada_em", "respondida_em", "id_aluno", "id_disponibilizacao"],
       [(x.ini, x.fim, x.status, x.just, x.criada, x.resp, s_aluno(x.aluno), s_disp(x.disp)) for x in solics], "solicitacoes")
insert("pagamento_simulado", ["valor_total", "status", "data_hora", "id_solicitacao"],
       [(float(pg.valor), pg.status, pg.quando, s_solic(pg.s)) for pg in pagamentos], "pagamentos simulados")
insert("reserva", ["status", "criada_em", "id_solicitacao"], [(r.status, r.criada, s_solic(r.s)) for r in reservas], "reservas")
insert("retirada", ["data_hora", "estado_conservacao", "observacao", "codigo_comprovante", "id_reserva", "id_biometria"],
       [(x.quando, x.estado, x.obs, x.cod, s_res(x.r), s_bio(x.bio)) for x in retiradas], "retiradas")
insert("devolucao", ["data_hora", "estado_conservacao", "itens_faltantes", "observacao", "codigo_comprovante", "id_retirada"],
       [(x.quando, x.estado, x.faltante, x.obs, x.cod, s_ret(x.ret)) for x in devolucoes], "devolucoes")
insert("dano", ["descricao", "data_hora", "status_andamento", "resolvido_em", "id_equipamento", "id_usuario_relator", "id_reserva"],
       [(x.desc, x.quando, x.status, x.resolvido, s_equip(x.eq), s_user(x.relator), s_res(x.r) if x.r else None) for x in danos], "danos")
insert("foto_dano", ["url_arquivo", "formato", "tamanho_bytes", "enviada_em", "id_dano"],
       [("danos/dano_%d/foto_%d.%s" % (f.dano.id, f.n + 1, f.fmt.lower()), f.fmt, f.tam, f.quando, s_dano(f.dano)) for f in fotos], "fotos dos danos")
insert("avaliacao", ["nota", "comentario", "data_hora", "id_aluno_avaliador", "id_reserva"],
       [(x.nota, x.com, x.quando, s_aluno(x.avaliador), s_res(x.r)) for x in avaliacoes], "avaliacoes")
insert("notificacao", ["tipo", "mensagem", "enviada_em", "lida", "id_usuario", "id_solicitacao"],
       [(n.tipo, n.msg, n.quando, n.quando < NOW - D(hours=20), s_user(n.user), s_solic(n.solic) if n.solic else None) for n in notifs],
       "notificacoes")
linhas = []
for l in logs:
    ip, la, lo = geo(l)
    linhas.append((l.tipo, l.tabela, ALVO[l.tabela](l.alvo), ip, la, lo, l.quando, s_user(l.user) if l.user else None))
insert("registro_operacao", ["tipo_operacao", "tabela_afetada", "id_afetado", "endereco_ip", "latitude", "longitude", "data_hora", "id_usuario"],
       linhas, "log de auditoria de todas as acoes acima (id_afetado tambem obtido por SELECT)")

open(sys.argv[1], "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("usuarios=%d alunos=%d equipamentos=%d disps=%d solicitacoes=%d reservas=%d retiradas=%d devolucoes=%d danos=%d fotos=%d avaliacoes=%d notificacoes=%d logs=%d" % (
    len(usuarios), len(alunos), len(equipamentos), len(disps), len(solics), len(reservas), len(retiradas), len(devolucoes),
    len(danos), len(fotos), len(avaliacoes), len(notifs), len(logs)))
from collections import Counter
print("status solicitacao:", dict(Counter(s.status for s in solics)))
print("status reserva:", dict(Counter(r.status for r in reservas)))
print("situacao equipamento:", dict(Counter(e.situacao for e in equipamentos)))
print("status dano:", dict(Counter(x.status for x in danos)))
