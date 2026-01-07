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
  // Tabela completa dos dias básicos por dia/mês
  static const Map<int, Map<int, List<int>>> _diasBasicosTabelaCompleta = {
    1: {
      // Janeiro
      1: [1, 5],
      2: [1, 6],
      3: [3, 6],
      4: [1, 5],
      5: [5, 6],
      6: [5, 6],
      7: [1, 7],
      8: [1, 3],
      9: [6, 9],
      10: [1, 5],
      11: [1, 6],
      12: [6, 9],
      13: [1, 5],
      14: [5, 6],
      15: [5, 6],
      16: [1, 5],
      17: [1, 3],
      18: [5, 6],
      19: [1, 5],
      20: [1, 6],
      21: [3, 6],
      22: [1, 5],
      23: [5, 6],
      24: [5, 6],
      25: [1, 5],
      26: [2, 3],
      27: [6, 9],
      28: [2, 7],
      29: [5, 7],
      30: [2, 3],
      31: [2, 7]
    },
    2: {
      // Fevereiro
      1: [1, 5],
      2: [2, 7],
      3: [3, 6],
      4: [2, 7],
      5: [5, 6],
      6: [3, 6],
      7: [2, 7],
      8: [2, 3],
      9: [3, 6],
      10: [2, 7],
      11: [5, 7],
      12: [5, 6],
      13: [2, 7],
      14: [5, 6],
      15: [3, 6],
      16: [2, 5],
      17: [2, 3],
      18: [3, 6],
      19: [2, 7],
      20: [2, 7],
      21: [3, 6],
      22: [2, 7],
      23: [5, 6],
      24: [5, 6],
      25: [2, 7],
      26: [2, 3],
      27: [6, 9],
      28: [2, 7],
      29: [6, 7],
      30: [3, 9],
      31: [1, 7]
    },
    3: {
      // Março
      1: [1, 7],
      2: [2, 7],
      3: [3, 6],
      4: [1, 7],
      5: [5, 7],
      6: [3, 6],
      7: [2, 7],
      8: [3, 6],
      9: [6, 9],
      10: [1, 7],
      11: [1, 7],
      12: [6, 7],
      13: [1, 5],
      14: [5, 7],
      15: [3, 6],
      16: [1, 2],
      17: [3, 6],
      18: [3, 6],
      19: [1, 7],
      20: [2, 7],
      21: [3, 6],
      22: [1, 7],
      23: [6, 7],
      24: [3, 6],
      25: [2, 7],
      26: [1, 3],
      27: [1, 9],
      28: [5, 9],
      29: [1, 7],
      30: [3, 6],
      31: [1, 5]
    },
    4: {
      // Abril
      1: [1, 7],
      2: [1, 7],
      3: [3, 9],
      4: [1, 7],
      5: [5, 7],
      6: [3, 6],
      7: [5, 7],
      8: [1, 3],
      9: [3, 9],
      10: [1, 7],
      11: [1, 7],
      12: [1, 9],
      13: [1, 7],
      14: [5, 7],
      15: [3, 6],
      16: [1, 2],
      17: [1, 3],
      18: [1, 3],
      19: [1, 7],
      20: [2, 7],
      21: [1, 3],
      22: [1, 7],
      23: [5, 7],
      24: [3, 5],
      25: [5, 7],
      26: [2, 3],
      27: [3, 6],
      28: [2, 7],
      29: [1, 7],
      30: [5, 6],
      31: [1, 3]
    },
    5: {
      // Maio
      1: [1, 2],
      2: [2, 7],
      3: [3, 6],
      4: [1, 7],
      5: [5, 6],
      6: [5, 6],
      7: [2, 7],
      8: [2, 5],
      9: [5, 9],
      10: [1, 5],
      11: [1, 7],
      12: [2, 6],
      13: [1, 7],
      14: [5, 6],
      15: [5, 6],
      16: [2, 5],
      17: [2, 3],
      18: [5, 6],
      19: [1, 2],
      20: [2, 7],
      21: [3, 6],
      22: [1, 7],
      23: [5, 6],
      24: [5, 6],
      25: [2, 7],
      26: [2, 5],
      27: [5, 9],
      28: [2, 7],
      29: [5, 7],
      30: [2, 3],
      31: [1, 5]
    },
    6: {
      // Junho
      1: [1, 5],
      2: [2, 7],
      3: [5, 6],
      4: [1, 5],
      5: [5, 6],
      6: [5, 6],
      7: [2, 7],
      8: [3, 5],
      9: [5, 9],
      10: [1, 5],
      11: [5, 7],
      12: [5, 6],
      13: [1, 5],
      14: [5, 6],
      15: [5, 6],
      16: [2, 5],
      17: [2, 5],
      18: [5, 6],
      19: [1, 5],
      20: [2, 7],
      21: [5, 6],
      22: [1, 5],
      23: [5, 6],
      24: [5, 6],
      25: [2, 7],
      26: [2, 5],
      27: [5, 6],
      28: [2, 7],
      29: [1, 7],
      30: [3, 6],
      31: [1, 5]
    },
    7: {
      // Julho
      1: [1, 2],
      2: [2, 7],
      3: [2, 3],
      4: [1, 7],
      5: [5, 7],
      6: [2, 6],
      7: [2, 7],
      8: [2, 3],
      9: [2, 3],
      10: [1, 2],
      11: [1, 7],
      12: [2, 6],
      13: [1, 2],
      14: [5, 7],
      15: [6, 7],
      16: [1, 2],
      17: [2, 3],
      18: [2, 3],
      19: [1, 2],
      20: [2, 7],
      21: [3, 6],
      22: [1, 2],
      23: [5, 7],
      24: [6, 7],
      25: [2, 7],
      26: [2, 3],
      27: [1, 9],
      28: [2, 7],
      29: [1, 7],
      30: [3, 6],
      31: [1, 7]
    },
    8: {
      // Agosto
      1: [1, 2],
      2: [1, 5],
      3: [3, 6],
      4: [1, 2],
      5: [1, 5],
      6: [3, 6],
      7: [2, 7],
      8: [2, 3],
      9: [3, 6],
      10: [1, 2],
      11: [1, 7],
      12: [1, 6],
      13: [1, 5],
      14: [1, 5],
      15: [1, 6],
      16: [1, 2],
      17: [1, 3],
      18: [1, 3],
      19: [1, 2],
      20: [2, 7],
      21: [3, 6],
      22: [1, 2],
      23: [1, 5],
      24: [3, 6],
      25: [2, 7],
      26: [2, 3],
      27: [3, 6],
      28: [2, 5],
      29: [1, 5],
      30: [3, 6],
      31: [1, 5]
    },
    9: {
      // Setembro
      1: [1, 5],
      2: [2, 5],
      3: [3, 6],
      4: [1, 5],
      5: [5, 6],
      6: [5, 6],
      7: [2, 5],
      8: [2, 3],
      9: [3, 6],
      10: [1, 2],
      11: [1, 5],
      12: [3, 6],
      13: [1, 7],
      14: [5, 6],
      15: [5, 6],
      16: [2, 5],
      17: [2, 3],
      18: [3, 6],
      19: [1, 5],
      20: [2, 7],
      21: [3, 6],
      22: [1, 7],
      23: [5, 6],
      24: [3, 6],
      25: [2, 7],
      26: [3, 6],
      27: [6, 9],
      28: [2, 7],
      29: [1, 7],
      30: [3, 6],
      31: [1, 5]
    },
    10: {
      // Outubro
      1: [2, 7],
      2: [2, 7],
      3: [3, 6],
      4: [1, 7],
      5: [5, 6],
      6: [3, 6],
      7: [2, 7],
      8: [3, 6],
      9: [3, 6],
      10: [1, 5],
      11: [1, 6],
      12: [2, 6],
      13: [1, 7],
      14: [5, 6],
      15: [3, 6],
      16: [1, 2],
      17: [3, 6],
      18: [3, 6],
      19: [2, 7],
      20: [2, 7],
      21: [3, 6],
      22: [1, 7],
      23: [5, 6],
      24: [3, 6],
      25: [2, 7],
      26: [3, 6],
      27: [6, 9],
      28: [2, 7],
      29: [1, 7],
      30: [3, 6],
      31: [1, 3]
    },
    11: {
      // Novembro
      1: [1, 7],
      2: [1, 7],
      3: [3, 9],
      4: [1, 7],
      5: [5, 7],
      6: [3, 5],
      7: [1, 7],
      8: [3, 9],
      9: [3, 9],
      10: [2, 7],
      11: [1, 7],
      12: [1, 9],
      13: [1, 7],
      14: [5, 7],
      15: [3, 5],
      16: [1, 5],
      17: [3, 9],
      18: [3, 9],
      19: [1, 7],
      20: [2, 7],
      21: [3, 9],
      22: [1, 7],
      23: [5, 7],
      24: [3, 5],
      25: [1, 7],
      26: [3, 9],
      27: [3, 9],
      28: [2, 7],
      29: [1, 7],
      30: [3, 6],
      31: [1, 7]
    },
    12: {
      // Dezembro
      1: [1, 7],
      2: [2, 7],
      3: [3, 6],
      4: [1, 7],
      5: [3, 6],
      6: [3, 6],
      7: [2, 7],
      8: [2, 3],
      9: [3, 9],
      10: [1, 7],
      11: [1, 7],
      12: [6, 9],
      13: [1, 3],
      14: [5, 6],
      15: [3, 6],
      16: [1, 2],
      17: [2, 3],
      18: [3, 6],
      19: [1, 7],
      20: [2, 7],
      21: [3, 6],
      22: [1, 7],
      23: [5, 6],
      24: [3, 6],
      25: [3, 7],
      26: [3, 6],
      27: [6, 9],
      28: [5, 6],
      29: [1, 6],
      30: [3, 6],
      31: [1, 7]
    },
  };

  /// Calcula os dias favoráveis conforme tabela e passos do documento
  List<int> calcularDiasFavoraveis() {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return [];
    final dia = dataNasc.day;
    final mes = dataNasc.month;
    final tabelaMes = _diasBasicosTabelaCompleta[mes];
    if (tabelaMes == null) return [];

    final basicos = tabelaMes[dia];
    if (basicos == null || basicos.length != 2) return [];

    final b1 = basicos[0];
    final b2 = basicos[1];
    final dias = <int>{b1, b2}; // Usar Set para evitar duplicatas

    int soma = b2 * 2;
    if (soma <= 31) dias.add(soma);

    bool alterna = true;
    while (true) {
      final valorASomar = alterna ? b1 : b2;
      soma += valorASomar;
      if (soma > 31) break;
      dias.add(soma);
      alterna = !alterna;
    }
    final listaOrdenada = dias.toList()..sort();
    return listaOrdenada;
  }

  /// Calcula o perfil numerológico completo
  NumerologyResult calculateProfile() {
    final destino = _calcularNumeroDestino();
    final expressao = _calcularNumeroExpressao();
    final motivacao = _calcularNumeroMotivacao();
    final impressao = _calcularNumeroImpressao();
    final missao = destino + expressao; // Simplificação comum
    final talentoOculto = _calcularTalentoOculto(motivacao, expressao);
    final dataNasc = _parseDate(dataNascimento);
    final psiquico = dataNasc != null ? _calcularNumeroPsiquico(dataNasc) : 0;
    
    final harmoniaConjugal = _calcularHarmoniaConjugal(destino, expressao);
    
    return NumerologyResult(
      idade: _calcularIdade(),
      numeros: {
        'destino': destino,
        'expressao': expressao,
        'motivacao': motivacao,
        'impressao': impressao,
        'missao': missao,
        'talentoOculto': talentoOculto,
        'psiquico': psiquico,
        'harmoniaConjugal': harmoniaConjugal,
      },
      estruturas: {
        'ciclosDeVida': _calcularCiclosDeVida(destino),
        'desafios': dataNasc != null ? _calcularDesafios(dataNasc, destino) : {},
        'momentosDecisivos': dataNasc != null ? _calcularMomentosDecisivos(dataNasc, destino) : {},
      },
      listas: {
        'licoesCarmicas': _calcularLicoesCarmicas(),
        'debitosCarmicos': _calcularDebitosCarmicos(destino, motivacao, expressao),
        'tendenciasOcultas': _calcularTendenciasOcultas(),
      },
    );
  }



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
    // Reduz cada componente separadamente
    final diaR = _reduzirNumero(dataNasc.day);
    final mesR = _reduzirNumero(dataNasc.month);
    final anoR = _reduzirNumero(dataNasc.year);
    // Soma e reduz mantendo mestres
    return _reduzirNumero(diaR + mesR + anoR, mestre: true);
  }

  Map<String, dynamic> _calcularCiclosDeVida(int numeroDestino) {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return {};
    final formatador = DateFormat('dd/MM/yyyy');
    // Duração do primeiro ciclo é 37 - destino (SEM reduzir mestres 11/22)
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
    const vogais = 'AEIOUYÃÕÁÉÍÓÚÀÂÊÔ'; // Inclui vogais acentuadas
    int somaTotal = 0;
    for (var letra in nomeCompleto.toUpperCase().split('')) {
      if (vogais.contains(letra)) {
        somaTotal += _calcularValor(letra);
      }
    }

    int e = _reduzirNumero(somaTotal, mestre: true);

    // REGRA ESPECIAL: Se o resultado for 2 ou 4, refaz o cálculo por palavra.
    if (e == 2 || e == 4) {
      final palavras = nomeCompleto.split(RegExp(r'\s+'));
      int totalPalavras = 0;
      for (final p in palavras) {
        int somaPalavra = p
            .toUpperCase()
            .split('')
            .where((l) => vogais.contains(l))
            .fold(0, (acc, l) => acc + _calcularValor(l));
        totalPalavras += _reduzirNumero(somaPalavra);
      }
      e = _reduzirNumero(totalPalavras, mestre: true);
    }
    return e;
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
    // Número de Impressão não preserva mestres (11/22 devem ser reduzidos)
    return _reduzirNumero(soma, mestre: false);
  }

  int _calcularTalentoOculto(int motivacao, int expressao) {
    return _reduzirNumero(motivacao + expressao, mestre: true);
  }

  // Número Psíquico: redução do dia de nascimento (1–9)
  int _calcularNumeroPsiquico(DateTime dataNasc) {
    return _reduzirNumero(dataNasc.day);
  }

  // Desafios: desafio1=|mes-dia|, desafio2=|ano-dia|, desafio3(principal)=|d1-d2|
  // Os períodos coincidem com os Ciclos de Vida
  Map<String, dynamic> _calcularDesafios(DateTime dataNasc, int numeroDestino) {
    final diaR = _reduzirNumero(dataNasc.day);
    final mesR = _reduzirNumero(dataNasc.month);
    final anoR = _reduzirNumero(dataNasc.year);

    // Desafios: resultados devem ser reduzidos (não mestre)
    final d1 = _reduzirNumero((mesR - diaR).abs(), mestre: false);
    final d2 = _reduzirNumero((anoR - diaR).abs(), mestre: false);
    final d3Principal = _reduzirNumero((d1 - d2).abs(), mestre: false);

    // Períodos baseados nos Ciclos de Vida (37 - Destino SEM reduzir mestres)
    final idadeFimDesafio1 = 37 - numeroDestino;
    final idadeInicioDesafio2 = idadeFimDesafio1;
    final idadeFimDesafio2 = idadeInicioDesafio2 + 27; // 2º Ciclo dura 27 anos
    final idadeInicioDesafio3 = idadeFimDesafio2;

    return {
      'desafio1': {
        'nome': 'Primeiro Desafio',
        'regente': d1,
        'idadeInicio': 0,
        'idadeFim': idadeFimDesafio1,
        'periodoIdade': 'nascimento até $idadeFimDesafio1 anos',
      },
      'desafio2': {
        'nome': 'Segundo Desafio',
        'regente': d2,
        'idadeInicio': idadeInicioDesafio2,
        'idadeFim': idadeFimDesafio2,
        'periodoIdade': '$idadeInicioDesafio2 a $idadeFimDesafio2 anos',
      },
      'desafioPrincipal': {
        'nome': 'Terceiro Desafio (Principal)',
        'regente': d3Principal,
        'idadeInicio': idadeInicioDesafio3,
        'idadeFim': 200, // Resto da vida
        'periodoIdade': 'a partir de $idadeInicioDesafio3 anos',
      },
    };
  }

  // Momentos Decisivos (Pinnacles): períodos e regentes conforme documento
  // P1 = reduzir(mês + dia), P2 = reduzir(dia + ano),
  // P3 = reduzir(P1 + P2), P4 = reduzir(mês + ano)
  Map<String, dynamic> _calcularMomentosDecisivos(
      DateTime dataNasc, int numeroDestino) {
    final mesR = _reduzirNumero(dataNasc.month);
    final diaR = _reduzirNumero(dataNasc.day);
    final anoR = _reduzirNumero(dataNasc.year);

    // Números mestres não são preservados aqui, conforme documento
    final p1Reg = _reduzirNumero(mesR + diaR, mestre: true);
    final p2Reg = _reduzirNumero(diaR + anoR, mestre: true);
    final p3Reg = _reduzirNumero(p1Reg + p2Reg, mestre: true);
    final p4Reg = _reduzirNumero(mesR + anoR, mestre: true);

    // Duração do primeiro ciclo é 37 - destino (SEM reduzir mestres 11/22)
    final anosP1 = 37 - numeroDestino;

    final anoNasc = dataNasc.year;
    final p1Inicio = anoNasc;
    final p1Fim = anoNasc + anosP1; // exemplo: 1969 -> 2002

    final p2Inicio = p1Fim;
    final p2Fim = p2Inicio + 9; // 9 anos

    final p3Inicio = p2Fim;
    final p3Fim = p3Inicio + 9; // 9 anos

    final p4Inicio = p3Fim;

    return {
      'p1': {
        'nome': 'Primeiro Momento Decisivo',
        'regente': p1Reg,
        'idadeInicio': 0,
        'idadeFim': anosP1,
        'periodoIdade': 'nascimento até $anosP1 anos',
        'periodoAno': '$p1Inicio a $p1Fim',
      },
      'p2': {
        'nome': 'Segundo Momento Decisivo',
        'regente': p2Reg,
        'idadeInicio': anosP1,
        'idadeFim': anosP1 + 9,
        'periodoIdade': '$anosP1 a ${anosP1 + 9} anos',
        'periodoAno': '$p2Inicio a $p2Fim',
      },
      'p3': {
        'nome': 'Terceiro Momento Decisivo',
        'regente': p3Reg,
        'idadeInicio': anosP1 + 9,
        'idadeFim': anosP1 + 18,
        'periodoIdade': '${anosP1 + 9} a ${anosP1 + 18} anos',
        'periodoAno': '$p3Inicio a $p3Fim',
      },
      'p4': {
        'nome': 'Quarto Momento Decisivo',
        'regente': p4Reg,
        'idadeInicio': anosP1 + 18,
        'idadeFim': 200, // Resto da vida
        'periodoIdade': 'a partir de ${anosP1 + 18} anos',
        'periodoAno': '$p4Inicio em diante',
      },
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
    // Tendência Oculta: aparece MAIS de três vezes (>=4 ocorrências)
    for (int i = 1; i <= 9; i++) {
      if ((contagem[i] ?? 0) >= 4) {
        tendencias.add(i);
      }
    }
    return tendencias..sort();
  }

  int _calcularRespostaSubconsciente() {
    return 9 - _calcularLicoesCarmicas().length;
  }

  // --- Harmonia Conjugal Logic ---

  int _calcularHarmoniaConjugal(int destino, int expressao) {
    // Soma Expressão + Destino e reduz a 1-9 (sem mestres)
    return _reduzirNumero(destino + expressao, mestre: false);
  }

  static const Map<int, Map<String, List<int>>> _tabelaHarmonia = {
    1: {'vibra': [9], 'atrai': [4, 8], 'oposto': [6, 7], 'passivo': [2, 3, 5]},
    2: {'vibra': [8], 'atrai': [7, 9], 'oposto': [5], 'passivo': [1, 3, 4, 6]},
    3: {'vibra': [7], 'atrai': [5, 6, 9], 'oposto': [4, 8], 'passivo': [1, 2]},
    4: {'vibra': [6], 'atrai': [1, 8], 'oposto': [3, 5], 'passivo': [2, 7, 9]},
    5: {'vibra': [5], 'atrai': [3, 9], 'oposto': [2, 4, 6], 'passivo': [1, 7, 8]},
    6: {'vibra': [4], 'atrai': [3, 7, 9], 'oposto': [1, 5, 8], 'passivo': [2]},
    7: {'vibra': [3], 'atrai': [2, 6], 'oposto': [1, 9], 'passivo': [4, 5, 8]},
    8: {'vibra': [2], 'atrai': [1, 4], 'oposto': [3, 6], 'passivo': [5, 7, 9]},
    9: {'vibra': [1], 'atrai': [2, 3, 5, 6], 'oposto': [7], 'passivo': [4, 8]},
  };

  static Map<String, dynamic> checkCompatibility(int harmonia1, int harmonia2) {
    if (harmonia1 == harmonia2) {
      if (harmonia1 == 5) {
        return {'status': 'Compatíveis (Vibram juntos)', 'descricao': 'Vocês possuem o mesmo número (5). Um completa o outro, excelente compatibilidade!'};
      }
      return {'status': 'Compatíveis (Monotonia)', 'descricao': 'Vocês possuem o mesmo número ($harmonia1). São compatíveis e harmônicos, mas o relacionamento tende a tornar-se monótono com o tempo se não houver novidades.'};
    }

    final regras = _tabelaHarmonia[harmonia1];
    if (regras == null) return {'status': 'Desconhecido', 'descricao': ''};

    if ((regras['vibra'] as List).contains(harmonia2)) {
      return {'status': 'Vibram Juntos', 'descricao': 'Excelente compatibilidade! O número $harmonia1 vibra em sintonia com o $harmonia2.'};
    }
    if ((regras['atrai'] as List).contains(harmonia2)) {
      return {'status': 'Atração', 'descricao': 'Existe uma forte atração entre os números $harmonia1 e $harmonia2.'};
    }
    if ((regras['oposto'] as List).contains(harmonia2)) {
      return {'status': 'Opostos', 'descricao': 'Os números $harmonia1 e $harmonia2 são opostos. Podem ter um excelente relacionamento se houver consciência e sabedoria para lidar com as diferenças.'};
    }
    if ((regras['passivo'] as List).contains(harmonia2)) {
      return {'status': 'Passivo', 'descricao': 'A relação entre $harmonia1 e $harmonia2 é passiva. Exige esforço mútuo para manter a chama acesa.'};
    }

    return {'status': 'Neutro', 'descricao': 'Relação sem fortes influências numerológicas diretas.'};
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
    final desafios = _calcularDesafios(dataNascDate, destino);

    final ciclosDeVida = _calcularCiclosDeVida(destino);

    Map<String, dynamic> cicloDeVidaAtual;
    if (idade < ciclosDeVida['ciclo1']['idadeFim']) {
      cicloDeVidaAtual = ciclosDeVida['ciclo1'];
    } else if (idade < ciclosDeVida['ciclo2']['idadeFim']) {
      cicloDeVidaAtual = ciclosDeVida['ciclo2'];
    } else {
      cicloDeVidaAtual = ciclosDeVida['ciclo3'];
    }

    // Desafio Atual
    Map<String, dynamic> desafioAtual;
    if (idade < (desafios['desafio1']?['idadeFim'] ?? 0)) {
      desafioAtual = desafios['desafio1'];
    } else if (idade < (desafios['desafio2']?['idadeFim'] ?? 0)) {
      desafioAtual = desafios['desafio2'];
    } else {
      desafioAtual = desafios['desafioPrincipal'];
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
    final momentosDecisivos = _calcularMomentosDecisivos(dataNascDate, destino);

    // Cálculos de listas (lições, débitos, tendências)
    final licoesCarmicas = _calcularLicoesCarmicas();
    final debitosCarmicos =
        _calcularDebitosCarmicos(destino, motivacao, expressao);
    final tendenciasOcultas = _calcularTendenciasOcultas();
    final diasFavoraveis = calcularDiasFavoraveis();
    final harmoniaConjugal = _calcularHarmoniaConjugal(destino, expressao);

    // Momento Decisivo Atual
    Map<String, dynamic> momentoDecisivoAtual;
    if (idade < (momentosDecisivos['p1']?['idadeFim'] ?? 0)) {
      momentoDecisivoAtual = momentosDecisivos['p1'];
    } else if (idade < (momentosDecisivos['p2']?['idadeFim'] ?? 0)) {
      momentoDecisivoAtual = momentosDecisivos['p2'];
    } else if (idade < (momentosDecisivos['p3']?['idadeFim'] ?? 0)) {
      momentoDecisivoAtual = momentosDecisivos['p3'];
    } else {
      momentoDecisivoAtual = momentosDecisivos['p4'];
    }

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
        'desafio': desafios['desafioPrincipal']?['regente'] ?? 0,
      },
      estruturas: {
        'ciclosDeVida': ciclosDeVida,
        'cicloDeVidaAtual': cicloDeVidaAtual,
        'harmoniaConjugal': _tabelaHarmonia[harmoniaConjugal] ?? {},
        'desafios': desafios,
        'desafioAtual': desafioAtual,
        'momentosDecisivos': momentosDecisivos,
        'momentoDecisivoAtual': momentoDecisivoAtual,
      },
      listas: {
        'licoesCarmicas': licoesCarmicas,
        'debitosCarmicos': debitosCarmicos,
        'tendenciasOcultas': tendenciasOcultas,
        'diasFavoraveis': diasFavoraveis,
      },
    );
  }

  // --- MÉTODO NOVO ADICIONADO PARA O CALENDÁRIO ---
  int calculatePersonalDayForDate(DateTime date) {
    final dataNasc = _parseDate(dataNascimento);
    if (dataNasc == null) return 0;

    // Ano pessoal muda no aniversário. Se a data consultada ainda não
    // alcançou o aniversário no ano corrente, usa-se (ano - 1).
    final aniversarioNoAno = DateTime(date.year, dataNasc.month, dataNasc.day);
    final anoParaCalculo =
        date.isBefore(aniversarioNoAno) ? date.year - 1 : date.year;

    final anoPessoal =
        _reduzirNumero(dataNasc.day + dataNasc.month + anoParaCalculo);
    final mesPessoal = _reduzirNumero(anoPessoal + date.month);
    final diaPessoal = _reduzirNumero(
        mesPessoal + _reduzirNumero(date.day, mestre: true),
        mestre: true);

    return diaPessoal;
  }

  /// Static helper for single-off calculations without instantiating the engine
  static int calculatePersonalDay(DateTime date, String birthDate) {
    // We create a temporary instance or just duplicate logic. 
    // Since _reduzirNumero is an instance method (which is weird, should be static), 
    // we'll instantiate a temporary engine.
    final engine = NumerologyEngine(nomeCompleto: '', dataNascimento: birthDate);
    return engine.calculatePersonalDayForDate(date);
  }

  // === SINCRO MATCH LOGIC (COMPATIBILIDADE) ===


  /// Verifica se uma data específica é favorável para um usuário
  bool isDateFavorable(DateTime targetDate) {
    if (_parseDate(dataNascimento) == null) return false;
    
    // A logica atual de calcularDiasFavoraveis é "para o mês corrente"?
    // O método original pega dia/mes de nascimento e gera dias fixos (1 a 31).
    // Assumimos que esses dias são favoráveis em QUALQUER mês.
    // (Esta é uma simplificação comum em numerologia cabalística de dias favoráveis)
    final diasFavoraveis = calcularDiasFavoraveis();
    return diasFavoraveis.contains(targetDate.day);
  }

  /// Matriz de compatibilidade entre Dias Pessoais
  /// Baseada em pesquisa de Numerologia Cabalística
  static const Map<String, double> _personalDayCompatibility = {
    // Pares Altamente Compatíveis (1.0)
    '1-9': 1.0, '9-1': 1.0, // Início + Conclusão
    '2-7': 1.0, '7-2': 1.0, // Harmonia + Espiritualidade
    '3-5': 1.0, '5-3': 1.0, // Criatividade + Liberdade
    '3-9': 1.0, '9-3': 1.0, // Comunicação + Compaixão
    '6-9': 1.0, '9-6': 1.0, // Família + Universal
    
    // Pares Complementares (0.8)
    '1-2': 0.8, '2-1': 0.8, // Liderança + Diplomacia
    '1-5': 0.8, '5-1': 0.8, // Iniciativa + Versatilidade
    '2-6': 0.8, '6-2': 0.8, // Cooperação + Família
    '3-6': 0.8, '6-3': 0.8, // Expressão + Harmonia
    '4-8': 0.8, '8-4': 0.8, // Construção + Realização
    '5-7': 0.8, '7-5': 0.8, // Liberdade + Sabedoria
    '6-8': 0.8, '8-6': 0.8, // Responsabilidade + Poder
    '7-9': 0.8, '9-7': 0.8, // Sabedoria + Compaixão
    '1-8': 0.8, '8-1': 0.8, // Liderança + Poder
    '2-4': 0.8, '4-2': 0.8, // Cooperação + Estrutura
    
    // Pares com Tensão (0.3)
    '1-4': 0.3, '4-1': 0.3, // Impulso vs. Rigidez
    '2-5': 0.3, '5-2': 0.3, // Estabilidade vs. Mudança
    '4-5': 0.3, '5-4': 0.3, // Ordem vs. Liberdade
    '4-7': 0.3, '7-4': 0.3, // Praticidade vs. Abstração
    '6-7': 0.3, '7-6': 0.3, // Família vs. Solidão
  };

  /// Retorna o score de compatibilidade entre dois Dias Pessoais
  static double _getPersonalDayCompatibility(int dpA, int dpB) {
    // Números iguais = ressonância perfeita
    if (dpA == dpB) return 1.0;
    
    // Busca na matriz de compatibilidade
    final key = '$dpA-$dpB';
    if (_personalDayCompatibility.containsKey(key)) {
      return _personalDayCompatibility[key]!;
    }
    
    // Padrão: Neutro
    return 0.5;
  }

  /// Calcula a compatibilidade entre dois usuários para uma data específica
  /// 
  /// Score Final = (FavorableScore × 0.5) + (PersonalDayScore × 0.5)
  /// 
  /// - FavorableScore: 1.0 (ambos), 0.5 (um), 0.0 (nenhum)
  /// - PersonalDayScore: Baseado na matriz de compatibilidade cabalística
  static double calculateCompatibilityScore({
    required DateTime date,
    required DateTime birthDateA,
    required DateTime birthDateB,
  }) {
    // Instancia engines temporárias para calcular
    final engineA = NumerologyEngine(nomeCompleto: '', dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateA));
    final engineB = NumerologyEngine(nomeCompleto: '', dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateB));

    // 1. Calcular Dias Favoráveis
    final bool favorableA = engineA.isDateFavorable(date);
    final bool favorableB = engineB.isDateFavorable(date);
    double favorableScore = (favorableA && favorableB) ? 1.0 
                          : (favorableA || favorableB) ? 0.5 
                          : 0.0;

    // 2. Calcular Dias Pessoais
    final int dpA = engineA.calculatePersonalDayForDate(date);
    final int dpB = engineB.calculatePersonalDayForDate(date);
    double pdScore = _getPersonalDayCompatibility(dpA, dpB);

    // 3. Score Final (média ponderada 50/50)
    return (favorableScore * 0.5) + (pdScore * 0.5);
  }

  /// Encontra as próximas datas onde AMBOS possuem dia favorável (Sincro Match)
  static List<DateTime> findNextCompatibleDates({
    required DateTime startDate,
    required DateTime birthDateA,
    required DateTime birthDateB,
    int limit = 5,
  }) {
    final engineA = NumerologyEngine(nomeCompleto: '', dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateA));
    final engineB = NumerologyEngine(nomeCompleto: '', dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateB));

    final daysA = engineA.calcularDiasFavoraveis(); // ex: [2, 5, 11, 20...]
    final daysB = engineB.calcularDiasFavoraveis(); // ex: [1, 5, 10, 20...]

    // Interseção: dias do mês bons para ambos
    final commonDays = daysA.toSet().intersection(daysB.toSet()).toList()..sort();

    final List<DateTime> results = [];
    DateTime cursor = startDate;

    // Procura nos próximos 60 dias
    for (int i = 0; i < 60; i++) {
        if (commonDays.contains(cursor.day)) {
            results.add(cursor);
            if (results.length >= limit) break;
        }
        cursor = cursor.add(const Duration(days: 1));
    }

    return results;
  }
}
