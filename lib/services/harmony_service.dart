import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class HarmonyService {
  // --- HARMONIA CONJUGAL LOGIC ---

  static const Map<int, Map<String, List<int>>> _tabelaHarmonia = {
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
      'oposto': [7],
      'passivo': [4, 8]
    },
  };

  static const Map<String, String> _detailedDescriptions = {
    'vibra':
        'A sintonia entre vocês é imediata e natural. Vocês tendem a enxergar o mundo sob a mesma ótica, o que facilita enormemente a compreensão mútua e a convivência. É uma relação fluida, onde o apoio e a parceria acontecem sem esforço excessivo, criando um ambiente de paz e crescimento conjunto.',
    'atrai':
        'Existe uma química poderosa e um interesse genuíno entre vocês. As qualidades de um estimulam o outro, gerando admiração e desejo. É uma dinâmica de aprendizado constante, onde as diferenças atuam como um ímã, mantendo a relação excitante e em constante movimento.',
    'oposto':
        'Uma relação de opostos traz desafios, mas também oportunidades únicas de evolução. Vocês veem a vida de ângulos contrários, o que exige diálogo, paciência e negociação. Quando bem trabalhada, essa dupla se torna imbatível, pois juntos vocês cobrem todas as perspectivas possíveis.',
    'passivo':
        'Uma relação tranquila e estável, sem grandes turbulências. Vocês se sentem confortáveis juntos, mas cuidado para não caírem na monotonia. O desafio aqui é manter a chama acesa ativamente, buscando novas aventuras e saindo da zona de conforto para oxigenar a união.',
    'monotonia':
        'Vocês são como espelhos um do outro. O conforto e a identificação são imediatos, mas existe o risco de se isolarem em uma bolha. Para que a relação prospere, é essencial buscarem estímulos externos e novidades que quebrem a rotina e tragam frescor ao convívio.',
  };

  /// Verifica a compatibilidade básica entre dois números de harmonia
  Map<String, dynamic> checkCompatibility(int harmonia1, int harmonia2) {
    if (harmonia1 == harmonia2) {
      if (harmonia1 == 5) {
        return {
          'status': 'Compatíveis (Vibram juntos)',
          'descricao':
              'Vocês possuem o mesmo número (5). Um completa o outro, excelente compatibilidade!',
          'detailedDescription': _detailedDescriptions['vibra']
        };
      }
      return {
        'status': 'Compatíveis (Monotonia)',
        'descricao':
            'Vocês possuem o mesmo número ($harmonia1). São compatíveis e harmônicos, mas o relacionamento tende a tornar-se monótono com o tempo.',
        'detailedDescription': _detailedDescriptions['monotonia']
      };
    }

    final regras = _tabelaHarmonia[harmonia1];
    if (regras == null) {
      return {
        'status': 'Desconhecido',
        'descricao': '',
        'detailedDescription': ''
      };
    }

    if ((regras['vibra'] as List).contains(harmonia2)) {
      return {
        'status': 'Vibram Juntos',
        'descricao':
            'Excelente compatibilidade! O número $harmonia1 vibra em sintonia com o $harmonia2.',
        'detailedDescription': _detailedDescriptions['vibra']
      };
    }
    if ((regras['atrai'] as List).contains(harmonia2)) {
      return {
        'status': 'Atração',
        'descricao':
            'Existe uma forte atração entre os números $harmonia1 e $harmonia2.',
        'detailedDescription': _detailedDescriptions['atrai']
      };
    }
    if ((regras['oposto'] as List).contains(harmonia2)) {
      return {
        'status': 'Opostos',
        'descricao':
            'Os números $harmonia1 e $harmonia2 são opostos. Podem ter um excelente relacionamento se houver sabedoria.',
        'detailedDescription': _detailedDescriptions['oposto']
      };
    }
    if ((regras['passivo'] as List).contains(harmonia2)) {
      return {
        'status': 'Passivo',
        'descricao':
            'A relação entre $harmonia1 e $harmonia2 é passiva. Exige esforço mútuo.',
        'detailedDescription': _detailedDescriptions['passivo']
      };
    }

    return {
      'status': 'Neutro',
      'descricao': 'Relação sem fortes influências numerológicas diretas.',
      'detailedDescription':
          'Uma relação aberta, influenciada principalmente pelas escolhas diárias de cada um, sem fortes tendências numerológicas pré-determinadas.'
    };
  }

  /// Calcula a compatibilidade amorosa (Sinastria) entre dois perfis.
  Map<String, dynamic> calculateSynastry({
    required NumerologyResult profileA,
    required NumerologyResult profileB,
  }) {
    // 1. Harmonia Conjugal (Extraída dos perfis)
    final harmoniaA = profileA.numeros['harmoniaConjugal'] ?? 0;
    final harmoniaB = profileB.numeros['harmoniaConjugal'] ?? 0;
    final match = checkCompatibility(harmoniaA, harmoniaB);

    double score = 50.0; // Base neutra

    switch (match['status']) {
      case 'Compatíveis (Vibram juntos)':
      case 'Compatíveis (Monotonia)':
      case 'Vibram Juntos':
        score = 95.0;
        break;
      case 'Atração':
        score = 85.0;
        break;
      case 'Opostos':
        score = 65.0;
        break;
      case 'Passivo':
        score = 40.0;
        break;
      case 'Neutro':
      default:
        score = 50.0;
    }

    // 2. Ajuste Fino: Destino (Propósito de Vida)
    final destinoA = profileA.numeros['destino']!;
    final destinoB = profileB.numeros['destino']!;

    if (destinoA == destinoB) {
      score += 5;
    } else if ((destinoA % 2) == (destinoB % 2)) {
      score += 2;
    }

    if (score > 100) score = 100;
    if (score < 0) score = 0;

    return {
      'score': score.toInt(),
      'status': match['status'],
      'description': match['descricao'],
      'details': {
        'numA': harmoniaA,
        'numB': harmoniaB,
        'destinyA': profileA.numeros['destino'],
        'expressionA': profileA.numeros['expressao'],
        'destinyB': profileB.numeros['destino'],
        'expressionB': profileB.numeros['expressao'],
        'destinyMatch': (destinoA == destinoB),
        'detailedDescription': match['detailedDescription'],
        // Provide raw rules context for AI
        'vibra': _tabelaHarmonia[harmoniaA]?['vibra'],
        'atrai': _tabelaHarmonia[harmoniaA]?['atrai'],
        'oposto': _tabelaHarmonia[harmoniaA]?['oposto'],
        'passivo': _tabelaHarmonia[harmoniaA]?['passivo'],
      }
    };
  }

  // --- CALENDAR & DATE MATCH ---

  /// Matriz de compatibilidade entre Dias Pessoais
  static const Map<String, double> _personalDayCompatibility = {
    '1-9': 1.0,
    '9-1': 1.0,
    '2-7': 1.0,
    '7-2': 1.0,
    '3-5': 1.0,
    '5-3': 1.0,
    '3-9': 1.0,
    '9-3': 1.0,
    '6-9': 1.0,
    '9-6': 1.0,
    '1-2': 0.8,
    '2-1': 0.8,
    '1-5': 0.8,
    '5-1': 0.8,
    '2-6': 0.8,
    '6-2': 0.8,
    '3-6': 0.8,
    '6-3': 0.8,
    '4-8': 0.8,
    '8-4': 0.8,
    '5-7': 0.8,
    '7-5': 0.8,
    '6-8': 0.8,
    '8-6': 0.8,
    '7-9': 0.8,
    '9-7': 0.8,
    '1-8': 0.8,
    '8-1': 0.8,
    '2-4': 0.8,
    '4-2': 0.8,
    '1-4': 0.3,
    '4-1': 0.3,
    '2-5': 0.3,
    '5-2': 0.3,
    '4-5': 0.3,
    '5-4': 0.3,
    '4-7': 0.3,
    '7-4': 0.3,
    '6-7': 0.3,
    '7-6': 0.3,
  };

  double _getPersonalDayCompatibility(int dpA, int dpB) {
    if (dpA == dpB) return 1.0;
    final key = '$dpA-$dpB';
    return _personalDayCompatibility[key] ?? 0.5;
  }

  double calculateCompatibilityScore({
    required DateTime date,
    required DateTime birthDateA,
    required DateTime birthDateB,
  }) {
    // Uses NumerologyEngine only for raw calculation
    final engineA = NumerologyEngine(
        nomeCompleto: '',
        dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateA));
    final engineB = NumerologyEngine(
        nomeCompleto: '',
        dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateB));

    // 1. Favorable Days (Local month context)
    final daysA =
        engineA.calcularDiasFavoraveis(); // Assuming this is general valid days
    final daysB = engineB.calcularDiasFavoraveis();

    final bool favorableA = daysA.contains(date.day);
    final bool favorableB = daysB.contains(date.day);

    double favorableScore = (favorableA && favorableB)
        ? 1.0
        : (favorableA || favorableB)
            ? 0.5
            : 0.0;

    // 2. Personal Days (Universal Date Context)
    final int dpA = engineA.calculatePersonalDayForDate(date);
    final int dpB = engineB.calculatePersonalDayForDate(date);
    double pdScore = _getPersonalDayCompatibility(dpA, dpB);

    return (favorableScore * 0.5) + (pdScore * 0.5);
  }

  /// Encontra próximas datas compatíveis
  List<DateTime> findNextCompatibleDates({
    required DateTime startDate,
    required DateTime birthDateA,
    required DateTime birthDateB,
    int limit = 5,
  }) {
    final engineA = NumerologyEngine(
        nomeCompleto: '',
        dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateA));
    final engineB = NumerologyEngine(
        nomeCompleto: '',
        dataNascimento: DateFormat('dd/MM/yyyy').format(birthDateB));

    final daysA = engineA.calcularDiasFavoraveis();
    final daysB = engineB.calcularDiasFavoraveis();

    final commonDays = daysA.toSet().intersection(daysB.toSet()).toList()
      ..sort();
    final List<DateTime> results = [];
    DateTime cursor = startDate;

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
