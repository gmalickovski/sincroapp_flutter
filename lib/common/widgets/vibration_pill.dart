// lib/common/widgets/vibration_pill.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

// Helper class para gerir as cores (privada para este arquivo)
class _VibrationColors {
  final Color background;
  final Color text;

  const _VibrationColors({required this.background, required this.text});
}

// Função de helper que mapeia o número para as cores
_VibrationColors getColorsForVibration(int vibrationNumber) {
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

// ATUALIZAÇÃO 1: Enum para definir o tipo da pílula
enum VibrationPillType { standard, compact }

class VibrationPill extends StatelessWidget {
  final int vibrationNumber;
  final VoidCallback? onTap;
  // ATUALIZAÇÃO 2: Novo parâmetro 'type'
  final VibrationPillType type;

  const VibrationPill({
    super.key,
    required this.vibrationNumber,
    this.onTap,
    this.type = VibrationPillType.standard, // O padrão é a versão normal
  });

  @override
  Widget build(BuildContext context) {
    final colors = getColorsForVibration(vibrationNumber);

    // ATUALIZAÇÃO 3: Lógica para renderizar a versão compacta
    if (type == VibrationPillType.compact) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: colors.background,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$vibrationNumber',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Código original para a pílula padrão
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

// O resto do arquivo (showVibrationInfoModal) permanece o mesmo
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

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.only(top: 64),
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
