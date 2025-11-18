// lib/common/widgets/numerology_detail_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

/// Modal que exibe informações detalhadas sobre números numerológicos
/// Suporta dois modos:
/// 1. Modal genérico com número, conteúdo e ícone (para a maioria dos cards)
/// 2. Modal de dias favoráveis com lista de números e textos longos
class NumerologyDetailModal extends StatelessWidget {
  // Modo genérico (usado pela maioria dos cards)
  final String title;
  final String? number;
  final VibrationContent? content;
  final Color? color;
  final IconData? icon;
  final String? categoryIntro;

  // Modo dias favoráveis (lista de números com textos longos)
  final List<int>? numerosFavoraveis;
  final String? explicacao;

  final VoidCallback? onClose;

  const NumerologyDetailModal({
    super.key,
    required this.title,
    this.number,
    this.content,
    this.color,
    this.icon,
    this.categoryIntro,
    this.numerosFavoraveis,
    this.explicacao,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Modo dias favoráveis: exibe lista de números com textos longos
    if (numerosFavoraveis != null && numerosFavoraveis!.isNotEmpty) {
      return _buildDiasFavoraveisModal(context);
    }

    // Modo genérico: exibe informação numerológica completa
    return _buildGenericModal(context);
  }

  /// Modal para dias favoráveis (lista de números com textos inspiradores)
  Widget _buildDiasFavoraveisModal(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    splashRadius: 20,
                  ),
                ],
              ),
              if (explicacao != null) ...[
                const SizedBox(height: 12),
                Text(
                  explicacao!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ...numerosFavoraveis!.map((n) => _buildDiaFavoravelLongo(n)),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal genérico para exibir informações numerológicas completas
  Widget _buildGenericModal(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final displayTitle = content?.tituloTradicional ?? content?.titulo ?? '';

    if (isDesktop) {
      return _buildDesktopModal(context, displayTitle);
    } else {
      return _buildMobileModal(context, displayTitle);
    }
  }

  Widget _buildDesktopModal(BuildContext context, String displayTitle) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(context, displayTitle),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: _buildContent(displayTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileModal(BuildContext context, String displayTitle) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildContent(displayTitle),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayTitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, color: color ?? AppColors.primaryAccent, size: 28),
          if (icon != null) const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            onPressed: onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String displayTitle) {
    if (content == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categoryIntro != null) ...[
          Text(
            categoryIntro!,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Removido: número de destaque para cards multi-número (já está no título)
        // if (number != null) _buildNumberSection(displayTitle),
        // if (number != null) const SizedBox(height: 32),
        _buildDescriptionSection(),
        if (content!.inspiracao.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildInspirationSection(),
        ],
        if (content!.tags.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildTagsSection(),
        ],
      ],
    );
  }

  Widget _buildDescriptionSection() {
    if (content == null) return const SizedBox.shrink();
    // Normaliza quebras de linha vindas do conteúdo: alguns textos podem usar <br> no "banco".
    final normalized = content!.descricaoCompleta
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ');

    final paragraphs =
        normalized.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // Helper local para renderizar um parágrafo aplicando as mesmas regras
    Widget buildParagraph(String text) {
      final t = text.trim();
      // Detectar subtítulo destacado com **texto**
      final subtitleMatch = RegExp(r'^\*\*(.+?)\*\*$').firstMatch(t);
      if (subtitleMatch != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
          child: Text(
            subtitleMatch.group(1)!,
            style: TextStyle(
              color: color ?? AppColors.primaryAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        );
      }

      // Detectar período destacado com *texto* (linha completa em itálico)
      final periodMatch = RegExp(r'^\*(.+?)\*$').firstMatch(t);
      if (periodMatch != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            periodMatch.group(1)!,
            style: TextStyle(
              color: (color ?? AppColors.primaryAccent).withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      // Detectar texto com markdown inline (ex: *Inspiração:* texto normal)
      if (t.contains(RegExp(r'\*[^*]+?\*'))) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildRichTextWithMarkdown(t),
        );
      }

      // Texto normal
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          t,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 16,
            height: 1.7,
          ),
        ),
      );
    }

    // Para cards de número único (InfoCard), inserir subtítulos pedidos:
    // 1) "O que é?" ou "O que são?" antes do primeiro parágrafo
    // 2) "Número: <n>" antes dos demais parágrafos
    final isSingleNumberCard = number != null && number!.trim().isNotEmpty;
    final widgets = <Widget>[];

    if (isSingleNumberCard && paragraphs.isNotEmpty) {
      final titleLower = title.trim().toLowerCase();
      final looksPlural = titleLower.endsWith('s') ||
          titleLower.endsWith('ões') ||
          titleLower.endsWith('ais') ||
          titleLower.endsWith('eis') ||
          titleLower.endsWith('is');

      final firstSubtitle = looksPlural ? 'O que são?' : 'O que é?';
      // Itens especiais: manter apenas "O que são?" e omitir "Número: X"
      final onlyWhatIs = title == 'Desafios' ||
          title == 'Ciclo de Vida' ||
          title == 'Momentos Decisivos';

      // Sempre posicionar os subtítulos em torno do PRIMEIRO parágrafo
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
        child: Text(
          firstSubtitle,
          style: TextStyle(
            color: color ?? AppColors.primaryAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ));
      // Primeiro parágrafo do texto completo
      widgets.add(buildParagraph(paragraphs.first));

      // "Número: X" deve começar a partir do próximo parágrafo (exceto itens especiais)
      if (!onlyWhatIs) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
          child: Text(
            'Número: ${number!}',
            style: TextStyle(
              color: color ?? AppColors.primaryAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ));
      }

      // Demais parágrafos, mantendo itálicos, subtítulos e rich text
      if (paragraphs.length > 1) {
        for (var i = 1; i < paragraphs.length; i++) {
          widgets.add(buildParagraph(paragraphs[i]));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    // Caso contrário (multi-number ou sem número), renderização padrão
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map(buildParagraph).toList(),
    );
  }

  /// Constrói RichText com suporte para *texto* inline (itálico/destaque)
  Widget _buildRichTextWithMarkdown(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*(.+?)\*');
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      // Adiciona texto antes do match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 16,
            height: 1.7,
          ),
        ));
      }

      // Adiciona texto destacado
      spans.add(TextSpan(
        text: match.group(1)!,
        style: TextStyle(
          color: color ?? AppColors.primaryAccent,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          height: 1.7,
        ),
      ));

      lastIndex = match.end;
    }

    // Adiciona texto restante
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 16,
          height: 1.7,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildInspirationSection() {
    if (content == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primaryAccent).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (color ?? AppColors.primaryAccent).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.format_quote,
            color: color ?? AppColors.primaryAccent,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              content!.inspiracao,
              style: TextStyle(
                color: color ?? AppColors.primaryAccent,
                fontSize: 16,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    if (content == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: content!.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primaryAccent).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (color ?? AppColors.primaryAccent).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: color ?? AppColors.primaryAccent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Constrói um item de dia favorável com texto longo inspirador
  Widget _buildDiaFavoravelLongo(int n) {
    final texto = ContentData.textosDiasFavoraveisLongos[n] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  n.toString(),
                  style: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dia Favorável $n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
