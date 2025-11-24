/// Interpretações numerológicas completas para enriquecer o contexto da IA
/// 
/// Este arquivo contém significados, palavras-chave, desafios e características
/// de cada número na Numerologia Cabalística.

class NumerologyInterpretations {
  /// Retorna interpretação completa de um número (1-9)
  static Map<String, dynamic> getNumberInterpretation(int number) {
    return _interpretations[number] ?? {};
  }

  /// Retorna significado resumido de um número
  static String getMeaning(int number) {
    return _interpretations[number]?['significado'] ?? 'Número desconhecido';
  }

  /// Retorna palavras-chave de um número
  static List<String> getKeywords(int number) {
    return List<String>.from(_interpretations[number]?['palavrasChave'] ?? []);
  }

  /// Retorna desafio principal de um número
  static String getChallenge(int number) {
    return _interpretations[number]?['desafio'] ?? '';
  }

  /// Retorna características positivas
  static List<String> getPositiveTraits(int number) {
    return List<String>.from(_interpretations[number]?['positivo'] ?? []);
  }

  /// Retorna características negativas
  static List<String> getNegativeTraits(int number) {
    return List<String>.from(_interpretations[number]?['negativo'] ?? []);
  }

  /// Mapa completo de interpretações
  static const Map<int, Map<String, dynamic>> _interpretations = {
    1: {
      'significado': 'Liderança, independência e pioneirismo',
      'palavrasChave': ['líder', 'pioneiro', 'independente', 'inovador', 'corajoso'],
      'desafio': 'Evitar egoísmo e autoritarismo',
      'positivo': ['Iniciativa', 'Coragem', 'Originalidade', 'Determinação'],
      'negativo': ['Egoísmo', 'Teimosia', 'Arrogância', 'Impaciência'],
      'vocacao': ['Empreendedor', 'Líder', 'Inventor', 'Diretor'],
      'relacionamento': 'Precisa de espaço e autonomia, pode ser dominador',
    },

    2: {
      'significado': 'Cooperação, diplomacia e sensibilidade',
      'palavrasChave': ['diplomata', 'cooperativo', 'sensível', 'pacificador', 'parceiro'],
      'desafio': 'Evitar dependência emocional e indecisão',
      'positivo': ['Empatia', 'Paciência', 'Tato', 'Colaboração'],
      'negativo': ['Dependência', 'Timidez', 'Indecisão', 'Passividade'],
      'vocacao': ['Mediador', 'Conselheiro', 'Diplomata', 'Assistente'],
      'relacionamento': 'Busca harmonia e parceria, pode ser muito dependente',
    },

    3: {
      'significado': 'Criatividade, comunicação e expressão',
      'palavrasChave': ['criativo', 'comunicativo', 'expressivo', 'otimista', 'social'],
      'desafio': 'Evitar dispersão e superficialidade',
      'positivo': ['Criatividade', 'Otimismo', 'Sociabilidade', 'Talento artístico'],
      'negativo': ['Dispersão', 'Superficialidade', 'Fofoca', 'Exagero'],
      'vocacao': ['Artista', 'Comunicador', 'Escritor', 'Entertainer'],
      'relacionamento': 'Alegre e sociável, precisa de variedade e estímulo',
    },

    4: {
      'significado': 'Estabilidade, organização e trabalho árduo',
      'palavrasChave': ['organizado', 'prático', 'disciplinado', 'confiável', 'trabalhador'],
      'desafio': 'Evitar rigidez e excesso de controle',
      'positivo': ['Disciplina', 'Confiabilidade', 'Praticidade', 'Perseverança'],
      'negativo': ['Rigidez', 'Teimosia', 'Limitação', 'Pessimismo'],
      'vocacao': ['Administrador', 'Engenheiro', 'Contador', 'Construtor'],
      'relacionamento': 'Leal e confiável, pode ser rígido e controlador',
    },

    5: {
      'significado': 'Liberdade, mudança e experiências',
      'palavrasChave': ['livre', 'aventureiro', 'versátil', 'curioso', 'adaptável'],
      'desafio': 'Evitar instabilidade e irresponsabilidade',
      'positivo': ['Versatilidade', 'Adaptabilidade', 'Curiosidade', 'Liberdade'],
      'negativo': ['Instabilidade', 'Irresponsabilidade', 'Inquietação', 'Excesso'],
      'vocacao': ['Viajante', 'Vendedor', 'Promotor', 'Jornalista'],
      'relacionamento': 'Precisa de liberdade, pode ter dificuldade com compromisso',
    },

    6: {
      'significado': 'Responsabilidade, família e harmonia',
      'palavrasChave': ['responsável', 'amoroso', 'protetor', 'harmonioso', 'conselheiro'],
      'desafio': 'Evitar sacrifício excessivo e interferência',
      'positivo': ['Responsabilidade', 'Amor', 'Proteção', 'Harmonia'],
      'negativo': ['Sacrifício excessivo', 'Interferência', 'Preocupação', 'Possessividade'],
      'vocacao': ['Conselheiro', 'Professor', 'Enfermeiro', 'Designer'],
      'relacionamento': 'Dedicado e protetor, pode ser possessivo',
    },

    7: {
      'significado': 'Sabedoria, introspecção e espiritualidade',
      'palavrasChave': ['sábio', 'analítico', 'espiritual', 'introspectivo', 'perfeccionista'],
      'desafio': 'Evitar isolamento e frieza emocional',
      'positivo': ['Sabedoria', 'Análise', 'Espiritualidade', 'Intuição'],
      'negativo': ['Isolamento', 'Frieza', 'Ceticismo', 'Distanciamento'],
      'vocacao': ['Pesquisador', 'Filósofo', 'Cientista', 'Terapeuta'],
      'relacionamento': 'Precisa de espaço e profundidade, pode ser distante',
    },

    8: {
      'significado': 'Poder, conquista material e ambição',
      'palavrasChave': ['poderoso', 'ambicioso', 'executivo', 'realizador', 'próspero'],
      'desafio': 'Evitar materialismo e abuso de poder',
      'positivo': ['Poder', 'Realização', 'Prosperidade', 'Liderança executiva'],
      'negativo': ['Materialismo', 'Abuso de poder', 'Workaholism', 'Frieza'],
      'vocacao': ['Executivo', 'Empresário', 'Banqueiro', 'Político'],
      'relacionamento': 'Busca status e poder, pode ser dominador',
    },

    9: {
      'significado': 'Humanitarismo, compaixão e finalização',
      'palavrasChave': ['humanitário', 'compassivo', 'idealista', 'generoso', 'sábio'],
      'desafio': 'Evitar dispersão emocional e idealismo excessivo',
      'positivo': ['Compaixão', 'Generosidade', 'Idealismo', 'Sabedoria universal'],
      'negativo': ['Dispersão', 'Idealismo excessivo', 'Mártir', 'Impraticidade'],
      'vocacao': ['Filantropo', 'Artista', 'Conselheiro', 'Líder espiritual'],
      'relacionamento': 'Amoroso e generoso, pode ser emocionalmente disperso',
    },
  };

  /// Interpretações de débitos kármicos
  static const Map<int, Map<String, dynamic>> karmaDebts = {
    13: {
      'numero': 13,
      'significado': 'Preguiça e falta de foco em vidas passadas',
      'licao': 'Aprender disciplina, foco e trabalho árduo',
      'desafio': 'Tendência à preguiça e dispersão',
      'superacao': 'Desenvolver disciplina e comprometimento',
    },
    14: {
      'numero': 14,
      'significado': 'Abuso de liberdade em vidas passadas',
      'licao': 'Aprender moderação e responsabilidade',
      'desafio': 'Tendência a excessos e vícios',
      'superacao': 'Desenvolver autocontrole e equilíbrio',
    },
    16: {
      'numero': 16,
      'significado': 'Abuso de poder e relacionamentos em vidas passadas',
      'licao': 'Aprender humildade e amor verdadeiro',
      'desafio': 'Quedas súbitas e lições através de perdas',
      'superacao': 'Desenvolver humildade e compaixão',
    },
    19: {
      'numero': 19,
      'significado': 'Abuso de poder e egoísmo em vidas passadas',
      'licao': 'Aprender a servir aos outros',
      'desafio': 'Dificuldade em aceitar ajuda',
      'superacao': 'Desenvolver humildade e serviço',
    },
  };

  /// Correspondência Ano Pessoal x Temas
  static const Map<int, Map<String, dynamic>> personalYearThemes = {
    1: {
      'tema': 'Novos Começos',
      'foco': 'Iniciar projetos, tomar iniciativa, ser independente',
      'energia': 'Pioneira, inovadora, corajosa',
      'evitar': 'Dependência, passividade, medo de arriscar',
    },
    2: {
      'tema': 'Parcerias e Cooperação',
      'foco': 'Desenvolver relacionamentos, colaborar, ter paciência',
      'energia': 'Diplomática, sensível, cooperativa',
      'evitar': 'Pressa, conflitos, isolamento',
    },
    3: {
      'tema': 'Criatividade e Expressão',
      'foco': 'Expressar-se, criar, socializar, comunicar',
      'energia': 'Criativa, otimista, expressiva',
      'evitar': 'Dispersão, superficialidade, excesso de compromissos',
    },
    4: {
      'tema': 'Trabalho e Estrutura',
      'foco': 'Construir bases sólidas, trabalhar duro, organizar',
      'energia': 'Prática, disciplinada, construtiva',
      'evitar': 'Rigidez, excesso de trabalho, resistência a mudanças',
    },
    5: {
      'tema': 'Mudanças e Liberdade',
      'foco': 'Experimentar, viajar, mudar, expandir horizontes',
      'energia': 'Livre, aventureira, versátil',
      'evitar': 'Instabilidade, irresponsabilidade, dispersão',
    },
    6: {
      'tema': 'Responsabilidade e Família',
      'foco': 'Cuidar da família, assumir responsabilidades, harmonizar',
      'energia': 'Amorosa, responsável, protetora',
      'evitar': 'Sacrifício excessivo, interferência, preocupação',
    },
    7: {
      'tema': 'Introspecção e Espiritualidade',
      'foco': 'Estudar, meditar, buscar sabedoria interior',
      'energia': 'Introspectiva, analítica, espiritual',
      'evitar': 'Isolamento, frieza, excesso de análise',
    },
    8: {
      'tema': 'Poder e Conquistas Materiais',
      'foco': 'Realizar, conquistar, prosperar, liderar',
      'energia': 'Poderosa, ambiciosa, realizadora',
      'evitar': 'Materialismo, abuso de poder, workaholism',
    },
    9: {
      'tema': 'Finalização e Humanitarismo',
      'foco': 'Encerrar ciclos, perdoar, servir, compartilhar',
      'energia': 'Compassiva, generosa, sábia',
      'evitar': 'Apego, dispersão emocional, idealismo excessivo',
    },
  };

  /// Interpretações detalhadas para DESTINO (Propósito Maior)
  /// O caminho completo que a vida quer levar a pessoa
  static const Map<int, Map<String, dynamic>> destinoInterpretations = {
    1: {
      'proposito': 'Liderar, inovar e abrir caminhos para os outros',
      'missaoDeAlma': 'Ser pioneiro e inspirar independência',
      'impactoNoMundo': 'Criar novos paradigmas e liderar mudanças',
      'realizacao': 'Tornar-se referência em sua área através da originalidade',
    },
    2: {
      'proposito': 'Harmonizar, mediar e unir pessoas',
      'missaoDeAlma': 'Ser ponte entre opostos e promover paz',
      'impactoNoMundo': 'Criar ambientes de cooperação e entendimento',
      'realizacao': 'Ser reconhecido pela capacidade de unir e pacificar',
    },
    3: {
      'proposito': 'Expressar, criar e alegrar o mundo',
      'missaoDeAlma': 'Inspirar através da arte e comunicação',
      'impactoNoMundo': 'Elevar a vibração através da criatividade',
      'realizacao': 'Deixar legado artístico ou comunicativo',
    },
    4: {
      'proposito': 'Construir, estruturar e criar bases sólidas',
      'missaoDeAlma': 'Ser alicerce e exemplo de disciplina',
      'impactoNoMundo': 'Criar sistemas e estruturas duradouras',
      'realizacao': 'Construir algo que perdure gerações',
    },
    5: {
      'proposito': 'Explorar, experimentar e expandir horizontes',
      'missaoDeAlma': 'Ser agente de mudança e liberdade',
      'impactoNoMundo': 'Quebrar paradigmas e inspirar aventura',
      'realizacao': 'Viver plenamente e inspirar outros a se libertarem',
    },
    6: {
      'proposito': 'Nutrir, proteger e harmonizar comunidades',
      'missaoDeAlma': 'Ser guardião do amor e da família',
      'impactoNoMundo': 'Criar ambientes de amor e responsabilidade',
      'realizacao': 'Ser pilar de amor e suporte para muitos',
    },
    7: {
      'proposito': 'Buscar verdade, ensinar sabedoria e elevar consciências',
      'missaoDeAlma': 'Ser mestre espiritual e guardião do conhecimento',
      'impactoNoMundo': 'Elevar a consciência coletiva',
      'realizacao': 'Tornar-se sábio e guia espiritual',
    },
    8: {
      'proposito': 'Manifestar abundância e liderar com poder consciente',
      'missaoDeAlma': 'Ser exemplo de prosperidade ética',
      'impactoNoMundo': 'Criar riqueza e oportunidades para muitos',
      'realizacao': 'Alcançar poder e usá-lo para o bem maior',
    },
    9: {
      'proposito': 'Servir a humanidade e finalizar ciclos kármicos',
      'missaoDeAlma': 'Ser luz para o mundo e exemplo de compaixão',
      'impactoNoMundo': 'Transformar o mundo através do amor universal',
      'realizacao': 'Deixar legado humanitário significativo',
    },
  };

  /// Interpretações detalhadas para EXPRESSÃO (Como age no mundo)
  /// Talentos naturais e forma de atuar
  static const Map<int, Map<String, dynamic>> expressaoInterpretations = {
    1: {
      'talentos': 'Liderança natural, iniciativa, originalidade',
      'formaDeAtuar': 'Age com independência e toma a frente',
      'donsNaturais': ['Inovação', 'Coragem', 'Decisão rápida'],
      'comoSeDestaca': 'Sendo pioneiro e assumindo riscos calculados',
    },
    2: {
      'talentos': 'Diplomacia, sensibilidade, capacidade de mediar',
      'formaDeAtuar': 'Age com tato e busca consenso',
      'donsNaturais': ['Empatia', 'Paciência', 'Escuta ativa'],
      'comoSeDestaca': 'Criando pontes e harmonizando conflitos',
    },
    3: {
      'talentos': 'Comunicação, criatividade, expressão artística',
      'formaDeAtuar': 'Age com entusiasmo e inspira através das palavras',
      'donsNaturais': ['Oratória', 'Arte', 'Otimismo contagiante'],
      'comoSeDestaca': 'Expressando-se de forma única e cativante',
    },
    4: {
      'talentos': 'Organização, planejamento, execução prática',
      'formaDeAtuar': 'Age com método e constrói passo a passo',
      'donsNaturais': ['Disciplina', 'Atenção aos detalhes', 'Confiabilidade'],
      'comoSeDestaca': 'Criando sistemas eficientes e duradouros',
    },
    5: {
      'talentos': 'Versatilidade, adaptabilidade, comunicação dinâmica',
      'formaDeAtuar': 'Age com flexibilidade e abraça mudanças',
      'donsNaturais': ['Adaptação rápida', 'Networking', 'Multitarefas'],
      'comoSeDestaca': 'Sendo versátil e trazendo novidades',
    },
    6: {
      'talentos': 'Cuidado, aconselhamento, criação de harmonia',
      'formaDeAtuar': 'Age com amor e assume responsabilidades',
      'donsNaturais': ['Empatia profunda', 'Senso estético', 'Proteção'],
      'comoSeDestaca': 'Criando ambientes harmoniosos e acolhedores',
    },
    7: {
      'talentos': 'Análise, pesquisa, intuição aguçada',
      'formaDeAtuar': 'Age com profundidade e busca compreensão',
      'donsNaturais': ['Pensamento analítico', 'Intuição', 'Sabedoria'],
      'comoSeDestaca': 'Trazendo insights profundos e soluções inovadoras',
    },
    8: {
      'talentos': 'Liderança executiva, visão estratégica, manifestação',
      'formaDeAtuar': 'Age com poder e foco em resultados',
      'donsNaturais': ['Gestão', 'Visão de negócios', 'Determinação'],
      'comoSeDestaca': 'Realizando grandes conquistas materiais',
    },
    9: {
      'talentos': 'Compaixão, visão holística, inspiração',
      'formaDeAtuar': 'Age com generosidade e olhar universal',
      'donsNaturais': ['Empatia universal', 'Idealismo', 'Carisma'],
      'comoSeDestaca': 'Inspirando e servindo causas maiores',
    },
  };

  /// Interpretações detalhadas para MOTIVAÇÃO (O que sente por dentro)
  /// Impulsos internos e desejos profundos
  static const Map<int, Map<String, dynamic>> motivacaoInterpretations = {
    1: {
      'desejosProfundos': 'Ser independente e reconhecido por suas conquistas',
      'oqueBusca': 'Autonomia, liderança e originalidade',
      'necessidadesEmocionais': 'Ser respeitado e ter liberdade de ação',
      'oqueMoveVoce': 'O desejo de ser o primeiro e fazer diferença',
    },
    2: {
      'desejosProfundos': 'Pertencer, ser amado e criar harmonia',
      'oqueBusca': 'Conexão profunda, parceria e paz',
      'necessidadesEmocionais': 'Ser valorizado e sentir-se parte de algo',
      'oqueMoveVoce': 'O desejo de união e harmonia nas relações',
    },
    3: {
      'desejosProfundos': 'Expressar-se e ser admirado por sua criatividade',
      'oqueBusca': 'Alegria, reconhecimento e liberdade criativa',
      'necessidadesEmocionais': 'Ser apreciado e ter espaço para criar',
      'oqueMoveVoce': 'O desejo de inspirar e alegrar o mundo',
    },
    4: {
      'desejosProfundos': 'Construir algo sólido e deixar legado',
      'oqueBusca': 'Segurança, estabilidade e resultados tangíveis',
      'necessidadesEmocionais': 'Sentir-se útil e ver progresso concreto',
      'oqueMoveVoce': 'O desejo de criar bases sólidas e duradouras',
    },
    5: {
      'desejosProfundos': 'Experimentar tudo e viver intensamente',
      'oqueBusca': 'Liberdade, aventura e variedade',
      'necessidadesEmocionais': 'Não se sentir preso ou limitado',
      'oqueMoveVoce': 'O desejo de explorar e expandir horizontes',
    },
    6: {
      'desejosProfundos': 'Amar, ser amado e criar harmonia familiar',
      'oqueBusca': 'Amor verdadeiro, família e responsabilidade afetiva',
      'necessidadesEmocionais': 'Ser necessário e cuidar de quem ama',
      'oqueMoveVoce': 'O desejo de nutrir e proteger',
    },
    7: {
      'desejosProfundos': 'Compreender os mistérios da vida e encontrar verdade',
      'oqueBusca': 'Sabedoria, autoconhecimento e conexão espiritual',
      'necessidadesEmocionais': 'Ter tempo sozinho para refletir',
      'oqueMoveVoce': 'O desejo de compreensão profunda e evolução',
    },
    8: {
      'desejosProfundos': 'Conquistar poder e manifestar abundância',
      'oqueBusca': 'Sucesso material, reconhecimento e influência',
      'necessidadesEmocionais': 'Sentir-se poderoso e bem-sucedido',
      'oqueMoveVoce': 'O desejo de realização e prosperidade',
    },
    9: {
      'desejosProfundos': 'Servir a humanidade e fazer diferença no mundo',
      'oqueBusca': 'Propósito maior, amor universal e transformação',
      'necessidadesEmocionais': 'Sentir que está contribuindo para o bem maior',
      'oqueMoveVoce': 'O desejo de amor universal e serviço',
    },
  };

  /// Interpretações detalhadas para MISSÃO (O que veio aprender)
  /// Lições da encarnação e aprendizados centrais
  static const Map<int, Map<String, dynamic>> missaoInterpretations = {
    1: {
      'licaoPrincipal': 'Aprender a liderar sem dominar',
      'aprendizadoCentral': 'Desenvolver independência respeitando os outros',
      'desafioEvolutivo': 'Equilibrar ego e humildade',
      'oquePrecisaDesenvolver': 'Liderança consciente e coragem equilibrada',
    },
    2: {
      'licaoPrincipal': 'Aprender a cooperar sem se perder',
      'aprendizadoCentral': 'Desenvolver empatia mantendo identidade',
      'desafioEvolutivo': 'Equilibrar dar e receber',
      'oquePrecisaDesenvolver': 'Parceria saudável e autoestima',
    },
    3: {
      'licaoPrincipal': 'Aprender a expressar-se com profundidade',
      'aprendizadoCentral': 'Desenvolver criatividade com foco',
      'desafioEvolutivo': 'Equilibrar leveza e seriedade',
      'oquePrecisaDesenvolver': 'Expressão autêntica e disciplina criativa',
    },
    4: {
      'licaoPrincipal': 'Aprender a construir com flexibilidade',
      'aprendizadoCentral': 'Desenvolver disciplina sem rigidez',
      'desafioEvolutivo': 'Equilibrar estrutura e adaptabilidade',
      'oquePrecisaDesenvolver': 'Organização consciente e abertura',
    },
    5: {
      'licaoPrincipal': 'Aprender a ser livre com responsabilidade',
      'aprendizadoCentral': 'Desenvolver versatilidade com foco',
      'desafioEvolutivo': 'Equilibrar liberdade e compromisso',
      'oquePrecisaDesenvolver': 'Liberdade consciente e estabilidade',
    },
    6: {
      'licaoPrincipal': 'Aprender a amar sem se sacrificar',
      'aprendizadoCentral': 'Desenvolver responsabilidade com limites',
      'desafioEvolutivo': 'Equilibrar cuidado próprio e do outro',
      'oquePrecisaDesenvolver': 'Amor equilibrado e autocuidado',
    },
    7: {
      'licaoPrincipal': 'Aprender a buscar sabedoria sem se isolar',
      'aprendizadoCentral': 'Desenvolver espiritualidade conectada',
      'desafioEvolutivo': 'Equilibrar introspecção e conexão',
      'oquePrecisaDesenvolver': 'Sabedoria compartilhada e abertura emocional',
    },
    8: {
      'licaoPrincipal': 'Aprender a manifestar poder com ética',
      'aprendizadoCentral': 'Desenvolver prosperidade consciente',
      'desafioEvolutivo': 'Equilibrar material e espiritual',
      'oquePrecisaDesenvolver': 'Poder responsável e generosidade',
    },
    9: {
      'licaoPrincipal': 'Aprender a servir sem se dispersar',
      'aprendizadoCentral': 'Desenvolver compaixão com discernimento',
      'desafioEvolutivo': 'Equilibrar idealismo e praticidade',
      'oquePrecisaDesenvolver': 'Serviço focado e desapego saudável',
    },
  };
}
