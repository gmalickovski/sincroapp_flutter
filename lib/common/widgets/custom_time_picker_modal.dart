// -----------------------------------------------------------------
// ARQUIVO ATUALIZADO: custom_time_picker_modal.dart
// -----------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class CustomTimePickerModal extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePickerModal({super.key, required this.initialTime});

  @override
  State<CustomTimePickerModal> createState() => _CustomTimePickerModalState();
}

class _CustomTimePickerModalState extends State<CustomTimePickerModal> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: AppColors.tertiaryText,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Selecionar horário",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: AppColors.border),

          // <-- MUDANÇA DE ESTILO AQUI (Stack) -->
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. O "Viewfinder" (fundo roxo sutil)
                Container(
                  height: 40, // Mesma altura do itemExtent
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.5), width: 1),
                  ),
                ),

                // 2. Os Seletores (agora sobre o viewfinder)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWheel(
                      controller: _hourController,
                      itemCount: 24, // 24 horas
                      onSelectedItemChanged: (index) {
                        setState(() {
                          // setState atualiza a cor
                          _selectedHour = index;
                          HapticFeedback.lightImpact();
                        });
                      },
                      isHour: true,
                    ),
                    Text(
                      ":",
                      style: TextStyle(
                        color: AppColors.primary, // : fica roxo
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildWheel(
                      controller: _minuteController,
                      itemCount: 60, // 60 minutos
                      onSelectedItemChanged: (index) {
                        setState(() {
                          // setState atualiza a cor
                          _selectedMinute = index;
                          HapticFeedback.lightImpact();
                        });
                      },
                      isHour: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // <-- FIM DA MUDANÇA DE ESTILO -->

          const Divider(color: AppColors.border, height: 1),
          // Botões de Ação
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Retorna null (cancelar)
                    },
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final newTime = TimeOfDay(
                          hour: _selectedHour, minute: _selectedMinute);
                      Navigator.pop(context, newTime); // Retorna a nova hora
                    },
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // <-- MUDANÇA DE ESTILO AQUI (TextStyle dinâmico) -->
  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required bool isHour, // Para saber qual estado verificar
  }) {
    return SizedBox(
      width: 70,
      height: 150,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40, // Altura de cada item
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelectedItemChanged,
        magnification: 1.2, // Mantém o zoom no centro
        useMagnifier: true,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            // 1. Verifica se este item é o selecionado
            final bool isSelected =
                isHour ? (index == _selectedHour) : (index == _selectedMinute);

            // 2. Define o estilo com base na seleção
            final Color color = isSelected
                ? AppColors.primary
                : AppColors.primaryText.withOpacity(0.5);
            final FontWeight fontWeight =
                isSelected ? FontWeight.bold : FontWeight.w500;

            return Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: fontWeight,
              ),
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }
}
