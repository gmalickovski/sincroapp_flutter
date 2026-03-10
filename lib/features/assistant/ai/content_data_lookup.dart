// lib/features/assistant/ai/content_data_lookup.dart
//
// Utility que busca dados de numerologia diretamente do ContentData local
// em vez de fazer queries ao Supabase (schema numerologia_core que dá 403).
// Isso elimina latência de rede, evita erros de permissão e reduz tokens.

import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

/// Busca dados de numerologia localmente a partir do ContentData.
class ContentDataLookup {
  ContentDataLookup._();

  /// Busca informações sobre um número específico ou por keyword.
  /// Retorna Map compacto pronto para ser enviado ao LLM.
  static Map<String, dynamic> search({
    required String query,
    int? numero,
  }) {
    final results = <Map<String, dynamic>>[];

    // ── 1. Busca por número específico ──────────────────────────────────
    if (numero != null) {
      _addByNumber(results, numero);
    }

    // ── 2. Busca por keyword na query ───────────────────────────────────
    final queryLower = query.toLowerCase();

    // Buscar nos textos longos dos dias favoráveis
    if (queryLower.contains('dia') || queryLower.contains('favoráv')) {
      _searchDiasText(results, queryLower, numero);
    }

    // Buscar nos ciclos de vida
    if (queryLower.contains('ciclo') || queryLower.contains('vida')) {
      _searchCiclosDeVida(results, queryLower, numero);
    }

    // Buscar no dia natalício
    if (queryLower.contains('natal') ||
        queryLower.contains('nascimento') ||
        queryLower.contains('dia natal')) {
      _searchDiaNatalicio(results, queryLower, numero);
    }

    // Buscar por conceitos genéricos (débito, cármico, destino, etc)
    if (results.isEmpty) {
      _searchGeneric(results, queryLower, numero);
    }

    if (results.isEmpty) {
      return {
        'query': query,
        'results': [],
        'total': 0,
        'note':
            'Nenhum resultado encontrado nos dados locais. Use seu conhecimento interno sobre numerologia para responder.',
      };
    }

    return {
      'query': query,
      'results': results,
      'total': results.length,
    };
  }

  /// Adiciona todas as informações disponíveis sobre um número.
  static void _addByNumber(List<Map<String, dynamic>> results, int numero) {
    // Dia Pessoal
    final diaPessoal = ContentData.vibracoes['diaPessoal']?[numero];
    if (diaPessoal != null) {
      results.add({
        'source': 'dia_pessoal',
        'numero': numero,
        'titulo': diaPessoal.titulo,
        'resumo': diaPessoal.descricaoCurta,
        'descricao': diaPessoal.descricaoCompleta,
        'inspiracao': diaPessoal.inspiracao,
        'tags': diaPessoal.tags,
      });
    }

    // Mês Pessoal
    final mesPessoal = ContentData.vibracoes['mesPessoal']?[numero];
    if (mesPessoal != null) {
      results.add({
        'source': 'mes_pessoal',
        'numero': numero,
        'titulo': mesPessoal.titulo,
        'resumo': mesPessoal.descricaoCurta,
        'descricao': mesPessoal.descricaoCompleta,
        'tags': mesPessoal.tags,
      });
    }

    // Ano Pessoal
    final anoPessoal = ContentData.vibracoes['anoPessoal']?[numero];
    if (anoPessoal != null) {
      results.add({
        'source': 'ano_pessoal',
        'numero': numero,
        'titulo': anoPessoal.titulo,
        'resumo': anoPessoal.descricaoCurta,
        'descricao': anoPessoal.descricaoCompleta,
        'tags': anoPessoal.tags,
      });
    }

    // Ciclo de Vida
    final ciclo = ContentData.textosCiclosDeVida[numero];
    if (ciclo != null) {
      results.add({
        'source': 'ciclo_de_vida',
        'numero': numero,
        'titulo': ciclo.titulo,
        'resumo': ciclo.descricaoCurta,
        'descricao': ciclo.descricaoCompleta,
        'tags': ciclo.tags,
      });
    }

    // Dia Natalício
    final natalicio = ContentData.textosDiaNatalicio[numero];
    if (natalicio != null) {
      results.add({
        'source': 'dia_natalicio',
        'numero': numero,
        'titulo': natalicio.titulo,
        'resumo': natalicio.descricaoCurta,
        'descricao': natalicio.descricaoCompleta,
        'tags': natalicio.tags,
      });
    }

    // Bússola de Atividades
    final bussola = ContentData.bussolaAtividades[numero];
    if (bussola != null) {
      results.add({
        'source': 'bussola_atividades',
        'numero': numero,
        'potencializar': bussola.potencializar,
        'atencao': bussola.atencao,
      });
    }

    // Texto dia favorável longo
    final textoLongo = ContentData.textosDiasFavoraveisLongos[numero];
    if (textoLongo != null) {
      results.add({
        'source': 'significado_dia',
        'numero': numero,
        'texto': textoLongo,
      });
    }
  }

  static void _searchDiasText(
      List<Map<String, dynamic>> results, String query, int? numero) {
    if (numero != null && numero >= 1 && numero <= 31) {
      final texto = ContentData.textosDiasFavoraveisLongos[numero];
      if (texto != null) {
        results.add({
          'source': 'significado_dia',
          'numero': numero,
          'texto': texto,
        });
      }
    }
  }

  static void _searchCiclosDeVida(
      List<Map<String, dynamic>> results, String query, int? numero) {
    if (numero != null) {
      final ciclo = ContentData.textosCiclosDeVida[numero];
      if (ciclo != null) {
        results.add({
          'source': 'ciclo_de_vida',
          'numero': numero,
          'titulo': ciclo.titulo,
          'resumo': ciclo.descricaoCurta,
          'descricao': ciclo.descricaoCompleta,
          'tags': ciclo.tags,
        });
      }
    } else {
      // Return all cycles in compact form
      ContentData.textosCiclosDeVida.forEach((key, value) {
        if (value.titulo.toLowerCase().contains(query) ||
            value.descricaoCurta.toLowerCase().contains(query)) {
          results.add({
            'source': 'ciclo_de_vida',
            'numero': key,
            'titulo': value.titulo,
            'resumo': value.descricaoCurta,
          });
        }
      });
    }
  }

  static void _searchDiaNatalicio(
      List<Map<String, dynamic>> results, String query, int? numero) {
    if (numero != null) {
      final nat = ContentData.textosDiaNatalicio[numero];
      if (nat != null) {
        results.add({
          'source': 'dia_natalicio',
          'numero': numero,
          'titulo': nat.titulo,
          'resumo': nat.descricaoCurta,
          'descricao': nat.descricaoCompleta,
          'tags': nat.tags,
        });
      }
    }
  }

  static void _searchGeneric(
      List<Map<String, dynamic>> results, String query, int? numero) {
    // If we have a number, just add everything about it
    if (numero != null) {
      _addByNumber(results, numero);
      return;
    }

    // Search by keyword across all vibrations
    final allCategories = ['diaPessoal', 'mesPessoal', 'anoPessoal'];
    for (final cat in allCategories) {
      final vibMap = ContentData.vibracoes[cat];
      if (vibMap == null) continue;
      for (final entry in vibMap.entries) {
        final v = entry.value;
        if (v.titulo.toLowerCase().contains(query) ||
            v.descricaoCurta.toLowerCase().contains(query) ||
            v.tags.any((t) => t.toLowerCase().contains(query))) {
          results.add({
            'source': cat,
            'numero': entry.key,
            'titulo': v.titulo,
            'resumo': v.descricaoCurta,
          });
        }
      }
      if (results.length >= 10) break; // Limit results
    }

    // Search in natalicio
    for (final entry in ContentData.textosDiaNatalicio.entries) {
      final v = entry.value;
      if (v.titulo.toLowerCase().contains(query) ||
          v.descricaoCurta.toLowerCase().contains(query) ||
          v.tags.any((t) => t.toLowerCase().contains(query))) {
        results.add({
          'source': 'dia_natalicio',
          'numero': entry.key,
          'titulo': v.titulo,
          'resumo': v.descricaoCurta,
        });
      }
      if (results.length >= 15) break;
    }
  }
}
