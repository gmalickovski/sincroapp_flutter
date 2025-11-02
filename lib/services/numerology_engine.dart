// lib/services/numerology_engine.dart

import 'package:intl/intl.dart';

// Classe de dados para um resultado mais organizado
class NumerologyResult {
  final int idade;
  final Map<String, int> numeros;
  final Map<String, dynamic> estruturas;

  NumerologyResult(
      {required this.idade, required this.numeros, required this.estruturas});
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
    String char = letra.toUpperCase();
    if (char == 'Ç') return 6;
    String charNormalizado = char
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
        .replaceAll('Ú', 'U');
    return _tabelaConversao[charNormalizado] ?? 0;
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

  Map<String, dynamic> _calcularTrianguloDaVida() {
    final nomeLimpo = nomeCompleto.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (nomeLimpo.isEmpty)
      return {'arcanoRegente': null, 'sequenciaCompletaArcanos': []};
    List<int> valoresNumericos =
        nomeLimpo.split('').map((l) => _calcularValor(l)).toList();
    List<int> sequenciaCompletaArcanos = [];
    for (int i = 0; i < valoresNumericos.length - 1; i++) {
      sequenciaCompletaArcanos
          .add(int.parse('${valoresNumericos[i]}${valoresNumericos[i + 1]}'));
    }
    List<int> linhaAtual = List.from(valoresNumericos);
    while (linhaAtual.length > 1) {
      List<int> proximaLinha = [];
      for (int j = 0; j < linhaAtual.length - 1; j++) {
        proximaLinha.add(_reduzirNumero(linhaAtual[j] + linhaAtual[j + 1]));
      }
      linhaAtual = proximaLinha;
    }
    return {
      'arcanoRegente': linhaAtual.isNotEmpty ? linhaAtual[0] : null,
      'sequenciaCompletaArcanos': sequenciaCompletaArcanos
    };
  }

  Map<String, dynamic> _calcularArcanoAtual(int idade, List<int> sequencia) {
    if (sequencia.isEmpty) return {'numero': null};
    final duracaoCicloArcano = 90 / sequencia.length;
    final indiceArcano = (idade / duracaoCicloArcano).floor();
    return {
      'numero': indiceArcano < sequencia.length ? sequencia[indiceArcano] : null
    };
  }

  NumerologyResult? calcular() {
    final dataNascDate = _parseDate(dataNascimento);
    if (nomeCompleto.isEmpty || dataNascDate == null) return null;

    final idade = _calcularIdade();
    final destino = _calcularNumeroDestino();
    final ciclosDeVida = _calcularCiclosDeVida(destino);

    Map<String, dynamic> cicloDeVidaAtual;
    if (idade < ciclosDeVida['ciclo1']['idadeFim']) {
      cicloDeVidaAtual = ciclosDeVida['ciclo1'];
    } else if (idade < ciclosDeVida['ciclo2']['idadeFim']) {
      cicloDeVidaAtual = ciclosDeVida['ciclo2'];
    } else {
      cicloDeVidaAtual = ciclosDeVida['ciclo3'];
    }

    final triangulo = _calcularTrianguloDaVida();
    final arcanoRegente = triangulo['arcanoRegente'];
    final sequenciaArcanos =
        List<int>.from(triangulo['sequenciaCompletaArcanos']);
    final arcanoAtual = _calcularArcanoAtual(idade, sequenciaArcanos);

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

    return NumerologyResult(
      idade: idade,
      numeros: {
        'diaPessoal': diaPessoal,
        'mesPessoal': mesPessoal,
        'anoPessoal': anoPessoal,
      },
      estruturas: {
        'ciclosDeVida': ciclosDeVida,
        'cicloDeVidaAtual': cicloDeVidaAtual,
        'arcanoRegente': arcanoRegente,
        'arcanoAtual': arcanoAtual,
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
    int anoNascReduzido = _reduzirNumero(dataNascUtc.year);

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
