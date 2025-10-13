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
              "Expresse-se! Um ótimo dia para socializar, escrever, e dar vazão à sua criatividade. A alegria e o otimismo estão no ar, aproveite para se conectar com os outros.",
          tags: ["Expressão", "Otimismo", "Sociabilidade"],
          inspiracao: "Sua alma tem uma voz, e hoje ela quer ser ouvida..."),
      4: const VibrationContent(
          titulo: "Estrutura e Trabalho",
          descricaoCurta:
              "Perfeito para organizar tarefas, planejar, focar em detalhes e realizar trabalhos práticos.",
          descricaoCompleta:
              "Dia de arregaçar as mangas. Foco na organização, no planejamento e no trabalho duro. A disciplina e a atenção aos detalhes trarão resultados sólidos.",
          tags: ["Ordem", "Disciplina", "Praticidade"],
          inspiracao: "Grandes catedrais são construídas tijolo por tijolo..."),
      5: const VibrationContent(
          titulo: "Mudança e Liberdade",
          descricaoCurta:
              "Propício para experimentar coisas novas, quebrar a rotina, viajar e ser flexível.",
          descricaoCompleta:
              "Abrace o inesperado. A energia de hoje favorece a mudança, a aventura e a versatilidade. Permita-se explorar novos caminhos e quebrar a rotina.",
          tags: ["Versatilidade", "Aventura", "Liberdade"],
          inspiracao: "O vento da mudança sopra a seu favor..."),
      6: const VibrationContent(
          titulo: "Harmonia e Responsabilidade",
          descricaoCurta:
              "Foco em questões de família, lar e relacionamentos. Dia de nutrir e cuidar.",
          descricaoCompleta:
              "Hoje, o foco se volta para o coração e para o lar. Um dia excelente para harmonizar relacionamentos, cuidar da casa e assumir responsabilidades afetivas.",
          tags: ["Harmonia", "Família", "Cuidado"],
          inspiracao: "O amor é a cola que une o universo..."),
      7: const VibrationContent(
          titulo: "Introspecção e Sabedoria",
          descricaoCurta:
              "Um dia para autoavaliação, estudo e busca por respostas internas. Confie na sua intuição.",
          descricaoCompleta:
              "Pause a agitação externa e olhe para dentro. A energia de hoje favorece o estudo, a meditação e a busca por um significado mais profundo. Confie na sua intuição.",
          tags: ["Sabedoria", "Fé", "Introspecção"],
          inspiracao: "As respostas mais importantes estão no silêncio..."),
      8: const VibrationContent(
          titulo: "Poder e Realização",
          descricaoCurta:
              "Energia de poder pessoal, sucesso material e reconhecimento. Ótimo para negócios.",
          descricaoCompleta:
              "Dia de colher os frutos! A energia favorece a ambição, o planejamento financeiro e a tomada de decisões importantes que impactam seu status e reconhecimento.",
          tags: ["Realização", "Poder", "Sucesso"],
          inspiracao: "Assuma o seu poder e manifeste seus objetivos..."),
      9: const VibrationContent(
          titulo: "Finalização e Compaixão",
          descricaoCurta:
              "Ideal para concluir ciclos, perdoar e praticar o desapego. Olhe para o todo.",
          descricaoCompleta:
              "É hora de fechar portas para que novas possam se abrir. Dia de limpeza, finalização de projetos e, acima de tudo, compaixão e perdão, por si e pelos outros.",
          tags: ["Conclusão", "Perdão", "Humanitarismo"],
          inspiracao:
              "Solte o que não serve mais para abrir espaço para o novo..."),
      11: const VibrationContent(
          titulo: "Intuição e Revelação",
          descricaoCurta:
              "Dia de grande sensibilidade e inspiração espiritual. Siga sua intuição mestra.",
          descricaoCompleta:
              "A vibração de hoje abre um canal direto com sua intuição. Preste atenção em sonhos, sincronicidades e insights. É um dia para inspirar e ser inspirado.",
          tags: ["Intuição", "Espiritualidade", "Revelação"],
          inspiracao: "Sua intuição é a sua bússola mais confiável..."),
      22: const VibrationContent(
          titulo: "Construção Mestra",
          descricaoCurta:
              "Potencial para realizar grandes feitos com impacto duradouro. Pense grande, mas com os pés no chão.",
          descricaoCompleta:
              "Hoje, você tem o poder de transformar sonhos em realidade de forma prática e em larga escala. É um dia para construir legados e trabalhar em projetos de grande impacto.",
          tags: ["Realização", "Praticidade", "Legado"],
          inspiracao:
              "Você é o arquiteto do seu mundo. Construa algo grandioso..."),
    },
    'mesPessoal': {
      1: const VibrationContent(
          titulo: "Mês de Inícios",
          descricaoCurta:
              "Este mês, a energia favorece novos começos. É hora de ser pioneiro, tomar decisões e agir com independência.",
          descricaoCompleta:
              "Este é o seu ponto de partida para um novo ciclo mensal. A energia está propícia para dar o primeiro passo em direção a novos projetos, assumir a liderança e afirmar sua individualidade.",
          tags: ["Iniciativa", "Autoconfiança", "Pioneirismo"],
          inspiracao:
              "A jornada de mil milhas começa com um único passo. Dê o seu agora."),
      2: const VibrationContent(
          titulo: "Mês de Parcerias",
          descricaoCurta:
              "Foque em colaboração e diplomacia. Relações e parcerias estão em destaque.",
          descricaoCompleta:
              "A palavra-chave deste mês é 'nós'. O progresso virá através da cooperação, da paciência e da diplomacia. Foque em fortalecer laços e construir pontes.",
          tags: ["Cooperação", "Relacionamentos", "Paciência"],
          inspiracao:
              "Juntos, somos mais fortes. O tema deste mês é a conexão."),
      3: const VibrationContent(
          titulo: "Mês de Expansão Social",
          descricaoCurta:
              "Sua criatividade e comunicação estão em alta. Um ótimo período para socializar e se expressar.",
          descricaoCompleta:
              "Este é um mês para ser visto e ouvido. Sua criatividade e magnetismo pessoal estão em alta. Comunique suas ideias, socialize e não tenha medo de brilhar.",
          tags: ["Criatividade", "Comunicação", "Alegria"],
          inspiracao: "O mundo é o seu palco. Deixe sua luz brilhar!"),
      4: const VibrationContent(
          titulo: "Mês de Organização",
          descricaoCurta:
              "Dedique-se ao trabalho, planejamento e construção de bases sólidas para o futuro.",
          descricaoCompleta:
              "Depois da expansão, é hora de estruturar. Este mês pede foco, disciplina e trabalho dedicado. Organize suas finanças, sua rotina e seus projetos para garantir estabilidade a longo prazo.",
          tags: ["Estrutura", "Trabalho", "Disciplina"],
          inspiracao:
              "Fundamentos sólidos sustentam os maiores sonhos. Este é o mês para construir."),
      5: const VibrationContent(
          titulo: "Mês de Mudanças",
          descricaoCurta:
              "Espere o inesperado. Um período de movimento, viagens, novas oportunidades e liberdade.",
          descricaoCompleta:
              "Prepare-se para o movimento. Este mês traz uma energia de mudança, aventura e liberdade. Esteja aberto a novas experiências, quebre a rotina e explore o desconhecido.",
          tags: ["Mudança", "Liberdade", "Aventura"],
          inspiracao: "A única constante é a mudança. Flua com ela."),
      6: const VibrationContent(
          titulo: "Mês de Harmonia",
          descricaoCurta:
              "Questões do lar, família e responsabilidades afetivas ganham destaque. Mês para nutrir.",
          descricaoCompleta:
              "O foco se volta para o lar e o coração. É um período para cuidar dos seus relacionamentos, embelezar seu ambiente e assumir responsabilidades com amor e dedicação.",
          tags: ["Família", "Responsabilidade", "Amor"],
          inspiracao: "Onde há amor, há um lar."),
      7: const VibrationContent(
          titulo: "Mês de Introspecção",
          descricaoCurta:
              "Um convite para olhar para dentro, estudar e buscar sabedoria. Confie na sua intuição.",
          descricaoCompleta:
              "É tempo de uma pausa para reflexão. Este mês favorece o estudo, a meditação e a busca por autoconhecimento. Ouça sua voz interior e confie na sua jornada.",
          tags: ["Sabedoria", "Fé", "Reflexão"],
          inspiracao:
              "O universo interior é tão vasto quanto o exterior. Explore-o."),
      8: const VibrationContent(
          titulo: "Mês de Conquistas",
          descricaoCurta:
              "Energia de poder pessoal, reconhecimento e sucesso material. Ótimo para avançar na carreira.",
          descricaoCompleta:
              "Este é um mês de poder e ambição. A energia está favorável para assumir o controle, tomar decisões estratégicas e colher os frutos do seu esforço, especialmente na área financeira e profissional.",
          tags: ["Sucesso", "Poder Pessoal", "Finanças"],
          inspiracao: "Você tem o poder de manifestar seus maiores objetivos."),
      9: const VibrationContent(
          titulo: "Mês de Finalização",
          descricaoCurta:
              "Período para concluir ciclos, liberar o que não serve mais e praticar o desapego.",
          descricaoCompleta:
              "Para começar um novo capítulo, é preciso terminar o anterior. Use este mês para finalizar projetos pendentes, resolver questões antigas e praticar o perdão e a compaixão.",
          tags: ["Conclusão", "Desapego", "Compaixão"],
          inspiracao: "Deixar ir é o primeiro passo para receber."),
      11: const VibrationContent(
          titulo: "Mês de Intuição Mestra",
          descricaoCurta:
              "Sua sensibilidade e intuição estão extremamente aguçadas. Confie nos seus insights.",
          descricaoCompleta:
              "Este mês, sua intuição é seu superpoder. A linha entre o mundo material e espiritual está mais tênue. Preste atenção aos sinais, sonhos e sincronicidades.",
          tags: ["Intuição", "Espiritualidade", "Inspiração"],
          inspiracao: "A inspiração sussurra, não grita. Ouça com atenção."),
      22: const VibrationContent(
          titulo: "Mês do Construtor Mestre",
          descricaoCurta:
              "Potencial para realizar grandes feitos práticos. Transforme sonhos em realidade concreta.",
          descricaoCompleta:
              "Este é um mês poderoso para tirar grandes ideias do papel e transformá-las em realidade. A energia favorece o planejamento e a execução de projetos ambiciosos e de longo prazo.",
          tags: ["Construção", "Legado", "Praticidade"],
          inspiracao: "Sonhe grande, mas construa com disciplina."),
    },
    'anoPessoal': {
      1: const VibrationContent(
          titulo: "Ano de Recomeço",
          descricaoCurta:
              "Um novo ciclo de 9 anos se inicia. É o ano para plantar as sementes do seu futuro.",
          descricaoCompleta:
              "Você está no ponto de partida de uma nova jornada de nove anos. Este é o momento de ter coragem, iniciar projetos, focar na sua independência e definir as intenções que guiarão seu futuro.",
          tags: ["Novos Inícios", "Independência", "Coragem"],
          inspiracao: "Este é o marco zero da sua próxima grande jornada..."),
      2: const VibrationContent(
          titulo: "Ano de Colaboração",
          descricaoCurta:
              "O foco está nos relacionamentos, parcerias e na paciência. Tempo de cultivar.",
          descricaoCompleta:
              "Depois do impulso inicial do ano passado, agora é tempo de cultivar. O foco está nos relacionamentos, na cooperação e na paciência. O progresso virá através da união e da diplomacia.",
          tags: ["União", "Diplomacia", "Paciência"],
          inspiracao: "Nenhuma semente cresce sozinha. É tempo de cultivar..."),
      3: const VibrationContent(
          titulo: "Ano de Crescimento",
          descricaoCurta:
              "Sua vida social e criativa floresce. É um ano para se comunicar, se expressar e celebrar.",
          descricaoCompleta:
              "Este é um ano de expansão e alegria. Sua vida social ganha destaque, e sua criatividade pede para ser expressa. Comunique-se, conecte-se e não tenha medo de mostrar seus talentos ao mundo.",
          tags: ["Expansão", "Otimismo", "Criatividade"],
          inspiracao: "A vida é uma celebração. É hora de florescer!"),
      4: const VibrationContent(
          titulo: "Ano de Construção",
          descricaoCurta:
              "Trabalho duro, disciplina e organização são as chaves. Um ano para construir bases sólidas.",
          descricaoCompleta:
              "Este é o ano de arregaçar as mangas e construir os alicerces para o seu futuro. Foco, disciplina e trabalho duro são essenciais. Organize suas finanças, sua carreira e sua vida.",
          tags: ["Fundação", "Esforço", "Disciplina"],
          inspiracao: "Construa hoje o castelo onde você viverá amanhã."),
      5: const VibrationContent(
          titulo: "Ano de Transformação",
          descricaoCurta:
              "Prepare-se para mudanças significativas. Um ano de liberdade, viagens e novas experiências.",
          descricaoCompleta:
              "O vento da transformação está soprando forte. Este ano promete mudanças, aventuras e uma sensação de liberdade. Esteja aberto ao inesperado e pronto para se adaptar.",
          tags: ["Mudança", "Aventura", "Liberdade"],
          inspiracao: "A mudança não é o fim, é o começo de algo novo."),
      6: const VibrationContent(
          titulo: "Ano de Responsabilidades",
          descricaoCurta:
              "Questões de família, lar e comunidade vêm à tona. É um ano para nutrir relacionamentos.",
          descricaoCompleta:
              "O foco se volta para o coração, o lar e a comunidade. É um ano de responsabilidades afetivas, de cuidar dos outros e de buscar harmonia em seus relacionamentos mais próximos.",
          tags: ["Harmonia", "Dever", "Família"],
          inspiracao:
              "O amor e o serviço aos outros são as maiores fontes de alegria."),
      7: const VibrationContent(
          titulo: "Ano de Autoavaliação",
          descricaoCurta:
              "Um período de introspecção, estudo e busca por sabedoria. Confie na sua intuição.",
          descricaoCompleta:
              "Este é um ano sabático para a alma. Um convite para desacelerar, refletir, estudar e se conectar com sua sabedoria interior. A busca por respostas e significado está em alta.",
          tags: ["Sabedoria", "Fé", "Introspecção"],
          inspiracao:
              "Para encontrar as respostas, primeiro silencie as perguntas."),
      8: const VibrationContent(
          titulo: "Ano de Colheita",
          descricaoCurta:
              "Poder pessoal, sucesso financeiro e reconhecimento estão em foco. É hora de colher os frutos.",
          descricaoCompleta:
              "Chegou a hora de colher o que você plantou nos últimos sete anos. Este é um ano de poder pessoal, reconhecimento e sucesso material. Assuma o controle de sua carreira e finanças.",
          tags: ["Realização", "Poder", "Abundância"],
          inspiracao: "Você está no comando. É hora de colher os frutos!"),
      9: const VibrationContent(
          titulo: "Ano de Finalização",
          descricaoCurta:
              "O fim de um ciclo de 9 anos. Tempo de limpar, perdoar, desapegar e se preparar para o novo.",
          descricaoCompleta:
              "Você está no final de um grande ciclo. Este é o momento de olhar para trás com gratidão, perdoar, liberar o que não serve mais e limpar o terreno para as novas sementes que você plantará no próximo ano.",
          tags: ["Conclusão", "Perdão", "Liberação"],
          inspiracao: "Todo final é a semente de um novo começo."),
      11: const VibrationContent(
          titulo: "Ano Mestre da Intuição",
          descricaoCurta:
              "Um ano de grande crescimento espiritual, inspiração e revelações. Sua intuição é o seu guia.",
          descricaoCompleta:
              "Este é um ano de grande potencial espiritual. Sua intuição estará mais forte do que nunca, agindo como um farol. Confie em seus insights e esteja aberto a revelações.",
          tags: ["Espiritualidade", "Intuição", "Mestria"],
          inspiracao: "Você é um canal para a sabedoria universal."),
      22: const VibrationContent(
          titulo: "Ano Mestre da Construção",
          descricaoCurta:
              "Potencial para transformar grandes sonhos em realidade tangível. O poder de manifestação está em suas mãos.",
          descricaoCompleta:
              "Este é o 'Ano do Arquiteto'. Você tem a capacidade de pegar uma grande visão e transformá-la em algo concreto e duradouro. Pense grande, mas planeje com cuidado.",
          tags: ["Manifestação", "Legado", "Poder Prático"],
          inspiracao: "Se você pode sonhar, você pode construir."),
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
