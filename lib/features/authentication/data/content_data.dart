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
  /// Textos completos e inspiradores para cada dia favorável do mês (1–31), explicando o significado cabalístico e, para 10–31 (exceto 11 e 22), a redução e seu significado repetido.
  static const Map<int, String> textosDiasFavoraveisLongos = {
    1: 'O dia 1 é o arquétipo do pioneirismo e da liderança na numerologia cabalística. Representa o impulso criador, a força de iniciar novos ciclos e a coragem de trilhar caminhos inéditos. Neste dia, a energia favorece a autoconfiança, a independência e a manifestação da vontade própria. É um convite para assumir o protagonismo da própria vida, confiar em sua intuição e dar o primeiro passo rumo aos seus sonhos.',
    2: 'O dia 2 simboliza a cooperação, a sensibilidade e a busca pela harmonia. Na numerologia cabalística, é o número da diplomacia, da escuta e do equilíbrio entre opostos. Este é um dia para cultivar parcerias, fortalecer laços afetivos e praticar a empatia. A energia do 2 ensina que juntos somos mais fortes e que a verdadeira força reside na união e no respeito mútuo.',
    3: 'O 3 é o número da expressão criativa, da comunicação e da alegria de viver. Representa a expansão, o otimismo e a capacidade de transformar ideias em palavras e ações. Neste dia, a numerologia cabalística inspira a celebrar a vida, compartilhar talentos e buscar leveza nas relações. É um momento propício para socializar, criar e espalhar entusiasmo ao seu redor.',
    4: 'O dia 4 traz a vibração da estabilidade, do trabalho árduo e da construção sólida. Na tradição cabalística, o 4 representa a ordem, a disciplina e a necessidade de estruturar sonhos em bases firmes. É um convite para planejar, organizar e perseverar, sabendo que o sucesso é fruto da dedicação constante. Este é o dia de colocar a casa em ordem e fortalecer as raízes.',
    5: 'O 5 é o número da liberdade, das mudanças e da aventura. Na numerologia cabalística, simboliza a busca por novas experiências, a adaptabilidade e o desejo de romper limites. Este dia favorece a ousadia, a flexibilidade e a abertura para o inesperado. É tempo de experimentar, viajar, aprender e permitir que a vida surpreenda com novas possibilidades.',
    6: 'O dia 6 vibra com a energia do amor, da responsabilidade e do cuidado com o outro. Representa a harmonia familiar, o senso de dever e a busca pelo equilíbrio entre dar e receber. Na numerologia cabalística, o 6 inspira a cultivar laços afetivos, dedicar-se ao lar e praticar a compaixão. É um dia para fortalecer vínculos e promover a paz ao seu redor.',
    7: 'O 7 é o número da introspecção, da espiritualidade e do autoconhecimento. Na tradição cabalística, simboliza a busca pela verdade interior, o estudo e a conexão com o sagrado. Este dia favorece a meditação, a reflexão e o aprofundamento em temas filosóficos ou espirituais. É um convite para silenciar a mente, ouvir a intuição e confiar no fluxo do universo.',
    8: 'O dia 8 traz a energia do poder, da realização material e da prosperidade. Na numerologia cabalística, representa a capacidade de manifestar abundância através do esforço, da liderança e da visão estratégica. É um dia para assumir responsabilidades, tomar decisões importantes e buscar o equilíbrio entre o mundo material e o espiritual. O 8 ensina que a verdadeira riqueza nasce da integridade e do propósito.',
    9: 'O 9 é o número da compaixão, da generosidade e das finalizações. Na tradição cabalística, simboliza o altruísmo, o desapego e a conclusão de ciclos. Este dia favorece o perdão, o serviço ao próximo e a liberação do que não serve mais. É um convite para praticar a empatia, ajudar quem precisa e preparar-se para novos começos.',
    10: 'O dia 10, na numerologia cabalística, reduz-se a 1 (1+0=1), mas carrega uma energia amplificada de liderança e novos começos. O 10 representa o ciclo completo e o renascimento, indicando que você está pronto para iniciar algo grandioso com sabedoria adquirida. É um dia para confiar em seu potencial, agir com coragem e abrir-se para oportunidades inéditas, sabendo que cada fim é também um novo início.',
    11: 'O 11 é um número mestre na numerologia cabalística, símbolo de inspiração, intuição elevada e visão espiritual. Este dia traz uma energia rara e poderosa, favorecendo insights profundos, criatividade e conexão com planos superiores. É um convite para ouvir sua voz interior, confiar em sua sensibilidade e inspirar os outros pelo exemplo. O 11 pede que você acredite em seus sonhos e siga sua missão de alma.',
    12: 'O dia 12 reduz-se a 3 (1+2=3), mas sua energia é intensificada, trazendo uma expressão criativa ainda mais vibrante. Na numerologia cabalística, o 12 representa a superação de desafios através da comunicação e da alegria. É um dia para transformar dificuldades em aprendizado, compartilhar experiências e celebrar a vida com otimismo. Use sua voz para inspirar e unir as pessoas ao seu redor.',
    13: 'O 13 reduz-se a 4 (1+3=4), mas carrega um significado especial de transformação e reconstrução. Na numerologia cabalística, o 13 representa a necessidade de superar obstáculos através do trabalho disciplinado e da resiliência. É um dia para reconstruir estruturas, aprender com os erros e persistir diante das adversidades. O 13 ensina que toda transformação exige esforço, mas traz recompensas duradouras.',
    14: 'O dia 14 reduz-se a 5 (1+4=5), intensificando a energia da liberdade e da mudança. Na tradição cabalística, o 14 simboliza a busca pelo equilíbrio entre prazer e responsabilidade. É um dia para experimentar novidades, mas com consciência e moderação. O 14 ensina que a verdadeira liberdade nasce do autodomínio e da capacidade de adaptar-se sem perder o foco.',
    15: 'O 15 reduz-se a 6 (1+5=6), trazendo uma vibração de amor, harmonia e responsabilidade ampliada. Na numerologia cabalística, o 15 representa o poder de curar relações e promover a paz através do afeto. É um dia para cuidar de quem ama, resolver conflitos e fortalecer os laços familiares. O 15 inspira a buscar equilíbrio entre o desejo pessoal e o bem-estar coletivo.',
    16: 'O dia 16 reduz-se a 7 (1+6=7), mas sua energia é marcada por profundas transformações e aprendizados espirituais. Na tradição cabalística, o 16 representa a necessidade de desapego e autoconhecimento. É um dia para refletir sobre escolhas, buscar respostas dentro de si e confiar no processo de evolução. O 16 ensina que as maiores lições vêm dos desafios e que a verdadeira força é interior.',
    17: 'O 17 reduz-se a 8 (1+7=8), intensificando a energia da realização e do poder pessoal. Na numerologia cabalística, o 17 simboliza conquistas materiais alcançadas com ética e propósito. É um dia para assumir o controle do próprio destino, tomar decisões estratégicas e manifestar prosperidade. O 17 lembra que o sucesso é fruto da integridade e do trabalho consciente.',
    18: 'O 18 reduz-se a 9 (1+8=9), trazendo uma vibração de compaixão, altruísmo e finalizações importantes. Na tradição cabalística, o 18 representa a necessidade de desapegar do passado e servir ao próximo. É um dia para praticar a generosidade, perdoar e encerrar ciclos com gratidão. O 18 ensina que ao liberar o que não serve mais, abrimos espaço para o novo.',
    19: 'O dia 19 reduz-se a 1 (1+9=10, 1+0=1), mas carrega uma energia de liderança renovada e superação de desafios. Na numerologia cabalística, o 19 representa a vitória após provações e a capacidade de recomeçar com mais sabedoria. É um dia para confiar em si mesmo, assumir responsabilidades e iniciar projetos com determinação. O 19 inspira a transformar obstáculos em oportunidades.',
    20: 'O 20 reduz-se a 2 (2+0=2), intensificando a energia da cooperação e da sensibilidade. Na tradição cabalística, o 20 simboliza a importância das relações e do apoio mútuo. É um dia para fortalecer parcerias, praticar a empatia e buscar harmonia em todos os ambientes. O 20 ensina que juntos podemos alcançar mais e que a verdadeira força está na união.',
    21: 'O 21 reduz-se a 3 (2+1=3), trazendo uma expressão criativa ampliada e alegria contagiante. Na numerologia cabalística, o 21 representa a realização através da comunicação e do otimismo. É um dia para celebrar conquistas, compartilhar ideias e inspirar os outros com sua energia positiva. O 21 lembra que a felicidade se multiplica quando é dividida.',
    22: 'O 22 é um número mestre na numerologia cabalística, símbolo de construção, legado e grandes realizações. Este dia traz uma energia poderosa para manifestar sonhos em larga escala, unir pessoas em torno de um propósito e deixar uma marca duradoura no mundo. O 22 pede visão, responsabilidade e compromisso com o bem coletivo. É um convite para agir com grandeza e construir algo que beneficie a todos.',
    23: 'O 23 reduz-se a 5 (2+3=5), intensificando a energia da liberdade, da versatilidade e da comunicação. Na tradição cabalística, o 23 representa a capacidade de adaptar-se rapidamente e de influenciar positivamente o ambiente. É um dia para buscar novas experiências, aprender com a diversidade e expressar-se com autenticidade. O 23 ensina que a flexibilidade é a chave para o crescimento.',
    24: 'O dia 24 reduz-se a 6 (2+4=6), trazendo uma vibração de cuidado, harmonia e responsabilidade familiar ampliada. Na numerologia cabalística, o 24 simboliza o poder de criar ambientes acolhedores e promover a paz. É um dia para dedicar-se ao lar, fortalecer vínculos e praticar a generosidade. O 24 inspira a buscar equilíbrio entre o eu e o outro.',
    25: 'O 25 reduz-se a 7 (2+5=7), intensificando a energia da introspecção, do estudo e da busca espiritual. Na tradição cabalística, o 25 representa a necessidade de aprofundar o autoconhecimento e confiar na intuição. É um dia para meditar, pesquisar e buscar respostas além da superfície. O 25 ensina que a sabedoria nasce do silêncio e da observação.',
    26: 'O 26 reduz-se a 8 (2+6=8), trazendo uma vibração de poder, realização e prosperidade ampliada. Na numerologia cabalística, o 26 simboliza a capacidade de liderar com justiça e manifestar abundância para si e para os outros. É um dia para tomar decisões importantes, assumir responsabilidades e agir com ética. O 26 lembra que a verdadeira riqueza é compartilhada.',
    27: 'O 27 reduz-se a 9 (2+7=9), intensificando a energia da compaixão, do altruísmo e das finalizações. Na tradição cabalística, o 27 representa a conclusão de ciclos importantes e o serviço ao próximo. É um dia para praticar o desapego, ajudar quem precisa e preparar-se para novos começos. O 27 ensina que ao servir, também somos transformados.',
    28: 'O dia 28 reduz-se a 1 (2+8=10, 1+0=1), trazendo uma energia de liderança renovada e capacidade de recomeçar. Na numerologia cabalística, o 28 simboliza a superação de desafios através da iniciativa e da coragem. É um dia para assumir o comando, confiar em seu potencial e iniciar projetos com determinação. O 28 inspira a transformar experiências em sabedoria.',
    29: 'O 29 reduz-se a 2 (2+9=11, número mestre), mas também pode ser visto como uma energia de sensibilidade e inspiração ampliada. Na tradição cabalística, o 29 favorece a intuição, a empatia e a conexão com planos superiores. É um dia para ouvir a voz interior, praticar a compaixão e inspirar os outros pelo exemplo. O 29 lembra que a verdadeira força está na sensibilidade.',
    30: 'O 30 reduz-se a 3 (3+0=3), trazendo uma expressão criativa e comunicativa ainda mais intensa. Na numerologia cabalística, o 30 representa a capacidade de inspirar, ensinar e alegrar o ambiente. É um dia para compartilhar ideias, celebrar conquistas e motivar as pessoas ao seu redor. O 30 ensina que a alegria é contagiante e transforma realidades.',
    31: 'O 31 reduz-se a 4 (3+1=4), trazendo uma energia de construção, disciplina e realização prática ampliada. Na tradição cabalística, o 31 simboliza a capacidade de transformar sonhos em realidade através do trabalho constante e da organização. É um dia para planejar, agir com responsabilidade e consolidar conquistas. O 31 lembra que o sucesso é construído passo a passo.',
  };

  /// Textos para cada dia favorável do mês (1–31), baseados em arquétipos cabalísticos
  static const Map<int, String> textosDiasFavoraveis = {
    1: 'Dia de liderança, iniciativa e novos começos. Tome a frente e confie em si mesmo.',
    2: 'Dia de cooperação, diplomacia e sensibilidade. Busque parcerias e harmonia.',
    3: 'Dia de criatividade, comunicação e alegria. Expresse-se e socialize.',
    4: 'Dia de organização, trabalho e disciplina. Estruture seus planos e seja prático.',
    5: 'Dia de mudanças, liberdade e movimento. Experimente algo novo e seja flexível.',
    6: 'Dia de cuidado, família e responsabilidade. Dedique-se ao lar e aos próximos.',
    7: 'Dia de introspecção, estudo e espiritualidade. Reserve tempo para si e reflita.',
    8: 'Dia de poder, realização e prosperidade. Foque em resultados e negócios.',
    9: 'Dia de compaixão, finalizações e altruísmo. Pratique o desapego e ajude o próximo.',
    10: 'Dia de liderança, iniciativa e novos começos. Tome a frente e confie em si mesmo.', // 1
    11: 'Dia de inspiração, intuição e visão espiritual. Siga sua voz interior e inspire outros.',
    12: 'Dia de criatividade, comunicação e alegria. Expresse-se e socialize.', // 3
    13: 'Dia de organização, trabalho e disciplina. Estruture seus planos e seja prático.', // 4
    14: 'Dia de mudanças, liberdade e movimento. Experimente algo novo e seja flexível.', // 5
    15: 'Dia de cuidado, família e responsabilidade. Dedique-se ao lar e aos próximos.', // 6
    16: 'Dia de introspecção, estudo e espiritualidade. Reserve tempo para si e reflita.', // 7
    17: 'Dia de poder, realização e prosperidade. Foque em resultados e negócios.', // 8
    18: 'Dia de compaixão, finalizações e altruísmo. Pratique o desapego e ajude o próximo.', // 9
    19: 'Dia de liderança, iniciativa e novos começos. Tome a frente e confie em si mesmo.', // 1
    20: 'Dia de cooperação, diplomacia e sensibilidade. Busque parcerias e harmonia.', // 2
    21: 'Dia de criatividade, comunicação e alegria. Expresse-se e socialize.', // 3
    22: 'Dia de construção, legado e grandes realizações. Pense grande e aja com propósito.',
    23: 'Dia de mudanças, liberdade e movimento. Experimente algo novo e seja flexível.', // 5
    24: 'Dia de cuidado, família e responsabilidade. Dedique-se ao lar e aos próximos.', // 6
    25: 'Dia de introspecção, estudo e espiritualidade. Reserve tempo para si e reflita.', // 7
    26: 'Dia de poder, realização e prosperidade. Foque em resultados e negócios.', // 8
    27: 'Dia de compaixão, finalizações e altruísmo. Pratique o desapego e ajude o próximo.', // 9
    28: 'Dia de liderança, iniciativa e novos começos. Tome a frente e confie em si mesmo.', // 1
    29: 'Dia de cooperação, diplomacia e sensibilidade. Busque parcerias e harmonia.', // 2
    30: 'Dia de criatividade, comunicação e alegria. Expresse-se e socialize.', // 3
    31: 'Dia de organização, trabalho e disciplina. Estruture seus planos e seja prático.', // 4
  };
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

  // REMOVIDO: Textos para Arcanos – funcionalidade descontinuada.

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

  // CICLOS DE VIDA (1–9) — grandes fases e capítulos da existência
  static final Map<int, VibrationContent> textosCiclosDeVida = {
    1: const VibrationContent(
      titulo: 'O Início',
      descricaoCurta:
          'Fase de novos começos, independência e afirmação pessoal.',
      descricaoCompleta:
          'Este ciclo aponta para uma fase da vida na qual as melhores oportunidades surgem pela sua iniciativa pessoal, coragem e independência. É um período para começar novos projetos, para assumir a liderança e para se afirmar no mundo com originalidade. O progresso dependerá unicamente da aplicação dos seus próprios recursos e da sua força de vontade.\n\nDe certa maneira, este pode ser um ciclo em que você se sentirá mais sozinho(a) em suas decisões, pois o chamado é para a autossuficiência. As associações tendem a se estabelecer a partir de sua própria iniciativa, mas isso não significa solidão, e sim a necessidade de empreender por conta própria e de confiar em seus instintos pioneiros.\n\nAbrace este tempo como uma oportunidade para se descobrir como um(a) líder. Seja no início da vida, aprendendo a ser independente, ou na maturidade, começando um novo capítulo, a energia é de começos. A colheita futura dependerá da coragem com que você planta suas sementes agora.',
      inspiracao: 'Este é o alvorecer de uma nova era em sua vida.',
      tags: ['Iniciativa', 'Independência', 'Começos'],
    ),
    2: const VibrationContent(
      titulo: 'A Parceria',
      descricaoCurta:
          'Fase de sensibilidade, cooperação e desenvolvimento de parcerias.',
      descricaoCompleta:
          'Este ciclo de vida indica um período de muita sensibilidade, cooperação e desenvolvimento de parcerias. Na infância, pode representar uma forte ligação com a figura materna ou a necessidade de um ambiente familiar harmonioso. Na vida adulta, é uma fase onde o progresso vem através da diplomacia, do trabalho em equipe e da paciência.\n\nÉ um tempo para aprender a arte de colaborar, de ouvir e de ser paciente. As conquistas tendem a ser resultado de uniões e associações, e não de esforços solitários. Na juventude, pode haver uma inclinação para buscar segurança em um relacionamento ou casamento precoce. O desenvolvimento da afeição através de amizades e relações diversas será uma constante.\n\nO grande aprendizado deste ciclo é desenvolver a autoconfiança para não se tornar excessivamente dependente dos outros. Use sua sensibilidade para construir pontes e harmonizar ambientes, mas sem nunca se anular. É um período para crescer através do toque suave e da força tranquila da cooperação.',
      inspiracao:
          'Depois de plantar suas sementes, aprenda a cultivar com os outros.',
      tags: ['Cooperação', 'Paciência', 'Relações'],
    ),
    3: const VibrationContent(
      titulo: 'A Criatividade',
      descricaoCurta:
          'Fase de expansão social, expressão criativa e vida vibrante.',
      descricaoCompleta:
          'Este ciclo representa um período de expansão, criatividade e intensa vida social. É uma fase marcada pela necessidade de se expressar, de se comunicar e de usar seus talentos de forma otimista e alegre. As oportunidades de progresso surgirão através das suas amizades, do seu carisma e da sua capacidade de inspirar os outros.\n\nNa juventude, pode ser um período de popularidade e de muitas atividades sociais, mas com o desafio de não dispersar as energias. Na maturidade, é uma fase para colher os frutos da sua criatividade, para viajar, para ensinar e para desfrutar de uma vida mais leve e cheia de beleza. As artes e a comunicação estarão em evidência.\n\nAbrace a alegria e a espontaneidade deste ciclo. Permita-se criar, socializar e expressar seus dons únicos. O desafio é manter o foco em seus objetivos para que toda essa energia vibrante se transforme em realizações concretas e não apenas em diversão passageira.',
      inspiracao: 'Este ciclo é uma celebração da sua expressão única.',
      tags: ['Expressão', 'Otimismo', 'Sociabilidade'],
    ),
    4: const VibrationContent(
      titulo: 'A Construção',
      descricaoCurta:
          'Fase de trabalho árduo, disciplina e edificação de bases sólidas.',
      descricaoCompleta:
          'Este ciclo de vida é um chamado para o trabalho, a disciplina e a construção de bases sólidas para o futuro. É um período de esforço concentrado, onde a organização, a praticidade e a persistência serão as chaves para o sucesso. As oportunidades virão através da sua dedicação e da sua capacidade de transformar planos em realidade.\n\nSeja na juventude, focado(a) nos estudos e no início da carreira, ou na vida adulta, construindo um patrimônio, esta fase exige responsabilidade e pés no chão. Não é um tempo para atalhos ou para a sorte, mas sim para o trabalho metódico que gera segurança e estabilidade duradouras.\n\nEncare este período como a fundação da sua casa. Cada tijolo assentado com esforço e honestidade garantirá a solidez da sua estrutura para os ciclos futuros. O desafio é não se tornar excessivamente rígido(a) ou workaholic. Encontre tempo para o descanso, pois ele também faz parte de uma construção saudável.',
      inspiracao: 'Tijolo por tijolo, você constrói o alicerce de seu futuro.',
      tags: ['Trabalho', 'Disciplina', 'Segurança'],
    ),
    5: const VibrationContent(
      titulo: 'A Liberdade',
      descricaoCurta:
          'Fase de mudanças constantes, aventuras e expansão de horizontes.',
      descricaoCompleta:
          'Este ciclo ambienta uma fase do destino na qual a expansão dos horizontes ocorre através de constantes mudanças, viagens e novas experiências. É um período de grande liberdade, aventuras e inovações, onde o progresso depende da sua versatilidade e dinamismo para lidar com um ambiente volátil e propenso a reviravoltas.\n\nAs melhores oportunidades de progresso podem surgir longe de casa, talvez em outra cidade ou país, exigindo de você uma grande capacidade de adaptação. É um tempo para se libertar de velhos padrões, para explorar novas relações e para aprender através da experiência direta com o mundo.\n\nAbrace o movimento e a mudança como seus maiores aliados neste ciclo. O desafio é usar essa imensa liberdade com responsabilidade, evitando a impulsividade e a inconstância. Ao canalizar essa energia de mudança para o seu crescimento pessoal e profissional, você viverá um dos períodos mais estimulantes e evolutivos da sua vida.',
      inspiracao: 'Mudança é evolução; abrace-a com coragem e consciência.',
      tags: ['Mudança', 'Liberdade', 'Aventura'],
    ),
    6: const VibrationContent(
      titulo: 'A Harmonia',
      descricaoCurta:
          'Fase de responsabilidades familiares, amor e serviço à comunidade.',
      descricaoCompleta:
          'Este ciclo de vida coloca em foco as responsabilidades familiares, o amor e o serviço à comunidade. É um período em que os relacionamentos, o lar e a busca pela harmonia terão um papel central em seu desenvolvimento. As oportunidades de progresso estarão diretamente ligadas à sua capacidade de cuidar, de aconselhar e de criar um ambiente de paz.\n\nSeja na juventude, com a formação de uma nova família, ou na maturidade, assumindo um papel de matriarca ou patriarca, esta fase exige um grande senso de justiça e dedicação. O casamento, os filhos, o cuidado com os pais ou o envolvimento em causas comunitárias serão temas recorrentes.\n\nSua realização neste ciclo virá do amor que você doa e recebe. O desafio é encontrar o equilíbrio entre as necessidades dos outros e as suas próprias, para não se anular. Ao se tornar um pilar de estabilidade e afeto, você constrói laços profundos e encontra uma felicidade genuína e duradoura.',
      inspiracao: 'O lar que você cuida hoje é o refúgio de amanhã.',
      tags: ['Família', 'Harmonia', 'Serviço'],
    ),
    7: const VibrationContent(
      titulo: 'A Sabedoria',
      descricaoCurta:
          'Fase de introspecção, estudo profundo e busca espiritual.',
      descricaoCompleta:
          'Este ciclo representa um período de introspecção, estudo e busca por um sentido mais profundo para a vida. É uma fase de desenvolvimento interior, onde o foco se volta do mundo externo para o seu universo pessoal. As oportunidades de progresso virão através do conhecimento, da especialização e do aprimoramento de suas habilidades.\n\nÉ um tempo para se questionar, para meditar e para buscar a verdade por trás das aparências. A espiritualidade, a ciência ou a filosofia podem se tornar áreas de grande interesse. Pode ser um período mais solitário, não por tristeza, mas por uma necessidade da alma de se recolher para poder crescer.\n\nAbrace este chamado para a sabedoria. Invista em si mesmo(a), estude, viaje para lugares que alimentem sua alma. O desafio é não se isolar completamente do mundo. Ao final deste ciclo, você emergirá com uma profundidade e uma fé inabaláveis, pronto(a) para compartilhar sua luz com o mundo.',
      inspiracao: 'No silêncio da alma, você encontra as maiores respostas.',
      tags: ['Sabedoria', 'Introspecção', 'Espiritualidade'],
    ),
    8: const VibrationContent(
      titulo: 'O Poder',
      descricaoCurta:
          'Fase de grandes realizações materiais, poder e reconhecimento.',
      descricaoCompleta:
          'Este é um ciclo de poder, ambição e grandes realizações no mundo material. É uma fase da vida em que você terá a oportunidade de assumir posições de autoridade, de lidar com finanças e de executar projetos de grande porte. O sucesso e o reconhecimento profissional estarão ao seu alcance, exigindo de você ética e justiça.\n\nA vida lhe trará a chance de colher os frutos de seus esforços passados. O poder de manifestação estará acentuado, mas também a responsabilidade por suas ações. É um período para aprender a equilibrar a ambição material com os valores espirituais, usando sua influência para o progresso coletivo.\n\nAssuma seu poder pessoal com confiança e integridade. Este é o seu momento de construir, de prosperar e de liderar. O desafio é não se deixar levar pelo materialismo ou pelo autoritarismo. Ao usar sua força com sabedoria e generosidade, você alcançará um sucesso que é não apenas abundante, mas também significativo.',
      inspiracao: 'Poder com ética constrói impérios; sem ela, ruínas.',
      tags: ['Poder', 'Realização', 'Abundância'],
    ),
    9: const VibrationContent(
      titulo: 'A Síntese',
      descricaoCurta:
          'Fase de finalizações, humanitarismo e sabedoria compassiva.',
      descricaoCompleta:
          'Este ciclo marca um período de finalizações, de humanitarismo e de grande sabedoria. É uma fase para concluir projetos, para resolver pendências do passado e para se desapegar do que não serve mais ao seu crescimento. As oportunidades de progresso virão através da sua compaixão, generosidade e do serviço altruísta.\n\nÉ um tempo de grande expansão da consciência, onde você desenvolverá uma visão mais universal da vida. Viagens, contato com diferentes culturas e o envolvimento em causas sociais podem ser proeminentes. Sua missão será a de ensinar, de curar e de inspirar os outros com seu amor incondicional.\n\nAbrace este ciclo como uma grande oportunidade de limpeza e de evolução espiritual. Perdoe, liberte-se e prepare-se para um novo começo em um patamar mais elevado. Ao se dedicar ao bem da humanidade, você encontrará a mais profunda realização e completará um importante capítulo de sua jornada.',
      inspiracao: 'Finalize com amor; o novo ciclo virá ainda mais elevado.',
      tags: ['Finalização', 'Humanitarismo', 'Sabedoria'],
    ),
  };

  // --- NOVOS CONTEÚDOS (substituem dependências ausentes) ---

  // DIA NATALÍCIO (1–31) — essência e traços natos do dia de nascimento
  static final Map<int, VibrationContent> textosDiaNatalicio = {
    1: const VibrationContent(
      titulo: 'O Pioneiro',
      descricaoCurta:
          'Essência de liderança, originalidade e independência nata.',
      descricaoCompleta:
          'Sua essência é a da liderança, da originalidade e da independência. Você carrega a marca do pioneirismo, com uma necessidade inata de criar, de inovar e de estar no controle do seu próprio caminho. Sua força de vontade é sua maior aliada, impulsionando-o(a) a superar qualquer obstáculo com coragem e determinação.\n\nVocê não nasceu para seguir, mas para guiar. Sua natureza é proativa e ambiciosa, sempre em busca de novos desafios que testem seus limites. A energia do número 1 lhe confere um carisma natural de líder, e as pessoas tendem a se inspirar em sua autoconfiança e em sua capacidade de transformar ideias em ação.\n\nSeu aprendizado ao longo da vida é equilibrar essa poderosa individualidade com a arte de cooperar. Aprender a ouvir e a valorizar a opinião dos outros não diminui sua força, pelo contrário, torna sua liderança ainda mais sábia e eficaz. Abrace sua natureza pioneira e use-a para iluminar o caminho.',
      inspiracao: 'Você nasceu para liderar; lidere com sabedoria.',
      tags: ['Pioneirismo', 'Liderança', 'Independência'],
    ),
    2: const VibrationContent(
      titulo: 'O Diplomata',
      descricaoCurta:
          'Essência de cooperação, sensibilidade e união harmoniosa.',
      descricaoCompleta:
          'A marca do seu nascimento é a da cooperação, da diplomacia e da sensibilidade. Sua essência verdadeira busca a harmonia e a união, e você possui um dom inato para atuar como pacificador(a), unindo pessoas e resolvendo conflitos com uma gentileza única. Sua força não está na imposição, mas na sua capacidade de persuadir e colaborar.\n\nVocê é uma pessoa naturalmente atenta aos detalhes e aos sentimentos alheios, o que faz de você um(a) amigo(a) e parceiro(a) extremamente leal e compreensivo(a). Sua natureza é a de somar, de apoiar e de trabalhar em equipe, encontrando grande satisfação em conquistas compartilhadas.\n\nSeu caminho de evolução envolve o desenvolvimento da autoconfiança e a valorização da sua própria voz. Sua tendência natural é colocar as necessidades dos outros em primeiro lugar, mas é crucial que você aprenda a impor seus limites. Ao fazer isso, sua natureza diplomática se torna sua maior fortaleza.',
      inspiracao: 'Gentileza que impõe limites é sabedoria.',
      tags: ['Diplomacia', 'Sensibilidade', 'Cooperação'],
    ),
    3: const VibrationContent(
      titulo: 'O Criador',
      descricaoCurta:
          'Essência criativa, comunicativa e alegre; dom da expressão.',
      descricaoCompleta:
          'Você nasceu sob a vibração da criatividade, da comunicação e do otimismo. Sua essência é alegre, sociável e expressiva, e você possui um dom natural para usar as palavras e as artes para encantar e inspirar as pessoas. A beleza e a alegria de viver são valores fundamentais para você.\n\nSua mente é ágil e cheia de ideias, e você tem a capacidade de enxergar o lado positivo das situações. Seu carisma natural atrai amigos e oportunidades, e você se sente realizado(a) em ambientes onde pode interagir, se expressar e compartilhar seu entusiasmo contagiante com o mundo.\n\nO seu grande aprendizado está em canalizar essa imensa energia criativa com foco e um pouco de disciplina. A tendência à dispersão pode ser seu maior desafio. Ao se comprometer com seus projetos e aprofundar seus talentos, você transforma seu potencial brilhante em realizações concretas e inspiradoras.',
      inspiracao: 'Criatividade focada torna-se genialidade.',
      tags: ['Criatividade', 'Comunicação', 'Otimismo'],
    ),
    4: const VibrationContent(
      titulo: 'O Construtor',
      descricaoCurta:
          'Essência de estabilidade, trabalho árduo e bases sólidas.',
      descricaoCompleta:
          'A sua essência é a da estabilidade, da organização e do trabalho. Você nasceu com a marca da responsabilidade e da confiança, e possui uma capacidade inata para construir bases sólidas e seguras em todas as áreas da vida. A persistência e a honestidade são os pilares do seu caráter.\n\nSua natureza é prática e metódica. Você se sente em paz quando está trabalhando de forma disciplinada em direção a um objetivo claro. Não teme o esforço e encontra grande satisfação em ver o resultado concreto de sua dedicação. As pessoas confiam em você por sua lealdade e seu senso de dever.\n\nSeu caminho de crescimento passa por aprender a ser mais flexível e a se permitir momentos de descanso e lazer. A rigidez e a teimosia podem ser desafios a serem superados. Ao equilibrar seu lado trabalhador com a espontaneidade, você constrói uma vida não apenas segura, mas também plena e feliz.',
      inspiracao: 'Esforço honesto constrói legados eternos.',
      tags: ['Construção', 'Disciplina', 'Estabilidade'],
    ),
    5: const VibrationContent(
      titulo: 'O Aventureiro',
      descricaoCurta:
          'Essência de liberdade, versatilidade e constante exploração.',
      descricaoCompleta:
          'A marca do seu nascimento é a da liberdade, da versatilidade e da aventura. Sua essência é curiosa, magnética e está em constante busca por novas experiências, conhecimentos e sensações. Você nasceu para explorar o mundo, quebrar rotinas e se adaptar às mais diversas situações com agilidade e inteligência.\n\nSua natureza é inquieta e comunicativa. Você precisa de movimento e de estímulos constantes para se sentir vivo(a). A mudança não o(a) assusta, pelo contrário, ela o(a) atrai. Seu carisma e sua facilidade de se conectar com as pessoas abrem inúmeras portas em sua jornada.\n\nSeu aprendizado de vida é usar essa imensa liberdade com responsabilidade e foco. A impulsividade e a inconstância podem ser seus maiores desafios. Ao canalizar sua energia de mudança para um propósito de crescimento e aprendizado, você transforma sua vida em uma aventura fascinante e cheia de evolução.',
      inspiracao: 'Liberdade com propósito é verdadeira aventura.',
      tags: ['Liberdade', 'Aventura', 'Versatilidade'],
    ),
    6: const VibrationContent(
      titulo: 'O Cuidador',
      descricaoCurta:
          'Essência de amor, harmonia familiar e responsabilidade afetiva.',
      descricaoCompleta:
          'Você nasceu sob a vibração do amor, da harmonia e da responsabilidade. Sua essência é a de um(a) cuidador(a) e conselheiro(a) nato(a), com um forte senso de justiça e um profundo desejo de criar paz e beleza em seu lar e em sua comunidade. O bem-estar da sua família e dos seus entes queridos é sua maior prioridade.\n\nSua natureza é afetuosa, idealista e protetora. Você tem um dom natural para nutrir, para ensinar e para resolver conflitos de forma equilibrada. Sente uma grande satisfação em servir e em assumir responsabilidades que visem o bem comum. Sua presença traz conforto e segurança para as pessoas.\n\nO seu caminho de evolução está em aprender a equilibrar o cuidado com os outros e o autocuidado. A tendência a se sacrificar pode gerar frustrações. Lembre-se de que, para cuidar bem dos outros, você precisa primeiro estar bem. Ao amar com equilíbrio, você se torna uma fonte inesgotável de harmonia e afeto.',
      inspiracao: 'Cuidar de si é amar os outros com integridade.',
      tags: ['Amor', 'Harmonia', 'Responsabilidade'],
    ),
    7: const VibrationContent(
      titulo: 'O Sábio',
      descricaoCurta:
          'Essência analítica, introspectiva e buscadora da verdade.',
      descricaoCompleta:
          'Sua essência é a do(a) pensador(a), do(a) especialista e do(a) buscador(a) da verdade. Você nasceu com a marca da introspecção e da análise, e possui uma mente investigativa que não se contenta com respostas superficiais. A busca pelo conhecimento e pela perfeição é o que move a sua alma.\n\nSua natureza é seletiva e reservada. Você valoriza a qualidade em vez da quantidade, seja em amizades ou em seus interesses. A solidão não o(a) assusta, pois é nela que você encontra clareza e se conecta com sua poderosa intuição. Sua presença transmite uma aura de mistério e sabedoria.\n\nSeu caminho de crescimento envolve aprender a compartilhar seu vasto mundo interior sem medo da vulnerabilidade. A tendência ao isolamento e a uma crítica excessiva podem ser seus maiores desafios. Ao confiar mais nos outros e ao unir sua mente brilhante com um coração aberto, você se torna um verdadeiro farol de conhecimento.',
      inspiracao: 'Sabedoria compartilhada multiplica-se.',
      tags: ['Sabedoria', 'Introspecção', 'Análise'],
    ),
    8: const VibrationContent(
      titulo: 'O Executor',
      descricaoCurta:
          'Essência de poder, justiça e capacidade realizadora material.',
      descricaoCompleta:
          'Você nasceu sob a vibração do poder, da justiça e da ambição realizadora. Sua essência é a de um(a) líder nato(a), com uma incrível capacidade de organização, administração e execução. Você tem um talento natural para o mundo material e para transformar grandes visões em empreendimentos de sucesso.\n\nSua natureza é forte, determinada e com um aguçado senso de justiça. Você não teme a responsabilidade e se sente à vontade em posições de autoridade, onde pode exercer sua capacidade de tomar decisões firmes e estratégicas. O sucesso material é importante para você, pois o vê como uma ferramenta para a segurança e o progresso.\n\nSeu aprendizado de vida está em equilibrar seu poder e sua ambição com a generosidade e a ética. A tendência ao autoritarismo ou à obsessão pelo trabalho pode ser um desafio. Ao usar sua força para construir e liderar com integridade e justiça, você não apenas alcança a prosperidade, mas também constrói um legado de respeito e admiração.',
      inspiracao: 'Poder ético constrói impérios duradouros.',
      tags: ['Poder', 'Justiça', 'Realização'],
    ),
    9: const VibrationContent(
      titulo: 'O Humanitário',
      descricaoCurta:
          'Essência compassiva, idealista e dedicada ao bem coletivo.',
      descricaoCompleta:
          'A marca do seu nascimento é a da compaixão, do humanitarismo e do amor universal. Sua essência é a de um(a) grande professor(a), artista e conselheiro(a), com uma visão ampla da vida e um profundo desejo de servir à humanidade. Você é um(a) idealista que sonha e trabalha por um mundo melhor.\n\nSua natureza é generosa, tolerante e extremamente sensível. Você se conecta facilmente com pessoas de todas as origens e sente as dores do mundo de forma muito intensa. O perdão e a doação são qualidades inatas em você, e sua presença inspira os outros a serem mais compreensivos e altruístas.\n\nSeu caminho de evolução envolve aprender a viver seus ideais no mundo prático sem se desiludir ou se esgotar. É crucial que você aprenda a estabelecer limites saudáveis e a cuidar de si mesmo(a) com a mesma compaixão que dedica aos outros. Ao fazer isso, seu amor se torna uma força de cura poderosa e inesgotável.',
      inspiracao: 'Compaixão sustentável transforma o mundo.',
      tags: ['Compaixão', 'Humanitarismo', 'Idealismo'],
    ),
    10: const VibrationContent(
      titulo: 'O Líder Intuitivo',
      descricaoCurta:
          'Liderança pioneira amplificada pela intuição e potencial infinito.',
      descricaoCompleta:
          'Sua essência combina a liderança pioneira do número 1 com o potencial infinito do zero. Você nasceu para ser um(a) líder carismático(a) e inspirador(a), mas sua liderança tem uma qualidade mais intuitiva e espiritual. Você tem a capacidade de iniciar grandes projetos que parecem vir de uma fonte superior de inspiração.\n\nVocê carrega a força e a independência do 1, mas o 0 o(a) torna mais adaptável e conectado(a) com as necessidades do todo. As pessoas são atraídas por sua confiança e por sua aparente conexão com um propósito maior. Sua jornada é sobre aprender a confiar plenamente nessa intuição e a usá-la como guia.\n\nSeu desafio é superar as dualidades internas: a vontade de agir do 1 e a passividade do 0. Quando você integra essas energias, torna-se um(a) líder visionário(a), capaz de manifestar ideias inovadoras com coragem e sensibilidade, abrindo caminhos não apenas para si, mas para muitos.',
      inspiracao: 'Intuição com ação manifesta milagres.',
      tags: ['Liderança', 'Intuição', 'Potencial'],
    ),
    11: const VibrationContent(
      titulo: 'O Mensageiro',
      descricaoCurta:
          'Número Mestre: essência de inspiração espiritual e visão elevada.',
      descricaoCompleta:
          'Você nasceu sob a influência de um Número Mestre, o que indica um grande potencial espiritual e um caminho de vida incomum. Sua essência é a de um(a) "mensageiro(a) espiritual", com uma intuição extremamente aguçada, dons psíquicos e uma capacidade inata de inspirar e elevar a consciência das pessoas.\n\nSua natureza é a do visionário, do idealista e do diplomata. Você carrega a sensibilidade do número 2 (1+1=2) elevada a uma oitava superior. Sua jornada envolve aprender a lidar com uma imensa tensão nervosa e a confiar em suas visões, mesmo que pareçam ilógicas para os outros. Você veio para ser um canal de luz e de revelação.\n\nSeu grande desafio é viver com os pés no chão sem perder sua conexão com o céu. É preciso encontrar um equilíbrio entre o mundo material e o espiritual. Ao aceitar sua missão de guia e inspirador(a) e ao viver com integridade, você tem o potencial de impactar positivamente a vida de milhares de pessoas e de alcançar uma profunda iluminação.',
      inspiracao: 'Você é canal de luz; ilumine sem queimar.',
      tags: ['Inspiração', 'Espiritualidade', 'Visão'],
    ),
    12: const VibrationContent(
      titulo: 'O Artista Colaborador',
      descricaoCurta:
          'Liderança + cooperação = criatividade; dom de colaboração artística.',
      descricaoCompleta:
          'Sua essência combina a liderança do 1 com a cooperação do 2, resultando na criatividade e expressão do 3 (1+2=3). Você é um(a) artista nato(a), com um dom especial para a colaboração criativa. Sua natureza é sociável e otimista, e você tem a rara habilidade de unir as pessoas através da arte e da comunicação.\n\nVocê não é um(a) criador(a) solitário(a); sua genialidade brilha mais forte quando está em parceria ou em equipe. Você sabe como liderar com gentileza (1 e 2) e como expressar ideias complexas de forma simples e cativante (3). Sua presença é leve e inspiradora, e você tem um talento para transformar qualquer ambiente em um lugar mais alegre.\n\nSeu caminho de aprendizado envolve superar a autocrítica e a indecisão, que podem surgir da dualidade entre o desejo de liderar (1) e a necessidade de agradar (2). Ao confiar em sua capacidade de se expressar autenticamente, você encontra sua força e se torna uma fonte de alegria e de criatividade para todos ao seu redor.',
      inspiracao: 'Criatividade compartilhada multiplica a beleza.',
      tags: ['Criatividade', 'Colaboração', 'Expressão'],
    ),
    13: const VibrationContent(
      titulo: 'O Transformador',
      descricaoCurta:
          'Débito cármico: poder de superação através do trabalho disciplinado.',
      descricaoCompleta:
          'Sua natureza essencial é marcada por um intenso poder de transformação e um chamado para o trabalho árduo e a disciplina. Você possui uma força interior e uma capacidade de superação admiráveis, sendo capaz de se reerguer das situações mais difíceis com uma resiliência impressionante. A vida constantemente o(a) convida a "morrer" para o velho e a renascer para o novo.\n\nA vibração do 13 traz consigo um débito cármico relacionado à preguiça ou ao mau uso da força de trabalho em vidas passadas. Por isso, nesta existência, o sucesso só é alcançado através do esforço contínuo, da organização e da persistência. Qualquer tentativa de pegar atalhos ou de agir de forma negligente tende a resultar em frustração.\n\nAbrace o trabalho não como um fardo, mas como sua ferramenta de libertação e poder. Sua capacidade de transformar e de construir é imensa, desde que canalizada de forma disciplinada. Ao honrar o valor do esforço, você não apenas supera seus desafios cármicos, mas também constrói uma vida de realizações sólidas e significativas.',
      inspiracao: 'Trabalho honesto liberta e transforma.',
      tags: ['Transformação', 'Trabalho', 'Superação'],
    ),
    14: const VibrationContent(
      titulo: 'O Explorador Versátil',
      descricaoCurta:
          'Débito cármico: liberdade equilibrada com responsabilidade financeira.',
      descricaoCompleta:
          'Sua natureza essencial se exprime pela busca incessante da compreensão dos fatos, das pessoas e das coisas. Você possui um temperamento versátil e aventureiro, sempre pronto(a) para viver novas experiências, viajar e conhecer pessoas, sem se prender excessivamente ao futuro. O que importa são os prazeres e as satisfações que a vida pode proporcionar no presente.\n\nVocê possui dons inatos para lidar com negócios e comércio, encontrando sempre maneiras ágeis de ganhar dinheiro, sem se importar com os riscos. No entanto, a vibração do 14 carrega um débito cármico relacionado a abusos da liberdade no passado, o que pode levá-lo(a) a ganhar com a mesma facilidade com que pode perder, caso não mantenha vigilância sobre seus desejos e impulsos.\n\nSeu dom de liderança é exercido com versatilidade, e suas escolhas são frequentemente guiadas pela emoção. O seu grande aprendizado está em equilibrar essa impulsividade com a razão e a intuição, usando sua imensa liberdade com responsabilidade e moderação. É nessa harmonia que seus resultados se tornam mais promissores e duradouros.',
      inspiracao: 'Liberdade consciente constrói prosperidade sustentável.',
      tags: ['Versatilidade', 'Liberdade', 'Negócios'],
    ),
    15: const VibrationContent(
      titulo: 'O Líder Magnético',
      descricaoCurta:
          'Carisma + liberdade + responsabilidade = liderança familiar e comunitária.',
      descricaoCompleta:
          'Sua essência combina a liderança do 1 com a liberdade do 5, resultando na vibração magnética e responsável do 6 (1+5=6). Você é uma pessoa extremamente carismática, com um dom natural para atrair e influenciar os outros. Sua natureza é generosa e você sente um forte chamado para assumir responsabilidades, especialmente no âmbito familiar e comunitário.\n\nVocê tem a capacidade de liderar com amor (1 e 6) e de se adaptar às necessidades do grupo com versatilidade (5). No entanto, essa combinação pode gerar um conflito interno entre o desejo de liberdade pessoal (5) e o senso de dever e as responsabilidades que você atrai (6).\n\nSeu aprendizado de vida está em encontrar o equilíbrio entre sua necessidade de aventura e seus compromissos. Ao aprender a integrar essas energias, você se torna um(a) líder comunitário(a) dinâmico(a) e inspirador(a), capaz de promover o bem-estar de todos sem sacrificar sua própria felicidade e individualidade.',
      inspiracao: 'Liderar com amor sem perder a liberdade pessoal.',
      tags: ['Carisma', 'Responsabilidade', 'Equilíbrio'],
    ),
    16: const VibrationContent(
      titulo: 'O Revelador',
      descricaoCurta:
          'Débito cármico: sabedoria conquistada por crises transformadoras.',
      descricaoCompleta:
          'Sua natureza essencial carrega uma profundidade de alma incomum. Você possui uma forte intuição, uma mente analítica aguçada e uma atração natural pelo estudo do místico e do oculto. É uma pessoa reservada, que valoriza a solidão como espaço para a autorreflexão e a conexão espiritual.\n\nO 16 é um número de débito cármico que indica que, em vidas passadas, pode ter havido abuso de poder espiritual ou intelectual. Por isso, nesta vida, você passará por crises e transformações profundas, que parecerão "quebrar" estruturas antigas de sua vida (relacionamentos, ego, crenças) para que você renasça em uma versão mais verdadeira e sábia de si mesmo(a).\n\nEssas provações não são punições, mas oportunidades de purificação. A torre que desmorona (simbolismo do 16) limpa o terreno para que você construa sobre bases mais sólidas e autênticas. Seu caminho é de aceitação humilde e de abertura para as lições espirituais. Ao fazer isso, você se torna um(a) sábio(a) e um(a) guia para aqueles que também buscam a verdade.',
      inspiracao: 'Da queda, renasce a sabedoria; da humildade, a luz.',
      tags: ['Sabedoria', 'Transformação', 'Espiritualidade'],
    ),
    17: const VibrationContent(
      titulo: 'O Visionário Executor',
      descricaoCurta:
          'Intuição + sabedoria + poder = liderança visionária e executiva.',
      descricaoCompleta:
          'Sua essência combina a sabedoria introspectiva do 7 com a liderança do 1, resultando no poder realizador do 8 (1+7=8). Você é um(a) líder nato(a) com uma visão profunda e uma capacidade incomum de transformar ideias espirituais e filosóficas em resultados materiais concretos. Você enxerga onde os outros não veem.\n\nVocê possui uma mente estratégica e brilhante (7), aliada a uma incrível capacidade de execução e comando (1 e 8). Sua intuição o(a) guia, e você confia em sua percepção. No entanto, a combinação dessas energias pode levá-lo(a) a um excesso de confiança ou a uma certa teimosia em suas convicções.\n\nSeu caminho de crescimento está em equilibrar sua força com a humildade e em permanecer aberto(a) ao aprendizado contínuo. Ao integrar sua sabedoria interior com uma ação ética e generosa, você se torna um(a) líder visionário(a) e próspero(a), capaz de deixar um legado tanto material quanto espiritual.',
      inspiracao: 'Visão interior com ação ética constrói impérios sólidos.',
      tags: ['Visão', 'Liderança', 'Poder'],
    ),
    18: const VibrationContent(
      titulo: 'O Justo',
      descricaoCurta:
          'Poder + espiritualidade + humanitarismo = liderança compassiva.',
      descricaoCompleta:
          'Sua essência combina o poder e a ambição do 8 com a liderança do 1, resultando na compaixão universal do 9 (1+8=9). Você é um(a) líder humanitário(a), com um forte senso de justiça e um profundo desejo de usar sua força e influência para o bem coletivo. Você nasceu para servir causas maiores.\n\nVocê possui uma capacidade inata de liderança (1), aliada a um poder de realização impressionante (8) e a um coração generoso e compassivo (9). Sua jornada envolve aprender a equilibrar suas ambições pessoais com seu chamado espiritual de servir à humanidade.\n\nSeu desafio é evitar cair em tendências autoritárias ou em frustrações quando os outros não correspondem aos seus altos ideais. Ao integrar sua força com a tolerância e o perdão, você se torna um(a) líder respeitado(a) e amado(a), capaz de promover mudanças profundas e positivas em grande escala.',
      inspiracao: 'Poder a serviço do amor transforma civilizações.',
      tags: ['Justiça', 'Humanitarismo', 'Liderança'],
    ),
    19: const VibrationContent(
      titulo: 'O Independente',
      descricaoCurta:
          'Débito cármico: equilíbrio entre independência e interdependência.',
      descricaoCompleta:
          'Você nasceu para ser independente e autônomo. Sua essência carrega uma grande força interior, autoconfiança e uma necessidade profunda de trilhar seu próprio caminho sem depender de ninguém. Você é ambicioso(a), criativo(a) e possui um forte desejo de se realizar tanto material quanto espiritualmente.\n\nO 19 é um número de débito cármico que indica um aprendizado sobre o equilíbrio entre independência e cooperação. Em vidas passadas, pode ter havido um uso egoísta ou abusivo do poder e da liderança. Nesta vida, você é desafiado(a) a ser forte e autossuficiente, mas sem cair na arrogância, no egoísmo ou no isolamento.\n\nSeu aprendizado está em perceber que a verdadeira força não vem de fazer tudo sozinho(a), mas de saber quando pedir ajuda, compartilhar e cooperar. Ao integrar sua poderosa individualidade com a humildade e a compaixão, você se torna um(a) líder inspirador(a), capaz de iluminar o caminho para si e para os outros.',
      inspiracao: 'Força individual iluminada pela compaixão coletiva.',
      tags: ['Independência', 'Força', 'Equilíbrio'],
    ),
    20: const VibrationContent(
      titulo: 'O Pacificador',
      descricaoCurta:
          'Cooperação + espiritualidade = diplomacia sensível e intuitiva.',
      descricaoCompleta:
          'Sua essência é a da cooperação, da sensibilidade e da paz. Você nasceu com a vibração do diplomata e do pacificador, possuindo um dom inato para unir pessoas e criar harmonia nos ambientes em que está. Sua natureza é gentil, intuitiva e profundamente atenta às necessidades alheias.\n\nA presença do zero (0) amplifica sua sensibilidade e sua conexão com o mundo espiritual, tornando você alguém extremamente receptivo às energias ao seu redor. Você sente tudo de forma intensa, o que pode tanto ser um grande dom quanto um desafio, especialmente se você não aprender a se proteger emocionalmente.\n\nSeu caminho de aprendizado envolve desenvolver limites saudáveis e cultivar a autoconfiança. É importante que você valorize sua própria voz e não se perca em agradar a todos. Ao equilibrar sua natureza cooperativa com a assertividade, você se torna um(a) mediador(a) sábio(a) e respeitado(a), capaz de promover paz e união com autenticidade.',
      inspiracao: 'Gentileza com limites é sabedoria em ação.',
      tags: ['Diplomacia', 'Sensibilidade', 'Paz'],
    ),
    21: const VibrationContent(
      titulo: 'O Expressivo Sociável',
      descricaoCurta:
          'Cooperação + liderança = criatividade comunicativa e alegria de viver.',
      descricaoCompleta:
          'Sua essência combina a cooperação do 2 com a liderança do 1, resultando na criatividade vibrante e comunicativa do 3 (2+1=3). Você é uma pessoa extremamente sociável, otimista e com um dom especial para a expressão artística, seja pela palavra, pela arte ou pela presença carismática.\n\nVocê tem a rara habilidade de liderar com diplomacia (1 e 2), unindo as pessoas através da alegria e da criatividade (3). Sua presença ilumina os ambientes, e você tem um talento natural para inspirar e motivar os outros. A vida social é fundamental para você, e você prospera em atividades colaborativas.\n\nSeu desafio está em não dispersar sua imensa energia em muitas direções ao mesmo tempo. A tendência à superficialidade e à falta de foco pode impedi-lo(a) de realizar todo o seu potencial. Ao canalizar sua criatividade com disciplina, você alcança grandes realizações e se torna uma fonte de inspiração duradoura.',
      inspiracao: 'Criatividade focada transforma talento em obra-prima.',
      tags: ['Expressão', 'Sociabilidade', 'Criatividade'],
    ),
    22: const VibrationContent(
      titulo: 'O Mestre Construtor',
      descricaoCurta:
          'Número Mestre: visão elevada + poder material = construtor de legados.',
      descricaoCompleta:
          'Você nasceu sob a vibração de um Número Mestre, o que indica um imenso potencial de realização material aliado a um propósito espiritual elevado. Sua essência é a do "Mestre Construtor", com a capacidade de transformar grandes visões espirituais em projetos concretos e duradouros que beneficiam a humanidade.\n\nVocê carrega a sensibilidade e a cooperação do número 4 (2+2=4) elevadas a uma oitava superior. Isso significa que você possui tanto a habilidade de trabalhar arduamente e de forma disciplinada quanto a visão para criar algo que transcenda o material e beneficie o coletivo. Você nasceu para deixar um legado.\n\nSeu grande desafio é lidar com a imensa pressão que acompanha esse potencial. É comum sentir-se sobrecarregado(a) ou duvidar de sua capacidade. Lembre-se de que sua jornada não é de conquistas rápidas, mas de construção sólida e paciente. Ao permanecer fiel à sua visão e trabalhar com integridade, você tem o poder de criar algo verdadeiramente grandioso e transformador.',
      inspiracao: 'Visão elevada com trabalho honesto constrói o impossível.',
      tags: ['Visão', 'Construção', 'Legado'],
    ),
    23: const VibrationContent(
      titulo: 'O Comunicador Adaptável',
      descricaoCurta:
          'Criatividade + versatilidade = comunicação dinâmica e evolução constante.',
      descricaoCompleta:
          'Sua essência combina a criatividade e a comunicação do 3 com a versatilidade e a liberdade do 2 (de 23: 2+3=5). Você é uma pessoa extremamente adaptável, sociável e com um dom especial para se comunicar com diferentes tipos de pessoas. Sua capacidade de adaptação é uma de suas maiores forças.\n\nVocê possui uma mente rápida e curiosa, sempre em busca de novos conhecimentos e experiências. Sua presença é magnética e você se sente em casa em ambientes dinâmicos e em constante mudança. A monotonia é seu maior inimigo, e você prospera quando pode expressar sua criatividade de formas variadas.\n\nSeu caminho de aprendizado está em canalizar sua imensa energia e versatilidade com foco. A tendência à dispersão e à superficialidade pode impedir que você alcance todo o seu potencial. Ao se comprometer com projetos de longo prazo e ao aprofundar seus talentos, você se torna um comunicador brilhante e influente.',
      inspiracao: 'Versatilidade com propósito é evolução constante.',
      tags: ['Comunicação', 'Versatilidade', 'Adaptação'],
    ),
    24: const VibrationContent(
      titulo: 'O Equilibrador Harmônico',
      descricaoCurta:
          'Sensibilidade + trabalho = harmonia construída na cooperação.',
      descricaoCompleta:
          'Sua essência combina a sensibilidade e a cooperação do 2 com o trabalho e a estabilidade do 4 (2+4=6). Você é uma pessoa que valoriza a harmonia, a paz e o trabalho em equipe. Sua natureza é cuidadosa e você tem um dom especial para criar ambientes equilibrados e organizados.\n\nVocê é extremamente responsável e confiável. As pessoas sabem que podem contar com você, pois você combina a empatia do 2 com a praticidade do 4, resultando na dedicação ao bem-estar coletivo do 6. Você se sente realizado(a) quando está ajudando e servindo aos outros de forma concreta.\n\nSeu aprendizado de vida está em equilibrar sua tendência ao sacrifício pessoal com o autocuidado. A responsabilidade excessiva pode gerar sobrecarga e frustração. Ao aprender a estabelecer limites saudáveis e a cuidar de si mesmo(a) com a mesma dedicação que oferece aos outros, você encontra uma felicidade duradoura.',
      inspiracao: 'Harmonia equilibrada começa no autocuidado.',
      tags: ['Harmonia', 'Responsabilidade', 'Cooperação'],
    ),
    25: const VibrationContent(
      titulo: 'O Diplomata Intuitivo',
      descricaoCurta:
          'Cooperação + sabedoria = diplomacia profunda e relações significativas.',
      descricaoCompleta:
          'Sua essência combina a cooperação do 2 com a sabedoria e a introspecção do 5 (de 25: 2+5=7). Você é uma pessoa extremamente sensível e intuitiva, com um dom especial para compreender as camadas mais profundas das relações humanas. Sua diplomacia vai além da superfície.\n\nVocê possui uma mente analítica e reflexiva, aliada a uma capacidade inata de colaboração. Sua força está na sua habilidade de ouvir com profundidade e de perceber o que não é dito. Você valoriza a qualidade nas relações e prefere poucos amigos verdadeiros a muitas conexões superficiais.\n\nSeu caminho de evolução envolve equilibrar sua necessidade de solidão e reflexão com sua vocação para a parceria e a cooperação. A tendência ao isolamento pode afastá-lo(a) das oportunidades de conexão. Ao compartilhar sua sabedoria com confiança, você se torna um mediador sábio e respeitado.',
      inspiracao: 'Sabedoria compartilhada em união multiplica a paz.',
      tags: ['Diplomacia', 'Intuição', 'Profundidade'],
    ),
    26: const VibrationContent(
      titulo: 'O Conselheiro Poderoso',
      descricaoCurta:
          'Cooperação + poder = responsabilidade equilibrada e liderança justa.',
      descricaoCompleta:
          'Sua essência combina a sensibilidade do 2 com o poder e a autoridade do 6 (de 26: 2+6=8). Você é uma pessoa com uma incrível capacidade de liderança equilibrada, unindo a empatia e a cooperação com a força e a justiça. Você nasceu para assumir grandes responsabilidades.\n\nVocê possui um dom natural para a gestão e para a organização, mas sempre com um olhar sensível às necessidades das pessoas. Sua liderança não é autoritária, mas justa e compassiva. Você tem a capacidade de construir e de prosperar materialmente sem perder sua humanidade.\n\nSeu aprendizado de vida está em equilibrar seu poder com a flexibilidade. A tendência à rigidez ou ao excesso de controle pode prejudicar suas relações. Ao usar sua força a serviço do bem comum e ao permanecer aberto(a) à colaboração, você se torna um líder admirado e próspero.',
      inspiracao: 'Poder compassivo constrói reinos justos.',
      tags: ['Liderança', 'Justiça', 'Responsabilidade'],
    ),
    27: const VibrationContent(
      titulo: 'O Humanitário Perceptivo',
      descricaoCurta:
          'Cooperação + espiritualidade = compaixão profunda e serviço iluminado.',
      descricaoCompleta:
          'Sua essência combina a cooperação do 2 com a sabedoria do 7, resultando na compaixão universal do 9 (2+7=9). Você é uma pessoa com uma sensibilidade espiritual profunda e um forte desejo de servir à humanidade. Sua empatia vai além do comum.\n\nVocê possui uma intuição aguçada e uma compreensão profunda das dores e das necessidades do mundo. Sua natureza é altruísta e você se sente chamado(a) a causas humanitárias e espirituais. Sua força está na sua capacidade de perdoar, de compreender e de amar de forma incondicional.\n\nSeu caminho de aprendizado está em evitar a tendência ao martírio ou à desilusão. É importante que você aprenda a estabelecer limites saudáveis e a cuidar de si mesmo(a) com a mesma compaixão que dedica aos outros. Ao equilibrar seu idealismo com a praticidade, você se torna um farol de luz e de cura.',
      inspiracao: 'Compaixão consciente cura sem se esgotar.',
      tags: ['Compaixão', 'Espiritualidade', 'Humanitarismo'],
    ),
    28: const VibrationContent(
      titulo: 'O Líder Humanitário',
      descricaoCurta:
          'Cooperação + poder = liderança voltada ao bem-estar coletivo.',
      descricaoCompleta:
          'Sua essência combina a cooperação do 2 com o poder do 8, resultando na liderança humanitária do 1 (2+8=10=1). Você é um(a) líder nato(a) com um profundo senso de responsabilidade social. Sua ambição não é apenas pessoal, mas voltada para o benefício da coletividade.\n\nVocê possui a sensibilidade do 2 aliada à força e à capacidade de realização do 8. Isso faz de você uma pessoa poderosa, mas com um coração generoso. Você tem a rara habilidade de prosperar materialmente enquanto promove o bem-estar de todos ao seu redor.\n\nSeu aprendizado de vida está em equilibrar sua ambição com a colaboração. A tendência a assumir o controle total pode gerar conflitos. Ao usar seu poder com humildade e ao incluir os outros em suas visões, você se torna um líder amado e respeitado, capaz de transformar vidas em grande escala.',
      inspiracao: 'Liderar com o coração é construir um mundo melhor.',
      tags: ['Liderança', 'Humanitarismo', 'Poder'],
    ),
    29: const VibrationContent(
      titulo: 'O Mestre da Intuição',
      descricaoCurta:
          'Cooperação + compaixão = serviço inspirado e intuição elevada.',
      descricaoCompleta:
          'Sua essência combina a sensibilidade e a cooperação do 2 com a compaixão universal do 9, resultando no Número Mestre 11 (2+9=11). Você é uma pessoa com uma intuição extremamente aguçada e um forte chamado espiritual. Sua missão é iluminar e inspirar.\n\nVocê possui uma percepção profunda da realidade e das necessidades humanas. Sua sensibilidade é tão refinada que você frequentemente capta informações além do óbvio. Sua natureza é a de um(a) conselheiro(a) espiritual, e as pessoas são naturalmente atraídas por sua sabedoria e compaixão.\n\nSeu grande desafio é lidar com a intensidade emocional e espiritual que acompanha essa vibração. É comum sentir-se sobrecarregado(a) pela sensibilidade ou duvidar de suas percepções. Ao confiar em sua intuição e ao estabelecer limites energéticos saudáveis, você se torna um canal de luz poderoso, capaz de elevar a consciência de muitos.',
      inspiracao: 'Intuição confiante é luz que guia multidões.',
      tags: ['Intuição', 'Compaixão', 'Espiritualidade'],
    ),
    30: const VibrationContent(
      titulo: 'O Criador Otimista',
      descricaoCurta:
          'Criatividade + espiritualidade = expressão alegre e inspiradora.',
      descricaoCompleta:
          'Sua essência carrega a criatividade, a comunicação e o otimismo do 3, amplificados pela espiritualidade do 0. Você é uma pessoa extremamente expressiva, alegre e com um dom especial para inspirar os outros através das artes, da palavra ou da sua presença magnética.\n\nVocê possui uma criatividade ilimitada (simbolizada pelo 0) e uma capacidade natural de ver a beleza e o lado positivo da vida. Sua energia é contagiante, e você tem o poder de transformar ambientes pesados em espaços de alegria e esperança. Sua missão é espalhar luz através da sua expressão.\n\nSeu caminho de aprendizado está em manter o foco e a disciplina. A tendência à dispersão e à superficialidade pode impedir que você realize todo o seu potencial criativo. Ao canalizar sua imensa energia com propósito e compromisso, você se torna um artista ou comunicador brilhante, capaz de tocar profundamente o coração das pessoas.',
      inspiracao: 'Criatividade com propósito é alegria que transforma.',
      tags: ['Criatividade', 'Otimismo', 'Inspiração'],
    ),
    31: const VibrationContent(
      titulo: 'O Construtor Criativo',
      descricaoCurta:
          'Criatividade + estabilidade = realização concreta através da expressão.',
      descricaoCompleta:
          'Sua essência combina a criatividade e a comunicação do 3 com o trabalho e a estabilidade do 1 (de 31: 3+1=4). Você é uma pessoa com um dom especial para transformar ideias criativas em realizações concretas e duradouras. Sua força está na sua capacidade de unir imaginação e disciplina.\n\nVocê possui a leveza e o otimismo do 3, mas com a praticidade e a persistência do 4. Isso faz de você alguém capaz de trabalhar em projetos criativos de longo prazo sem perder o entusiasmo. Você tem a rara habilidade de ser ao mesmo tempo artista e construtor.\n\nSeu aprendizado de vida está em equilibrar sua necessidade de liberdade criativa com as demandas da disciplina. A tensão entre a espontaneidade do 3 e a rigidez do 4 pode gerar frustração. Ao integrar essas energias, você se torna um criador produtivo e realizado, capaz de deixar um legado artístico sólido e inspirador.',
      inspiracao: 'Criatividade disciplinada constrói obras eternas.',
      tags: ['Criatividade', 'Construção', 'Realização'],
    ),
  };

  static VibrationContent? diaNatalicioLookup(int day) =>
      textosDiaNatalicio[day];

  // DESTINO (1–9, 11, 22) — o grande caminho de vida traçado
  static final Map<int, VibrationContent> textosDestino = {
    1: const VibrationContent(
      titulo: 'Independência e Liderança',
      descricaoCurta:
          'Caminho de autodescoberta, liderança e criatividade original.',
      descricaoCompleta:
          'Seu caminho de vida exige o desenvolvimento da independência, da liderança e da criatividade. O destino o(a) levará a situações em que precisará agir com coragem e originalidade, tornando-se um(a) pioneiro(a) em sua área de atuação. As oportunidades de progresso surgirão quando você assumir a frente e confiar em sua própria força, sem depender da aprovação alheia.\n\nEste é um caminho de autodescoberta e de afirmação da sua individualidade. A vida lhe ensinará, por vezes de forma desafiadora, a importância de ser autossuficiente e de acreditar em suas próprias ideias. Os maiores triunfos virão de projetos que você iniciar e liderar com determinação.\n\nAbrace a jornada do herói que existe em você. Seu destino não é seguir os passos de ninguém, mas deixar suas próprias pegadas no mundo. Ao desenvolver sua força de vontade e sua capacidade de inovar, você não apenas realizará seu potencial, mas também se tornará uma inspiração de coragem para todos.',
      inspiracao: 'Seu destino é abrir caminhos onde ninguém ousou ir.',
      tags: ['Liderança', 'Pioneirismo', 'Independência'],
    ),
    2: const VibrationContent(
      titulo: 'Cooperação e Diplomacia',
      descricaoCurta: 'Caminho de parcerias, sensibilidade e união harmoniosa.',
      descricaoCompleta:
          'Seu destino está ligado à cooperação, à diplomacia e ao desenvolvimento de relacionamentos harmoniosos. A vida lhe trará oportunidades para trabalhar em equipe, para ser um(a) mediador(a) e para aprender a virtude da paciência. Seu sucesso não virá da competição, mas da sua habilidade de construir pontes e unir pessoas.\n\nEste é um caminho que lhe ensinará a importância da sensibilidade, do tato e da atenção aos detalhes. Você será colocado(a) em situações que exigirão que você ouça mais do que fale, e que use sua intuição para navegar nas complexidades das relações humanas. As parcerias serão fundamentais para o seu crescimento.\n\nSua evolução está em se tornar um pilar de equilíbrio e paz. Seu destino é mostrar ao mundo o poder da união e da gentileza. Ao desenvolver suas habilidades de colaboração e ao confiar em sua intuição, você encontrará um sucesso sereno e duradouro, construído sobre alicerces de respeito e afeto mútuos.',
      inspiracao: 'Seu destino é unir o que estava separado.',
      tags: ['Cooperação', 'Diplomacia', 'Sensibilidade'],
    ),
    3: const VibrationContent(
      titulo: 'Comunicação e Alegria',
      descricaoCurta:
          'Caminho de expressão criativa, otimismo e celebração da vida.',
      descricaoCompleta:
          'O caminho do seu destino envolve a comunicação, a criatividade e a expressão dos seus talentos. A vida o(a) colocará em cenários onde a alegria, o otimismo e a sociabilidade serão as chaves para o progresso. As oportunidades surgirão através do uso da sua voz, da sua criatividade e do seu magnetismo pessoal para inspirar e encantar.\n\nEsta é uma jornada de expansão e de celebração da vida. Você está destinado(a) a desenvolver seus dons artísticos e a compartilhar sua visão otimista com o mundo. Os relacionamentos e as amizades terão um papel crucial, abrindo portas e trazendo as oportunidades mais inesperadas e felizes.\n\nSua missão é espalhar a luz. Não tenha medo de ser o centro das atenções ou de expressar suas ideias mais ousadas. Seu destino é usar sua criatividade para curar, para motivar e para tornar o mundo um lugar mais belo e vibrante. Abrace sua alegria, pois ela é o seu maior guia.',
      inspiracao: 'Seu destino é pintar o mundo com cores e alegria.',
      tags: ['Comunicação', 'Criatividade', 'Otimismo'],
    ),
    4: const VibrationContent(
      titulo: 'Construção e Estabilidade',
      descricaoCurta:
          'Caminho de trabalho disciplinado e edificação de bases sólidas.',
      descricaoCompleta:
          'Seu destino exige trabalho, disciplina e a construção de bases sólidas. O plano de sua vida o(a) guiará por um caminho de esforço e persistência, onde a organização e a praticidade serão fundamentais para o sucesso. As oportunidades de progresso virão através da sua dedicação e da sua capacidade de transformar projetos em realizações concretas.\n\nEste é um caminho que lhe ensinará o valor da paciência, da honestidade e da responsabilidade. A vida lhe apresentará desafios que só poderão ser superados com um planejamento cuidadoso e um esforço contínuo. Não haverá atalhos fáceis, mas cada passo dado com firmeza o(a) levará a uma estabilidade invejável.\n\nAbrace sua vocação de construtor(a). Seu destino é criar segurança e ordem, seja em sua família, em sua carreira ou em sua comunidade. Ao honrar o valor do trabalho e da disciplina, você não apenas alcançará seus objetivos, mas também construirá um legado de confiança e durabilidade que resistirá ao teste do tempo.',
      inspiracao: 'Seu destino é edificar alicerces que o tempo respeita.',
      tags: ['Construção', 'Disciplina', 'Estabilidade'],
    ),
    5: const VibrationContent(
      titulo: 'Liberdade e Transformação',
      descricaoCurta:
          'Caminho de mudanças constantes, aventuras e versatilidade.',
      descricaoCompleta:
          'O caminho do seu destino é marcado pela liberdade, pelas mudanças e pela versatilidade. A vida lhe proporcionará inúmeras experiências, viagens e a necessidade de se adaptar constantemente a novos cenários e pessoas. As melhores oportunidades surgirão quando você abraçar o novo e usar sua capacidade de se reinventar com coragem.\n\nEsta é uma jornada de expansão dos horizontes e de aprendizado contínuo. Você está destinado(a) a quebrar rotinas, a questionar o convencional e a explorar as múltiplas facetas da existência. A monotonia será sua maior inimiga, e o progresso dependerá da sua disposição para se manter em movimento.\n\nSeu grande aprendizado de destino é usar essa imensa liberdade com sabedoria e responsabilidade. A impulsividade pode ser uma armadilha, mas quando você alinha seu desejo de mudança a um propósito, sua vida se torna uma aventura extraordinária, cheia de crescimento, conhecimento e inspiração.',
      inspiracao: 'Seu destino é explorar todas as possibilidades da vida.',
      tags: ['Liberdade', 'Mudança', 'Aventura'],
    ),
    6: const VibrationContent(
      titulo: 'Harmonia e Serviço',
      descricaoCurta:
          'Caminho de responsabilidade afetiva, cuidado e busca pela paz.',
      descricaoCompleta:
          'Seu destino está intrinsecamente ligado às responsabilidades familiares, ao serviço à comunidade e à busca incessante pela harmonia. A vida o(a) colocará em posições onde terá que cuidar, aconselhar e equilibrar as relações. As oportunidades de progresso e autorrealização virão através do amor, da doação e da sua capacidade de criar um ambiente de paz.\n\nEste é um caminho que lhe ensinará o verdadeiro significado da justiça, da responsabilidade afetiva e do amor ao próximo. Você será um pilar para sua família e seus amigos, e seu lar será um refúgio de beleza e acolhimento. Seu crescimento virá ao assumir essas responsabilidades com o coração aberto.\n\nAbrace sua vocação de ser um(a) harmonizador(a). Seu destino é curar os laços, promover o bem-estar e ensinar pelo exemplo o valor da união e do afeto. Ao se dedicar a essa nobre tarefa, você encontrará uma felicidade profunda e um sentimento de propósito que preencherá sua alma.',
      inspiracao: 'Seu destino é ser o coração que une e harmoniza.',
      tags: ['Harmonia', 'Responsabilidade', 'Família'],
    ),
    7: const VibrationContent(
      titulo: 'Conhecimento e Sabedoria',
      descricaoCurta:
          'Caminho de introspecção, estudo e busca pela verdade profunda.',
      descricaoCompleta:
          'O caminho do seu destino é o do conhecimento, da especialização e da profunda introspecção. A vida o(a) guiará para o estudo, a pesquisa e a busca de um sentido mais profundo para a existência. O progresso virá através do desenvolvimento da sua mente, da sua intuição e da sua capacidade de se tornar um(a) especialista em sua área de interesse.\n\nEsta é uma jornada para dentro de si mesmo(a). Você será convidado(a) a passar tempo em reflexão, a questionar o status quo e a buscar a verdade por trás das aparências. A espiritualidade e a ciência serão campos férteis para o seu desenvolvimento, e o conhecimento será sua ferramenta mais poderosa.\n\nSeu aprendizado de destino é aprender a confiar em sua sabedoria interior e a compartilhá-la com o mundo sem perder sua essência. O isolamento pode ser uma tentação, mas sua luz brilha mais forte quando ilumina os outros. Ao se tornar um farol de conhecimento e fé, você cumpre seu propósito e encontra a paz.',
      inspiracao: 'Seu destino é desvendar os mistérios e iluminar mentes.',
      tags: ['Conhecimento', 'Sabedoria', 'Introspecção'],
    ),
    8: const VibrationContent(
      titulo: 'Poder e Realização Material',
      descricaoCurta:
          'Caminho de autoridade, justiça e equilíbrio entre matéria e espírito.',
      descricaoCompleta:
          'A direção geral da sua existência será no sentido de um esforço ativo para restaurar o equilíbrio nas áreas importantes da vida, especialmente aquelas que envolvem poder, dinheiro e justiça. Seu destino está traçado para que viva e trabalhe com pessoas influentes, pois você possui uma vocação executiva e uma visão para organizar e planejar ações de grande porte.\n\nSeu carisma atrairá colaboradores fiéis, dos quais dependerá o sucesso dos seus empreendimentos. A facilidade para ganhar dinheiro decorre do poder espiritual exercido sobre o mundo da matéria, o que aumenta sua responsabilidade de ser justo(a) com todos. Sua autoridade deve ser exercida com respeito e justeza nas decisões.\n\nO sucesso em seu caminho será alcançado através do equilíbrio entre a ambição pelo sucesso material e financeiro e a prática da espiritualidade. É fundamental que estude as leis da prosperidade para não se perder nas oportunidades de ganhos que surgirão através do exercício de seu poder.',
      inspiracao:
          'Seu destino é liderar com justiça e construir prosperidade para todos.',
      tags: ['Poder', 'Autoridade', 'Equilíbrio'],
    ),
    9: const VibrationContent(
      titulo: 'Compaixão e Amor Universal',
      descricaoCurta: 'Caminho de doação, altruísmo e serviço à humanidade.',
      descricaoCompleta:
          'Seu destino é o da compaixão, do altruísmo e do amor universal. Seu caminho evolutivo o(a) levará a se dedicar a grandes causas, a viajar pelo mundo e a servir à humanidade de formas inspiradoras. As oportunidades de progresso surgirão quando você compartilhar sua sabedoria, sua criatividade e sua generosidade sem esperar nada em troca.\n\nEsta é uma jornada de finalizações e de transcendência. A vida lhe pedirá para aprender o desapego, a perdoar profundamente e a desenvolver uma visão universal, livre de preconceitos. Você está destinado(a) a ser um exemplo de tolerância e de amor incondicional.\n\nAbrace sua vocação de ser um agente de transformação no mundo. Seu destino é deixar um legado de bondade e de inspiração. Ao se dedicar ao bem-estar coletivo e ao cultivar a compaixão em seu coração, você completará um importante ciclo evolutivo e encontrará a mais elevada forma de realização.',
      inspiracao: 'Seu destino é amar sem fronteiras e servir sem limites.',
      tags: ['Compaixão', 'Humanitarismo', 'Altruísmo'],
    ),
    11: const VibrationContent(
      titulo: 'Inspiração Espiritual',
      descricaoCurta:
          'Caminho de intuição elevada, inspiração e liderança espiritual.',
      descricaoCompleta:
          'Seu destino é o de um(a) mensageiro(a) espiritual, trazendo inspiração, revelações e insights que elevam a consciência coletiva. A vida o(a) colocará em posições de grande visibilidade, onde sua intuição e sensibilidade serão suas maiores ferramentas. As oportunidades surgirão quando você confiar plenamente em sua voz interior e tiver coragem de compartilhar suas visões, mesmo que pareçam à frente de seu tempo.\n\nEsta é uma jornada de alto padrão vibratório, que exige integridade, fé e um compromisso com o desenvolvimento espiritual. Você está destinado(a) a ser um farol de luz, inspirando os outros através de suas palavras, ações ou criações artísticas. O nervosismo e a dúvida podem ser grandes desafios.\n\nAo aceitar sua missão de guia espiritual, você alcança níveis extraordinários de autorrealização. Seu destino é iluminar o caminho para aqueles que ainda caminham na escuridão, mostrando que existe um plano maior e mais belo para a humanidade.',
      inspiracao: 'Seu destino é ser canal de luz e inspiração divina.',
      tags: ['Intuição', 'Inspiração', 'Espiritualidade'],
    ),
    22: const VibrationContent(
      titulo: 'Mestre Construtor',
      descricaoCurta:
          'Caminho de grandes realizações práticas com impacto global.',
      descricaoCompleta:
          'Seu destino é o do(a) Mestre Construtor(a): transformar sonhos espirituais elevados em estruturas concretas que beneficiem a humanidade em larga escala. A vida lhe dará oportunidades para liderar projetos de grande porte — sejam corporações, fundações, sistemas educacionais ou infraestruturas — que terão um impacto duradouro e positivo no mundo.\n\nEste é um caminho de imensa responsabilidade e poder. Você está destinado(a) a ser o(a) arquiteto(a) de um novo mundo, unindo idealismo espiritual com capacidade prática de execução. Sua visão é ampla e seu potencial para deixar um legado é incomparável.\n\nO maior desafio é não se sobrecarregar com a magnitude de sua própria missão ou usar seu poder para fins egoístas. Ao se manter conectado(a) ao ideal de serviço e trabalhar com disciplina e humildade, você tem o potencial de criar estruturas que marcarão gerações. Seu destino é construir pontes — literais e figuradas — que unam a humanidade.',
      inspiracao:
          'Seu destino é construir o impossível e torná-lo real para todos.',
      tags: ['Construção', 'Legado', 'Impacto Global'],
    ),
  };

  // EXPRESSÃO (1–9) — como os talentos se manifestam no mundo
  static final Map<int, VibrationContent> textosExpressao = {
    1: const VibrationContent(
      titulo: 'Liderança e Iniciativa',
      descricaoCurta: 'Talentos de comando, empreendedorismo e ação pioneira.',
      descricaoCompleta:
          'Seus talentos se manifestam através da liderança, da iniciativa e de uma originalidade marcante. Você age no mundo de forma independente e corajosa, preferindo abrir novos caminhos a seguir os já existentes. Sua principal aptidão é a de comandar, empreender e transformar ideias em ações concretas com uma determinação inabalável.\n\nA sua força reside na sua capacidade de ser pioneiro(a). Você se destaca em qualquer ambiente que exija autoconfiança e poder de decisão. Sua energia é a do começo, do impulso inicial que coloca tudo em movimento. As pessoas naturalmente o(a) seguem, inspiradas pela sua coragem e visão.\n\nO grande desafio para a sua expressão plena é aprender a arte da colaboração. Sua inclinação natural é agir sozinho(a), mas seu potencial de realização se multiplica quando você equilibra sua individualidade com a capacidade de ouvir e trabalhar em equipe, transformando a imposição em inspiração.',
      inspiracao:
          'Liderar é abrir caminhos; inspirar é convidar outros a trilhá-los.',
      tags: ['Liderança', 'Iniciativa', 'Pioneirismo'],
    ),
    2: const VibrationContent(
      titulo: 'Diplomacia e Parceria',
      descricaoCurta: 'Talentos de mediação, cooperação e criação de harmonia.',
      descricaoCompleta:
          'Você interage com o mundo de maneira diplomática, colaborativa e extremamente paciente. Seus maiores talentos estão ligados à sua incrível capacidade de unir pessoas, de atuar como mediador(a) e de resolver conflitos com uma sensibilidade única. Você é a personificação da parceria e da cooperação.\n\nSua força não está no confronto, mas na gentileza e na persuasão. Você se destaca em atividades que exigem trabalho em equipe, tato e atenção aos detalhes. É um(a) excelente ouvinte e conselheiro(a), capaz de trazer harmonia e equilíbrio aos ambientes mais caóticos.\n\nSeu caminho de crescimento passa pelo desenvolvimento da autoconfiança e pela afirmação de suas próprias necessidades. A tendência a colocar os outros em primeiro lugar pode levá-lo(a) a se anular. Ao aprender a dizer "não" quando necessário, sua diplomacia se torna ainda mais poderosa e respeitada.',
      inspiracao:
          'Unir não é se anular; é harmonizar sem perder a melodia própria.',
      tags: ['Diplomacia', 'Mediação', 'Cooperação'],
    ),
    3: const VibrationContent(
      titulo: 'Criatividade e Comunicação',
      descricaoCurta:
          'Talentos artísticos, comunicação magnética e otimismo contagiante.',
      descricaoCompleta:
          'Sua forma de agir no mundo é criativa, comunicativa e cheia de otimismo. Você possui o dom da palavra e da autoexpressão, encantando e inspirando as pessoas ao seu redor com seu carisma e sua alegria de viver. Seus talentos brilham intensamente nas artes, na comunicação, nas vendas e em todas as atividades sociais.\n\nA criatividade flui através de você de maneira natural, seja escrevendo, falando, cantando ou atuando. Você tem a rara habilidade de dar vida e cor a tudo o que toca. Sua energia magnética atrai amigos e oportunidades, e sua visão otimista da vida é contagiante.\n\nO maior desafio para sua expressão é manter o foco e a disciplina. A abundância de ideias e interesses pode levar à dispersão de energia. Quando você aprende a canalizar sua imensa criatividade em projetos concretos e a levá-los até o fim, seu sucesso se torna tão brilhante quanto a sua personalidade.',
      inspiracao: 'Criar é fácil; concluir com maestria é arte.',
      tags: ['Criatividade', 'Comunicação', 'Otimismo'],
    ),
    4: const VibrationContent(
      titulo: 'Trabalho e Estrutura',
      descricaoCurta:
          'Talentos de organização, construção e planejamento metódico.',
      descricaoCompleta:
          'Você se expressa no mundo através do trabalho, da disciplina e de uma notável capacidade de organização. É uma pessoa prática, confiável e com um talento especial para construir bases sólidas e seguras em todas as áreas da vida. Sua marca é a persistência e a dedicação em tudo o que faz.\n\nSeus talentos se destacam em atividades que exigem método, planejamento e atenção aos detalhes. Seja na administração, na engenharia, na construção ou em qualquer campo que precise de ordem e estrutura, sua contribuição é inestimável. Você é a pessoa que transforma o caos em sistema e os planos em realidade.\n\nO seu crescimento está em aprender a ser mais flexível e a se permitir momentos de descanso e lazer. A tendência a se prender excessivamente ao trabalho e à rotina pode limitar sua visão. Ao se abrir para o novo e confiar que nem tudo precisa ser tão rígido, você constrói uma vida não apenas sólida, mas também feliz e equilibrada.',
      inspiracao: 'Estrutura sustenta sonhos; flexibilidade os mantém vivos.',
      tags: ['Organização', 'Disciplina', 'Construção'],
    ),
    5: const VibrationContent(
      titulo: 'Versatilidade e Liberdade',
      descricaoCurta:
          'Talentos de adaptação rápida, comunicação dinâmica e inovação.',
      descricaoCompleta:
          'Seus talentos se revelam na sua incrível versatilidade, na sua rápida adaptabilidade e no seu contagiante espírito de aventura. Você age no mundo de forma magnética e curiosa, buscando constantemente por novas experiências, conhecimentos e sensações. A liberdade é o oxigênio para a sua alma e a chave para sua expressão.\n\nVocê tem uma habilidade rara de se sentir em casa em qualquer lugar e de se comunicar com todos os tipos de pessoas. O seu dinamismo o(a) torna excelente em profissões que envolvem viagens, vendas, publicidade e qualquer área que exija pensamento rápido e capacidade de improvisação. A mudança não o(a) assusta, ela o(a) estimula.\n\nO grande desafio para você é usar essa imensa liberdade com foco e responsabilidade. A impulsividade e a busca incessante pelo novo podem levar à inconstância e à dificuldade em concluir projetos. Quando você aprende a direcionar sua energia e a se comprometer com um propósito, sua versatilidade se torna um dom para a inovação e o progresso.',
      inspiracao: 'Liberdade sem foco dispersa; com propósito, transforma.',
      tags: ['Versatilidade', 'Liberdade', 'Adaptação'],
    ),
    6: const VibrationContent(
      titulo: 'Cuidado e Harmonia',
      descricaoCurta:
          'Talentos de acolhimento, ensino e criação de ambientes harmoniosos.',
      descricaoCompleta:
          'A maneira como você se expressa revela que sua principal característica é a capacidade de acomodar a todos com conforto e bem-estar. Seu jeito carinhoso e afável permite que você se relacione com facilidade e construa amizades duradouras. Você tem um forte senso de justiça e responsabilidade, buscando sempre a harmonia em seu lar e em seus grupos sociais.\n\nEducar, ensinar e cuidar são alguns dos seus muitos talentos, assim como as artes e tudo o que contribui para a estética e a beleza da vida. Você sente um prazer genuíno em servir e em criar ambientes onde todos se sintam acolhidos e seguros. Sua generosidade é imensa, e você não mede esforços para ajudar quem precisa.\n\nSua maneira de amar envolve uma grande dose de emoção, dedicação e manifestações de afeto, pois você precisa sentir o calor humano através do contato físico. O seu desafio é aprender a equilibrar o cuidado com os outros e o autocuidado, pois a tendência a se sacrificar pode gerar frustrações quando não há reciprocidade.',
      inspiracao:
          'Cuidar dos outros começa cuidando de si com a mesma ternura.',
      tags: ['Cuidado', 'Harmonia', 'Serviço'],
    ),
    7: const VibrationContent(
      titulo: 'Sabedoria e Análise',
      descricaoCurta:
          'Talentos de pesquisa profunda, intuição aguçada e busca da verdade.',
      descricaoCompleta:
          'Você interage com o mundo de forma analítica, introspectiva e perfeccionista. Seus talentos estão profundamente ligados à sua mente afiada e à sua capacidade de pesquisa, estudo e busca pelo conhecimento aprofundado. Você não se contenta com respostas superficiais; sua natureza é a de um(a) especialista, um(a) sábio(a) que busca a verdade.\n\nSua intuição é uma ferramenta poderosa, guiando-o(a) em suas investigações e reflexões. Você se destaca em carreiras acadêmicas, científicas, tecnológicas ou espirituais, onde sua mente analítica e seu desejo de perfeição podem brilhar. O silêncio e a solidão não o(a) assustam, pois são neles que você encontra suas melhores ideias.\n\nO principal desafio para sua expressão é aprender a conectar seu vasto mundo interior com o mundo exterior. A tendência ao isolamento pode impedi-lo(a) de compartilhar seus dons. Ao aprender a traduzir seus conhecimentos de forma acessível e a se abrir emocionalmente, você se torna um verdadeiro farol de sabedoria e inspiração.',
      inspiracao:
          'Sabedoria isolada é tesouro guardado; compartilhada, ilumina.',
      tags: ['Sabedoria', 'Análise', 'Intuição'],
    ),
    8: const VibrationContent(
      titulo: 'Poder e Gestão',
      descricaoCurta:
          'Talentos de liderança empresarial, gestão e visão estratégica.',
      descricaoCompleta:
          'Sua forma de agir no mundo é poderosa, justa e notavelmente ambiciosa. Você possui um talento natural para a administração, os negócios e a liderança de grandes organizações. Sua visão estratégica e sua capacidade de gerenciar recursos e pessoas são as chaves para alcançar o sucesso material e o reconhecimento que você almeja.\n\nVocê tem os pés no chão e uma habilidade ímpar para transformar esforço em resultados concretos e duradouros. O poder e a autoridade não o(a) intimidam; pelo contrário, você se sente confortável em posições de comando, onde pode exercer seu aguçado senso de justiça e sua capacidade de organização.\n\nSeu caminho de crescimento está em equilibrar a ambição material com os valores éticos e espirituais. O verdadeiro poder, para você, reside em construir algo que não apenas gere riqueza, mas que também promova o progresso e o bem-estar coletivo. Usar sua força para servir com justiça é a sua mais elevada forma de expressão.',
      inspiracao: 'Poder verdadeiro constrói impérios que elevam, não dominam.',
      tags: ['Poder', 'Gestão', 'Liderança'],
    ),
    9: const VibrationContent(
      titulo: 'Compaixão e Humanitarismo',
      descricaoCurta:
          'Talentos de ensino, arte universal e serviço à humanidade.',
      descricaoCompleta:
          'Você se expressa no mundo de maneira compassiva, humanitária e profundamente inspiradora. Seus talentos estão a serviço de um ideal maior, usando sua sabedoria, generosidade e visão ampla para ajudar os outros e lutar por um mundo melhor. Você é um(a) grande professor(a), artista e conselheiro(a) nato(a).\n\nSua energia é universal, permitindo que você se conecte com pessoas de todas as origens com uma tolerância e compreensão admiráveis. Você se sente realizado(a) ao se dedicar a causas sociais, artísticas ou filantrópicas, onde pode aplicar sua criatividade e seu amor pela humanidade.\n\nSeu maior desafio é aprender a viver seus ideais no mundo prático sem se desiludir. A sensibilidade elevada pode torná-lo(a) vulnerável ao sofrimento alheio. O segredo para sua plena expressão é aprender a doar sem se esgotar, a perdoar sem guardar mágoas e a inspirar pelo exemplo, tornando-se um canal vivo do amor incondicional.',
      inspiracao: 'Compaixão prática transforma sonhos em legados vivos.',
      tags: ['Compaixão', 'Humanitarismo', 'Ensino'],
    ),
  };

  // MOTIVAÇÃO (1–9) — descrição curta para cards e completa para modal
  static final Map<int, VibrationContent> textosMotivacao = {
    1: const VibrationContent(
      titulo: 'Liderança e Autonomia',
      descricaoCurta:
          'Você se realiza liderando, iniciando e criando seu próprio caminho.',
      descricaoCompleta:
          'Sua alma vibra com o desejo de ser pioneiro(a), de liderar e de trilhar um caminho único. A independência não é apenas uma escolha, mas uma necessidade profunda que alimenta suas decisões mais importantes. Você se sente verdadeiramente vivo(a) quando está no comando, criando algo novo e superando desafios com sua própria força e originalidade.\n\nEssa busca incessante por autonomia o(a) impulsiona a assumir a dianteira em projetos e a inspirar coragem nos outros. Seus valores mais íntimos estão alicerçados na autossuficiência e na crença inabalável em seu próprio potencial. É essa força interior que o(a) guia, mesmo nos momentos de dúvida, a seguir sua própria verdade.\n\nLembre-se de equilibrar essa poderosa energia. Em momentos de insegurança, a tendência pode ser o isolamento ou o autoritarismo. A verdadeira liderança, no entanto, floresce quando sua independência inspira e abre caminhos não apenas para si, mas para todos ao seu redor.',
      inspiracao: 'Lidere a si mesmo primeiro; o mundo seguirá a sua coragem.',
      tags: ['Liderança', 'Início', 'Autonomia'],
    ),
    2: const VibrationContent(
      titulo: 'Harmonia e Cooperação',
      descricaoCurta:
          'Você se move pela união, paz e construção de pontes com os outros.',
      descricaoCompleta:
          'O que verdadeiramente move sua alma é a busca pela harmonia, pela união e pela cooperação. Você encontra sua força mais profunda na capacidade de construir pontes, de pacificar ambientes e de trabalhar em conjunto com os outros. Seus valores internos estão enraizados na diplomacia, na gentileza e em um desejo genuíno de ver todos ao seu redor em paz.\n\nEssa necessidade de conexão faz de você um(a) parceiro(a), amigo(a) e colega inestimável. Sua intuição é aguçada para perceber as necessidades alheias, e sua maior satisfação vem de poder contribuir, apoiar e fazer parte de algo maior que si mesmo(a). A segurança dos laços afetivos e das parcerias saudáveis é o que nutre seu espírito.\n\nO seu desafio e, ao mesmo tempo, seu grande dom, é aprender a colaborar sem perder sua própria voz. Cultive a autoconfiança para que sua sensibilidade seja sua maior força, e não uma porta para a dependência. Seu caminho de realização está em ser o elo que une e fortalece.',
      inspiracao:
          'Harmonia não é ausência de voz — é a arte de afinar propósitos.',
      tags: ['Cooperação', 'Diplomacia', 'Parcerias'],
    ),
    3: const VibrationContent(
      titulo: 'Expressão e Alegria',
      descricaoCurta:
          'Você busca se expressar, criar e encantar por meio da comunicação.',
      descricaoCompleta:
          'Sua essência anseia por se expressar, por criar e por se conectar com o mundo de forma alegre e otimista. A comunicação é a chave da sua alma, e você se sente realizado(a) quando pode compartilhar suas ideias, sua criatividade e seu entusiasmo. A beleza, a arte e a vida social são os combustíveis que incendeiam sua vontade e suas ambições.\n\nVocê é movido(a) pelo desejo de inspirar e encantar, de usar as palavras e a criatividade para tornar o mundo um lugar mais leve e vibrante. A popularidade e as amizades sinceras são extremamente importantes para você, pois é na troca com os outros que sua alma verdadeiramente se expande e floresce.\n\nSeu principal aprendizado é canalizar essa imensa energia criativa de forma focada. A tendência à dispersão pode ser um desafio, mas quando você encontra um objetivo claro para sua expressão, seu potencial se torna ilimitado. Use seu dom para espalhar alegria e inspiração, pois essa é a sua mais bela contribuição ao mundo.',
      inspiracao: 'Sua voz é ponte — atravesse e leve luz para o outro lado.',
      tags: ['Comunicação', 'Criatividade', 'Sociabilidade'],
    ),
    4: const VibrationContent(
      titulo: 'Estrutura e Disciplina',
      descricaoCurta:
          'Você se realiza construindo bases sólidas com ética e constância.',
      descricaoCompleta:
          'A sua essência psíquica de alma se revela na fidelidade absoluta pelos seus ideais, pela ordem e pela disciplina. A busca por segurança e estabilidade é a força motriz que guia suas decisões mais íntimas. Você é movido(a) pelo desejo de construir bases sólidas para o futuro, tanto no plano material quanto no emocional, valorizando o trabalho árduo, a honestidade e a persistência.\n\nSeus planos e objetivos são traçados com cuidado, e você possui um código de ética rígido que norteia suas ações. A sensação de dever cumprido e a segurança de ter tudo sob controle trazem paz ao seu coração. Sua maior ambição é criar um legado de estabilidade e confiança para si e para aqueles que ama.\n\nÉ importante que você se permita desfrutar do presente e encontre flexibilidade em meio à sua disciplina. A rigidez excessiva pode torná-lo(a) resistente a mudanças necessárias. Lembre-se que a verdadeira segurança vem não apenas do que você constrói, mas da sua capacidade de se adaptar e confiar no fluxo da vida.',
      inspiracao: 'Disciplina com propósito constrói o que o tempo respeita.',
      tags: ['Estrutura', 'Trabalho', 'Responsabilidade'],
    ),
    5: const VibrationContent(
      titulo: 'Liberdade e Mudança',
      descricaoCurta:
          'Você é movido(a) por novas experiências, movimento e versatilidade.',
      descricaoCompleta:
          'O desejo pulsante por liberdade, aventura e constante mudança é o que verdadeiramente o(a) impulsiona. Sua alma anseia por novas experiências, por explorar o desconhecido e por se sentir livre de qualquer rotina ou amarra. A versatilidade é seu sobrenome, e você se sente vivo(a) quando está em movimento, aprendendo e se adaptando a novos cenários.\n\nEssa motivação interna o(a) torna uma pessoa magnética e curiosa, sempre em busca de sensações que expandam seus horizontes. Suas escolhas são guiadas pela necessidade de sentir o vento da mudança soprando, seja através de viagens, novos conhecimentos ou relacionamentos dinâmicos. A monotonia é a prisão da sua alma.\n\nSeu grande desafio é viver essa liberdade com propósito e responsabilidade. A impulsividade pode levá-lo(a) a caminhos de inconstância, mas quando você alinha seu desejo de explorar com um objetivo maior, sua jornada se torna uma poderosa fonte de evolução e inspiração para todos ao seu redor.',
      inspiracao: 'Liberdade com direção vira ponte — não fuga.',
      tags: ['Liberdade', 'Versatilidade', 'Aventura'],
    ),
    6: const VibrationContent(
      titulo: 'Cuidado e Harmonia',
      descricaoCurta:
          'Você se realiza nutrindo vínculos, lares e responsabilidades afetivas.',
      descricaoCompleta:
          'A busca por harmonia no lar, o senso de responsabilidade e o desejo de cuidar dos outros são suas principais motivações. Sua essência valoriza a família, a comunidade e as relações afetivas, sentindo-se realizado(a) ao criar ambientes de paz e bem-estar. Você age como um(a) conselheiro(a) e protetor(a) natural para aqueles que ama.\n\nA necessidade de se sentir útil e amado(a) é o que move suas decisões mais profundas. Você encontra grande satisfação em servir, em nutrir e em ver seus entes queridos felizes e seguros. Sua alma se expande através de atos de amor, generosidade e justiça, buscando sempre o equilíbrio e a beleza nas relações humanas.\n\nO seu aprendizado está em encontrar o equilíbrio entre o doar e o receber. O sacrifício excessivo, sem a devida reciprocidade, pode levar à frustração e ao ressentimento. Ame e cuide dos outros, mas nunca se esqueça de nutrir também a sua própria alma, pois você merece o mesmo carinho que oferece ao mundo.',
      inspiracao: 'Quem cuida com medida floresce com consistência.',
      tags: ['Família', 'Responsabilidade', 'Justiça'],
    ),
    7: const VibrationContent(
      titulo: 'Verdade e Sabedoria',
      descricaoCurta:
          'Você busca conhecimento profundo, significado e aperfeiçoamento.',
      descricaoCompleta:
          'Sua alma busca incansavelmente o conhecimento, a verdade e um sentido mais profundo para a existência. Você é motivado(a) pela análise, pela pesquisa e pela introspecção, preferindo a quietude da reflexão para tomar suas decisões. A perfeição, a especialização e a sabedoria são os ideais que o(a) impulsionam em sua jornada.\n\nVocê possui uma mente investigativa e uma intuição aguçada que o(a) levam a questionar tudo o que é superficial. Sente-se atraído(a) pelos mistérios da vida, pela ciência, filosofia e espiritualidade. Sua motivação não é material, mas sim a de desvendar os segredos do universo e de si mesmo(a).\n\nSeu maior desafio é aprender a compartilhar sua imensa sabedoria interior sem se isolar do mundo. A tendência ao distanciamento pode ser grande, mas sua luz brilha mais forte quando ilumina o caminho dos outros. Confie em sua intuição e permita que seu conhecimento se transforme em uma fonte de inspiração.',
      inspiracao: 'O silêncio certo revela respostas inteiras.',
      tags: ['Conhecimento', 'Introspecção', 'Fé'],
    ),
    8: const VibrationContent(
      titulo: 'Realização e Justiça',
      descricaoCurta:
          'Você quer construir, prosperar e liderar com eficiência e ética.',
      descricaoCompleta:
          'A ambição por sucesso, poder e justiça é a grande força que move a sua alma. Seus valores mais íntimos estão ligados à organização, ao planejamento e à execução de grandes projetos que tragam progresso e prosperidade. Você deseja conquistar uma posição de autoridade e reconhecimento, utilizando sua força para construir um legado duradouro.\n\nVocê tem uma capacidade natural para lidar com o mundo material e financeiro, enxergando oportunidades onde outros não veem. O desejo de superação e a busca pela excelência são constantes em sua vida. Sua motivação é a de ser um pilar de força e estabilidade, provendo segurança e liderando pelo exemplo.\n\nO caminho para sua realização plena está em equilibrar o poder material com os valores espirituais. O autoritarismo e a obsessão pelo trabalho são tendências que precisam de atenção. Quando você usa sua autoridade com justiça e generosidade, seu sucesso se torna uma força para o bem, beneficiando a todos ao seu redor.',
      inspiracao: 'Poder com propósito vira legado — não só resultado.',
      tags: ['Realização', 'Gestão', 'Equilíbrio'],
    ),
    9: const VibrationContent(
      titulo: 'Serviço e Compaixão',
      descricaoCurta:
          'Você se inspira ao servir, perdoar e elevar o bem comum.',
      descricaoCompleta:
          'Sua motivação mais profunda nasce do amor universal, da compaixão e de um intenso desejo de servir à humanidade. Você sente um forte impulso para se dedicar a causas maiores, para ajudar os necessitados e para tornar o mundo um lugar mais justo e fraterno. Seus ideais são elevados e sua visão de vida é ampla e generosa.\n\nVocê é movido(a) pela necessidade de fazer a diferença, de deixar um legado de bondade e altruísmo. A generosidade, o perdão e a doação são os valores que guiam suas escolhas mais importantes. Sua alma se sente plena quando está contribuindo para o bem-estar coletivo, sem esperar nada em troca.\n\nSeu grande aprendizado é praticar essa doação sem se sobrecarregar com os problemas do mundo, lembrando-se de cuidar também de si. Sua sensibilidade é um dom precioso. Permita que sua compaixão seja uma fonte de cura e inspiração, e você encontrará a mais profunda e verdadeira realização.',
      inspiracao: 'Servir com limites saudáveis multiplica o bem.',
      tags: ['Humanitarismo', 'Perdão', 'Altruísmo'],
    ),
    // Cobertura básica para números mestres (fallback)
    11: _buildBasico(
      tituloBase: 'Motivação',
      foco: 'desejos do coração e aquilo que impulsiona suas escolhas',
    )[11]!,
    22: _buildBasico(
      tituloBase: 'Motivação',
      foco: 'desejos do coração e aquilo que impulsiona suas escolhas',
    )[22]!,
  };

  // IMPRESSÃO (1–9) — como você é percebido(a) à primeira vista
  static final Map<int, VibrationContent> textosImpressao = {
    1: const VibrationContent(
      titulo: 'Liderança e Iniciativa',
      descricaoCurta: 'Imagem de liderança, independência e autoconfiança.',
      descricaoCompleta:
          'Você projeta uma imagem de liderança, independência e uma autoconfiança contagiante. As pessoas o(a) percebem como alguém original, corajoso(a) e determinado(a), que não tem medo de assumir a frente e traçar o próprio rumo. Sua postura e modo de agir transmitem uma aura de autoridade e iniciativa.\n\nEssa primeira impressão faz com que os outros naturalmente confiem em sua capacidade de resolver problemas e de iniciar novos projetos. Sua presença é marcante, e você é visto(a) como a pessoa ideal para tomar decisões importantes e guiar a equipe em direção ao sucesso.\n\nÉ importante estar ciente de que essa forte imagem pode, por vezes, ser interpretada como arrogância ou individualismo. Busque equilibrar sua força com a empatia, mostrando que sua liderança também sabe ouvir e colaborar, transformando sua poderosa imagem em uma fonte de inspiração para todos.',
      inspiracao: 'A força que inicia também acolhe quem caminha junto.',
      tags: ['Liderança', 'Autonomia', 'Início'],
    ),
    2: const VibrationContent(
      titulo: 'Gentileza e Cooperação',
      descricaoCurta: 'Imagem de doçura, paz e diplomacia.',
      descricaoCompleta:
          'A sua aparência tímida e serena pode enganar a muitos, pois por trás dela existe uma grande força interior. Você passa a impressão de ser uma personalidade dócil, sensível, delicada e compreensiva, alguém que busca a harmonia e evita conflitos a todo custo. Sua presença transmite paz e tranquilidade.\n\nCom movimentos discretos e um jeito gentil, você aparenta ser uma pessoa modesta e pacífica, que valoriza a companhia e a segurança dos relacionamentos. Seu bom gosto no vestuário é notável, mas sempre pautado pela discrição, refletindo sua natureza reservada.\n\nEssa imagem de pessoa amável e prestativa pode atrair aqueles que desejam se aproveitar de sua boa vontade. Lembre-se que a primeira impressão nem sempre revela a totalidade do ser. É no conjunto de todas as suas características que sua verdadeira personalidade se estabelece e seus talentos se manifestam plenamente.',
      inspiracao: 'Gentileza é poder que age por dentro.',
      tags: ['Diplomacia', 'Paz', 'Parceria'],
    ),
    3: const VibrationContent(
      titulo: 'Carisma e Expressão',
      descricaoCurta: 'Imagem criativa, comunicativa e sociável.',
      descricaoCompleta:
          'As pessoas o(a) veem como alguém extremamente comunicativo(a), otimista e sociável. Sua imagem externa é a de uma pessoa criativa, popular e cheia de vida, que atrai os outros com seu carisma e sua simpatia contagiante. Você parece estar sempre de bom humor e pronto(a) para uma boa conversa.\n\nSua aparência e seu modo de se expressar são vibrantes e artísticos, o que faz com que os outros o(a) percebam como alguém com grande talento para as artes e para a comunicação. Você brilha em ambientes sociais, tornando-se facilmente o centro das atenções de forma natural e agradável.\n\nÉ fundamental lembrar que essa imagem leve e descontraída pode, por vezes, ser interpretada como superficialidade. Mostre ao mundo que, por trás de toda essa alegria, existe também profundidade e comprometimento. Assim, seu magnetismo pessoal se tornará uma ferramenta ainda mais poderosa para o sucesso.',
      inspiracao: 'Carisma com foco vira impacto duradouro.',
      tags: ['Comunicação', 'Alegria', 'Criatividade'],
    ),
    4: const VibrationContent(
      titulo: 'Solidez e Confiança',
      descricaoCurta: 'Imagem séria, organizada e extremamente confiável.',
      descricaoCompleta:
          'Você transmite uma imagem de seriedade, organização e extrema confiança. É percebido(a) como alguém trabalhador(a), disciplinado(a) e leal, em quem se pode depositar grandes responsabilidades. Sua postura firme e seu jeito prático de encarar a vida inspiram segurança e respeito.\n\nSua aparência tende a ser sóbria e conservadora, refletindo sua busca por estabilidade e ordem. As pessoas veem em você um pilar de força, alguém que mantém os pés no chão e que é capaz de construir projetos sólidos e duradouros. Sua palavra é vista como uma garantia.\n\nEssa primeira impressão de rigidez pode, ocasionalmente, afastar pessoas que buscam mais flexibilidade e espontaneidade. Permita que os outros também conheçam seu lado mais descontraído. Ao equilibrar sua seriedade com um pouco de leveza, você se tornará uma presença ainda mais admirada e querida.',
      inspiracao: 'Firmeza com leveza atrai confiança e proximidade.',
      tags: ['Estrutura', 'Disciplina', 'Lealdade'],
    ),
    5: const VibrationContent(
      titulo: 'Dinamismo e Liberdade',
      descricaoCurta: 'Imagem versátil, magnética e aventureira.',
      descricaoCompleta:
          'Sua imagem pública é a de alguém versátil, magnético(a) e com um espírito aventureiro. As pessoas o(a) percebem como uma pessoa curiosa, inteligente e que adora a liberdade e o movimento. Seu modo de agir é moderno e desinibido, atraindo os outros com seu entusiasmo e sua energia contagiante.\n\nVocê transmite a ideia de que está sempre pronto(a) para uma nova experiência, adaptando-se com facilidade a diferentes pessoas e situações. Sua presença é estimulante e imprevisível, o que desperta a curiosidade e o interesse de todos ao seu redor. Sua imagem está associada ao progresso e à novidade.\n\nÉ importante ter atenção para que essa imagem de liberdade não seja confundida com inconstância ou irresponsabilidade. Mostre que sua versatilidade vem acompanhada de propósito e que seu desejo de mudança é, na verdade, uma busca por evolução. Assim, seu magnetismo será uma força para o crescimento.',
      inspiracao: 'Movimento com propósito é sinônimo de evolução.',
      tags: ['Versatilidade', 'Curiosidade', 'Mudança'],
    ),
    6: const VibrationContent(
      titulo: 'Acolhimento e Responsabilidade',
      descricaoCurta: 'Imagem de cuidado, justiça e confiabilidade.',
      descricaoCompleta:
          'Você projeta uma imagem de responsabilidade, acolhimento e grande confiabilidade. É visto(a) como uma pessoa de família, um(a) conselheiro(a) nato(a) e alguém que se preocupa genuinamente com o bem-estar dos outros. Sua presença transmite harmonia, segurança e serenidade.\n\nAs pessoas sentem que podem contar com você nos momentos difíceis, pois sua aura é a de um porto seguro. Sua aparência e seu modo de tratar os outros são afetuosos e justos, fazendo com que se sentam confortáveis e protegidos ao seu lado. Você é a personificação do lar e da estabilidade afetiva.\n\nEssa impressão de ser o(a) "cuidador(a)" do grupo pode atrair pessoas que buscam apenas tirar proveito de sua boa vontade. Aprenda a impor limites saudáveis, para que sua generosidade seja sempre uma fonte de alegria, e não de sobrecarga. Seu dom de harmonizar ambientes é precioso, use-o com sabedoria.',
      inspiracao: 'Limites claros protegem o amor que você oferece.',
      tags: ['Cuidado', 'Justiça', 'Família'],
    ),
    7: const VibrationContent(
      titulo: 'Profundidade e Especialização',
      descricaoCurta: 'Imagem analítica, reservada e de grande saber.',
      descricaoCompleta:
          'As pessoas o(a) percebem como alguém introspectivo(a), inteligente e com um ar de mistério. Sua imagem é a de um(a) especialista ou estudioso(a), que parece estar sempre analisando o mundo a um nível mais profundo. Sua postura reservada e seu olhar analítico despertam a curiosidade e o respeito.\n\nSua aparência tende a ser discreta e refinada, refletindo sua busca pela perfeição e pelo conhecimento. Você não sente a necessidade de chamar a atenção; sua sabedoria fala por si. Essa aura de distanciamento intelectual pode ser interpretada como nobreza e profundidade.\n\nÉ importante notar que essa imagem pode, por vezes, passar a impressão de que você é uma pessoa fria ou inacessível. Faça um esforço consciente para se conectar emocionalmente com os outros, compartilhando um pouco do seu vasto mundo interior. Isso o(a) tornará uma presença ainda mais fascinante e admirada.',
      inspiracao: 'Deixar-se ver também é parte da sabedoria.',
      tags: ['Conhecimento', 'Refinamento', 'Introspecção'],
    ),
    8: const VibrationContent(
      titulo: 'Poder e Reconhecimento',
      descricaoCurta: 'Imagem forte, estratégica e bem-sucedida.',
      descricaoCompleta:
          'Sua imagem pública é a de poder, sucesso e autoridade. Você é percebido(a) como um(a) executivo(a) nato(a), alguém com visão de negócios e uma incrível capacidade para liderar grandes projetos. Sua postura é imponente e sua aparência, geralmente elegante, transmite confiança e controle absolutos.\n\nAs pessoas olham para você e veem alguém que sabe o que quer e como alcançar. Sua presença inspira respeito e, por vezes, um certo temor. Você é visto(a) como uma pessoa justa, mas firme, que lida com o mundo material com maestria e ambição.\n\nEsteja atento(a) para que essa impressão de poder não seja confundida com materialismo excessivo ou arrogância. Demonstre que sua força também está a serviço de um propósito maior e que sua liderança é pautada pela ética. Ao fazer isso, sua imagem de sucesso se transformará em um verdadeiro legado de inspiração.',
      inspiracao: 'Poder que serve multiplica resultados e respeito.',
      tags: ['Autoridade', 'Estratégia', 'Sucesso'],
    ),
    9: const VibrationContent(
      titulo: 'Humanidade e Inspiração',
      descricaoCurta: 'Imagem sábia, compassiva e universal.',
      descricaoCompleta:
          'Você projeta uma imagem de humanitarismo, sabedoria e uma profunda compaixão. As pessoas o(a) enxergam como um(a) idealista, alguém generoso(a) e que se importa com o bem maior da coletividade. Sua presença transmite uma aura de tranquilidade, tolerância e compreensão, inspirando confiança e respeito.\n\nSeu modo de ver o mundo parece mais amplo, e você é percebido(a) como um(a) grande professor(a) ou conselheiro(a), alguém a quem se pode recorrer em busca de uma palavra sábia e imparcial. Sua energia é universal, e você parece se conectar com todos os tipos de pessoas sem qualquer preconceito.\n\nO desafio dessa imagem é não parecer alguém distante da realidade prática do dia a dia. É importante mostrar que seus ideais elevados podem ser aplicados de forma concreta e efetiva. Ao unir sua visão humanitária com ações práticas, você se torna um verdadeiro agente de transformação no mundo.',
      inspiracao: 'Ideais que viram ação mudam destinos.',
      tags: ['Compaixão', 'Sabedoria', 'Universalidade'],
    ),
    // NÚMEROS MESTRES (Impressão)
    11: const VibrationContent(
      titulo: 'Inspiração, Visão e Intuição Elevada',
      descricaoCurta:
          'Imagem inspiradora, sensível e visionária; presença que eleva o ambiente.',
      descricaoCompleta:
          'No contexto de Impressão, o 11 projeta uma imagem de inspiração e de percepção aguçada. As pessoas tendem a enxergá-lo(a) como alguém sensível, intuitivo(a) e com um brilho diferente no olhar — uma presença que eleva a conversa e desperta confiança espiritual. Sua postura transmite propósito e idealismo, como se você carregasse uma visão maior a ser compartilhada com o mundo.\n\n'
          'Em encontros e primeiras conversas, você pode parecer um(a) guia natural: alguém que capta nuances, acolhe com empatia e oferece palavras que tocam o essencial. Essa aura “mestre” do 11 nasce da sua capacidade de enxergar possibilidades e significados onde outros veem apenas fatos. Por isso, sua imagem frequentemente inspira, conforta e encoraja.\n\n'
          'O ponto de atenção está em equilibrar essa sensibilidade elevada com centramento. Em dias mais tensos, a mesma intensidade pode soar como nervosismo, dispersão ou excesso de expectativa. Ao ancorar sua intuição em hábitos simples (respiração, rotina leve, presença no corpo), sua impressão permanece clara e luminosa: um convite a sonhar mais alto, mas com os pés no chão.',
      inspiracao:
          'Quando você honra a sua sensibilidade, sua presença ilumina sem ofuscar.',
      tags: ['Mestre', 'Intuição', 'Inspiração'],
    ),
    22: const VibrationContent(
      titulo: 'Construção Visionária e Presença Sólida',
      descricaoCurta:
          'Imagem de liderança serena, visão prática e capacidade de realizar em grande escala.',
      descricaoCompleta:
          'Como Impressão, o 22 — Mestre Construtor — transmite uma presença firme, pragmática e inspiradora ao mesmo tempo. A primeira leitura que os outros fazem é a de alguém confiável, organizado(a) e dotado(a) de uma visão objetiva de futuro. Você passa a sensação de que “as coisas andam” ao seu lado: há método, foco e ambição saudável.\n\n'
          'Sua imagem combina autoridade tranquila com cuidado pelo coletivo. Em conversas iniciais, é comum que percebam sua clareza no pensar, sua disciplina e a habilidade de transformar ideias em planos concretos. O 22 inspira segurança: parece saber onde quer chegar — e como levar pessoas e projetos com você.\n\n'
          'O cuidado está em evitar rigidez excessiva ou a impressão de frieza utilitária. Lembrar-se de mostrar o coração por trás da estratégia mantém a sua presença magnética e humana. Quando a visão elevada se alia à escuta e à colaboração, sua impressão se torna um chamado natural à construção de algo que perdure e beneficie muitos.',
      inspiracao:
          'Visão com método vira legado; método com coração vira ponte para todos.',
      tags: ['Mestre', 'Construção', 'Liderança'],
    ),
  };

  // MISSÃO DE VIDA (1–9, 11, 22) — propósito transcendental e autorrealização
  static final Map<int, VibrationContent> textosMissao = {
    1: const VibrationContent(
      titulo: 'Ser Pioneiro(a)',
      descricaoCurta:
          'Desenvolver individualidade e inspirar independência nos outros.',
      descricaoCompleta:
          'Sua missão é desenvolver a individualidade e a liderança, inspirando os outros a serem mais independentes e corajosos. Você veio ao mundo para ser um(a) pioneiro(a), para inovar e para ensinar pelo exemplo o poder da força de vontade e da iniciativa. Sua felicidade depende de sua capacidade de ser autêntico(a) e de guiar os outros com originalidade e confiança.\n\nO universo confia a você a tarefa de desbravar novos territórios, seja no campo das ideias, das artes ou dos negócios. Sua jornada consiste em superar o medo da solidão e a tendência ao autoritarismo, transformando sua energia de comando em uma liderança que capacita e eleva as pessoas ao seu redor.\n\nAo cumprir sua missão de ser um farol de independência e inovação, você não apenas alcança sua própria autorrealização, mas também acende a chama da coragem no coração de muitos. Assuma seu poder com responsabilidade, pois seu propósito é criar e liderar o caminho para o novo.',
      inspiracao:
          'Sua missão é abrir caminhos e inspirar outros a seguirem seus próprios.',
      tags: ['Pioneirismo', 'Liderança', 'Inovação'],
    ),
    2: const VibrationContent(
      titulo: 'Promover União',
      descricaoCurta: 'Ensinar diplomacia, paciência e o poder da cooperação.',
      descricaoCompleta:
          'Sua vocação é promover a união, a paz e a cooperação entre as pessoas. Você tem a missão de ensinar ao mundo a importância da diplomacia, da paciência e do trabalho em equipe. Sua autorrealização virá ao atuar como um(a) pacificador(a), conectando corações e harmonizando ambientes através de sua imensa sensibilidade e compreensão.\n\nA vida lhe dará a oportunidade de mostrar que a verdadeira força não reside na agressividade, mas na gentileza e na capacidade de construir pontes. Sua tarefa é curar divisões, seja em sua família, em seu trabalho ou em sua comunidade, usando seu dom de ouvir e de mediar.\n\nAo abraçar sua missão de ser um elo de união, você encontra sua felicidade e cumpre seu propósito divino. O mundo precisa desesperadamente de sua calma e de sua sabedoria para resolver conflitos. Seja o exemplo vivo de que a cooperação e o amor são as ferramentas mais poderosas para a evolução.',
      inspiracao: 'Sua missão é unir corações e curar divisões.',
      tags: ['União', 'Paz', 'Diplomacia'],
    ),
    3: const VibrationContent(
      titulo: 'Expressar Alegria',
      descricaoCurta:
          'Inspirar otimismo e beleza através da comunicação criativa.',
      descricaoCompleta:
          'Sua missão na vida é expressar a alegria, a criatividade e a comunicação. Você veio para inspirar o otimismo e a beleza no mundo através de seus talentos artísticos e de sua incrível capacidade de se comunicar. Sua felicidade será encontrada ao compartilhar sua luz e sua criatividade com os outros, tornando a vida de todos mais leve, colorida e cheia de esperança.\n\nO universo lhe deu o dom da palavra e da expressão para que você seja um canal de inspiração. Sua tarefa é usar essa ferramenta para motivar, para encantar e para elevar o espírito humano. Seja através da arte, da escrita ou da simples convivência, seu propósito é lembrar as pessoas da alegria de viver.\n\nNão subestime o poder do seu otimismo. Em um mundo muitas vezes cinzento, sua missão de espalhar cores e sorrisos é de um valor inestimável. Ao viver sua verdade criativa e ao se expressar autenticamente, você cumpre seu propósito e se torna uma fonte de inspiração contagiante.',
      inspiracao: 'Sua missão é lembrar ao mundo que a vida é celebração.',
      tags: ['Alegria', 'Comunicação', 'Criatividade'],
    ),
    4: const VibrationContent(
      titulo: 'Construir Ordem',
      descricaoCurta:
          'Ensinar o valor do trabalho, disciplina e bases sólidas.',
      descricaoCompleta:
          'Sua vocação é manifestar a ordem, a disciplina e a segurança no plano terreno. Você tem a missão de ensinar ao mundo o valor do trabalho honesto, da persistência e da responsabilidade. Veio ao mundo para construir bases sólidas e duradouras, seja na forma de uma família estável, uma carreira confiável ou um projeto que beneficie a comunidade.\n\nSua tarefa é trazer estrutura e forma aos sonhos e às ideias. A vida lhe dará a oportunidade de ser um pilar de estabilidade para os outros, um exemplo vivo de que, com dedicação e método, é possível alcançar qualquer objetivo. Sua integridade e sua confiabilidade são seus maiores dons.\n\nAo cumprir sua missão de ser um(a) construtor(a), você encontra sua autorrealização e sua felicidade. O mundo precisa de sua praticidade e de seu senso de dever para se manter em pé. Honre sua capacidade de transformar o abstrato em concreto, pois seu propósito é criar um legado de segurança e confiança para as futuras gerações.',
      inspiracao: 'Sua missão é edificar estruturas que o tempo não derruba.',
      tags: ['Construção', 'Disciplina', 'Segurança'],
    ),
    5: const VibrationContent(
      titulo: 'Encorajar Liberdade',
      descricaoCurta:
          'Estimular mudanças, coragem e liberdade com responsabilidade.',
      descricaoCompleta:
          'A sua missão é encorajar o bom exercício da liberdade, com responsabilidade, estimular a coragem e o espírito aventureiro que explora novos campos do conhecimento. Você veio para provocar mudanças e transformações na consciência humana e na sociedade, mostrando que é possível viver de forma mais livre e autêntica.\n\nEsta missão é desafiadora, pois exige que você equilibre o desejo de aventura com o respeito aos limites estabelecidos pela afetividade e pela responsabilidade por seus atos. O perigo está em se perder nos excessos dos sentidos ou em confundir a liberdade com a libertinagem.\n\nA melhor maneira de cumprir sua missão é pelo exemplo. Ao viver sua liberdade de forma consciente, contendo a impulsividade e honrando seus compromissos, você se torna um verdadeiro agente de progresso. Sua felicidade resultará de sua autorrealização ao inspirar os outros a se libertarem de suas próprias amarras.',
      inspiracao:
          'Sua missão é mostrar que liberdade verdadeira vem com consciência.',
      tags: ['Liberdade', 'Mudança', 'Transformação'],
    ),
    6: const VibrationContent(
      titulo: 'Servir e Harmonizar',
      descricaoCurta: 'Cuidar, aconselhar e criar ambientes de paz e amor.',
      descricaoCompleta:
          'Sua missão é servir, harmonizar e cuidar, especialmente no âmbito da família e da comunidade. Sua vocação é ser um(a) conselheiro(a), um porto seguro para os que o(a) cercam, ensinando pelo exemplo o valor do amor, da responsabilidade e da justiça. A felicidade virá ao criar um ambiente de paz e bem-estar e ao se sentir útil para os outros.\n\nVocê veio a este mundo com a tarefa de ser um pilar de equilíbrio nos relacionamentos. Sua jornada envolve curar laços, nutrir os necessitados e embelezar o ambiente ao seu redor. Seja através da arte, do ensino ou do simples ato de ouvir, seu propósito é manifestar o amor em sua forma mais prática e acolhedora.\n\nAo abraçar essa missão de guardião(ã) do lar e da comunidade, você encontra sua mais profunda autorrealização. O mundo precisa de sua capacidade de harmonizar e de seu senso de justiça para se tornar um lugar mais amável. Honre sua vocação para o serviço, pois nela reside a chave para uma vida plena de significado.',
      inspiracao: 'Sua missão é ser refúgio de paz em tempos de tempestade.',
      tags: ['Serviço', 'Harmonia', 'Cuidado'],
    ),
    7: const VibrationContent(
      titulo: 'Compartilhar Sabedoria',
      descricaoCurta:
          'Buscar e ensinar conhecimento profundo e verdades espirituais.',
      descricaoCompleta:
          'Sua missão é buscar e compartilhar o conhecimento e a sabedoria que transcendem o mundo material. Você veio para aprofundar o entendimento sobre os mistérios da vida e para ensinar os outros a olharem para dentro de si, a desenvolverem a fé e a conectarem-se com a sua espiritualidade. Sua autorrealização será encontrada na vida intelectual e espiritual.\n\nSua jornada é a de um(a) filósofo(a), cientista ou mestre espiritual, que ilumina o caminho com sua inteligência e, acima de tudo, com sua intuição. Sua tarefa é investigar, questionar e revelar as verdades ocultas, mostrando ao mundo que existe muito mais do que os olhos podem ver.\n\nAo cumprir sua missão de ser um farol de sabedoria, você ajuda a humanidade a evoluir. Não tema os períodos de solidão, pois são neles que você encontrará suas maiores revelações. Confie em sua voz interior e compartilhe o que descobrir, pois seu propósito é despertar a consciência.',
      inspiracao: 'Sua missão é iluminar mentes e despertar almas.',
      tags: ['Sabedoria', 'Conhecimento', 'Espiritualidade'],
    ),
    8: const VibrationContent(
      titulo: 'Liderar com Justiça',
      descricaoCurta:
          'Usar poder e abundância para promover progresso ético e equilibrado.',
      descricaoCompleta:
          'Sua vocação é aprender a usar o poder, a autoridade e a abundância material com justiça e equilíbrio. Você tem a missão de organizar, administrar e liderar grandes projetos que promovam o progresso para todos. Sua felicidade depende de sua capacidade de conciliar o sucesso material com os valores espirituais, ensinando aos outros como manifestar a prosperidade de forma ética.\n\nA vida lhe confiará posições de grande responsabilidade e influência. Sua tarefa é usar esse poder não para o ganho egoísta, mas para criar oportunidades, gerar empregos e administrar os recursos do planeta com sabedoria e visão de futuro. Você veio para ser um exemplo de liderança justa e eficiente.\n\nAo abraçar sua missão de ser um(a) executivo(a) do bem, você encontra sua autorrealização. O mundo precisa de sua força e de sua capacidade de organização para prosperar de forma equilibrada. Demonstre que é possível ser ambicioso(a) e ético(a), poderoso(a) e justo(a), e seu legado será de imensa riqueza em todos os sentidos.',
      inspiracao: 'Sua missão é provar que poder com ética transforma o mundo.',
      tags: ['Poder', 'Justiça', 'Liderança'],
    ),
    9: const VibrationContent(
      titulo: 'Amar Universalmente',
      descricaoCurta: 'Ensinar compaixão, perdão e dedicação ao bem coletivo.',
      descricaoCompleta:
          'Sua missão é viver e ensinar o amor incondicional, a compaixão e o perdão. Você veio ao mundo para se dedicar a causas humanitárias e para inspirar os outros com sua generosidade e sabedoria. Sua autorrealização e felicidade serão alcançadas quando você se desapegar do que é pessoal e se dedicar ao bem-estar coletivo.\n\nSua jornada é a de um(a) grande professor(a), artista ou filantropo(a), cuja vida se torna uma mensagem de esperança para o mundo. Sua tarefa é transcender fronteiras e preconceitos, mostrando a todos que somos uma única família humana. O perdão e o desapego serão suas ferramentas mais poderosas.\n\nAo viver essa missão de doação universal, você completa um importante ciclo em sua evolução espiritual. Não se prenda às pequenas coisas; sua visão deve ser sempre ampla e inclusiva. Inspire a humanidade com seu exemplo de altruísmo, e você encontrará uma paz e uma plenitude que transcendem qualquer conquista material.',
      inspiracao:
          'Sua missão é ser farol de amor que ilumina toda a humanidade.',
      tags: ['Amor Universal', 'Compaixão', 'Altruísmo'],
    ),
    11: const VibrationContent(
      titulo: 'Mensageiro(a) Espiritual',
      descricaoCurta:
          'Elevar consciências e trazer revelações inspiradoras ao mundo.',
      descricaoCompleta:
          'Sua missão é a de ser um(a) "mensageiro(a) espiritual", um canal de inspiração e intuição para a humanidade. Você veio para elevar a consciência das pessoas, trazendo novas ideias, revelações e uma profunda compreensão das leis espirituais. Sua vocação é a de ser um farol de luz em tempos de escuridão, guiando os outros através de sua sabedoria intuitiva.\n\nEsta é uma missão de grande responsabilidade, que exige que você viva em um alto padrão de integridade e que confie plenamente em sua voz interior. Sua jornada envolverá o desenvolvimento de seus dons psíquicos e a coragem de compartilhar suas visões, mesmo que pareçam à frente de seu tempo. Você é um(a) professor(a) espiritual, um(a) artista inspirado(a) ou um(a) diplomata da paz.\n\nAo aceitar seu papel de guia e inspirador(a), você alcança os mais altos níveis de autorrealização. O nervosismo e a dúvida podem ser seus maiores desafios, mas a fé em seu propósito lhe dará a força necessária. Ilumine o mundo com sua visão única, pois sua missão é despertar a espiritualidade nos corações.',
      inspiracao:
          'Sua missão é canalizar luz divina e despertar almas adormecidas.',
      tags: ['Inspiração', 'Intuição', 'Espiritualidade'],
    ),
    22: const VibrationContent(
      titulo: 'Mestre Construtor(a)',
      descricaoCurta:
          'Transformar sonhos espirituais em realizações concretas de impacto global.',
      descricaoCompleta:
          'Sua missão é a do(a) "Mestre Construtor(a)": transformar os mais elevados sonhos espirituais em realidade concreta para o benefício da humanidade. Você veio para criar projetos de grande escala que tenham um impacto duradouro e positivo no mundo, unindo o idealismo com uma extraordinária capacidade de planejamento e execução.\n\nVocê tem a vocação para liderar grandes corporações, fundações, ou até mesmo nações, com o propósito de criar um futuro melhor. Sua tarefa é construir pontes, hospitais, sistemas educacionais ou qualquer estrutura que sirva para unir e elevar a condição humana. Você é o(a) arquiteto(a) de um novo mundo.\n\nEsta é a mais poderosa das missões, e seu maior desafio é não se sobrecarregar com a magnitude de sua própria visão ou não usar seu poder para fins puramente egoístas. Ao se manter conectado(a) ao seu ideal de serviço e ao trabalhar de forma prática e disciplinada, você tem o potencial de deixar um legado que marcará gerações.',
      inspiracao:
          'Sua missão é construir o futuro da humanidade — tijolo por tijolo.',
      tags: ['Construção', 'Legado', 'Impacto Mundial'],
    ),
  };

  // TALENTO OCULTO detalhado (1–9) — habilidades dormentes que emergem
  static final Map<int, VibrationContent> textosTalentoOculto = {
    1: const VibrationContent(
      titulo: 'Empreender e Liderar',
      descricaoCurta: 'Novo talento para inovar e atuar com autonomia.',
      descricaoCompleta:
          'De forma sutil e intuitiva, desperta em você um novo talento para empreender e inovar. Uma força interior o(a) impulsiona a atuar de forma mais independente e autônoma, mesmo que o restante de sua personalidade seja mais colaborativo. Este dom inato se manifesta como uma nova coragem para assumir a liderança de seus próprios projetos.\n\nEsse senso de liderança pode se revelar na decisão de abrir seu próprio negócio, assumir um novo cargo de maior responsabilidade ou simplesmente tomar as rédeas de sua vida com mais determinação. É um chamado da alma para a autossuficiência e a originalidade, um reforço em sua individualidade.\n\nEste talento pode se projetar de forma positiva, como um espírito empreendedor e uma iniciativa renovada, ou de forma negativa, como arrogância e prepotência. O segredo está em usar essa nova força com sabedoria, como um dom que aperfeiçoa suas habilidades e o(a) impulsiona a realizar seu potencial máximo.',
      inspiracao:
          'Liderar a si mesmo é o primeiro passo de toda grande jornada.',
      tags: ['Empreendedorismo', 'Autonomia', 'Iniciativa'],
    ),
    2: const VibrationContent(
      titulo: 'Diplomacia e Parceria',
      descricaoCurta:
          'Dom intuitivo para colaborar e mediar com sensibilidade.',
      descricaoCompleta:
          'Emerge de seu interior um dom intuitivo para a diplomacia, a colaboração e a formação de parcerias estratégicas. Mesmo que você seja naturalmente independente, surge uma nova e sutil capacidade de unir pessoas, de agir com mais sensibilidade e de perceber as nuances dos relacionamentos que antes passavam despercebidas.\n\nEste talento se manifesta como uma voz interior que o(a) guia para a cooperação em vez do confronto. Você se descobre um(a) excelente mediador(a), capaz de harmonizar ambientes e de encontrar soluções ganha-ganha com uma facilidade surpreendente. É a sabedoria da alma ensinando o poder da união.\n\nUse este dom para fortalecer seus laços pessoais e profissionais. Ele é um aperfeiçoamento de suas habilidades, trazendo mais equilíbrio e profundidade às suas interações. Confie nessa sua nova capacidade de perceber e de conectar, pois ela abrirá portas para um sucesso compartilhado e muito mais gratificante.',
      inspiracao: 'Unir forças multiplica resultados e reduz esforços.',
      tags: ['Diplomacia', 'Parceria', 'Sensibilidade'],
    ),
    3: const VibrationContent(
      titulo: 'Comunicação e Criação',
      descricaoCurta: 'Talento mágico para comunicar e expressar com otimismo.',
      descricaoCompleta:
          'Desperta em você um talento sutil e quase mágico para a comunicação e a expressão criativa. Uma nova capacidade de usar as palavras, as ideias e as artes de forma otimista vem à tona, aumentando seu magnetismo pessoal e sua habilidade de inspirar e encantar as pessoas ao seu redor.\n\nEste dom se manifesta como um senso de humor mais aguçado, uma ideia brilhante que surge "do nada" ou uma facilidade repentina para se socializar e fazer amigos. É a sua criança interior se manifestando de forma sábia, trazendo mais alegria e leveza para a sua personalidade.\n\nAbrace este talento como um presente da sua alma. Use-o para motivar, para criar e para espalhar otimismo. Ele é um aperfeiçoamento de quem você é, projetando uma luz que não apenas ilumina o seu caminho, mas também o de todos que têm o prazer de estar ao seu lado.',
      inspiracao: 'Palavras bem escolhidas abrem corações e oportunidades.',
      tags: ['Comunicação', 'Otimismo', 'Criatividade'],
    ),
    4: const VibrationContent(
      titulo: 'Ordem e Praticidade',
      descricaoCurta: 'Senso intuitivo para estruturar e materializar ideias.',
      descricaoCompleta:
          'Desenvolve-se em seu interior um senso intuitivo para a ordem, a disciplina e a praticidade. De forma sutil, uma nova habilidade para construir e gerenciar com mais eficiência vem à tona, trazendo um alicerce de estabilidade e segurança para sua vida, mesmo que sua personalidade seja naturalmente mais sonhadora ou impulsiva.\n\nEste dom se manifesta como uma capacidade inata de transformar ideias em realidade concreta através do trabalho focado e da persistência. Você pode se surpreender com uma nova paciência para lidar com tarefas detalhadas ou com uma súbita clareza sobre como organizar seus projetos para o sucesso a longo prazo.\n\nAbrace este talento como a força que materializa seus sonhos. Ele é o elo entre o plano das ideias e o mundo real, um aperfeiçoamento de suas habilidades que lhe permite construir um legado de confiança e realizações duradouras.',
      inspiracao: 'Estrutura bem planejada sustenta os maiores sonhos.',
      tags: ['Disciplina', 'Praticidade', 'Construção'],
    ),
    5: const VibrationContent(
      titulo: 'Versatilidade e Adaptação',
      descricaoCurta: 'Dom sutil para lidar com mudanças e explorar o novo.',
      descricaoCompleta:
          'Revela-se em você um dom sutil para a versatilidade e a adaptação rápida. Uma nova e intuitiva capacidade de lidar com as mudanças e de explorar o desconhecido surge, trazendo mais liberdade e dinamismo para sua personalidade, mesmo que você tenha uma natureza mais cautelosa.\n\nEste talento se manifesta como uma agilidade mental para encontrar soluções criativas diante de imprevistos e uma sensação de conforto em situações que antes lhe causariam ansiedade. É a sua alma mostrando que a mudança não é uma ameaça, mas uma oportunidade de crescimento e expansão.\n\nUse este dom para se libertar de velhos padrões e para abraçar as infinitas possibilidades que a vida oferece. Confie na sua nova capacidade de se reinventar, pois ela o(a) guiará por jornadas fascinantes e o(a) tornará uma pessoa ainda mais magnética e interessante.',
      inspiracao: 'Flexibilidade diante do inesperado é força, não fraqueza.',
      tags: ['Adaptação', 'Liberdade', 'Reinvenção'],
    ),
    6: const VibrationContent(
      titulo: 'Aconselhamento e Cura',
      descricaoCurta:
          'Talento intuitivo para cuidar e harmonizar relacionamentos.',
      descricaoCompleta:
          'Emerge de seu interior um talento intuitivo para o aconselhamento, a cura e o serviço ao próximo. Uma nova capacidade de cuidar, de harmonizar relacionamentos e de assumir responsabilidades afetivas com sabedoria e compaixão se manifesta, tornando-o(a) um ponto de apoio natural para sua família e comunidade.\n\nEste dom sutil pode se revelar em uma palavra de conforto que você oferece no momento certo, em um conselho justo que pacifica um conflito ou em um desejo genuíno de criar um ambiente de paz e bem-estar para todos. É a sua alma expressando sua vocação para o amor e a justiça.\n\nAcolha este talento como uma de suas mais belas qualidades. Ele enriquece sua personalidade e o(a) conecta profundamente com as pessoas. Ao exercer essa capacidade de nutrir e harmonizar, você não apenas ajuda os outros, mas também encontra um caminho de profunda realização pessoal.',
      inspiracao: 'Quem cura com amor deixa marcas eternas.',
      tags: ['Cuidado', 'Aconselhamento', 'Harmonia'],
    ),
    7: const VibrationContent(
      titulo: 'Intuição e Análise',
      descricaoCurta: 'Dom inato para análise profunda e busca da verdade.',
      descricaoCompleta:
          'Desperta em você um dom inato para a análise profunda, a intuição e a busca da verdade. Uma nova profundidade intelectual e espiritual surge em sua personalidade, permitindo que você compreenda os mistérios da vida de uma forma que transcende a lógica comum, quase como uma revelação.\n\nEste talento se manifesta em uma percepção mais aguçada, em uma necessidade de aprofundar seus estudos ou em uma intuição poderosa que o(a) guia para as decisões corretas. É a sua alma de sábio(a) e especialista vindo à tona, buscando a perfeição e o conhecimento.\n\nConfie nesta voz interior que busca a sabedoria. Este dom é um convite para explorar seu mundo interior e para se tornar um(a) especialista naquilo que ama. Ao cultivar este talento, você não apenas enriquece a si mesmo(a), mas também se torna um farol de clareza e conhecimento para os outros.',
      inspiracao:
          'A sabedoria silenciosa guia com mais precisão que mil palavras.',
      tags: ['Intuição', 'Análise', 'Sabedoria'],
    ),
    8: const VibrationContent(
      titulo: 'Liderança e Gestão',
      descricaoCurta:
          'Talento sutil para administrar e conquistar sucesso material.',
      descricaoCompleta:
          'Manifesta-se em você um talento sutil para a liderança, a organização e o sucesso material. De forma intuitiva, uma nova capacidade de administrar com justiça, eficiência e visão de futuro vem à tona, como um dom inato para os negócios e para a execução de grandes projetos.\n\nEste senso de poder e autoridade pode surgir em momentos cruciais, quando você assume o controle de uma situação com uma firmeza e clareza surpreendentes. É a sua alma mostrando seu potencial para construir, prosperar e liderar com integridade.\n\nUse este dom para transformar seus objetivos em conquistas grandiosas. Este talento é um aperfeiçoamento de suas habilidades, dando-lhe a força e a visão necessárias para não apenas alcançar o sucesso, mas também para usar essa posição para promover o progresso e a justiça para todos ao seu redor.',
      inspiracao: 'Gestão com visão e ética constrói impérios duradouros.',
      tags: ['Gestão', 'Liderança', 'Realização'],
    ),
    9: const VibrationContent(
      titulo: 'Compaixão e Amor Universal',
      descricaoCurta:
          'Dom intuitivo para servir a humanidade com generosidade.',
      descricaoCompleta:
          'Revela-se em sua alma um dom intuitivo para a compaixão, a generosidade e o amor universal. Uma nova e sutil capacidade de compreender as dores do mundo e de ajudar a humanidade se manifesta, projetando em sua personalidade uma aura de sabedoria, altruísmo e uma imensa empatia.\n\nEste talento pode se expressar em um ato de caridade espontâneo, em uma palavra de perdão que liberta, ou em um desejo irresistível de se envolver em causas sociais e humanitárias. É a sua alma se conectando com o todo, sentindo o chamado para servir a um propósito maior.\n\nAbrace este dom como sua mais elevada vocação. Ele o(a) convida a transcender o ego e a viver para o bem coletivo. Ao permitir que este talento floresça, você se torna um canal de amor e inspiração, deixando um legado de bondade e compaixão no mundo.',
      inspiracao: 'Servir com amor transforma vidas — começando pela sua.',
      tags: ['Compaixão', 'Humanitarismo', 'Generosidade'],
    ),
    // Fallback para números mestres
    11: _buildBasico(
      tituloBase: 'Talento Oculto',
      foco: 'habilidades latentes que despertam em você',
    )[11]!,
    22: _buildBasico(
      tituloBase: 'Talento Oculto',
      foco: 'habilidades latentes que despertam em você',
    )[22]!,
  };

  // APTIDÕES E POTENCIALIDADES PROFISSIONAIS (1–9)
  static final Map<int, VibrationContent> textosAptidoesProfissionais = {
    1: const VibrationContent(
      titulo: 'Liderança e Pioneirismo',
      descricaoCurta: 'Carreiras de liderança, empreendedorismo e inovação.',
      descricaoCompleta:
          'Seus talentos apontam para carreiras onde a liderança, a independência e a inovação são essenciais. Você nasceu para estar à frente, para criar e para gerenciar. Posições de comando, empreendedorismo, direção de empresas, carreira militar ou política, e qualquer atividade autônoma onde possa imprimir sua marca e tomar suas próprias decisões são extremamente favoráveis.\n\nSua força de vontade e determinação o(a) tornam apto(a) para ser um(a) pioneiro(a). Áreas como tecnologia, design, invenções ou qualquer campo que exija abrir novos mercados se beneficiam imensamente do seu perfil. Você não apenas segue tendências, você as cria.\n\nPara alcançar o sucesso, é crucial que você acredite em sua capacidade de liderar e não tenha medo de assumir riscos calculados. Seu maior potencial se realiza quando você tem autonomia para agir. Busque ambientes que valorizem sua iniciativa e permitam que sua visão inovadora floresça.',
      inspiracao: 'Pioneiros constroem caminhos onde outros veem apenas mato.',
      tags: ['Liderança', 'Inovação', 'Empreendedorismo'],
    ),
    2: const VibrationContent(
      titulo: 'Diplomacia e Colaboração',
      descricaoCurta:
          'Carreiras que exigem sensibilidade, cooperação e análise.',
      descricaoCompleta:
          'Suas aptidões naturais brilham em profissões que exigem diplomacia, cooperação e sensibilidade. Você tem um talento especial para trabalhar em equipe, para mediar conflitos e para criar ambientes harmoniosos. Carreiras como diplomata, psicólogo(a), assistente social, terapeuta, professor(a) ou em recursos humanos são perfeitas para você.\n\nSua paciência e atenção aos detalhes também o(a) qualificam para atividades que requerem precisão e análise, como pesquisa, contabilidade, biblioteconomia ou qualquer função de suporte e assessoria a um líder. Sua maior força está em sua capacidade de colaborar e de apoiar os outros, trazendo equilíbrio e coesão para o grupo.\n\nO sucesso profissional virá quando você encontrar um ambiente que valorize suas habilidades de relacionamento e sua capacidade de unir pessoas. Lembre-se de que sua sensibilidade é um dom poderoso; use-a para construir parcerias sólidas e para promover a paz e a cooperação em seu meio de trabalho.',
      inspiracao: 'Quem une com tato constrói equipes invencíveis.',
      tags: ['Diplomacia', 'Cooperação', 'Análise'],
    ),
    3: const VibrationContent(
      titulo: 'Comunicação e Criatividade',
      descricaoCurta: 'Carreiras em artes, comunicação e interação social.',
      descricaoCompleta:
          'Seu potencial profissional é imenso em todas as áreas ligadas à comunicação, criatividade e interação social. Você tem o dom da palavra e da autoexpressão, o que o(a) torna excelente como ator/atriz, escritor(a), jornalista, publicitário(a), designer, músico(a) ou qualquer profissão no mundo das artes e do entretenimento.\n\nSua energia otimista e seu carisma natural também abrem portas em carreiras que envolvem o contato com o público, como vendas, relações públicas, organização de eventos ou turismo. Sua capacidade de inspirar e motivar as pessoas é um trunfo valioso em qualquer campo que você escolher.\n\nPara que seus talentos floresçam, busque um trabalho que lhe traga alegria e que não seja excessivamente rotineiro. Ambientes dinâmicos e que permitam a livre expressão de suas ideias são ideais. Canalize sua criatividade com foco e seus dons de comunicação o(a) levarão a um sucesso brilhante e gratificante.',
      inspiracao: 'Criatividade com foco vira carreira de impacto.',
      tags: ['Comunicação', 'Artes', 'Criatividade'],
    ),
    4: const VibrationContent(
      titulo: 'Estrutura e Gestão',
      descricaoCurta:
          'Carreiras que exigem organização, disciplina e trabalho metódico.',
      descricaoCompleta:
          'Você se destaca em profissões que exigem disciplina, organização, honestidade e um trabalho metódico. Sua capacidade de construir e de trazer ordem ao caos faz de você um(a) excelente administrador(a), engenheiro(a), arquiteto(a), contador(a) ou planejador(a) financeiro. Qualquer carreira que exija a criação de sistemas e estruturas sólidas é ideal.\n\nSua persistência e atenção aos detalhes também são valiosas em áreas como o direito, a programação de computadores, o funcionalismo público e trabalhos que envolvam a terra, como a agricultura ou a geologia. Sua marca é a confiança e a capacidade de entregar resultados concretos e de alta qualidade.\n\nO sucesso para você está em encontrar uma carreira que ofereça estabilidade e onde seu esforço seja reconhecido. Ambientes de trabalho organizados e com regras claras favorecem seu desempenho. Lembre-se de que sua dedicação é sua maior virtude; através dela, você é capaz de construir um legado profissional de imenso valor e durabilidade.',
      inspiracao: 'Bases sólidas sustentam os maiores sucessos.',
      tags: ['Organização', 'Disciplina', 'Estrutura'],
    ),
    5: const VibrationContent(
      titulo: 'Dinamismo e Adaptação',
      descricaoCurta:
          'Carreiras dinâmicas com liberdade, movimento e aprendizado constante.',
      descricaoCompleta:
          'Suas potencialidades brilham em carreiras dinâmicas, que envolvam liberdade, movimento e constante aprendizado. A rotina de um escritório convencional pode limitar seu imenso potencial. Você é excelente em vendas, publicidade, jornalismo investigativo, turismo, promoção de eventos e qualquer área que exija pensamento rápido e adaptabilidade.\n\nSeu magnetismo pessoal e sua habilidade de se comunicar com diferentes públicos o(a) tornam um(a) ótimo(a) advogado(a) de tribunal, detetive ou profissional de relações internacionais. Carreiras que envolvem o uso do corpo e dos sentidos, como gastronomia, esportes ou dança, também são extremamente favoráveis.\n\nPara se realizar profissionalmente, busque um trabalho que ofereça variedade, desafios e a liberdade de gerenciar seu próprio tempo. Abrace sua versatilidade, pois ela é sua maior aliada. Em um mundo em constante mudança, sua capacidade de se reinventar é a chave para um sucesso extraordinário e uma vida profissional excitante.',
      inspiracao: 'Versatilidade bem direcionada é sinônimo de progresso.',
      tags: ['Dinamismo', 'Adaptação', 'Liberdade'],
    ),
    6: const VibrationContent(
      titulo: 'Cuidado e Harmonia',
      descricaoCurta:
          'Carreiras voltadas ao bem-estar humano, ensino e aconselhamento.',
      descricaoCompleta:
          'Você poderá atuar profissionalmente em todas as atividades que envolvam o ser humano e seu bem-estar geral. Terá mais êxito quando, na atividade profissional escolhida, surgirem oportunidades de ajustar todos da equipe numa atmosfera de harmonia e paz. Sua natureza cuidadora e seu senso de justiça o(a) tornam um(a) profissional exemplar.\n\nAlgumas atividades se destacam: Educação, ensino, artes, administração hospitalar, biblioteconomia, decoração, enfermagem, medicina, nutrição, psicologia, advocacia, serviço social, recursos humanos e consultoria. Seu talento para criar ambientes harmoniosos e para aconselhar as pessoas é um diferencial em qualquer uma dessas áreas.\n\nO sucesso virá de carreiras onde você possa expressar seu desejo de servir e de melhorar a vida das pessoas. Ambientes de trabalho que valorizem a colaboração, a ética e o bem-estar coletivo são os mais adequados para você. Ao alinhar sua profissão com sua vocação de cuidar, você encontrará uma satisfação profunda e duradoura.',
      inspiracao: 'Cuidar com propósito transforma profissão em vocação.',
      tags: ['Cuidado', 'Ensino', 'Harmonia'],
    ),
    7: const VibrationContent(
      titulo: 'Especialização e Pesquisa',
      descricaoCurta:
          'Carreiras que exigem pesquisa, análise e conhecimento técnico profundo.',
      descricaoCompleta:
          'Seu potencial se realiza plenamente em carreiras que exijam pesquisa, análise, especialização e um profundo conhecimento técnico. Você nasceu para ser um(a) especialista. Áreas como ciência, tecnologia, pesquisa acadêmica, filosofia, teologia, análise de sistemas ou qualquer campo da engenharia são perfeitas para sua mente analítica.\n\nSua intuição e seu perfeccionismo também o(a) qualificam para profissões que exigem um olhar apurado e um toque de refinamento, como relojoaria, joalheria, crítica de arte ou restauração. Sua capacidade de concentração e de aprofundamento em um único tema é o que o(a) diferencia da maioria.\n\nBusque uma profissão que lhe permita trabalhar com um certo grau de autonomia e silêncio, onde você possa mergulhar em seus pensamentos e investigações. O reconhecimento virá não pela popularidade, mas pela excelência e pela genialidade do seu trabalho. Sua mente é sua maior ferramenta; invista nela e o sucesso será uma consequência natural.',
      inspiracao: 'Especialização com profundidade abre portas raras.',
      tags: ['Pesquisa', 'Análise', 'Especialização'],
    ),
    8: const VibrationContent(
      titulo: 'Negócios e Liderança',
      descricaoCurta:
          'Carreiras em administração, finanças e liderança de grandes projetos.',
      descricaoCompleta:
          'Suas aptidões são para o mundo dos grandes negócios, do poder e da liderança. Você tem um talento natural para a administração, as finanças e a execução de projetos de grande porte. Carreiras como diretor(a) de empresa (CEO), banqueiro(a), investidor(a), juiz(a), político(a) ou grande empreendedor(a) estão em perfeita sintonia com sua energia.\n\nSua visão estratégica e sua capacidade de organização permitem que você gerencie com maestria tanto recursos financeiros quanto humanos. Você não teme a responsabilidade e se sente à vontade em posições de autoridade, onde pode exercer seu aguçado senso de justiça e sua ambição por progresso.\n\nPara alcançar o ápice do sucesso, busque desafios que estejam à altura de sua capacidade. Não se contente com pouco. Seu caminho é o da construção de impérios, sejam eles financeiros, empresariais ou sociais. Ao aliar seu poder com a ética, seu legado profissional será de prosperidade e grande impacto.',
      inspiracao:
          'Visão estratégica aliada à ética constrói impérios duradouros.',
      tags: ['Administração', 'Finanças', 'Liderança'],
    ),
    9: const VibrationContent(
      titulo: 'Humanitarismo e Artes',
      descricaoCurta:
          'Carreiras com propósito humanitário, ensino e expressão criativa.',
      descricaoCompleta:
          'Seu potencial brilha em profissões que tenham um propósito humanitário e que permitam expressar sua criatividade e compaixão. Você se realiza em carreiras que visam ajudar os outros ou inspirar a humanidade. Medicina, enfermagem, direito (especialmente direitos humanos), serviço social, psicologia e ensino são vocações naturais para você.\n\nSeu lado artístico e sua visão ampla do mundo também o(a) tornam um(a) excelente artista, músico(a), escritor(a) ou filósofo(a). Qualquer profissão que permita que você se comunique com grandes públicos e transmita uma mensagem de esperança e transformação está alinhada com seus talentos.\n\nO sucesso para você não se mede apenas em termos financeiros, mas no impacto positivo que seu trabalho causa no mundo. Busque uma carreira que alimente sua alma e que esteja a serviço de um ideal maior. Ao fazer isso, você não apenas encontrará prosperidade, mas também um profundo sentimento de missão cumprida.',
      inspiracao: 'Impacto humano vale mais que qualquer título.',
      tags: ['Humanitarismo', 'Ensino', 'Artes'],
    ),
    // Fallback para números mestres
    11: _buildBasico(
      tituloBase: 'Aptidões Profissionais',
      foco: 'áreas de maior potencial e realização na carreira',
    )[11]!,
    22: _buildBasico(
      tituloBase: 'Aptidões Profissionais',
      foco: 'áreas de maior potencial e realização na carreira',
    )[22]!,
  };

  // NÚMERO PSÍQUICO (1–9) — como você se vê internamente e suas escolhas íntimas
  static final Map<int, VibrationContent> textosNumeroPsiquico = {
    1: const VibrationContent(
      titulo: 'Independência Interior',
      descricaoCurta: 'Você se vê como independente, original e líder natural.',
      descricaoCompleta:
          'Interiormente, você se vê como uma pessoa independente, original e com uma forte necessidade de liderar seus próprios caminhos. Suas escolhas em áreas como amizades, profissão e relacionamentos são guiadas por um desejo de autonomia e de não se submeter à vontade alheia. Você busca parceiros e amigos que respeitem seu espaço e admirem sua força.\n\nSua ambição é ser o(a) número um, o(a) pioneiro(a) em tudo o que faz. Essa força interior o(a) torna uma pessoa decidida e corajosa, que não tem medo de enfrentar desafios sozinho(a). No entanto, essa mesma força pode se manifestar como impaciência e uma certa dificuldade em aceitar ordens ou críticas.\n\nPara uma vida mais harmoniosa, é importante que você canalize essa poderosa energia de liderança de forma construtiva. Aprender a ouvir e a colaborar não enfraquece sua individualidade, mas a enriquece, tornando suas conquistas ainda mais significativas e inspiradoras para os outros.',
      inspiracao:
          'Liderar a si mesmo com sabedoria inspira quem caminha ao lado.',
      tags: ['Independência', 'Autonomia', 'Liderança'],
    ),
    2: const VibrationContent(
      titulo: 'Busca por União',
      descricaoCurta:
          'Você se vê como alguém que busca paz, cooperação e conexão.',
      descricaoCompleta:
          'Interiormente, você se percebe como alguém que busca a união, a paz e a cooperação. Suas escolhas mais íntimas, seja em amizades, relacionamentos ou na carreira, são fortemente influenciadas pelo seu desejo de pertencer e de criar laços harmoniosos. Você valoriza a lealdade, a amizade e a segurança que um bom relacionamento pode oferecer.\n\nSua natureza é a de um(a) diplomata, preferindo sempre o caminho do acordo ao do conflito. Você tem uma sensibilidade aguçada para as necessidades dos outros e se sente realizado(a) quando pode apoiar e colaborar. No entanto, essa mesma sensibilidade pode torná-lo(a) vulnerável a mágoas e propenso(a) a depender da aprovação alheia.\n\nSeu caminho de equilíbrio está em cultivar a autoconfiança para que sua gentileza não seja confundida com fraqueza. Aprenda a valorizar suas próprias opiniões e necessidades com a mesma dedicação que dedica aos outros. Ao fazer isso, sua capacidade de unir pessoas se torna uma força ainda mais poderosa e respeitada.',
      inspiracao: 'Colaborar com voz própria une sem anular.',
      tags: ['União', 'Diplomacia', 'Sensibilidade'],
    ),
    3: const VibrationContent(
      titulo: 'Expressão Interior',
      descricaoCurta: 'Você se vê como criativo(a), otimista e social.',
      descricaoCompleta:
          'Por dentro, você se vê como um ser criativo, otimista e com uma necessidade vital de se expressar e socializar. Suas escolhas são guiadas pelo desejo de alegria, beleza e comunicação. Você busca amigos, parceiros e atividades que estimulem sua imaginação e permitam que sua personalidade vibrante brilhe.\n\nSeu mundo interior é colorido e cheio de ideias. A monotonia e o silêncio excessivo podem causar-lhe angústia, pois sua alma anseia por interação e pela troca de energia que acontece nos encontros sociais. Você é naturalmente popular e atrai as pessoas com seu carisma e seu entusiasmo pela vida.\n\nO grande aprendizado para sua alma é encontrar o foco e a disciplina para canalizar essa imensa energia criativa. A tendência à dispersão pode impedi-lo(a) de concretizar seus muitos talentos. Ao se comprometer com seus projetos e aprofundar suas paixões, você transforma seu potencial ilimitado em realizações inspiradoras.',
      inspiracao: 'Criatividade com foco vira legado duradouro.',
      tags: ['Expressão', 'Criatividade', 'Alegria'],
    ),
    4: const VibrationContent(
      titulo: 'Busca por Segurança',
      descricaoCurta:
          'Você se vê como prático(a), organizado(a) e em busca de estabilidade.',
      descricaoCompleta:
          'Em seu íntimo, você se percebe como alguém prático, organizado e com uma profunda necessidade de segurança e estabilidade. Suas decisões em todas as áreas da vida são pautadas pela lógica, pela honestidade e pelo desejo de construir bases sólidas e duradouras. Você busca relacionamentos e trabalhos que ofereçam confiança e previsibilidade.\n\nSua natureza é a de um(a) construtor(a). Você se sente em paz quando está trabalhando de forma metódica em direção a um objetivo claro. A disciplina e a responsabilidade não são fardos para você, mas sim as ferramentas com as quais você edifica sua vida. Sua lealdade e seu senso de dever são admiráveis.\n\nSeu desafio interior é aprender a ser mais flexível e a se permitir relaxar. A tendência ao excesso de trabalho e à rigidez pode impedi-lo(a) de desfrutar das alegrias espontâneas da vida. Encontre o equilíbrio entre a construção e o descanso, e sua vida será não apenas segura, mas também plena e feliz.',
      inspiracao: 'Estrutura com flexibilidade sustenta felicidade real.',
      tags: ['Segurança', 'Praticidade', 'Disciplina'],
    ),
    5: const VibrationContent(
      titulo: 'Espírito Livre',
      descricaoCurta:
          'Você se vê como versátil, curioso(a) e ávido(a) por liberdade.',
      descricaoCompleta:
          'Sua essência psíquica caracteriza-se por uma índole frágil e delicada, uma mente ativa e um aguçado interesse por aprender coisas novas e explorar o desconhecido. Você se vê como um espírito livre, que precisa de movimento, variedade e constantes estímulos para se sentir feliz e realizado(a).\n\nAgilidade nas decisões, impulsividade no comportamento e planos de curto prazo são uma constante em sua vida. Você se sente bem em uma atmosfera alegre e divertida, e suas escolhas de amizades, viagens e até mesmo de profissão são guiadas por essa busca incessante pela liberdade e por novas experiências que satisfaçam sua curiosidade.\n\nCom uma intuição bem desenvolvida e grande facilidade de adaptação, você lida bem com o inesperado. Seu maior desafio é aprender a usar essa liberdade com responsabilidade, evitando a inconstância e a impulsividade que podem prejudicar a construção de bases sólidas para o seu futuro.',
      inspiracao: 'Liberdade com raízes permite voos mais altos.',
      tags: ['Liberdade', 'Versatilidade', 'Curiosidade'],
    ),
    6: const VibrationContent(
      titulo: 'Guardião(ã) da Harmonia',
      descricaoCurta:
          'Você se vê como responsável, cuidador(a) e em busca de harmonia.',
      descricaoCompleta:
          'Interiormente, você se vê como o(a) guardião(ã) da harmonia e da justiça, com um forte senso de responsabilidade pela sua família e comunidade. Suas escolhas são guiadas por um profundo desejo de cuidar, de nutrir e de criar um ambiente de paz e amor para todos ao seu redor. Você busca relacionamentos baseados no companheirismo, na lealdade e no afeto.\n\nSua alma anseia por se sentir útil e por assumir responsabilidades. Você tem um dom natural para o aconselhamento e para a resolução de problemas domésticos e emocionais. A beleza, a ordem e o conforto do lar são essenciais para o seu bem-estar e sua felicidade.\n\nO seu caminho de crescimento está em aprender a equilibrar o doar e o receber. Sua inclinação para o sacrifício pode levá-lo(a) a se anular em prol dos outros. Lembre-se de que o autocuidado não é egoísmo, mas uma necessidade. Ao se nutrir, você terá ainda mais amor e energia para compartilhar com o mundo.',
      inspiracao: 'Quem se nutre primeiro cuida melhor de todos.',
      tags: ['Responsabilidade', 'Cuidado', 'Harmonia'],
    ),
    7: const VibrationContent(
      titulo: 'Buscador(a) da Verdade',
      descricaoCurta:
          'Você se vê como analítico(a), introspectivo(a) e em busca de sabedoria.',
      descricaoCompleta:
          'Em seu âmago, você se percebe como um(a) buscador(a) da verdade, um(a) pensador(a) profundo(a) com uma mente analítica e intuitiva. Suas escolhas são guiadas pela necessidade de compreender os mistérios da vida, e você se sente atraído(a) por tudo que é profundo, intelectual e espiritual. Você busca relacionamentos e amizades com quem possa ter trocas mentais estimulantes.\n\nSua natureza é introspectiva e você valoriza a solidão como um espaço para recarregar suas energias e organizar seus pensamentos. Você não se contenta com respostas fáceis e está sempre investigando, estudando e buscando a perfeição em tudo o que faz. Sua intuição é uma bússola poderosa.\n\nSeu maior desafio é conectar seu rico mundo interior com as pessoas ao seu redor. A tendência ao isolamento e a dificuldade em expressar sentimentos podem criar uma barreira. Ao aprender a compartilhar sua sabedoria com mais calor humano, você se torna uma fonte de inspiração e conhecimento para todos.',
      inspiracao: 'Sabedoria compartilhada transforma solidão em legado.',
      tags: ['Análise', 'Introspecção', 'Sabedoria'],
    ),
    8: const VibrationContent(
      titulo: 'Ambição e Força',
      descricaoCurta:
          'Você se vê como forte, ambicioso(a) e voltado(a) ao sucesso material.',
      descricaoCompleta:
          'Interiormente, você se vê como uma pessoa forte, ambiciosa e com uma grande capacidade de liderança e execução. Suas escolhas são guiadas pelo desejo de sucesso, poder e justiça material. Você busca relacionamentos e projetos que estejam à altura de sua força e de sua visão de longo alcance.\n\nVocê possui um senso prático apurado e uma habilidade natural para organizar e administrar. O mundo material não o(a) assusta; pelo contrário, você o vê como uma arena onde pode exercer seu talento para construir e prosperar. Você busca o controle das situações e se sente realizado(a) ao ver seus esforços se transformarem em resultados concretos.\n\nSeu aprendizado está em equilibrar sua ambição com a generosidade e a ética. O poder, para você, deve ser uma ferramenta de progresso não apenas pessoal, mas coletivo. Ao usar sua força com justiça e sabedoria, você não apenas alcança o sucesso, mas constrói um legado de respeito e admiração.',
      inspiracao:
          'Ambição com ética constrói legados que transcendem gerações.',
      tags: ['Ambição', 'Força', 'Sucesso'],
    ),
    9: const VibrationContent(
      titulo: 'Idealista Compassivo(a)',
      descricaoCurta:
          'Você se vê como humanitário(a), idealista e com profunda compaixão.',
      descricaoCompleta:
          'Em sua essência, você se percebe como um(a) idealista, um(a) humanista com uma profunda compaixão por todos os seres. Suas escolhas são guiadas por um desejo de servir a um propósito maior e de tornar o mundo um lugar melhor. Você busca relacionamentos e atividades que tenham um significado profundo e que contribuam para o bem coletivo.\n\nSua alma é generosa e você possui uma visão ampla e tolerante da vida. Você se conecta facilmente com pessoas de todas as origens e sente as dores do mundo como se fossem suas. O amor incondicional, o perdão e a doação são os valores que norteiam sua jornada.\n\nSeu grande desafio é viver com os pés no chão sem perder a fé na humanidade. Sua alta sensibilidade pode, por vezes, levar a desilusões. Aprenda a canalizar seu idealismo em ações práticas e a cuidar de si mesmo(a) para não se esgotar. Sua capacidade de amar é seu maior dom; compartilhe-o com sabedoria.',
      inspiracao: 'Compaixão prática muda o mundo — um gesto de cada vez.',
      tags: ['Humanitarismo', 'Compaixão', 'Idealismo'],
    ),
    // Fallback para números mestres
    11: _buildBasico(
      tituloBase: 'Número Psíquico',
      foco: 'como você se vê internamente e suas escolhas íntimas',
    )[11]!,
    22: _buildBasico(
      tituloBase: 'Número Psíquico',
      foco: 'como você se vê internamente e suas escolhas íntimas',
    )[22]!,
  };

  // TENDÊNCIAS OCULTAS (1–9) — impulsos subconscientes que precisam ser equilibrados
  static final Map<int, VibrationContent> textosTendenciasOcultas = {
    1: const VibrationContent(
      titulo: 'Autoritarismo e Egoísmo',
      descricaoCurta:
          'Impulso subconsciente para dominar e colocar-se acima dos outros.',
      descricaoCompleta:
          'É o ímpeto da individualidade que se manifesta em seus impulsos. Em momentos de desequilíbrio, pode haver uma forte tendência ao autoritarismo, à dominância e a um egoísmo que o(a) faz colocar suas necessidades acima de tudo e de todos. A impaciência e o desejo de fazer tudo à sua maneira são traços fortes.\n\nEste impulso remanescente de memórias passadas pode levá-lo(a) a ter dificuldade em seguir ordens ou em trabalhar em equipe, preferindo sempre o caminho solo. A arrogância pode surgir como uma máscara para a insegurança, afastando pessoas que poderiam ser importantes aliadas em sua jornada.\n\nO antídoto para essa tendência é cultivar a humildade e a empatia. Lembre-se que a verdadeira liderança não impõe, mas inspira. Ao aprender a ouvir e a valorizar a contribuição dos outros, você transforma o ímpeto do egoísmo em uma poderosa e construtiva força de iniciativa.',
      inspiracao: 'Liderar não é dominar; é inspirar e elevar.',
      tags: ['Egoísmo', 'Autoritarismo', 'Equilíbrio'],
    ),
    2: const VibrationContent(
      titulo: 'Dependência Excessiva',
      descricaoCurta:
          'Impulso para depender emocionalmente dos outros e evitar decisões.',
      descricaoCompleta:
          'É o impulso das associações que rege suas atitudes subconscientes. Isso pode se manifestar como uma tendência a depender excessivamente dos outros, principalmente da família e dos amigos, tanto no aspecto monetário quanto, e especialmente, no emocional. Você pode sentir uma grande dificuldade em tomar decisões sozinho(a).\n\nEssa busca por apoio pode levá-lo(a) a se anular em relacionamentos, a ter medo da solidão e a se tornar suscetível à manipulação. A passividade e a submissão podem ser comportamentos recorrentes, nascidos de uma memória de insegurança e da crença de que você não é capaz de se virar sem ajuda.\n\nPara equilibrar essa tendência, é crucial desenvolver a autoconfiança e a independência emocional. Aprenda a desfrutar de sua própria companhia e a confiar em seu próprio julgamento. Ao fazer isso, sua necessidade de se associar se transforma em uma bela capacidade de cooperar, sem jamais perder sua própria identidade.',
      inspiracao: 'Cooperar é somar forças; depender é abdicar de si.',
      tags: ['Dependência', 'Insegurança', 'Autonomia'],
    ),
    3: const VibrationContent(
      titulo: 'Vaidade e Dispersão',
      descricaoCurta:
          'Impulso para ser o centro das atenções e evitar responsabilidades.',
      descricaoCompleta:
          'É o ímpeto da autoexpressão que aflora em seus comportamentos. Quando em desequilíbrio, há uma forte tendência à vaidade, à impaciência e à presunção. A necessidade de ser o centro das atenções pode levá-lo(a) a atitudes exibicionistas e a uma certa superficialidade nos relacionamentos.\n\nEste impulso pode fazer com que você disperse suas energias em múltiplos projetos sem concluir nenhum, vivendo sem objetivos concretos e buscando sempre diversões e festas, sem se preocupar muito com o dia de amanhã. A fuga das responsabilidades pode ser um padrão recorrente.\n\nO caminho para a harmonia está em canalizar sua imensa criatividade com foco e propósito. Use seu dom de comunicação para inspirar, e não apenas para entreter. Ao cultivar a disciplina e a profundidade, sua necessidade de se expressar se torna uma fonte de grande alegria e de realizações admiráveis.',
      inspiracao: 'Expressão com propósito cria; sem ele, apenas distrai.',
      tags: ['Vaidade', 'Dispersão', 'Foco'],
    ),
    4: const VibrationContent(
      titulo: 'Rigidez e Controle',
      descricaoCurta:
          'Impulso para controlar tudo e resistir a mudanças e flexibilidade.',
      descricaoCompleta:
          'É o impulso da ordem e do controle que se manifesta em seus padrões. Em desequilíbrio, isso pode levar a uma rigidez excessiva, teimosia e a uma resistência a qualquer tipo de mudança. A necessidade de ter tudo planejado e sob controle pode gerar ansiedade e dificuldade em lidar com o improviso.\n\nEssa tendência pode torná-lo(a) excessivamente crítico(a) consigo mesmo(a) e com os outros, ou, no extremo oposto, levar à preguiça e à procrastinação como uma forma de rebeldia contra a própria necessidade de estrutura. O apego ao trabalho e às regras pode sufocar sua espontaneidade.\n\nO antídoto está em aprender a arte da flexibilidade. Entenda que a vida flui e que nem tudo pode ser controlado. Permita-se errar, relaxar e experimentar o novo. Ao equilibrar a disciplina com a leveza, você constrói uma vida que não é apenas segura, mas também feliz e adaptável.',
      inspiracao: 'Estrutura sem flexibilidade quebra; com ela, sustenta.',
      tags: ['Rigidez', 'Controle', 'Flexibilidade'],
    ),
    5: const VibrationContent(
      titulo: 'Impulsividade e Excessos',
      descricaoCurta:
          'Impulso para buscar prazeres sem responsabilidade e fugir de compromissos.',
      descricaoCompleta:
          'É o ímpeto da mudança e da liberdade pessoal que guia seus impulsos. Quando essa energia está em desequilíbrio, há uma forte tendência a viver à custa dos outros, a abusar dos prazeres sensoriais (sexo, drogas, bebidas) e a tomar decisões precipitadas e impulsivas. A aversão à rotina pode se tornar uma fuga de responsabilidades.\n\nEssa busca incessante por novas sensações pode levá-lo(a) a uma vida de inconstância, com dificuldade em se firmar em relacionamentos, trabalhos ou locais. A impaciência e a irresponsabilidade podem ser os reflexos de uma liberdade mal compreendida, que não leva em conta as consequências dos próprios atos.\n\nPara harmonizar essa tendência, é essencial alinhar sua liberdade com um propósito. Use sua versatilidade para crescer e aprender, não para fugir. Ao cultivar a autodisciplina e o respeito pelos outros, sua imensa energia de mudança se transforma em uma poderosa força para a inovação e o progresso consciente.',
      inspiracao: 'Liberdade consciente liberta; impulsividade aprisiona.',
      tags: ['Impulsividade', 'Excessos', 'Responsabilidade'],
    ),
    6: const VibrationContent(
      titulo: 'Controle e Martírio',
      descricaoCurta:
          'Impulso para controlar os entes queridos e cobrar gratidão.',
      descricaoCompleta:
          'É o impulso do idealismo e da responsabilidade que molda suas atitudes. No lado negativo, isso pode se manifestar como uma tendência a ser excessivamente controlador(a) com as pessoas que ama, a se intrometer em assuntos alheios e a se tornar um "mártir", que se sacrifica pelos outros e depois cobra gratidão.\n\nO perfeccionismo, especialmente no lar e nos relacionamentos, pode torná-lo(a) uma pessoa ansiosa e difícil de agradar. A teimosia e a crença de que você sempre sabe o que é melhor para os outros podem gerar conflitos e ressentimentos, mesmo que sua intenção seja a de ajudar.\n\nO equilíbrio vem ao aprender a amar com desapego. Ofereça seu cuidado e seu conselho, mas respeite a liberdade e as escolhas de cada um. Cuide dos outros, mas não se esqueça de si mesmo(a). Ao transformar a cobrança em aceitação, seu impulso de harmonizar se torna uma fonte de verdadeiro amor e conforto.',
      inspiracao: 'Amor verdadeiro oferece; não impõe nem cobra.',
      tags: ['Controle', 'Perfeccionismo', 'Desapego'],
    ),
    7: const VibrationContent(
      titulo: 'Isolamento e Frieza',
      descricaoCurta:
          'Impulso para se isolar emocionalmente e intelectualizar sentimentos.',
      descricaoCompleta:
          'É o impulso da análise e da introspecção que se revela em seu subconsciente. Quando em desequilíbrio, essa tendência pode levar ao isolamento, ao pessimismo e a uma frieza emocional que afasta as pessoas. A mente crítica pode se voltar contra si mesmo(a), gerando sentimentos de inferioridade e perfeccionismo paralisante.\n\nEssa necessidade de entender tudo pode levá-lo(a) a desconfiar dos outros e a reprimir seus próprios sentimentos, com medo de parecer vulnerável. A tendência a intelectualizar as emoções pode criar uma barreira entre você e uma conexão mais profunda e genuína com a vida.\n\nO caminho para o equilíbrio está em desenvolver a fé e a confiança. Aprenda a sentir mais e a analisar menos. Permita-se ser imperfeito(a) e abra seu coração para os outros. Ao fazer isso, sua mente brilhante se une a um coração aberto, transformando o isolamento em uma sabedoria que inspira e conecta.',
      inspiracao: 'Sabedoria sem coração é fria; com ele, transforma.',
      tags: ['Isolamento', 'Frieza', 'Confiança'],
    ),
    8: const VibrationContent(
      titulo: 'Dominação e Materialismo',
      descricaoCurta:
          'Impulso para dominar, acumular poder e negligenciar o lado humano.',
      descricaoCompleta:
          'É o ímpeto do poder e da ambição que rege seus impulsos. No lado negativo, isso pode se manifestar como uma forte tendência ao autoritarismo, à intolerância e a um materialismo excessivo. O desejo de estar no controle pode levá-lo(a) a ser dominador(a) e a ter dificuldade em perdoar fraquezas, tanto as suas quanto as dos outros.\n\nEsse impulso pode resultar em uma obsessão por trabalho e status, negligenciando a saúde, a família e o lado espiritual da vida. A impaciência com processos lentos e a busca por poder a qualquer custo podem levá-lo(a) a tomar decisões injustas e a atropelar os sentimentos alheios.\n\nO antídoto para essa tendência é cultivar a justiça, a generosidade e a paciência. Entenda que o verdadeiro poder reside no equilíbrio e na capacidade de usar sua força para o bem de todos. Ao transformar a dominação em liderança servidora, sua ambição se torna uma força motriz para o progresso coletivo.',
      inspiracao: 'Poder a serviço do bem eleva; a serviço do ego, corrompe.',
      tags: ['Materialismo', 'Dominação', 'Justiça'],
    ),
    9: const VibrationContent(
      titulo: 'Idealismo Impraticável',
      descricaoCurta:
          'Impulso para viver em sonhos e absorver os problemas do mundo.',
      descricaoCompleta:
          'É o impulso do idealismo e da doação que se manifesta em seus padrões. Em desequilíbrio, isso pode levar a uma tendência a viver em um mundo de sonhos, com grande dificuldade em lidar com os aspectos práticos da vida. A generosidade pode se tornar imoderada, fazendo com que você seja facilmente explorado(a) por outros.\n\nA forte emotividade e a sensibilidade podem resultar em grandes oscilações de humor e em uma tendência a absorver os problemas do mundo, gerando ansiedade e depressão. A dificuldade em dizer "não" e em estabelecer limites pode levar ao esgotamento físico e emocional.\n\nPara harmonizar essa tendência, é crucial aprender a ser compassivo(a) também consigo mesmo(a). Ancore seus ideais em ações práticas e realistas. Doe, mas aprenda a receber. Ao equilibrar sua imensa capacidade de amar com o autocuidado e o senso prático, seu idealismo se torna uma poderosa e sustentável força de transformação.',
      inspiracao: 'Compaixão com limites sustenta; sem eles, esgota.',
      tags: ['Idealismo', 'Emotividade', 'Limites'],
    ),
  };

  // RESPOSTA SUBCONSCIENTE (1–9) — reação instintiva em emergências
  static final Map<int, VibrationContent> textosRespostaSubconsciente = {
    1: const VibrationContent(
      titulo: 'Ação e Liderança',
      descricaoCurta:
          'Reação instintiva: agir, tomar a frente e assumir controle.',
      descricaoCompleta:
          'Sua primeira reação a uma emergência é agir, tomar a frente e assumir o controle. De forma instintiva, você busca a solução mais rápida e direta, sem hesitação. Seu impulso é o da liderança e da ação imediata, mesmo que isso signifique agir sozinho(a) e assumir todos os riscos.\n\nEssa reatividade pode ser extremamente eficaz em crises que exigem uma decisão rápida, pois você não se paralisa pelo medo. No entanto, essa mesma impulsividade pode levá-lo(a) a agir de forma precipitada, sem analisar todas as variáveis, ou a passar por cima dos outros com uma atitude autoritária.\n\nSua força está na sua coragem e iniciativa. O desafio é aprender a respirar fundo por um instante antes de agir, permitindo que sua decisão seja não apenas rápida, mas também a mais sábia. Canalize seu instinto de líder para organizar e inspirar, e você será imbatível em qualquer emergência.',
      inspiracao: 'Coragem para agir é dom; sabedoria para pausar é virtude.',
      tags: ['Ação', 'Coragem', 'Liderança'],
    ),
    2: const VibrationContent(
      titulo: 'Busca de Apoio',
      descricaoCurta:
          'Reação instintiva: procurar parceria e apaziguar a situação.',
      descricaoCompleta:
          'Diante de uma crise, sua primeira reação instintiva é buscar apoio, parceria ou tentar apaziguar a situação. Você não age de forma impulsiva, mas tende a se retrair por um momento para avaliar o impacto emocional do evento. Seu impulso é o de procurar alguém com quem compartilhar o fardo ou buscar uma solução diplomática.\n\nEssa reatividade o(a) torna um excelente ponto de apoio em crises coletivas, pois sua preocupação imediata é com o bem-estar do grupo e a manutenção da harmonia. No entanto, em uma emergência que exige ação individual e imediata, essa tendência à hesitação ou à dependência pode ser prejudicial.\n\nSua força reside na sua sensibilidade e na sua capacidade de unir. O aprendizado está em desenvolver a autoconfiança para agir sozinho(a) quando necessário. Lembre-se de que a calma e a cooperação são poderosas, mas, às vezes, a decisão mais pacificadora é aquela que você toma com firmeza e por si só.',
      inspiracao: 'União fortalece; mas às vezes é preciso decidir sozinho.',
      tags: ['Apoio', 'Diplomacia', 'Hesitação'],
    ),
    3: const VibrationContent(
      titulo: 'Comunicação Criativa',
      descricaoCurta: 'Reação instintiva: se comunicar, usar humor e otimismo.',
      descricaoCompleta:
          'Sua reação instintiva a uma emergência é se comunicar, usar o humor ou buscar uma solução criativa e otimista. Você tende a verbalizar o que está acontecendo, seja para pedir ajuda, para acalmar os outros com uma palavra de encorajamento ou para aliviar a tensão com uma piada. Seu impulso é o da expressão.\n\nEssa reatividade pode ser maravilhosa para manter o moral elevado e para encontrar soluções inovadoras que ninguém mais pensou. No entanto, em crises que exigem silêncio, seriedade e foco absoluto, sua tendência a falar e a se dispersar pode ser inadequada ou até mesmo prejudicial.\n\nSua força está na sua capacidade de inspirar e de pensar fora da caixa. O desafio é aprender a discernir quando sua expressão é útil e quando o silêncio e a concentração são necessários. Ao equilibrar seu otimismo com a seriedade do momento, sua criatividade se torna uma ferramenta poderosa para superar qualquer desafio.',
      inspiracao: 'Palavras certas no momento certo acalmam tempestades.',
      tags: ['Comunicação', 'Otimismo', 'Criatividade'],
    ),
    4: const VibrationContent(
      titulo: 'Organização Prática',
      descricaoCurta:
          'Reação instintiva: organizar, planejar e criar estrutura.',
      descricaoCompleta:
          'Diante de uma crise, sua primeira reação é prática e focada. Você não entra em pânico; em vez disso, sua mente começa a trabalhar instintivamente para organizar, planejar e criar uma estrutura para resolver o problema. Seu impulso é o de trazer ordem ao caos, buscando a solução mais lógica e segura.\n\nEssa reatividade é extremamente valiosa em emergências que requerem um plano de ação claro e metódico. Você é a pessoa que se lembra dos detalhes práticos que todos esquecem. Contudo, essa necessidade de controle pode torná-lo(a) lento(a) para reagir em situações que pedem improviso e flexibilidade, ou pode gerar frustração se as coisas não saírem como planejado.\n\nSua força reside na sua estabilidade e no seu senso prático. O aprendizado está em confiar que você também pode ser flexível quando necessário. Lembre-se que um bom plano inclui a capacidade de se adaptar. Ao unir sua organização com um toque de espontaneidade, você se torna um pilar de força inabalável em qualquer tempestade.',
      inspiracao: 'Ordem sustenta; mas flexibilidade permite sobreviver.',
      tags: ['Organização', 'Praticidade', 'Controle'],
    ),
    5: const VibrationContent(
      titulo: 'Adaptação Rápida',
      descricaoCurta:
          'Reação instintiva: se mover, adaptar e improvisar rapidamente.',
      descricaoCompleta:
          'Sua reação instintiva a uma emergência é a da adaptação e da ação rápida. Você sente uma descarga de adrenalina e seu impulso é o de se mover, de mudar a situação e de encontrar uma saída, por mais inusitada que seja. A liberdade de ação é crucial para você em um momento de crise.\n\nEssa reatividade o(a) torna incrivelmente engenhoso(a) e capaz de improvisar soluções sob pressão. Você não se prende a regras e pensa rápido. No entanto, essa mesma impulsividade pode levá-lo(a) a agir de forma precipitada, sem avaliar os riscos, ou a se tornar impaciente com os que reagem de forma mais lenta.\n\nSua força está na sua versatilidade e na sua coragem para agir. O desafio é canalizar essa energia de forma construtiva, respirando por um segundo para garantir que sua ação seja não apenas rápida, mas também eficaz. Ao fazer isso, sua capacidade de adaptação o(a) torna apto(a) a superar praticamente qualquer imprevisto.',
      inspiracao: 'Adaptabilidade é sobrevivência; com consciência, é mestria.',
      tags: ['Adaptação', 'Improviso', 'Agilidade'],
    ),
    6: const VibrationContent(
      titulo: 'Cuidado e Proteção',
      descricaoCurta:
          'Reação instintiva: proteger os outros e restaurar harmonia.',
      descricaoCompleta:
          'Diante de uma crise, sua primeira reação é se preocupar com o bem-estar das pessoas envolvidas. Seu instinto não é o de salvar a si mesmo(a), mas o de proteger, cuidar e assumir a responsabilidade pelo grupo. Seu impulso é o de restaurar a harmonia e a segurança emocional de todos.\n\nEssa reatividade o(a) torna o porto seguro em momentos de pânico coletivo. Você é a pessoa que acalma, que oferece um ombro amigo e que organiza o cuidado com os mais vulneráveis. Contudo, essa forte empatia pode sobrecarregá-lo(a) emocionalmente, fazendo com que você absorva o sofrimento alheio e se esqueça de suas próprias necessidades.\n\nSua força reside no seu imenso coração e no seu senso de dever. O aprendizado está em estabelecer limites saudáveis para não se esgotar. Lembre-se que para ser um bom cuidador, você também precisa estar forte. Ao equilibrar a compaixão com o autocuidado, você se torna uma fonte de cura e estabilidade para todos.',
      inspiracao: 'Cuidar dos outros começa cuidando de si.',
      tags: ['Cuidado', 'Proteção', 'Empatia'],
    ),
    7: const VibrationContent(
      titulo: 'Análise Distante',
      descricaoCurta:
          'Reação instintiva: se afastar, analisar e refletir friamente.',
      descricaoCompleta:
          'Sua reação a uma emergência é se afastar para analisar a situação. Você reage de maneira arredia e não gosta de se envolver com problemas alheios. Numa crise, seu primeiro impulso é dar um passo para trás, se recolher para refletir e considerar analiticamente a situação antes de tomar qualquer atitude.\n\nEssa capacidade de manter a calma e de analisar friamente sob pressão é uma grande vantagem, permitindo que você encontre a solução mais inteligente e evite erros impulsivos. Você busca a resposta na lógica e na estratégia, não no pânico.\n\nNo entanto, essa necessidade de introspecção pode ser interpretada como frieza ou falta de ação. Se a situação for grave, há o risco de você se entregar a uma depressão ou a vícios como forma de escape. O desafio é unir sua mente brilhante a uma ação oportuna, transformando sua análise em uma solução eficaz no tempo certo.',
      inspiracao: 'Análise ilumina; mas ação no tempo certo salva.',
      tags: ['Análise', 'Distanciamento', 'Estratégia'],
    ),
    8: const VibrationContent(
      titulo: 'Comando Decisivo',
      descricaoCurta: 'Reação instintiva: assumir comando e restaurar a ordem.',
      descricaoCompleta:
          'Diante de uma crise, sua reação instintiva é assumir o comando. Você não hesita em tomar decisões difíceis e em delegar tarefas, buscando restaurar a ordem e o controle da situação com firmeza e autoridade. Seu impulso é o de liderar e de executar um plano de ação poderoso.\n\nEssa reatividade é extremamente eficaz em emergências que exigem uma liderança forte e decidida. Você não se intimida com a pressão e sua autoconfiança inspira segurança nos outros. Você é a pessoa que naturalmente assume a frente quando todos os outros estão perdidos.\n\nO desafio dessa resposta automática é não se tornar excessivamente autoritário(a) ou impaciente com as reações emocionais dos outros. Sua necessidade de controle pode fazer com que você ignore a sensibilidade do momento. Ao equilibrar sua força com a compaixão, sua liderança se torna não apenas eficaz, mas também inspiradora.',
      inspiracao: 'Liderança firme inspira; mas com compaixão, transforma.',
      tags: ['Comando', 'Autoridade', 'Decisão'],
    ),
    9: const VibrationContent(
      titulo: 'Visão Compassiva',
      descricaoCurta:
          'Reação instintiva: manter calma e agir com compaixão universal.',
      descricaoCompleta:
          'Sua primeira reação a uma emergência é de uma calma surpreendente, com uma visão ampla da situação. Seu impulso instintivo é o de compreender o quadro geral e de agir com compaixão, se preocupando com o bem de todos os envolvidos, mesmo daqueles que não conhece. Você pensa no impacto coletivo da crise.\n\nEssa reatividade o(a) torna um(a) grande conselheiro(a) em momentos de pânico, pois sua perspectiva elevada ajuda a acalmar e a dar um sentido maior aos acontecimentos. Você não se perde em detalhes triviais, mas foca no que é humanamente mais importante. No entanto, essa visão ampla pode, por vezes, paralisá-lo(a) ou dificultar a tomada de ações práticas e imediatas.\n\nSua força reside na sua sabedoria e na sua imensa compaixão. O aprendizado está em traduzir essa visão humanitária em ações concretas e eficazes. Ao unir seu idealismo com a praticidade, você se torna uma presença curadora e transformadora em meio a qualquer adversidade.',
      inspiracao: 'Compaixão ampla ilumina; mas ação prática transforma.',
      tags: ['Compaixão', 'Visão', 'Calma'],
    ),
  };

  // LIÇÕES CÁRMICAS (1–9) — aprendizados essenciais desta encarnação
  static final Map<int, VibrationContent> textosLicoesCarmicas = {
    1: const VibrationContent(
      titulo: 'Lição Cármica 1 — Iniciativa e Autoconfiança',
      descricaoCurta:
          'Aprender a ser independente e a confiar em seu próprio poder.',
      descricaoCompleta:
          'A lição a ser aprendida é a da iniciativa e da autoconfiança. Em vidas passadas, pode ter havido uma tendência à dependência ou à falta de coragem para seguir o próprio caminho e defender suas ideias. Você pode ter vivido na sombra de outras pessoas, negligenciando o desenvolvimento da sua força interior.\n\nAgora, a vida lhe cobrará que desenvolva a independência, a força de vontade e a capacidade de liderar. Você será constantemente colocado(a) em situações onde precisará tomar a frente, decidir por si mesmo(a) e agir sem esperar pelos outros. O aprendizado envolve superar a insegurança e aprender a confiar em suas próprias habilidades.\n\nEncare cada desafio como uma oportunidade para fortalecer sua individualidade. A vida o(a) convida a ser o(a) protagonista de sua própria história. Ao aprender a ser pioneiro(a) e a acreditar em seu potencial, você não apenas quita essa dívida, mas também descobre o imenso poder que reside em você.',
      inspiracao: 'Seu maior poder nasce quando você confia em si mesmo(a).',
      tags: ['Iniciativa', 'Autoconfiança', 'Independência'],
    ),
    2: const VibrationContent(
      titulo: 'Lição Cármica 2 — Cooperação e Diplomacia',
      descricaoCurta:
          'Desenvolver paciência, sensibilidade e espírito de equipe.',
      descricaoCompleta:
          'Você precisa aprender a virtude da cooperação, da diplomacia e da paciência. A negligência no passado pode ter se manifestado como teimosia, falta de tato com os sentimentos alheios ou uma recusa em trabalhar em equipe. Talvez você tenha agido de forma egoísta, sem considerar o impacto de suas ações nos outros.\n\nNesta vida, você enfrentará situações que exigirão que desenvolva a sensibilidade, a capacidade de ceder e de colaborar harmonicamente. O aprendizado está em se tornar um(a) bom(a) ouvinte, em respeitar os diferentes ritmos e em valorizar o poder da união para alcançar objetivos comuns.\n\nSua evolução espiritual depende de sua habilidade de construir pontes em vez de muros. Cada vez que você age com gentileza, paciência e espírito de equipe, você avança em sua jornada. Abrace a arte da diplomacia, pois ela lhe trará paz interior e sucesso em seus relacionamentos.',
      inspiracao: 'A verdadeira força está em saber ceder sem se perder.',
      tags: ['Cooperação', 'Diplomacia', 'Paciência'],
    ),
    3: const VibrationContent(
      titulo: 'Lição Cármica 3 — Expressão e Otimismo',
      descricaoCurta:
          'Cultivar a alegria de viver e a comunicação construtiva.',
      descricaoCompleta:
          'A lição é sobre a expressão criativa, o otimismo e a comunicação clara. No passado, você pode ter reprimido seus talentos, se entregado ao pessimismo e à crítica excessiva, ou ter usado o dom da palavra de forma superficial ou maledicente. A alegria de viver pode ter sido negligenciada.\n\nA vida agora lhe pede para desenvolver a comunicação construtiva, a alegria de viver e a autoexpressão. O aprendizado envolve superar a timidez, o medo do julgamento e a autocrítica, permitindo que sua luz interior e seus dons criativos brilhem para o mundo. Você precisa aprender a ver e a expressar a beleza da vida.\n\nPermita-se ser mais sociável, otimista e criativo(a). Use suas palavras para inspirar e elevar, não para diminuir. Ao cultivar a alegria e a gratidão, e ao compartilhar seus talentos com o mundo, você não apenas aprende sua lição, mas também torna a jornada de todos mais leve e colorida.',
      inspiracao:
          'Alegria compartilhada se multiplica; tristeza dividida diminui.',
      tags: ['Expressão', 'Otimismo', 'Criatividade'],
    ),
    4: const VibrationContent(
      titulo: 'Lição Cármica 4 — Disciplina e Persistência',
      descricaoCurta:
          'Aprender o valor do trabalho honesto e da responsabilidade.',
      descricaoCompleta:
          'O aprendizado necessário é o da disciplina, da organização e da persistência. A falta de esforço, a preguiça, a desordem ou a inconstância em vidas anteriores criaram esta lição. Você pode ter abandonado projetos importantes pela metade ou ter evitado as responsabilidades do trabalho árduo.\n\nNesta existência, você será desafiado(a) a ser mais prático(a), metódico(a) e a construir bases sólidas através do trabalho focado. A superação da tendência à procrastinação e a capacidade de levar seus planos até a conclusão são fundamentais. A vida exigirá que você honre seus compromissos.\n\nEncare a disciplina não como uma prisão, mas como a ferramenta que lhe dará liberdade e segurança. Cada tarefa concluída, cada meta alcançada com seu próprio esforço, é uma vitória em sua jornada evolutiva. Ao se tornar uma pessoa confiável e trabalhadora, você constrói a estabilidade que sua alma busca.',
      inspiracao: 'Disciplina hoje constrói a liberdade de amanhã.',
      tags: ['Disciplina', 'Persistência', 'Responsabilidade'],
    ),
    5: const VibrationContent(
      titulo: 'Lição Cármica 5 — Liberdade com Responsabilidade',
      descricaoCurta: 'Equilibrar aventura com consciência e compromisso.',
      descricaoCompleta:
          'A lição a ser aprendida é o uso correto e construtivo da liberdade. O abuso dos cinco sentidos (excessos com comida, bebida, sexo), a irresponsabilidade, a impulsividade ou o medo paralisante de mudanças no passado geraram a necessidade deste aprendizado. Você pode ter vivido sem considerar as consequências de seus atos.\n\nA vida lhe trará situações que exigirão versatilidade, coragem para mudar e, acima de tudo, responsabilidade por suas escolhas. O aprendizado consiste em encontrar o equilíbrio entre a aventura e o compromisso, aprendendo que a verdadeira liberdade caminha junto com a autodisciplina e o respeito aos outros.\n\nAbrace as mudanças como oportunidades de crescimento, mas aja com consciência e moderação. Use sua curiosidade para aprender e evoluir, não apenas para buscar o prazer momentâneo. Ao se tornar mestre de sua própria liberdade, você a transforma em uma poderosa força para o progresso.',
      inspiracao: 'Liberdade sem consciência é apenas caos disfarçado.',
      tags: ['Liberdade', 'Responsabilidade', 'Equilíbrio'],
    ),
    6: const VibrationContent(
      titulo: 'Lição Cármica 6 — Responsabilidade Afetiva',
      descricaoCurta: 'Aprender a harmonia, o serviço e a justiça nos afetos.',
      descricaoCompleta:
          'Você precisa aprender sobre a responsabilidade afetiva, a harmonia no lar e o senso de justiça nos relacionamentos. Negligências com a família, com o cônjuge, com os filhos ou com a comunidade no passado podem ter criado esta lição. Você pode ter sido egoísta em suas relações, colocando suas necessidades sempre em primeiro lugar.\n\nAgora, a vida lhe cobrará uma postura mais conciliadora, doadora e dedicada ao lar e aos relacionamentos. O aprendizado está em encontrar o equilíbrio entre suas necessidades e as dos outros, em assumir suas responsabilidades domésticas e afetivas com amor, e em ser um pilar de estabilidade e justiça para seus entes queridos.\n\nSua evolução passa por aprender a arte de doar e de criar harmonia. Cada ato de serviço amoroso, cada decisão justa dentro do lar, cada momento de cuidado genuíno com o outro é um passo em direção à quitação deste débito. Ao se tornar um ponto de equilíbrio e afeto, você cura a si mesmo(a) e a todos ao seu redor.',
      inspiracao: 'Amor sem responsabilidade é apenas sentimento passageiro.',
      tags: ['Responsabilidade', 'Harmonia', 'Serviço'],
    ),
    7: const VibrationContent(
      titulo: 'Lição Cármica 7 — Fé e Espiritualidade',
      descricaoCurta: 'Desenvolver a confiança na vida e a conexão espiritual.',
      descricaoCompleta:
          'O aprendizado envolve desenvolver a fé, a confiança na vida e a conexão com sua espiritualidade. O excesso de materialismo, o ceticismo exacerbado ou o uso indevido do conhecimento para fins egoístas em vidas passadas podem ter gerado esta carência. Você pode ter se fechado em sua própria lógica, desconfiando de tudo o que não podia ver ou tocar.\n\nNesta vida, você será desafiado(a) a olhar para dentro, a desenvolver a intuição, a estudar filosofias mais profundas e a confiar em algo maior que a mente racional. O aprendizado está em superar o medo da entrega e o isolamento, encontrando respostas não apenas nos livros, mas também no silêncio do seu coração.\n\nPermita-se questionar, mas também se permita crer. A fé não é a ausência de dúvida, mas a coragem de seguir em frente apesar dela. Ao desenvolver a confiança na sabedoria do universo e em sua própria intuição, você encontra uma paz e um sentido para a vida que nenhuma lógica material pode oferecer.',
      inspiracao: 'Fé não é ver para crer; é crer para então enxergar.',
      tags: ['Fé', 'Espiritualidade', 'Intuição'],
    ),
    8: const VibrationContent(
      titulo: 'Lição Cármica 8 — Justiça no Poder',
      descricaoCurta: 'Aprender o uso ético do poder e dos recursos materiais.',
      descricaoCompleta:
          'Esta é a lição da justiça no exercício do poder e na aplicação dos talentos para a multiplicação das riquezas. A falta de vontade e a ineficiência na conduta profissional, ou o abuso de autoridade e a má gestão financeira em vidas passadas, vêm prejudicando o bom andamento da sua evolução espiritual.\n\nVocê precisa desenvolver o senso da justiça, equilibrar as forças do poder dentro de si e aprender a lidar com o dinheiro de forma saudável e produtiva. O aprendizado envolve ser ético(a) nos negócios, ambicioso(a) com responsabilidade e generoso(a) com os frutos de seu trabalho, compreendendo que a verdadeira prosperidade é aquela que beneficia a todos.\n\nA vida lhe trará oportunidades de assumir posições de liderança e de gerenciar recursos importantes. Cada decisão justa e cada ato de boa administração será uma oportunidade de quitar esse débito. Ao se tornar um exemplo de integridade e poder a serviço do bem, você transforma seu carma em uma fonte de grande sucesso.',
      inspiracao: 'Poder com justiça eleva; poder sem ética destrói.',
      tags: ['Justiça', 'Poder', 'Integridade'],
    ),
    9: const VibrationContent(
      titulo: 'Lição Cármica 9 — Compaixão Universal',
      descricaoCurta:
          'Aprender o amor incondicional e a responsabilidade global.',
      descricaoCompleta:
          'Esta é a lição da compaixão pela humanidade, do amor como a lei maior da evolução espiritual. A falta de solidariedade, o egoísmo, a insensibilidade pela dor alheia e a dureza de sentimento em existências passadas vêm prejudicando o bom andamento da sua evolução espiritual.\n\nVocê precisa desenvolver a compaixão, a generosidade, o perdão e assumir sua parcela de responsabilidade pelo progresso material e espiritual de toda a humanidade. O aprendizado está em olhar para além de seu próprio umbigo e em se importar genuinamente com o bem-estar dos outros, praticando a caridade moral e material.\n\nA vida lhe apresentará muitas oportunidades de ajudar, de perdoar e de servir. Não se feche em seu mundo. Cada ato de bondade, por menor que pareça, é um passo gigantesco em sua jornada. Ao abrir seu coração para o amor universal, você não apenas aprende sua lição mais importante, mas também encontra o verdadeiro propósito de sua alma.',
      inspiracao: 'Compaixão genuína transforma o mundo e a própria alma.',
      tags: ['Compaixão', 'Amor Universal', 'Generosidade'],
    ),
  };

  // DÉBITOS CÁRMICOS (13, 14, 16, 19) — provas de regeneração por erros graves do passado
  static final Map<int, VibrationContent> textosDebitosCarmicos = {
    13: const VibrationContent(
      titulo: 'Débito Cármico 13 — Regeneração pelo Trabalho',
      descricaoCurta:
          'Superação de preguiça e negligência através do esforço honesto.',
      descricaoCompleta:
          'Esta é uma prova de regeneração relacionada a possíveis atentados contra a vida (própria ou de outrem) em encarnações passadas. A causa pode ter sido suicídio, negligência que causou a morte, ou homicídio, resultantes de preguiça, negatividade ou imprudência. Os reflexos na existência atual podem surgir como dificuldades para aceitar rotinas, medo de acidentes e morte, negatividade e preguiça.\n\nA vida lhe impõe a necessidade de valorizar o trabalho e a oportunidade de estar encarnado(a). A tendência à procrastinação ou a se sentir descontente com a vida são ecos desse passado que precisam ser superados com esforço consciente. Qualquer caminho que pareça um "atalho fácil" pode ser uma armadilha para a reincidência no erro.\n\nA regeneração vem através da disciplina no trabalho, mantendo-se sempre ocupado(a) e produtivo(a). Transforme o trabalho em sua missão e sua âncora. Ao se dedicar com afinco a uma atividade construtiva, você domina os medos, afasta os pensamentos negativos e honra o presente da vida, transmutando essa difícil prova em uma fonte de grande realização.',
      inspiracao: 'Trabalho honesto é a chave que liberta o espírito.',
      tags: ['Trabalho', 'Regeneração', 'Disciplina'],
    ),
    14: const VibrationContent(
      titulo: 'Débito Cármico 14 — Desapego e Honestidade',
      descricaoCurta:
          'Superar ganância e aprender o uso justo da liberdade e dos bens.',
      descricaoCompleta:
          'Esta é uma prova de regeneração relacionada a possíveis prejuízos materiais e financeiros causados a outros por egoísmo, ganância e apego, cometidos em encarnações passadas. A causa pode ter sido roubo, corrupção ou má gestão que prejudicaram terceiros. Os reflexos na vida atual podem se manifestar como traições nos negócios, prejuízos financeiros inesperados, problemas com sócios e instabilidade emocional.\n\nA vida lhe cobrará uma nova postura em relação à liberdade e aos bens materiais. Você pode se ver passando por perdas súbitas ou enfrentando obstáculos que parecem minar seus esforços, como um lembrete constante de que a verdadeira segurança não está no acúmulo, mas na circulação justa dos recursos.\n\nA conscientização passa pelo desapego, pela definição de objetivos claros e pela flexibilidade diante dos obstáculos. A regeneração acontece quando você age com honestidade em todas as transações, usa sua liberdade com responsabilidade e entende que o que foi tirado no passado precisa, de alguma forma, ser devolvido através da prática do bem e da justiça.',
      inspiracao: 'Verdadeira riqueza está em dar, não em acumular para si.',
      tags: ['Desapego', 'Honestidade', 'Justiça'],
    ),
    16: const VibrationContent(
      titulo: 'Débito Cármico 16 — Lealdade nos Afetos',
      descricaoCurta:
          'Reajuste por transgressões afetivas e restauração da confiança.',
      descricaoCompleta:
          'Refere-se a um reajuste por transgressões ligadas ao abuso da afetividade e a relacionamentos ilícitos em vidas passadas. A causa pode envolver adultério, abandono de lares, sedução para fins egoístas ou a criação de ilusões que levaram outros ao sofrimento emocional e à destruição de famílias. Houve um uso irresponsável do amor e da confiança.\n\nNa vida atual, este débito se manifesta através de grandes desilusões amorosas, solidão inexplicável, traições, dificuldade em construir relacionamentos estáveis e a sensação de que seus planos e projetos desmoronam inesperadamente. É como se uma torre fosse construída sobre areia movediça, refletindo a falta de bases sólidas nos relacionamentos do passado.\n\nA regeneração ocorre através da prática da lealdade, da sinceridade nos afetos e do profundo respeito aos sentimentos alheios. É preciso construir uma vida baseada na humildade e na integridade, valorizando o lar e os compromissos assumidos. Ao se tornar um exemplo de fidelidade e responsabilidade afetiva, você reconstrói sua "torre" sobre uma rocha firme.',
      inspiracao: 'Amor verdadeiro honra compromissos e respeita sentimentos.',
      tags: ['Lealdade', 'Integridade', 'Respeito'],
    ),
    19: const VibrationContent(
      titulo: 'Débito Cármico 19 — Humildade e Cooperação',
      descricaoCurta:
          'Superar abuso de poder e aprender a servir com humildade.',
      descricaoCompleta:
          'Este débito está ligado ao abuso de poder, autoridade e inteligência em encarnações anteriores. A causa pode ter sido o uso da força para oprimir, a tirania, o egoísmo extremo e a imposição da própria vontade sobre os outros de forma cruel e manipuladora. Houve uma desconexão com a empatia e um foco exclusivo nos próprios interesses.\n\nNa existência atual, os reflexos surgem como a perda de poder, a dificuldade em ser ouvido(a) e respeitado(a), a dependência de outras pessoas e a sensação de estar sempre em posições subalternas ou de ser vítima de injustiças. A vida o(a) coloca "do outro lado da moeda" para que aprenda a lição da humildade.\n\nA superação se dá pelo desenvolvimento da compaixão, pela cooperação e pelo uso de qualquer posição de liderança, por menor que seja, para servir, e não para dominar. É preciso aprender a trabalhar em equipe, a ouvir os outros e a se alegrar com o sucesso alheio. Ao se tornar uma fonte de apoio e inspiração, você transmuta a arrogância do passado em uma nobreza de espírito.',
      inspiracao:
          'Servir com humildade eleva mais que comandar com arrogância.',
      tags: ['Humildade', 'Cooperação', 'Serviço'],
    ),
  };

  // DESAFIOS (0–8) — obstáculos principais a superar na jornada de vida
  static final Map<int, VibrationContent> textosDesafios = {
    0: const VibrationContent(
      titulo: 'Todas as Possibilidades',
      descricaoCurta: 'Dificuldade em escolher e se firmar; necessidade de fé.',
      descricaoCompleta:
          'O desafio do número 0 é o desafio de todas as possibilidades, o que pode se manifestar como uma dificuldade em escolher um caminho e se firmar. Representa a necessidade de desenvolver a fé e de confiar no potencial ilimitado que existe dentro de si, superando a indecisão, a apatia ou o medo de não ser nada. A superação vem ao escolher e se comprometer com qualquer um dos outros desafios (de 1 a 8), usando sua força de vontade para transformar o potencial em realidade.\n\nEste desafio raro sugere que você tem a liberdade e a capacidade de trabalhar em qualquer uma das áreas representadas pelos outros números. No entanto, essa abundância de opções pode paralisá-lo(a), fazendo com que você se sinta perdido(a) ou sem um propósito claro.\n\nA chave está em aceitar que não existe uma escolha "errada". Comprometa-se com um caminho, confie em sua intuição e avance com fé. Ao fazer isso, você descobrirá que seu verdadeiro desafio era apenas o de começar.',
      inspiracao: 'Escolher um caminho com fé liberta o potencial infinito.',
      tags: ['Escolha', 'Fé', 'Potencial'],
    ),
    1: const VibrationContent(
      titulo: 'Individualidade e Autoconfiança',
      descricaoCurta:
          'Superar dependência ou egoísmo; afirmar-se com equilíbrio.',
      descricaoCompleta:
          'Este é o desafio da individualidade. Indica uma dificuldade em se afirmar e em confiar nas próprias capacidades, levando à indecisão ou à dependência dos outros. No extremo oposto, pode se manifestar como autossuficiência exagerada, egoísmo e teimosia.\n\nA vida lhe pedirá constantemente para tomar a frente, para ser pioneiro(a) e para defender suas próprias ideias. A hesitação em assumir seu poder pessoal será a principal barreira a ser superada. O medo de ficar sozinho(a) ou a arrogância de achar que não precisa de ninguém são as duas faces deste desafio.\n\nA superação está em desenvolver uma autoconfiança equilibrada. É preciso aprender a ser um(a) líder que sabe ouvir, que tem iniciativa mas também coopera. Ao encontrar a força para ser você mesmo(a) de forma autêntica e respeitosa, você transforma esta barreira em sua maior virtude.',
      inspiracao: 'Liderar a si mesmo é o primeiro passo para liderar outros.',
      tags: ['Autoconfiança', 'Independência', 'Equilíbrio'],
    ),
    2: const VibrationContent(
      titulo: 'Cooperação e Sensibilidade',
      descricaoCurta:
          'Equilibrar emoções; estabelecer limites saudáveis sem se anular.',
      descricaoCompleta:
          'Este é o desafio da cooperação e da sensibilidade. Ele indica uma dificuldade em lidar com as próprias emoções, que pode se manifestar como timidez excessiva, medo da rejeição e uma hipersensibilidade que o(a) torna muito vulnerável às opiniões e energias alheias. Você pode ter dificuldade em dizer "não" e em impor limites.\n\nNo extremo oposto, este desafio pode se revelar como uma aparente falta de sensibilidade, uma recusa em cooperar e uma atitude de "não me importo", como um escudo para proteger seu interior sensível. A dificuldade está em equilibrar a empatia com a autoproteção.\n\nA superação vem com o desenvolvimento da inteligência emocional e da autoconfiança. Aprenda a valorizar sua sensibilidade como um dom, e não como uma fraqueza. Ao estabelecer limites saudáveis e ao aprender a colaborar sem se anular, você transforma este desafio em uma poderosa capacidade de unir e harmonizar.',
      inspiracao: 'Sensibilidade com limites é sabedoria emocional.',
      tags: ['Sensibilidade', 'Limites', 'Cooperação'],
    ),
    3: const VibrationContent(
      titulo: 'Foco e Autoestima',
      descricaoCurta:
          'Superar dispersão e vaidade; canalizar criatividade com disciplina.',
      descricaoCompleta:
          'Este desafio da vaidade e da dispersão precisa ser equilibrado numa autoestima saudável. Indica uma dificuldade de concentração, uma tendência a começar muitas coisas e não terminar nenhuma, e um medo de não ser notado(a) ou amado(a). Isso pode levar a uma busca incessante por atenção, a uma autocrítica severa ou a uma vaidade exagerada.\n\nVocê pode ter muitos talentos, mas a dificuldade em focar em um de cada vez impede que eles floresçam. A vida lhe apresentará situações que exigirão disciplina e comprometimento para superar a tendência à superficialidade.\n\nA superação está em encontrar um canal construtivo para sua imensa criatividade e em desenvolver uma autoestima que não dependa da aprovação externa. Escolha um projeto, dedique-se a ele e sinta a alegria da realização. Ao fazer isso, você transforma a dispersão em expressão criativa e a vaidade em um amor-próprio genuíno.',
      inspiracao: 'Foco transforma talento disperso em obra-prima.',
      tags: ['Foco', 'Autoestima', 'Disciplina'],
    ),
    4: const VibrationContent(
      titulo: 'Disciplina Equilibrada',
      descricaoCurta:
          'Superar preguiça ou rigidez; trabalhar sem se tornar workaholic.',
      descricaoCompleta:
          'Este é o desafio da disciplina no trabalho, que precisa ser implementada sem rigor excessivo. Indica uma dificuldade com a ordem, o esforço e a praticidade, que pode se manifestar como preguiça, desorganização e uma tendência a evitar o trabalho duro. No extremo oposto, pode levar a uma obsessão por trabalho, a uma rigidez inflexível e a um medo de relaxar.\n\nA vida lhe trará desafios que só poderão ser superados com persistência, método e paciência. A tendência a buscar atalhos ou a se sentir sobrecarregado(a) pelas responsabilidades será uma constante a ser vencida.\n\nA superação vem ao encontrar um equilíbrio saudável entre o esforço e o lazer. Crie uma rotina que funcione para você, celebre as pequenas vitórias e aprenda que a disciplina pode ser libertadora, e não uma prisão. Ao fazer as pazes com o trabalho, você constrói a estabilidade que tanto almeja.',
      inspiracao: 'Disciplina equilibrada constrói sem aprisionar.',
      tags: ['Disciplina', 'Equilíbrio', 'Trabalho'],
    ),
    5: const VibrationContent(
      titulo: 'Liberdade Responsável',
      descricaoCurta:
          'Superar impulsividade ou medo da mudança; liberdade consciente.',
      descricaoCompleta:
          'Este é o desafio da liberdade e da disciplina. Indica uma dificuldade em lidar com a liberdade de forma construtiva, o que pode se manifestar como impulsividade, irresponsabilidade e uma busca incessante por prazeres momentâneos, com medo de se prender a qualquer compromisso. No extremo oposto, pode se revelar como um medo paralisante da mudança, da aventura e de novas experiências, apegando-se de forma rígida à rotina por medo do desconhecido.\n\nA vida lhe apresentará constantemente situações que exigirão de você versatilidade, coragem para se adaptar e, acima de tudo, responsabilidade pelas suas escolhas. A tendência a agir sem pensar nas consequências ou a se sentir preso(a) e limitado(a) será a barreira a ser superada.\n\nA superação vem ao aprender que a verdadeira liberdade floresce com a autodisciplina. Use sua curiosidade para aprender e evoluir, não para fugir. Ao se comprometer com seus objetivos e ao mesmo tempo se permitir explorar o mundo de forma consciente, você transforma este desafio em um poderoso motor para o crescimento.',
      inspiracao: 'Liberdade com responsabilidade é verdadeira evolução.',
      tags: ['Liberdade', 'Responsabilidade', 'Mudança'],
    ),
    6: const VibrationContent(
      titulo: 'Amor Realista',
      descricaoCurta:
          'Superar idealismo ou descaso nos afetos; amar sem se anular.',
      descricaoCompleta:
          'Este é o desafio do amor e da responsabilidade. Indica uma dificuldade em estabelecer relações harmoniosas e equilibradas, que pode se manifestar como um idealismo excessivo, esperando a perfeição dos outros e se desiludindo facilmente. No extremo oposto, pode levar a uma atitude de descaso com as responsabilidades familiares e afetivas, ou a uma postura de "mártir", que se anula pelos outros e depois cobra o sacrifício.\n\nA vida lhe trará lições sobre o que é o amor verdadeiro, a justiça nos relacionamentos e o equilíbrio entre o dar e o receber. A tendência a ser controlador(a) e a impor seus ideais aos outros, ou a ser excessivamente permissivo(a), será o principal obstáculo.\n\nA superação está em desenvolver um amor mais realista e compassivo, tanto pelos outros quanto por si mesmo(a). Aprenda a aceitar as imperfeições humanas e a assumir suas responsabilidades com alegria, e não como um fardo. Ao encontrar essa harmonia, você transforma este desafio em um dom para criar laços de amor genuíno e duradouro.',
      inspiracao: 'Amor verdadeiro aceita imperfeições e nutre com alegria.',
      tags: ['Amor', 'Equilíbrio', 'Realismo'],
    ),
    7: const VibrationContent(
      titulo: 'Fé e Confiança',
      descricaoCurta:
          'Superar ceticismo ou isolamento; desenvolver fé e entrega.',
      descricaoCompleta:
          'Este é o desafio da fé e da confiança. Indica uma dificuldade em acreditar em si mesmo(a) e no fluxo da vida, o que pode se manifestar como ceticismo, pessimismo e uma mente excessivamente crítica que o(a) leva ao isolamento. O medo da traição ou da imperfeição pode fazer com que você reprima seus sentimentos e construa um muro ao redor de si.\n\nA vida lhe pedirá para olhar para além das aparências e para confiar em sua intuição. A tendência a intelectualizar tudo e a desconfiar do que não pode ser provado logicamente será a barreira que o(a) impede de experimentar uma conexão mais profunda com o lado espiritual da existência.\n\nA superação vem através da entrega e do desenvolvimento da fé. Permita-se sentir mais e analisar menos. Abra-se para o mistério e aprenda a confiar na sabedoria do seu coração. Ao fazer isso, você transforma o medo em sabedoria e o isolamento em uma profunda e pacífica conexão com o todo.',
      inspiracao: 'Fé é a ponte entre a mente e o coração.',
      tags: ['Fé', 'Confiança', 'Entrega'],
    ),
    8: const VibrationContent(
      titulo: 'Poder Equilibrado',
      descricaoCurta:
          'Superar medo ou abuso de poder; usar abundância com ética.',
      descricaoCompleta:
          'Este é o desafio do poder e da abundância. Indica uma dificuldade em lidar com o mundo material, o que pode se manifestar de duas formas extremas. A primeira é um medo do poder e do dinheiro, levando-o(a) a se autossabotar, a evitar posições de liderança e a viver em constante preocupação com a escassez. A segunda é uma busca obsessiva por poder e status, levando à tirania, à ganância e a um comportamento de "vale tudo" para alcançar o sucesso.\n\nA vida lhe apresentará oportunidades para exercer autoridade e para gerenciar recursos importantes. Sua reação a essas oportunidades, seja de medo ou de abuso, definirá seu progresso. A lição é aprender que o poder material não é bom nem mau, mas uma ferramenta neutra.\n\nA superação está em desenvolver uma relação saudável e equilibrada com o poder e o dinheiro. Aprenda a ser um(a) líder justo(a), ambicioso(a) com ética e generoso(a) com sua prosperidade. Ao entender que a verdadeira abundância vem de usar sua força para o bem de todos, você transforma este desafio em uma fonte de grande realização.',
      inspiracao: 'Poder com ética transforma escassez em abundância coletiva.',
      tags: ['Poder', 'Abundância', 'Ética'],
    ),
  };

  // MOMENTOS DECISIVOS / PINÁCULOS (1–9) — fases cruciais de oportunidade
  static final Map<int, VibrationContent> textosMomentosDecisivos = {
    1: const VibrationContent(
      titulo: 'Iniciativa e Pioneirismo',
      descricaoCurta:
          'Fase de novos começos; progresso pela independência e liderança.',
      descricaoCompleta:
          'Este período de sua vida oportuniza o progresso através da iniciativa, da independência e da coragem para começar algo novo. As decisões mais importantes estarão ligadas à sua capacidade de agir por conta própria, de liderar um projeto ou de afirmar sua individualidade. É um tempo para ser pioneiro(a) e autossuficiente.\n\nAs circunstâncias o(a) empurrarão para a frente, exigindo que você tome as rédeas de sua própria vida. Novas ideias, novos empreendimentos ou uma nova direção de vida podem surgir, e o sucesso dependerá da sua determinação em seguir em frente, mesmo que precise caminhar sozinho(a) por um tempo.\n\nAbrace a energia dos começos. Este não é um momento para hesitar, mas para agir com confiança em seus próprios talentos. As decisões que você tomar agora, com base em sua força de vontade e originalidade, terão o poder de definir todo um novo e promissor capítulo de sua jornada.',
      inspiracao: 'Novos começos exigem coragem; você a possui.',
      tags: ['Iniciativa', 'Liderança', 'Novos Começos'],
    ),
    2: const VibrationContent(
      titulo: 'Cooperação e Diplomacia',
      descricaoCurta:
          'Fase de parcerias; progresso pela paciência e colaboração.',
      descricaoCompleta:
          'Este é um período em que o progresso pessoal e profissional acontecerá através da cooperação, da diplomacia e da paciência. As oportunidades mais importantes virão de parcerias, do trabalho em equipe e da sua habilidade de se relacionar de forma harmoniosa. É um momento para agir com tato e sensibilidade.\n\nAs decisões cruciais não devem ser tomadas de forma impulsiva ou solitária. O cenário pede que você ouça, que colabore e que espere o momento certo para agir. O desenvolvimento de relacionamentos de confiança, seja no trabalho ou na vida pessoal, será a chave para o seu sucesso e felicidade nesta fase.\n\nCultive a arte da colaboração. Sua capacidade de unir pessoas e de mediar conflitos estará em alta e será a fonte de suas maiores conquistas. As decisões tomadas com base no respeito mútuo e na busca por um objetivo comum o(a) levarão a um crescimento sólido e a uma profunda paz interior.',
      inspiracao: 'Parcerias genuínas multiplicam resultados.',
      tags: ['Cooperação', 'Diplomacia', 'Parcerias'],
    ),
    3: const VibrationContent(
      titulo: 'Expressão e Criatividade',
      descricaoCurta:
          'Fase de expansão social; progresso pela comunicação e talentos.',
      descricaoCompleta:
          'O momento decisivo 3 oportuniza o progresso pessoal e profissional através da expansão das relações sociais e do desenvolvimento de seus talentos criativos. É uma fase que favorece a autoexpressão, as amizades, os romances e a fertilidade em todos os sentidos.\n\nEste é um período para usar sua comunicação e seu carisma para abrir portas. As decisões mais importantes estarão ligadas à sua capacidade de se expressar e de se conectar com os outros de forma otimista e inspiradora. A vida social estará em evidência, trazendo oportunidades inesperadas de crescimento.\n\nAproveite este cenário que expõe a popularidade e um modo mais descontraído e jovial de viver. As escolhas que você fizer com base em sua criatividade e em sua alegria de viver terão o poder de expandir seus horizontes e de trazer grande satisfação pessoal e profissional.',
      inspiracao: 'Criatividade e alegria abrem portas inesperadas.',
      tags: ['Criatividade', 'Comunicação', 'Expansão'],
    ),
    4: const VibrationContent(
      titulo: 'Construção e Disciplina',
      descricaoCurta:
          'Fase de trabalho efetivo; progresso pela persistência e organização.',
      descricaoCompleta:
          'O momento decisivo 4 oportuniza o progresso pessoal e profissional e a construção de um alicerce sólido para o futuro. É uma fase voltada para o trabalho efetivo, que pede paciência, disciplina e persistência para que os resultados se concretizem.\n\nAs decisões mais importantes deste período estarão ligadas à sua carreira, finanças e à organização da sua vida. É um tempo para construir, para economizar e para se dedicar com afinco aos seus objetivos de longo prazo. O sucesso virá do esforço metódico e da sua capacidade de ser prático(a) e responsável.\n\nEste momento expõe a necessidade de aplicar os preceitos corretos na direção do progresso material, pela força de vontade para se obter os resultados positivos almejados. As escolhas feitas com base na disciplina e na honestidade criarão a estabilidade e a segurança que você tanto busca para o seu futuro.',
      inspiracao: 'Esforço metódico hoje garante prosperidade amanhã.',
      tags: ['Construção', 'Disciplina', 'Estabilidade'],
    ),
    5: const VibrationContent(
      titulo: 'Mudança e Liberdade',
      descricaoCurta:
          'Fase de transformações; progresso pela adaptabilidade e coragem.',
      descricaoCompleta:
          'Este é um período em que as oportunidades de progresso surgirão através da mudança, da versatilidade e da coragem para se aventurar no novo. As decisões mais importantes estarão ligadas à sua capacidade de se adaptar, de promover seus talentos de forma magnética e de usar sua liberdade com inteligência.\n\nA vida pode lhe apresentar reviravoltas inesperadas, viagens, mudanças de carreira ou de residência. Este não é um momento para se apegar ao passado, mas para abraçar o futuro com entusiasmo. O sucesso dependerá da sua agilidade e da sua disposição para explorar novos horizontes.\n\nAbrace a energia da mudança como sua maior aliada. As escolhas que você fizer com base na sua curiosidade e na sua capacidade de se reinventar o(a) levarão a um período de grande expansão e aprendizado. É tempo de se libertar do que não serve mais e de avançar com coragem rumo ao desconhecido.',
      inspiracao: 'Mudança consciente é evolução em ação.',
      tags: ['Mudança', 'Liberdade', 'Adaptação'],
    ),
    6: const VibrationContent(
      titulo: 'Responsabilidade e Harmonia',
      descricaoCurta:
          'Fase de compromissos familiares; progresso pelo amor e serviço.',
      descricaoCompleta:
          'O momento decisivo 6 oportuniza o progresso pessoal e profissional através das atividades ligadas ao bem-estar do ser humano e ao senso de responsabilidade. As decisões mais importantes estarão ligadas à sua família, ao seu lar e à sua comunidade. É um período em que o progresso depende em grande parte da harmonia familiar.\n\nPode ser um momento para se casar, ter filhos, cuidar de entes queridos ou assumir uma posição de liderança em seu grupo social ou profissional. A vida pedirá que você equilibre suas próprias necessidades com as dos outros, agindo com justiça e compaixão.\n\nSua inclinação será para servir, ajudar, aconselhar e liderar para o progresso de todos. As escolhas que você fizer com base no amor, no dever e na busca pela harmonia trarão uma profunda sensação de realização e consolidarão seus laços afetivos de forma duradoura.',
      inspiracao: 'Amor e responsabilidade constroem laços eternos.',
      tags: ['Responsabilidade', 'Harmonia', 'Família'],
    ),
    7: const VibrationContent(
      titulo: 'Sabedoria e Introspecção',
      descricaoCurta:
          'Fase de aperfeiçoamento interior; progresso pelo conhecimento e fé.',
      descricaoCompleta:
          'O momento decisivo 7 oportuniza o progresso pessoal e profissional através do aperfeiçoamento intelectual, científico, filosófico, moral e espiritual. É um período mais introspectivo, de busca por um sentido mais profundo da vida e de aprimoramento de suas habilidades.\n\nAs decisões mais importantes não serão de ação externa, mas de reflexão interna. É um tempo para estudar, para se especializar, para meditar e para desenvolver a fé. O sucesso virá não do esforço físico, mas da aplicação da inteligência e da intuição.\n\nAproveite este cenário propício para refinar as habilidades mais preciosas de sua personalidade. As escolhas que você fizer com base na busca pela sabedoria e pelo autoconhecimento o(a) levarão a um novo patamar de consciência e o(a) prepararão para um futuro de grandes realizações.',
      inspiracao: 'Sabedoria interior ilumina o caminho externo.',
      tags: ['Sabedoria', 'Introspecção', 'Espiritualidade'],
    ),
    8: const VibrationContent(
      titulo: 'Poder e Realização',
      descricaoCurta:
          'Fase de sucesso material; progresso pela liderança e gestão.',
      descricaoCompleta:
          'Este é um período em que o progresso se manifestará através do poder, da autoridade e do sucesso material. As oportunidades estarão ligadas à sua carreira, às finanças e à sua capacidade de liderar com eficiência e visão. As decisões tomadas agora terão um grande impacto em sua estabilidade e reconhecimento a longo prazo.\n\nA vida o(a) colocará em posições de responsabilidade, onde você precisará administrar recursos importantes e exercer seu poder de forma justa e equilibrada. É um tempo para ser ambicioso(a), para organizar e para executar grandes projetos com confiança.\n\nAssuma o comando com integridade. As escolhas que você fizer com base em seu senso de justiça e em sua capacidade de gestão o(a) levarão a um período de grande prosperidade e realização. É o momento de colher os frutos do seu trabalho e de se estabelecer como uma autoridade em sua área.',
      inspiracao: 'Lidere com ética; colha abundância com propósito.',
      tags: ['Poder', 'Realização', 'Autoridade'],
    ),
    9: const VibrationContent(
      titulo: 'Compaixão e Finalização',
      descricaoCurta:
          'Fase de culminância; progresso pelo desapego e serviço humanitário.',
      descricaoCompleta:
          'Este período de sua vida oportuniza o progresso através da compaixão, do desapego e do serviço à humanidade. É uma fase de culminância, onde você terá a chance de finalizar um ciclo importante e de compartilhar a sabedoria adquirida ao longo de sua jornada.\n\nAs decisões mais importantes estarão ligadas a deixar para trás o que não serve mais, a perdoar e a se dedicar a causas maiores que seus interesses pessoais. Sua visão se tornará mais ampla e universal, e o sucesso virá de atos de generosidade e de sua capacidade de inspirar os outros.\n\nAbrace sua natureza humanitária. As escolhas feitas com base no amor incondicional e na busca por um mundo melhor o(a) levarão a uma profunda paz de espírito e a uma sensação de missão cumprida. É um tempo para se conectar com sua essência mais elevada e para deixar um legado de bondade.',
      inspiracao: 'Finalize com amor; inspire com generosidade.',
      tags: ['Compaixão', 'Finalização', 'Legado'],
    ),
  };




  /// Textos completos de Harmonia Conjugal por número (1–9)
  static const Map<int, String> textosHarmoniaConjugal = {
    1: 'No amor, a pessoa de número 1 é intensa, leal e tende a assumir a liderança na relação. Precisa de um(a) parceiro(a) que admire sua força, mas que também tenha sua própria individualidade, para que não haja uma dinâmica de dominação. Gosta de novidades e detesta a rotina, por isso busca sempre inovar e manter a chama da paixão acesa através de novas experiências.\n\nA independência é crucial, e precisa de seu próprio espaço para se sentir completo(a). A barreira no relacionamento pode surgir do excesso de egocentrismo ou da dificuldade em ceder. Para que a relação floresça, precisa aprender a compartilhar o comando e a ouvir as necessidades do outro com a mesma atenção que dá às suas.',
    2: 'As pessoas regidas pelo número 2 buscam nos relacionamentos uma parceria baseada na amizade sincera, no carinho e na segurança. Não são afeitas a grandes paixões avassaladoras, preferindo a tranquilidade de uma união estável e harmoniosa. São parceiros(as) extremamente dedicados(as), sensíveis e diplomáticos(as).\n\nO maior desafio é a tendência a se deixar influenciar por opiniões alheias, o que pode gerar insegurança e mal-entendidos. A carência de diálogo pode se tornar uma barreira se o(a) parceiro(a) for autoritário(a). Há também o risco de confundir amizades externas com um interesse romântico platônico.',
    3: 'Regidas pela comunicação e pela alegria, as pessoas de número 3 tendem a se envolver facilmente, muitas vezes confundindo amizade com interesse amoroso. Buscam um relacionamento que seja leve, divertido e socialmente ativo. Enquanto mais jovens, podem ter dificuldade em se estabelecer em um relacionamento firme, tendendo a se firmar após os 30 anos.\n\nUma boa dose de idealismo faz com que não levem o relacionamento tão a sério até se sentirem confortavelmente amparados dentro dele. A rotina e o excesso de cobranças podem sufocar sua necessidade de expressão e de liberdade, sendo este o principal desafio para a estabilidade do casal.',
    4: 'As pessoas regidas pelo número 4 são fortemente atraídas para o casamento e para a estabilidade de um relacionamento duradouro. São parceiros(as) extremamente leais, práticos(as) e dedicados(as), que buscam construir uma vida segura e confortável ao lado de quem amam. O que mais lhes desperta interesse é a segurança e a confiança mútua.\n\nSão conservadoras e pouco afeitas a grandes aventuras ou mudanças drásticas na rotina, o que pode ser um desafio para parceiros(as) mais espontâneos(as). Sua tendência à teimosia e a uma certa rigidez de pensamento pode gerar conflitos se não houver flexibilidade de ambas as partes.',
    5: 'As aventuras, o gosto por variedades e viagens, e a dificuldade para encarar a rotina fazem com que as pessoas de número 5 se tornem um tanto instáveis nos seus relacionamentos. Levadas pelo magnetismo sexual e pela facilidade de se relacionar com todos, geralmente não selecionam com muito rigor seus pares e são levadas pela inconstância. Precisam de um(a) parceiro(a) que ame a liberdade tanto quanto elas.\n\nA relação ideal é aquela que estimula o crescimento, a mudança e a exploração. A comunicação aberta e a ausência de ciúmes e cobranças são fundamentais para que se sintam felizes e comprometidas. O tédio é o maior inimigo do seu relacionamento; por isso, a criatividade e a disposição para experimentar coisas novas são essenciais.',
    6: 'Escolher um(a) parceiro(a) ideal para o casamento faz parte dos planos das pessoas regidas pelo número 6, que levam muito em conta o companheirismo, a emotividade e a harmonia do lar. São parceiros(as) extremamente românticos(as), dedicados(as) e que buscam a estabilidade de uma união baseada no amor e na responsabilidade mútua.\n\nMesmo que sejam ardentes na paixão, são tímidos na sua expressão e preferem a segurança de um sentimento de união estável. O desafio pode surgir de seu alto idealismo, que pode levar a desilusões ou a uma tendência a querer controlar a vida do(a) parceiro(a) "para o bem dele(a)". Magoam-se facilmente com a falta de gratidão.',
    7: 'A natureza dos relacionamentos das pessoas de número 7 tende para a intensidade intelectual e espiritual. Buscam um(a) parceiro(a) com quem possam ter diálogos profundos, compartilhar conhecimentos e crescer mutuamente. A compatibilidade mental é, muitas vezes, mais importante que a atração física.\n\nSão parceiros(as) seletivos(as) e que precisam de muito espaço pessoal e momentos de solidão para se sentirem equilibrados(as). A falta de paciência e a necessidade de variar podem levá-los a se tornarem volúveis, especialmente na juventude, tendendo a se estabilizar em um relacionamento duradouro após alcançarem certa maturidade.',
    8: 'As pessoas regidas pelo número 8 tendem a se firmar por longo tempo ou por toda a vida no casamento, pois são sinceras e honram seu comprometimento. Buscam um(a) parceiro(a) que seja tão ambicioso(a) e forte quanto elas, alguém com quem possam construir um verdadeiro império, seja ele familiar ou material.\n\nPrezam o companheirismo, a fidelidade e o comprometimento, e exigem o mesmo em troca. O desafio nos relacionamentos pode vir de sua forte necessidade de controle e de uma tendência a colocar o trabalho e a carreira em primeiro lugar, negligenciando as necessidades emocionais do(a) parceiro(a).',
    9: 'Aspirando por um relacionamento estável e duradouro, as pessoas regidas pelo número 9 buscam um amor que seja quase uma missão de vida. A compatibilidade intelectual e de ideais é um elemento fundamental para o sucesso do relacionamento. São parceiros(as) generosos(as), compassivos(as) e com uma visão ampla da vida.\n\nEnquanto jovens, tendem a se envolver com parceiros(as) mais maduros(as); na medida em que amadurecem, podem começar a se interessar por pessoas mais jovens, o que pode acarretar separações caso já estejam casados(as). O desafio é equilibrar seu amor pela humanidade com a atenção e a dedicação que um relacionamento a dois exige.',
  };

  // Helper para construir mapas básicos por número
  static Map<int, VibrationContent> _buildBasico({
    required String tituloBase,
    required String foco,
  }) {
    final Map<int, VibrationContent> m = {};
    void add(int n, String titulo, List<String> tags) {
      // Remove prefix redundante (ex: "Impressão 11 —") e mantém apenas o significado.
      // Capitaliza início da string para exibição consistente.
      final String significado = _capitalizeTitulo(titulo);
      m[n] = VibrationContent(
        titulo: significado,
        descricaoCurta: "Energia $n aplicada a $foco.",
        descricaoCompleta:
            "O número $n, no contexto de $tituloBase, sugere $foco com nuances de '$titulo'. Use essa vibração como guia prático para decisões e prioridades.",
        inspiracao:
            "Quando você honra a energia $n, o caminho de $tituloBase se alinha.",
        tags: tags,
      );
    }

    add(1, 'início, autonomia e liderança', ['Início', 'Autonomia', 'Foco']);
    add(2, 'cooperação, sensibilidade e diplomacia', ['Cooperação', 'Tato']);
    add(3, 'comunicação, criatividade e expressão', ['Expressão', 'Criar']);
    add(4, 'estrutura, disciplina e constância', ['Estrutura', 'Rotina']);
    add(5, 'mudança, liberdade e adaptabilidade', ['Mudança', 'Aventura']);
    add(6, 'harmonia, cuidado e responsabilidade', ['Cuidado', 'Família']);
    add(7, 'introspecção, estudo e fé', ['Autoconhecimento', 'Fé']);
    add(8, 'poder pessoal, realização e gestão', ['Poder', 'Resultados']);
    add(9, 'síntese, compaixão e encerramentos', ['Síntese', 'Humanitário']);
    add(11, 'inspiração, visão e intuição elevada', ['Mestre', 'Intuição']);
    add(22, 'construção em grande escala e legado', ['Mestre', 'Construção']);

    return m;
  }

  // Capitaliza cada segmento separado por vírgulas para melhor legibilidade.
  static String _capitalizeTitulo(String raw) {
    final parts =
        raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return parts
        .map((segment) => segment.isEmpty
            ? segment
            : segment[0].toUpperCase() + segment.substring(1))
        .join(', ');
  }
}
