// lib/features/authentication/data/content_data.dart

import 'package:flutter/foundation.dart';

/// Um modelo de dados padronizado para todo o conteúdo textual do aplicativo.
@immutable
class VibrationContent {
  /// O título principal a ser exibido (ex: "Início e Ação").
  final String titulo;

  /// Um título secundário ou tradicional, usado principalmente para os Arcanos (ex: "O Mago").
  final String? tituloTradicional;

  /// A descrição curta exibida no card do dashboard.
  final String descricaoCurta;

  /// O texto descritivo completo, para ser usado em uma visualização detalhada.
  final String descricaoCompleta;

  /// O texto inspiracional do dia/mês/ano/arcano.
  final String inspiracao;

  /// Uma lista de palavras-chave associadas.
  final List<String> tags;

  const VibrationContent({
    required this.titulo,
    this.tituloTradicional,
    required this.descricaoCurta,
    required this.descricaoCompleta,
    required this.inspiracao,
    this.tags = const [],
  });
}

/// Dados para a Bússola de Atividades.
@immutable
class BussolaContent {
  final List<String> potencializar;
  final List<String> atencao;

  const BussolaContent({required this.potencializar, required this.atencao});
}

/// Classe principal que armazena todos os dados de conteúdo do aplicativo.
class ContentData {
  // Estrutura unificada para Dia, Mês e Ano
  static final Map<String, Map<int, VibrationContent>> vibracoes = {
    'diaPessoal': {
      1: const VibrationContent(
          titulo: "Início e Ação",
          descricaoCurta:
              "Ótimo para iniciar projetos, tomar decisões importantes e agir com independência.",
          descricaoCompleta:
              "Hoje é um dia para plantar sementes. Tome a iniciativa, lidere com confiança e não tenha medo de começar algo novo. A energia é de independência e coragem.",
          tags: ["Liderança", "Inovação", "Coragem"],
          inspiracao: "A página está em branco e a caneta está na sua mão..."),
      2: const VibrationContent(
          titulo: "Cooperação e Diplomacia",
          descricaoCurta:
              "Favorece parcerias, trabalho em equipe, negociações e atividades que exigem paciência.",
          descricaoCompleta:
              "Foque em parcerias e no trabalho em equipe. A paciência e a diplomacia são suas melhores ferramentas. Ouça mais, seja receptivo e busque harmonia.",
          tags: ["Paciência", "Tato", "União"],
          inspiracao: "Nenhuma sinfonia é feita de uma única nota..."),
      3: const VibrationContent(
          titulo: "Comunicação e Criatividade",
          descricaoCurta:
              "Ideal para reuniões criativas, socializar, escrever, apresentar ideias e se expressar.",
          descricaoCompleta:
              "Expresse-se! Um ótimo dia para socializar, escrever, e dar vazão à sua criatividade...",
          tags: ["Expressão", "Otimismo", "Sociabilidade"],
          inspiracao: "Sua alma tem uma voz, e hoje ela quer ser ouvida..."),
      4: const VibrationContent(
          titulo: "Estrutura e Trabalho",
          descricaoCurta:
              "Perfeito para organizar tarefas, planejar, focar em detalhes e realizar trabalhos práticos.",
          descricaoCompleta:
              "Dia de arregaçar as mangas. Foco na organização, no planejamento e no trabalho duro...",
          tags: ["Ordem", "Disciplina", "Praticidade"],
          inspiracao: "Grandes catedrais são construídas tijolo por tijolo..."),
      5: const VibrationContent(
          titulo: "Mudança e Liberdade",
          descricaoCurta:
              "Propício para experimentar coisas novas, quebrar a rotina, viajar e ser flexível.",
          descricaoCompleta:
              "Abrace o inesperado. A energia de hoje favorece a mudança, a aventura e a versatilidade...",
          tags: ["Versatilidade", "Aventura", "Liberdade"],
          inspiracao: "O vento da mudança sopra a seu favor..."),
    },
    'mesPessoal': {
      1: const VibrationContent(
          titulo: "Mês de Inícios",
          descricaoCurta:
              "Este mês, a energia favorece novos começos. É hora de ser pioneiro, tomar decisões e agir com independência.",
          descricaoCompleta: "Este mês, a energia favorece novos começos...",
          tags: ["Iniciativa", "Autoconfiança"],
          inspiracao: "Este é o seu ponto de partida..."),
      2: const VibrationContent(
          titulo: "Mês de Parcerias",
          descricaoCurta:
              "Foque em colaboração e diplomacia. Relações e parcerias estão em destaque.",
          descricaoCompleta: "Foque em colaboração e diplomacia...",
          tags: ["Cooperação", "Relacionamentos"],
          inspiracao: "O tema deste mês é a conexão..."),
      3: const VibrationContent(
          titulo: "Mês de Expansão Social",
          descricaoCurta:
              "Sua criatividade e comunicação estão em alta. Um ótimo período para socializar e se expressar.",
          descricaoCompleta: "Sua criatividade e comunicação estão em alta...",
          tags: ["Criatividade", "Comunicação"],
          inspiracao: "Deixe sua luz brilhar!..."),
      4: const VibrationContent(
          titulo: "Mês de Organização",
          descricaoCurta:
              "Dedique-se ao trabalho, planejamento e construção de bases sólidas.",
          descricaoCompleta:
              "Dedique-se ao trabalho, planejamento e construção de bases sólidas...",
          tags: ["Estrutura", "Trabalho"],
          inspiracao: "Este é o mês para construir..."),
      5: const VibrationContent(
          titulo: "Mês de Mudanças",
          descricaoCurta:
              "Espere o inesperado. Um período de movimento, viagens e novas oportunidades.",
          descricaoCompleta: "Espere o inesperado...",
          tags: ["Mudança", "Liberdade"],
          inspiracao: "Prepare-se para o movimento..."),
    },
    'anoPessoal': {
      1: const VibrationContent(
          titulo: "Ano de Recomeço",
          descricaoCurta:
              "Um novo ciclo de 9 anos se inicia. É o ano para plantar as sementes do seu futuro.",
          descricaoCompleta: "Um novo ciclo de 9 anos se inicia...",
          tags: ["Novos Inícios", "Independência"],
          inspiracao: "Este é o marco zero da sua próxima grande jornada..."),
      2: const VibrationContent(
          titulo: "Ano de Colaboração",
          descricaoCurta:
              "O foco está nos relacionamentos, parcerias e na paciência.",
          descricaoCompleta:
              "O foco está nos relacionamentos, parcerias e na paciência...",
          tags: ["União", "Diplomacia"],
          inspiracao:
              "Depois do impulso inicial do ano passado, agora é tempo de cultivar..."),
      3: const VibrationContent(
          titulo: "Ano de Crescimento",
          descricaoCurta:
              "Sua vida social e criativa floresce. É um ano para se comunicar e se expressar.",
          descricaoCompleta: "Sua vida social e criativa floresce...",
          tags: ["Expansão", "Otimismo"],
          inspiracao: "É hora de florescer!..."),
      4: const VibrationContent(
          titulo: "Ano de Construção",
          descricaoCurta:
              "Trabalho duro, disciplina e organização são as chaves. Um ano para construir bases sólidas.",
          descricaoCompleta:
              "Trabalho duro, disciplina e organização são as chaves...",
          tags: ["Fundação", "Esforço"],
          inspiracao: "Este é o ano de arregaçar as mangas..."),
      5: const VibrationContent(
          titulo: "Ano de Transformação",
          descricaoCurta:
              "Prepare-se para mudanças significativas. Um ano de liberdade, viagens e novas experiências.",
          descricaoCompleta: "Prepare-se para mudanças significativas...",
          tags: ["Mudança", "Aventura"],
          inspiracao: "O vento da transformação está soprando forte..."),
      6: const VibrationContent(
          titulo: "Ano de Responsabilidades",
          descricaoCurta:
              "Questões de família, lar e comunidade vêm à tona. É um ano para nutrir relacionamentos.",
          descricaoCompleta:
              "Questões de família, lar e comunidade vêm à tona...",
          tags: ["Harmonia", "Dever"],
          inspiracao: "O foco se volta para o coração e para o lar..."),
      7: const VibrationContent(
          titulo: "Ano de Autoavaliação",
          descricaoCurta:
              "Um período de introspecção, estudo e busca por sabedoria. Confie na sua intuição.",
          descricaoCompleta:
              "Um período de introspecção, estudo e busca por sabedoria...",
          tags: ["Sabedoria", "Fé"],
          inspiracao: "Este é um ano sabático para a alma..."),
      8: const VibrationContent(
          titulo: "Ano de Colheita",
          descricaoCurta:
              "Poder pessoal, sucesso financeiro e reconhecimento estão em foco.",
          descricaoCompleta:
              "Poder pessoal, sucesso financeiro e reconhecimento estão em foco...",
          tags: ["Realização", "Poder"],
          inspiracao: "Chegou a hora de colher os frutos!..."),
    },
  };

  // Textos para os Arcanos
  static final Map<int, VibrationContent> textosArcanos = {
    1: const VibrationContent(
        titulo: "Arcano 1",
        tituloTradicional: "O Mago",
        descricaoCurta:
            "Representa o poder da manifestação, habilidade e comunicação.",
        descricaoCompleta:
            "É a energia para iniciar, criar e transformar ideias em realidade.",
        tags: ["Manifestação", "Habilidade", "Início"],
        inspiracao: "Você tem o poder de criar a sua realidade..."),
    2: const VibrationContent(
        titulo: "Arcano 2",
        tituloTradicional: "A Papisa",
        descricaoCurta:
            "Simboliza a intuição, o mistério e o conhecimento oculto.",
        descricaoCompleta:
            "Pede introspecção, paciência e atenção aos sinais do subconsciente.",
        tags: ["Intuição", "Sabedoria", "Mistério"],
        inspiracao: "O conhecimento mais profundo não está nos livros..."),
    3: const VibrationContent(
        titulo: "Arcano 3",
        tituloTradicional: "A Imperatriz",
        descricaoCurta:
            "É a energia da criação, fertilidade, abundância e da natureza.",
        descricaoCompleta:
            "Favorece o crescimento, o cuidado e a expressão da beleza.",
        tags: ["Criação", "Abundância", "Nutrição"],
        inspiracao: "Você é um canal de criação e abundância..."),
    4: const VibrationContent(
        titulo: "Arcano 4",
        tituloTradicional: "O Imperador",
        descricaoCurta:
            "Representa a estrutura, a autoridade, a ordem e o controle.",
        descricaoCompleta:
            "Pede organização, disciplina e a assunção de responsabilidades.",
        tags: ["Estrutura", "Autoridade", "Disciplina"],
        inspiracao: "A liberdade floresce na estrutura..."),
    5: const VibrationContent(
        titulo: "Arcano 5",
        tituloTradicional: "O Papa",
        descricaoCurta:
            "Simboliza a tradição, a sabedoria, a educação e a busca por um propósito maior.",
        descricaoCompleta:
            "Favorece o aprendizado e o compartilhamento de conhecimento.",
        tags: ["Sabedoria", "Tradição", " propósito"],
        inspiracao: "Sua jornada tem um propósito maior..."),
    6: const VibrationContent(
        titulo: "Arcano 6",
        tituloTradicional: "Os Enamorados",
        descricaoCurta: "Fala de escolhas, uniões, relacionamentos e harmonia.",
        descricaoCompleta:
            "Pede decisões tomadas com o coração e a busca pelo equilíbrio nas relações.",
        tags: ["Escolhas", "União", "Relacionamentos"],
        inspiracao: "A vida é feita de escolhas que revelam quem somos..."),
  };

  // Bússola de Atividades
  static final Map<int, BussolaContent> bussolaAtividades = {
    1: const BussolaContent(potencializar: [
      "Começar um novo projeto ou curso.",
      "Tomar a liderança em uma situação."
    ], atencao: [
      "Impaciência e impulsividade.",
      "Agir sem pensar nas consequências."
    ]),
    2: const BussolaContent(potencializar: [
      "Resolver um mal-entendido com alguém.",
      "Trabalhar em equipe."
    ], atencao: [
      "Indecisão e dependência excessiva.",
      "Sensibilidade extrema a críticas."
    ]),
    3: const BussolaContent(potencializar: [
      "Sair com amigos, socializar.",
      "Escrever, pintar ou qualquer atividade criativa."
    ], atencao: [
      "Fofocas e comunicação superficial.",
      "Dispersão de energia."
    ]),
    4: const BussolaContent(potencializar: [
      "Organizar sua casa ou espaço de trabalho.",
      "Planejar suas finanças."
    ], atencao: [
      "Teimosia e rigidez.",
      "Excesso de trabalho."
    ]),
    5: const BussolaContent(potencializar: [
      "Experimentar algo novo, quebrar a rotina.",
      "Fazer uma pequena viagem ou passeio."
    ], atencao: [
      "Inquietação e falta de foco.",
      "Exageros (comida, bebida, gastos)."
    ]),
    6: const BussolaContent(potencializar: [
      "Passar tempo com a família.",
      "Cuidar da casa, decorar ou fazer reparos."
    ], atencao: [
      "Assumir responsabilidades que não são suas.",
      "Tendência a se preocupar demais."
    ]),
    7: const BussolaContent(potencializar: [
      "Ler um livro, estudar um assunto de interesse.",
      "Meditar ou passar um tempo em silêncio."
    ], atencao: [
      "Isolamento excessivo.",
      "Ceticismo e desconfiança."
    ]),
    8: const BussolaContent(potencializar: [
      "Negociar um aumento ou fechar um negócio.",
      "Assumir o controle de suas finanças."
    ], atencao: [
      "Ser autoritário ou dominador.",
      "Foco excessivo no material."
    ]),
    9: const BussolaContent(potencializar: [
      "Finalizar tarefas pendentes, limpar a casa.",
      "Fazer um trabalho voluntário."
    ], atencao: [
      "Nostalgia ou apego excessivo ao passado.",
      "Sentimento de melancolia."
    ]),
    0: const BussolaContent(
        potencializar: ["Observar seus sentimentos e pensamentos."],
        atencao: ["Agir no piloto automático."]), // Para o 'default'
  };

  // Textos Explicativos para a tela de 'Saiba Mais'
  static final Map<String, String> textosExplicativos = {
    'vibracaoDia':
        "A Vibração do Dia, ou seu Dia Pessoal, revela a energia predominante que influenciará suas próximas 24 horas...",
    'mesPessoal':
        "Seu Mês Pessoal define o tema principal e as lições que o universo te convida a explorar durante este ciclo...",
    'anoPessoal':
        "O Ano Pessoal é o grande palco da sua jornada anual. Ele dita o ritmo, os desafios e as oportunidades...",
    'cicloDeVida':
        "Os Ciclos de Vida são os grandes capítulos da sua existência. Cada ciclo, regido por um número, aponta para os aprendizados...",
    'arcanoRegente':
        "Seu Arcano Regente é a essência da sua personalidade e sua missão de alma. Ele representa a energia fundamental que te acompanha...",
    'arcanoVigente':
        "O Arcano Vigente, ou Arcano do Ano, ilumina o caminho do seu ano pessoal. Ele atua como um sábio conselheiro...",
    'bussolaAtividades':
        "A Bússola de Atividades é sua guia prática para o dia. Baseada na energia do seu Dia Pessoal, ela sugere ações para 'Potencializar'...",
  };

  // Sugestões para o Diário (Journal)
  static final Map<int, List<String>> journalPrompts = {
    1: [
      "Que nova iniciativa posso começar hoje?",
      "Qual é o meu principal objetivo para este novo ciclo?"
    ],
    2: [
      "Com quem eu preciso me conectar ou colaborar hoje?",
      "Como posso praticar a paciência e a diplomacia?"
    ],
    3: [
      "De que forma posso expressar minha criatividade hoje?",
      "O que me traria alegria e otimismo neste momento?"
    ],
    4: [
      "Qual tarefa prática ou meta de trabalho posso avançar hoje?",
      "Como posso criar mais estabilidade e organização?"
    ],
  };

  static final Map<int, VibrationContent> textosCiclosDeVida = {
    1: const VibrationContent(
        titulo: "O Início",
        descricaoCurta:
            "Um ciclo para plantar sementes. É um período de novos começos, independência e muita energia.",
        descricaoCompleta: "O foco é em você e na sua individualidade.",
        tags: ["Iniciativa", "Independência", "Começos"],
        inspiracao: "Este é o alvorecer de uma nova era em sua vida..."),
    2: const VibrationContent(
        titulo: "A Parceria",
        descricaoCurta:
            "Momento de paciência, cooperação e desenvolvimento de parcerias.",
        descricaoCompleta: "O foco está nas relações e na diplomacia.",
        tags: ["Cooperação", "Paciência", "Relações"],
        inspiracao:
            "Depois de plantar suas sementes, o Ciclo 2 te ensina a arte de cultivar com os outros..."),
    3: const VibrationContent(
        titulo: "A Criatividade",
        descricaoCurta:
            "Um período de expansão social e expressão criativa. A comunicação está em alta.",
        descricaoCompleta:
            "É um tempo para socializar, se divertir e dar vida a novas ideias.",
        tags: ["Expressão", "Otimismo", "Sociabilidade"],
        inspiracao: "Este ciclo é uma celebração da sua expressão única..."),
  };
}
