// lib/common/widgets/vibration_pill.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

// Helper class para gerir as cores
class _VibrationColors {
  final Color background;
  final Color text;

  const _VibrationColors({required this.background, required this.text});
}

class VibrationPill extends StatelessWidget {
  final int vibrationNumber;
  final VoidCallback? onTap; // O onTap é opcional

  const VibrationPill({
    super.key,
    required this.vibrationNumber,
    this.onTap,
  });

  // Mapeia o número da vibração para as suas cores correspondentes
  _VibrationColors _getColors() {
    switch (vibrationNumber) {
      case 1:
        return const _VibrationColors(
            background: Color(0xffef4444), text: Colors.white);
      case 2:
        return const _VibrationColors(
            background: Color(0xfff97316), text: Colors.white);
      case 3:
        return const _VibrationColors(
            background: Color(0xffeab308), text: Colors.black);
      case 4:
        return const _VibrationColors(
            background: Color(0xff84cc16), text: Colors.black);
      case 5:
        return const _VibrationColors(
            background: Color(0xff22d3ee), text: Colors.black);
      case 6:
        return const _VibrationColors(
            background: Color(0xff3b82f6), text: Colors.white);
      case 7:
        return const _VibrationColors(
            background: Color(0xff8b5cf6), text: Colors.white);
      case 8:
        return const _VibrationColors(
            background: Color(0xffec4899), text: Colors.white);
      case 9:
        return const _VibrationColors(
            background: Color(0xff14b8a6), text: Colors.white);
      case 11:
        return const _VibrationColors(
            background: Color(0xffa78bfa), text: Colors.white);
      case 22:
        return const _VibrationColors(
            background: Color(0xff6366f1), text: Colors.white);
      default:
        return const _VibrationColors(
            background: Color(0xff6b7280), text: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Vibração $vibrationNumber',
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// --- NOVA FUNÇÃO REUTILIZÁVEL PARA MOSTRAR O MODAL ---
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

  // Usa a mesma função _getColors da pílula para a cor do header do modal
  final colors = VibrationPill(vibrationNumber: vibrationNumber)._getColors();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xff1f2937),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header colorido
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Text(
                'Vibração do Dia: ${vibrationContent.titulo}',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Conteúdo do modal
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  vibrationContent.descricaoCompleta,
                  style: TextStyle(
                    color: Colors.grey.shade300,
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
