// lib/services/numerology_engine.dart

import 'package:intl/intl.dart';

// Classe de dados para um resultado mais organizado
class NumerologyResult {
  final int idade;
  final Map<String, int> numeros;
  final Map<String, dynamic> estruturas;
  final Map<String, dynamic> listas; // NOVO: lições, débitos, tendências, etc.

  NumerologyResult({
    required this.idade,
    required this.numeros,
    required this.estruturas,
    required this.listas,
  });
}

class NumerologyEngine {
  final String nomeCompleto;
  final String dataNascimento;

  NumerologyEngine({required this.nomeCompleto, required this.dataNascimento});

  static const Map<String, int> _tabelaConversao = {
    'A': 1, 'I': 1, 'Q': 1, 'J': 1, 'Y': 1,
    'B': 2, 'K': 2, 'R': 2,
    'C': 3, 'G': 3, 'L': 3, 'S': 3,
    'D': 4, 'M': 4, 'T': 4, 'X': 4, // Adicionado 'X'
    'E': 5, 'H': 5, 'N': 5,
    'U': 6, 'V': 6, 'W': 6,
    'O': 7, 'Z': 7,
    'F': 8, 'P': 8,
  };

  int _reduzirNumero(int n, {bool mestre = false}) {
    while (n > 9) {
      if (mestre && (n == 11 || n == 22)) {
        return n;
      }
      n = n.toString().split('').map(int.parse).reduce((a, b) => a + b);
    }
    return n;
  }

  int _calcularValor(String letra) {
    // Implementação simples anterior não suportava diacríticos aumentados; mantemos ajuste mestre.
    final upper = letra.toUpperCase();
    if (upper == 'Ç') return 6;
    int base = _tabelaConversao[upper
            .replaceAll('Á', 'A')
            .replaceAll('À', 'A')
            .replaceAll('Ã', 'A')
            .replaceAll('Â', 'A')
            .replaceAll('É', 'E')
            .replaceAll('Ê', 'E')
            .replaceAll('Í', 'I')
            .replaceAll('Ó', 'O')
            .replaceAll('Õ', 'O')
            .replaceAll('Ô', 'O')
            .replaceAll('Ú', 'U')] ??
        0;
    switch (upper) {
      case 'Á':
      case 'É':
      case 'Í':
      case 'Ó':
      case 'Ú':
        return base + 2;
      case 'Ã':
      case 'Õ':
        return base + 3;
      case 'À':
        return base * 3;
      default:
        return base;
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(dateStr);
    } catch (e) {
      return null;
    }
  }

  int _calcularIdade() {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return 0;
    final hoje = DateTime.now();
    int idade = hoje.year - dataNasc.year;
    if (hoje.month < dataNasc.month ||
        (hoje.month == dataNasc.month && hoje.day < dataNasc.day)) {
      idade--;
    }
    return idade;
  }

  int _calcularNumeroDestino() {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return 0;
    return _reduzirNumero(dataNasc.day + dataNasc.month + dataNasc.year,
        mestre: true);
  }

  Map<String, dynamic> _calcularCiclosDeVida(int numeroDestino) {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return {};
    final formatador = DateFormat('dd/MM/yyyy');
    final idadeFimCiclo1 = 37 - numeroDestino;
    final dataFim1 = DateTime(
        dataNasc.year + idadeFimCiclo1, dataNasc.month, dataNasc.day - 1);
    final idadeInicioCiclo2 = idadeFimCiclo1;
    final idadeFimCiclo2 = idadeInicioCiclo2 + 27;
    final dataInicio2 = DateTime(
        dataNasc.year + idadeInicioCiclo2, dataNasc.month, dataNasc.day);
    final dataFim2 = DateTime(
        dataNasc.year + idadeFimCiclo2, dataNasc.month, dataNasc.day - 1);
    final idadeInicioCiclo3 = idadeFimCiclo2;
    final dataInicio3 = DateTime(
        dataNasc.year + idadeInicioCiclo3, dataNasc.month, dataNasc.day);
    return {
      'ciclo1': {
        'nome': "Primeiro Ciclo de Vida",
        'regente': _reduzirNumero(dataNasc.month),
        'periodo': 'Nascimento até ${formatador.format(dataFim1)}',
        'idadeFim': idadeFimCiclo1
      },
      'ciclo2': {
        'nome': "Segundo Ciclo de Vida",
        'regente': _reduzirNumero(dataNasc.day, mestre: true),
        'periodo':
            '${formatador.format(dataInicio2)} a ${formatador.format(dataFim2)}',
        'idadeInicio': idadeInicioCiclo2,
        'idadeFim': idadeFimCiclo2
      },
      'ciclo3': {
        'nome': "Terceiro Ciclo de Vida",
        'regente': _reduzirNumero(dataNasc.year, mestre: true),
        'periodo': 'A partir de ${formatador.format(dataInicio3)}',
        'idadeInicio': idadeInicioCiclo3
      },
    };
  }

  // REMOVIDO: Funções de Arcanos (_calcularTrianguloDaVida e _calcularArcanoAtual) – não fazem mais parte do modelo numerológico atual.

  // === NOVOS MÉTODOS DE CÁLCULO (baseados no JS) ===

  int _calcularNumeroExpressao() {
    final nomeLimpo = nomeCompleto.replaceAll(RegExp(r'\s+'), '');
    int soma = nomeLimpo.split('').fold(0, (acc, l) => acc + _calcularValor(l));
    int e = _reduzirNumero(soma, mestre: true);
    if (e == 2 || e == 4) {
      // Regra do mestre: somar por palavra reduzida
      final palavras = nomeCompleto.split(RegExp(r'\s+'));
      int totalPalavras = 0;
      for (final p in palavras) {
        int somaPalavra =
            p.split('').fold(0, (acc, l) => acc + _calcularValor(l));
        totalPalavras += _reduzirNumero(somaPalavra);
      }
      e = _reduzirNumero(totalPalavras);
    }
    return e;
  }

  int _calcularNumeroMotivacao() {
    const vogais = 'AEIOUY';
    int soma = 0;
    for (var letra in nomeCompleto.split('')) {
      final char = letra.toUpperCase();
      if (vogais.contains(char)) {
        soma += _calcularValor(letra);
      }
    }
    return _reduzirNumero(soma, mestre: true);
  }

  int _calcularNumeroImpressao() {
    const consoantes = 'BCDFGHJKLMNPQRSTVWXYZÇ';
    int soma = 0;
    for (var letra in nomeCompleto.split('')) {
      final char = letra.toUpperCase();
      if (consoantes.contains(char)) {
        soma += _calcularValor(letra);
      }
    }
    return _reduzirNumero(soma, mestre: true);
  }

  int _calcularTalentoOculto(int motivacao, int expressao) {
    return _reduzirNumero(motivacao + expressao);
  }

  // Número Psíquico: redução do dia de nascimento (1–9)
  int _calcularNumeroPsiquico(DateTime dataNasc) {
    return _reduzirNumero(dataNasc.day);
  }

  // Desafio Principal (0–8): |mês reduzido - dia reduzido|
  // Desafios: desafio1=|mes-dia|, desafio2=|ano-dia|, principal=|d1-d2|
  Map<String, int> _calcularDesafios(DateTime dataNasc) {
    final diaR = _reduzirNumero(dataNasc.day);
    final mesR = _reduzirNumero(dataNasc.month);
    final anoR = _reduzirNumero(dataNasc.year);
    final d1 = (mesR - diaR).abs();
    final d2 = (anoR - diaR).abs();
    final principal = (d1 - d2).abs();
    return {
      'desafio1': d1,
      'desafio2': d2,
      'desafioPrincipal': principal,
    };
  }

  // Momentos Decisivos (Pinnacles):
  // P1 = reduzir(mês + dia), P2 = reduzir(dia + ano),
  // P3 = reduzir(P1 + P2), P4 = reduzir(mês + ano)
  Map<String, dynamic> _calcularMomentosDecisivos(
      DateTime dataNasc, int idade) {
    final mesR = _reduzirNumero(dataNasc.month);
    final diaR = _reduzirNumero(dataNasc.day);
    final anoR = _reduzirNumero(dataNasc.year);

    final p1 = _reduzirNumero(mesR + diaR, mestre: true);
    final p2 = _reduzirNumero(diaR + anoR, mestre: true);
    final p3 = _reduzirNumero(p1 + p2, mestre: true);
    final p4 = _reduzirNumero(mesR + anoR, mestre: true);

    int atual;
    if (idade <= 36) {
      atual = p1;
    } else if (idade <= 45) {
      atual = p2;
    } else if (idade <= 54) {
      atual = p3;
    } else {
      atual = p4;
    }

    return {
      'p1': p1,
      'p2': p2,
      'p3': p3,
      'p4': p4,
      'atual': atual,
    };
  }

  List<int> _calcularLicoesCarmicas() {
    final numerosPresentes = <int>{};
    final nomeLimpo = nomeCompleto.replaceAll(RegExp(r'\s+'), '');
    for (var letra in nomeLimpo.split('')) {
      final valor = _calcularValor(letra);
      if (valor > 0) {
        numerosPresentes.add(_reduzirNumero(valor));
      }
    }
    final licoes = <int>[];
    for (int i = 1; i <= 9; i++) {
      if (!numerosPresentes.contains(i)) {
        licoes.add(i);
      }
    }
    return licoes;
  }

  List<int> _calcularDebitosCarmicos(
      int destino, int motivacao, int expressao) {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return [];

    final debitos = <int>{};
    final diaNascimento = dataNasc.day;

    // Débitos kármicos diretos do dia de nascimento
    if ([13, 14, 16, 19].contains(diaNascimento)) {
      debitos.add(diaNascimento);
    }

    // Mapeamento: número -> débito kármico
    const Map<int, int> mapeamento = {4: 13, 5: 14, 7: 16, 1: 19};

    for (var numero in [destino, motivacao, expressao]) {
      if (mapeamento.containsKey(numero)) {
        debitos.add(mapeamento[numero]!);
      }
    }

    return debitos.toList()..sort();
  }

  List<int> _calcularTendenciasOcultas() {
    final contagem = <int, int>{};
    final nomeLimpo = nomeCompleto.replaceAll(RegExp(r'\s+'), '');

    for (var letra in nomeLimpo.split('')) {
      final valor = _calcularValor(letra);
      if (valor > 0) {
        final reduzido = _reduzirNumero(valor);
        contagem[reduzido] = (contagem[reduzido] ?? 0) + 1;
      }
    }

    final tendencias = <int>[];
    for (int i = 1; i <= 9; i++) {
      if ((contagem[i] ?? 0) >= 3) {
        tendencias.add(i);
      }
    }
    return tendencias..sort();
  }

  int _calcularRespostaSubconsciente() {
    return 9 - _calcularLicoesCarmicas().length;
  }

  Map<String, dynamic> _calcularHarmoniaConjugal(int missao) {
    const harmonias = {
      1: {
        'vibra': [9],
        'atrai': [4, 8],
        'oposto': [6, 7],
        'passivo': [2, 3, 5]
      },
      2: {
        'vibra': [8],
        'atrai': [7, 9],
        'oposto': [5],
        'passivo': [1, 3, 4, 6]
      },
      3: {
        'vibra': [7],
        'atrai': [5, 6, 9],
        'oposto': [4, 8],
        'passivo': [1, 2]
      },
      4: {
        'vibra': [6],
        'atrai': [1, 8],
        'oposto': [3, 5],
        'passivo': [2, 7, 9]
      },
      5: {
        'vibra': [5],
        'atrai': [3, 9],
        'oposto': [2, 4, 6],
        'passivo': [1, 7, 8]
      },
      6: {
        'vibra': [4],
        'atrai': [3, 7, 9],
        'oposto': [1, 5, 8],
        'passivo': [2]
      },
      7: {
        'vibra': [3],
        'atrai': [2, 6],
        'oposto': [1, 9],
        'passivo': [4, 5, 8]
      },
      8: {
        'vibra': [2],
        'atrai': [1, 4],
        'oposto': [3, 6],
        'passivo': [5, 7, 9]
      },
      9: {
        'vibra': [1],
        'atrai': [2, 3, 5, 6],
        'passivo': [4, 8]
      },
    };
    return harmonias[missao] ?? {};
  }

  // === FIM DOS NOVOS MÉTODOS ===

  NumerologyResult? calcular() {
    final dataNascDate = _parseDate(dataNascimento);
    if (nomeCompleto.isEmpty || dataNascDate == null) return null;

    final idade = _calcularIdade();
    final destino = _calcularNumeroDestino();
    final expressao = _calcularNumeroExpressao();
    final motivacao = _calcularNumeroMotivacao();
    final impressao = _calcularNumeroImpressao();
    final missao = _reduzirNumero(expressao + destino, mestre: true);
    final talentoOculto = _calcularTalentoOculto(motivacao, expressao);
    final respostaSubconsciente = _calcularRespostaSubconsciente();
    final diaNatalicio = dataNascDate.day; // Dia de nascimento (1-31)
    final numeroPsiquico = _calcularNumeroPsiquico(dataNascDate);
    final desafios = _calcularDesafios(dataNascDate);

    final ciclosDeVida = _calcularCiclosDeVida(destino);

    Map<String, dynamic> cicloDeVidaAtual;
    if (idade < ciclosDeVida['ciclo1']['idadeFim']) {
      cicloDeVidaAtual = ciclosDeVida['ciclo1'];
    } else if (idade < ciclosDeVida['ciclo2']['idadeFim']) {
      cicloDeVidaAtual = ciclosDeVida['ciclo2'];
    } else {
      cicloDeVidaAtual = ciclosDeVida['ciclo3'];
    }

    // Arcanos descontinuados: removidos do cálculo.

    final hoje = DateTime.now();
    final aniversarioJaPassou = hoje.month > dataNascDate.month ||
        (hoje.month == dataNascDate.month && hoje.day >= dataNascDate.day);
    final anoParaCalculo = aniversarioJaPassou ? hoje.year : hoje.year - 1;

    final anoPessoal =
        _reduzirNumero(dataNascDate.day + dataNascDate.month + anoParaCalculo);
    final mesPessoal = _reduzirNumero(anoPessoal + hoje.month);
    final diaPessoal = _reduzirNumero(
        mesPessoal + _reduzirNumero(hoje.day, mestre: true),
        mestre: true);

    // Momentos decisivos (pinnacles)
    final momentosDecisivos = _calcularMomentosDecisivos(dataNascDate, idade);

    // Cálculos de listas (lições, débitos, tendências)
    final licoesCarmicas = _calcularLicoesCarmicas();
    final debitosCarmicos =
        _calcularDebitosCarmicos(destino, motivacao, expressao);
    final tendenciasOcultas = _calcularTendenciasOcultas();
    final harmoniaConjugal = _calcularHarmoniaConjugal(missao);

    return NumerologyResult(
      idade: idade,
      numeros: {
        'diaPessoal': diaPessoal,
        'mesPessoal': mesPessoal,
        'anoPessoal': anoPessoal,
        'destino': destino,
        'expressao': expressao,
        'motivacao': motivacao,
        'impressao': impressao,
        'missao': missao,
        'talentoOculto': talentoOculto,
        'respostaSubconsciente': respostaSubconsciente,
        'diaNatalicio': diaNatalicio,
        'numeroPsiquico': numeroPsiquico,
        // Aptidões Profissionais: utilizamos o número de Expressão como base
        'aptidoesProfissionais': expressao,
        'desafio': desafios['desafioPrincipal'] ?? 0,
      },
      estruturas: {
        'ciclosDeVida': ciclosDeVida,
        'cicloDeVidaAtual': cicloDeVidaAtual,
        'harmoniaConjugal': harmoniaConjugal,
        'desafios': desafios,
        'momentosDecisivos': momentosDecisivos,
        'momentoDecisivoAtual': momentosDecisivos['atual'],
      },
      listas: {
        'licoesCarmicas': licoesCarmicas,
        'debitosCarmicos': debitosCarmicos,
        'tendenciasOcultas': tendenciasOcultas,
      },
    );
  }

  // --- MÉTODO NOVO ADICIONADO PARA O CALENDÁRIO ---
  int calculatePersonalDayForDate(DateTime date) {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return 0;

    // Ensure we work with UTC date consistently
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    final dataNascUtc =
        DateTime.utc(dataNasc.year, dataNasc.month, dataNasc.day);

    // Redução inicial dos números
    int diaNascReduzido = _reduzirNumero(dataNascUtc.day);
    int mesNascReduzido = _reduzirNumero(dataNascUtc.month);

    // Redução do ano atual
    int anoAtualReduzido = _reduzirNumero(utcDate.year);

    // Cálculo do ano pessoal
    int anoPessoal =
        _reduzirNumero(diaNascReduzido + mesNascReduzido + anoAtualReduzido);

    // Cálculo do mês pessoal
    int mesPessoal = _reduzirNumero(anoPessoal + _reduzirNumero(utcDate.month));

    // Cálculo final do dia pessoal
    return _reduzirNumero(mesPessoal + _reduzirNumero(utcDate.day));
  }
}
