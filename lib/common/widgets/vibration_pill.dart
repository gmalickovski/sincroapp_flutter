import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart'; // Import AppColors
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

// Helper class (inalterada)
class VibrationColors {
  final Color background;
  final Color text;
  const VibrationColors({required this.background, required this.text});
}

// Função getColorsForVibration (inalterada)
VibrationColors getColorsForVibration(int vibrationNumber) {
  // ... (código das cores inalterado) ...
  switch (vibrationNumber) {
    case 1:
      return const VibrationColors(
          background: Color(0xffef4444), text: Colors.white); // Vermelho
    case 2:
      return const VibrationColors(
          background: Color(0xfff97316), text: Colors.white); // Laranja
    case 3:
      return const VibrationColors(
          background: Color(0xffca8a04),
          text: Colors.white); // Amarelo Escuro (Yellow-600)
    case 4:
      return const VibrationColors(
          background: Color(0xff65a30d),
          text: Colors.white); // Verde Lima Escuro (Lime-600)
    case 5:
      return const VibrationColors(
          background: Color(0xff0891b2),
          text: Colors.white); // Ciano Escuro (Cyan-600)
    case 6:
      return const VibrationColors(
          background: Color(0xff3b82f6), text: Colors.white); // Azul
    case 7:
      return const VibrationColors(
          background: Color(0xff8b5cf6), text: Colors.white); // Violeta
    case 8:
      return const VibrationColors(
          background: Color(0xffec4899), text: Colors.white); // Rosa
    case 9:
      return const VibrationColors(
          background: Color(0xff14b8a6), text: Colors.white); // Verde Água
    case 11:
      return const VibrationColors(
          background: Color(0xffa78bfa), text: Colors.white); // Lilás (Mestre)
    case 22:
      return const VibrationColors(
          background: Color(0xff6366f1), text: Colors.white); // Indigo (Mestre)
    default: // Caso 0 ou inesperado
      return const VibrationColors(
          background: Color(0xff6b7280), text: Colors.white); // Cinza
  }
}

// --- INÍCIO DA MUDANÇA: Adiciona o tipo 'micro', 'medium' e 'filterPopup' ---
enum VibrationPillType { standard, compact, micro, medium, filterPopup }
// --- FIM DA MUDANÇA ---

class VibrationPill extends StatelessWidget {
  final int vibrationNumber;
  final VoidCallback? onTap;
  final VibrationPillType type;
  final bool forceInvertedColors;

  const VibrationPill({
    super.key,
    required this.vibrationNumber,
    this.onTap,
    this.type = VibrationPillType.standard,
    this.forceInvertedColors = false,
  });

  @override
  Widget build(BuildContext context) {
    if (vibrationNumber <= 0) {
      return const SizedBox.shrink();
    }

    final baseColors = getColorsForVibration(vibrationNumber);
    final Color effectiveBgColor =
        forceInvertedColors ? baseColors.text : baseColors.background;
    final Color effectiveTextColor =
        forceInvertedColors ? baseColors.background : baseColors.text;

    final VoidCallback? effectiveOnTap = onTap ??
        (type == VibrationPillType.filterPopup
            ? null
            : () {
                showVibrationInfoModal(context,
                    vibrationNumber: vibrationNumber);
              });

    // --- INÍCIO DA MUDANÇA: Lógica para o tipo 'micro' ---
    if (type == VibrationPillType.micro) {
      final text = '$vibrationNumber';
      final len = text.length;

      Widget pillContent;
      BorderRadius borderRadius;

      if (len <= 1) {
        // 1 dígito: mantém círculo micro, levemente maior para melhor leitura
        borderRadius = BorderRadius.circular(8);
        pillContent = Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        );
      } else if (len == 2) {
        // 2 dígitos: vira cápsula (badge) com padding horizontal
        borderRadius = BorderRadius.circular(8);
        pillContent = Container(
          height: 16,
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: effectiveBgColor,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        );
      } else {
        // 3+ dígitos: cápsula um pouco maior com largura mínima maior
        borderRadius = BorderRadius.circular(9);
        pillContent = Container(
          height: 18,
          constraints: const BoxConstraints(minWidth: 28),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: effectiveBgColor,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        );
      }

      // O InkWell para o micro tipo (mantendo o onTap)
      return InkWell(
        onTap: effectiveOnTap,
        borderRadius: borderRadius,
        child: pillContent,
      );
    }
    // --- FIM DA MUDANÇA ---

    // --- INÍCIO DA MUDANÇA: Lógica para o tipo 'medium' (36x36) ---
    if (type == VibrationPillType.medium) {
      Widget pillContent = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$vibrationNumber',
            style: TextStyle(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 14, // Fonte um pouco maior
            ),
          ),
        ),
      );
      return InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(18),
        child: pillContent,
      );
    }
    // --- FIM DA MUDANÇA ---

    // --- INÍCIO DA MUDANÇA: Lógica para o tipo 'filterPopup' (44x44) ---
    if (type == VibrationPillType.filterPopup) {
      Widget pillContent = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$vibrationNumber',
            style: TextStyle(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 15, // Fonte ajustada para 40px
            ),
          ),
        ),
      );
      return InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(20),
        child: pillContent,
      );
    }
    // --- FIM DA MUDANÇA ---

    // Tipo Compact (inalterado - 24x24, fonte 12)
    if (type == VibrationPillType.compact) {
      Widget pillContent = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$vibrationNumber',
            style: TextStyle(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
      return InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(12),
        child: pillContent,
      );
    }

    // Tipo Standard (inalterado)
    Widget pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Dia Pessoal $vibrationNumber',
        style: TextStyle(
          color: effectiveTextColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
    return InkWell(
      onTap: effectiveOnTap,
      borderRadius: BorderRadius.circular(20),
      child: pillContent,
    );
  }
}

// Modal (inalterado)
void showVibrationInfoModal(BuildContext context,
    {required int vibrationNumber}) {
  final vibrationContent = ContentData.vibracoes['diaPessoal']
          ?[vibrationNumber] ??
      const VibrationContent(
        titulo: 'Indisponível',
        descricaoCurta: 'Não foi possível carregar os dados desta vibração.',
        descricaoCompleta: '',
        inspiracao: '',
      );

  final colors = getColorsForVibration(vibrationNumber);

  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              color: AppColors.cardBackground,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header com botão fechar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.secondaryText),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                  ),

                  // Título e Conteúdo
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                      child: Column(
                        children: [
                          // Título Colorido
                          Text(
                            'Dia Pessoal $vibrationNumber',
                            style: TextStyle(
                              color: colors.background, // A cor da vibração
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vibrationContent.titulo,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Divisor sutil
                          Container(
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                                color: colors.background.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 24),

                          // Texto Descritivo
                          Text(
                            vibrationContent.descricaoCompleta.isEmpty
                                ? vibrationContent.descricaoCurta
                                : vibrationContent.descricaoCompleta,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
                              height: 1.6,
                            ),
                            textAlign: TextAlign
                                .center, // Centralizado para leitura fluida
                          ),

                          if (vibrationContent.inspiracao.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.background.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: colors.background
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      color: colors.background),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      vibrationContent.inspiracao,
                                      style: TextStyle(
                                        color: AppColors.primaryText
                                            .withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
