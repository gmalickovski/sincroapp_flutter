import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart'; // Import AppColors
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

// Helper class (inalterada)
class _VibrationColors {
  final Color background;
  final Color text;
  const _VibrationColors({required this.background, required this.text});
}

// Função getColorsForVibration (inalterada)
_VibrationColors getColorsForVibration(int vibrationNumber) {
  // ... (código das cores inalterado) ...
  switch (vibrationNumber) {
    case 1:
      return const _VibrationColors(
          background: Color(0xffef4444), text: Colors.white); // Vermelho
    case 2:
      return const _VibrationColors(
          background: Color(0xfff97316), text: Colors.white); // Laranja
    case 3:
      return const _VibrationColors(
          background: Color(0xffeab308), text: Colors.black); // Amarelo
    case 4:
      return const _VibrationColors(
          background: Color(0xff84cc16), text: Colors.black); // Verde Lima
    case 5:
      return const _VibrationColors(
          background: Color(0xff22d3ee), text: Colors.black); // Ciano
    case 6:
      return const _VibrationColors(
          background: Color(0xff3b82f6), text: Colors.white); // Azul
    case 7:
      return const _VibrationColors(
          background: Color(0xff8b5cf6), text: Colors.white); // Violeta
    case 8:
      return const _VibrationColors(
          background: Color(0xffec4899), text: Colors.white); // Rosa
    case 9:
      return const _VibrationColors(
          background: Color(0xff14b8a6), text: Colors.white); // Verde Água
    case 11:
      return const _VibrationColors(
          background: Color(0xffa78bfa), text: Colors.white); // Lilás (Mestre)
    case 22:
      return const _VibrationColors(
          background: Color(0xff6366f1), text: Colors.white); // Indigo (Mestre)
    default: // Caso 0 ou inesperado
      return const _VibrationColors(
          background: Color(0xff6b7280), text: Colors.white); // Cinza
  }
}

// --- INÍCIO DA MUDANÇA: Adiciona o tipo 'micro' ---
enum VibrationPillType { standard, compact, micro }
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

    final VoidCallback effectiveOnTap = onTap ??
        () {
          showVibrationInfoModal(context, vibrationNumber: vibrationNumber);
        };

    // --- INÍCIO DA MUDANÇA: Lógica para o tipo 'micro' ---
    if (type == VibrationPillType.micro) {
      Widget pillContent = Container(
        // Tamanho 16x16
        width: 16,
        height: 16,
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
              // Fonte bem pequena
              fontSize: 8,
            ),
          ),
        ),
      );
      // O InkWell para o micro tipo (mantendo o onTap)
      return InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(8), // Raio correspondente
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
  // ... código inalterado ...
  final vibrationContent = ContentData.vibracoes['diaPessoal']
          ?[vibrationNumber] ??
      const VibrationContent(
        titulo: 'Indisponível',
        descricaoCurta: 'Não foi possível carregar os dados desta vibração.',
        descricaoCompleta: '',
        inspiracao: '',
      );

  final colors = getColorsForVibration(vibrationNumber);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // Fundo transparente para ver bordas
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        // Define altura máxima para evitar cobrir a tela inteira em listas longas
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75, // 75% da altura
        ),
        margin: const EdgeInsets.only(top: 64), // Margem para status bar
        decoration: const BoxDecoration(
          color: AppColors.cardBackground, // Usa cor do app
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Encolhe para caber o conteúdo
          children: [
            // Barra superior colorida com o título
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.background, // Cor da vibração
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Text(
                'Dia Pessoal $vibrationNumber: ${vibrationContent.titulo}',
                style: TextStyle(
                  color: colors.text, // Cor do texto da vibração
                  fontSize: 20, // Um pouco menor
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center, // Centraliza título
              ),
            ),
            // Conteúdo scrollável
            Flexible(
              // Permite que o SingleChildScrollView expanda e encolha
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(24, 16, 24, 24), // Ajusta padding
                child: Text(
                  vibrationContent.descricaoCompleta.isEmpty
                      ? vibrationContent
                          .descricaoCurta // Fallback se completa vazia
                      : vibrationContent.descricaoCompleta,
                  style: const TextStyle(
                    // Usa cores do app
                    color: AppColors.secondaryText,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
